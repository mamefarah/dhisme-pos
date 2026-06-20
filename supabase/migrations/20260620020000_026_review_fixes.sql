-- Address PR review findings:
-- 1. Preserve pre-migration supplier debt and allocate historical supplier payments.
-- 2. Make cumulative line refunds reconcile exactly to the original net line total.

alter table public.purchases
  add column if not exists legacy_partial_payment_unknown boolean not null default false;

-- Only rows still carrying the migration defaults are treated as legacy rows.
-- A legacy partial purchase has no recoverable initial paid amount in the old schema,
-- so preserve the full liability and flag it for manual review instead of losing debt.
update public.purchases
set paid_amount = case
      when payment_status = 'paid' then total_amount
      else 0
    end,
    balance_amount = case
      when payment_status = 'paid' then 0
      else total_amount
    end,
    legacy_partial_payment_unknown = payment_status = 'partial'
where coalesce(paid_amount,0) = 0
  and coalesce(balance_amount,0) = 0
  and total_amount > 0;

-- Allocate any historical supplier payment records FIFO after restoring liabilities.
do $$
declare
  v_payment record;
  v_purchase record;
  v_remaining numeric(14,2);
  v_allocate numeric(14,2);
begin
  for v_payment in
    select sp.*,
           sp.amount - coalesce((
             select sum(a.amount)
             from public.supplier_payment_allocations a
             where a.payment_id = sp.id
           ),0) as unallocated
    from public.supplier_payments sp
    order by sp.supplier_id, sp.created_at, sp.id
  loop
    v_remaining := v_payment.unallocated;
    if v_remaining <= 0 then
      continue;
    end if;

    for v_purchase in
      select p.id, p.balance_amount
      from public.purchases p
      where p.store_id = v_payment.store_id
        and p.supplier_id = v_payment.supplier_id
        and p.balance_amount > 0
        and p.created_at <= v_payment.created_at
      order by p.purchase_date, p.created_at, p.id
      for update
    loop
      exit when v_remaining <= 0;
      v_allocate := least(v_remaining, v_purchase.balance_amount);

      insert into public.supplier_payment_allocations(
        store_id, payment_id, purchase_id, amount
      ) values (
        v_payment.store_id, v_payment.id, v_purchase.id, v_allocate
      )
      on conflict (payment_id, purchase_id) do update
      set amount = excluded.amount;

      update public.purchases p
      set paid_amount = least(p.total_amount, p.paid_amount + v_allocate),
          balance_amount = greatest(0, p.balance_amount - v_allocate),
          payment_status = case
            when greatest(0, p.balance_amount - v_allocate) = 0 then 'paid'
            else 'partial'
          end
      where p.id = v_purchase.id;

      v_remaining := v_remaining - v_allocate;
    end loop;
  end loop;

  update public.suppliers s
  set total_balance = coalesce((
        select sum(p.balance_amount)
        from public.purchases p
        where p.store_id = s.store_id
          and p.supplier_id = s.id
      ),0),
      updated_at = now();
end $$;

create or replace function public.record_return_v2(
  p_sale_id uuid,
  p_items jsonb,
  p_refund_method text,
  p_reason text,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_return_id uuid := gen_random_uuid();
  v_return_no text := public.new_return_no();
  v_sale public.sales%rowtype;
  v_sale_item public.sale_items%rowtype;
  v_product public.products%rowtype;
  v_item jsonb;
  v_qty numeric(14,2);
  v_refund numeric(14,2) := 0;
  v_line_refund numeric(14,2);
  v_already_refunded numeric(14,2);
  v_remaining_qty numeric(14,2);
  v_remaining_amount numeric(14,2);
  v_new_balance numeric(14,2);
  v_new_paid numeric(14,2);
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Only owner or manager can process returns'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Return items are required';
  end if;
  if p_refund_method not in ('cash','bank','mobile_money','credit_adjustment') then
    raise exception 'Invalid refund method';
  end if;
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'Return reason is required';
  end if;

  v_claim := private.claim_operation(
    v_store_id,'return',p_idempotency_key,auth.uid()
  );
  if not (v_claim->>'claimed')::boolean then
    return (v_claim->>'result_id')::uuid;
  end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  select * into v_sale
  from public.sales
  where id = p_sale_id
    and store_id = v_store_id
    and status = 'completed'
  for update;
  if not found then raise exception 'Completed sale not found'; end if;

  -- Validate every line and calculate the exact cumulative refund.
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty <= 0 then raise exception 'Return quantity must be positive'; end if;

    select * into v_sale_item
    from public.sale_items
    where id = (v_item->>'sale_item_id')::uuid
      and sale_id = p_sale_id
      and store_id = v_store_id
    for update;
    if not found then raise exception 'Sale item not found'; end if;

    v_remaining_qty := v_sale_item.quantity - v_sale_item.returned_quantity;
    if v_qty > v_remaining_qty then
      raise exception 'Return quantity exceeds remaining sold quantity for %', v_sale_item.product_name;
    end if;

    select coalesce(sum(ri.total_price),0)
    into v_already_refunded
    from public.return_items ri
    join public.returns r on r.id = ri.return_id
    where ri.sale_item_id = v_sale_item.id
      and r.status = 'completed';

    v_remaining_amount := greatest(0, v_sale_item.total_price - v_already_refunded);

    -- The final return receives the exact remaining cents. Partial returns use
    -- the original net line total proportionally, never rounded unit_price.
    if abs(v_qty - v_remaining_qty) <= 0.000001 then
      v_line_refund := v_remaining_amount;
    else
      v_line_refund := least(
        v_remaining_amount,
        round(v_sale_item.total_price * v_qty / v_sale_item.quantity, 2)
      );
    end if;

    if v_line_refund <= 0 then
      raise exception 'No refundable amount remains for %', v_sale_item.product_name;
    end if;
    v_refund := v_refund + v_line_refund;
  end loop;

  if p_refund_method = 'credit_adjustment' then
    if v_sale.sale_type <> 'credit' then
      raise exception 'Credit adjustment is only valid for credit sales';
    end if;
    if v_refund > v_sale.balance_amount then
      raise exception 'Credit adjustment exceeds the outstanding invoice balance';
    end if;
  elsif v_refund > v_sale.paid_amount then
    raise exception 'Cash/bank refund exceeds the amount paid';
  end if;

  insert into public.returns(
    id,store_id,sale_id,customer_id,seller_id,return_no,subtotal,
    refund_amount,refund_method,reason,status,created_by
  ) values (
    v_return_id,v_store_id,p_sale_id,v_sale.customer_id,v_sale.seller_id,
    v_return_no,v_refund,v_refund,p_refund_method,trim(p_reason),'completed',auth.uid()
  );

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;

    select * into v_sale_item
    from public.sale_items
    where id = (v_item->>'sale_item_id')::uuid
      and sale_id = p_sale_id
      and store_id = v_store_id
    for update;

    v_remaining_qty := v_sale_item.quantity - v_sale_item.returned_quantity;
    select coalesce(sum(ri.total_price),0)
    into v_already_refunded
    from public.return_items ri
    join public.returns r on r.id = ri.return_id
    where ri.sale_item_id = v_sale_item.id
      and r.status = 'completed';
    v_remaining_amount := greatest(0, v_sale_item.total_price - v_already_refunded);

    if abs(v_qty - v_remaining_qty) <= 0.000001 then
      v_line_refund := v_remaining_amount;
    else
      v_line_refund := least(
        v_remaining_amount,
        round(v_sale_item.total_price * v_qty / v_sale_item.quantity, 2)
      );
    end if;

    select * into v_product
    from public.products
    where id = v_sale_item.product_id
      and store_id = v_store_id
    for update;

    insert into public.return_items(
      store_id,return_id,sale_item_id,product_id,product_name,unit,
      quantity,unit_price,total_price
    ) values (
      v_store_id,v_return_id,v_sale_item.id,v_sale_item.product_id,
      v_sale_item.product_name,v_sale_item.unit,v_qty,
      round(v_line_refund / v_qty,2),v_line_refund
    );

    update public.sale_items
    set returned_quantity = returned_quantity + v_qty
    where id = v_sale_item.id;

    insert into public.stock_movements(
      store_id,product_id,movement_type,quantity,previous_stock,new_stock,
      reference_id,created_by,approval_status,notes
    ) values (
      v_store_id,v_product.id,'return',v_qty,v_product.current_stock,
      v_product.current_stock + v_qty,v_return_id,auth.uid(),
      'not_required','Return '||v_return_no
    );

    update public.products
    set current_stock = current_stock + v_qty,
        updated_at = now()
    where id = v_product.id;
  end loop;

  if p_refund_method = 'credit_adjustment' then
    v_new_balance := v_sale.balance_amount - v_refund;
    v_new_paid := v_sale.paid_amount;
  else
    v_new_balance := v_sale.balance_amount;
    v_new_paid := v_sale.paid_amount - v_refund;

    insert into public.cash_ledger(
      store_id,user_id,direction,payment_method,amount,
      source_type,source_id,description
    ) values (
      v_store_id,auth.uid(),'outflow',p_refund_method,v_refund,
      'return_refund',v_return_id,'Return '||v_return_no
    );
  end if;

  update public.sales
  set refunded_amount = refunded_amount + v_refund,
      paid_amount = v_new_paid,
      balance_amount = v_new_balance,
      payment_status = case
        when v_new_balance = 0 then 'paid'
        when v_new_paid > 0 then 'partial'
        else 'unpaid'
      end
  where id = p_sale_id;

  if v_sale.customer_id is not null then
    update public.customers c
    set total_balance = coalesce((
      select sum(s.balance_amount)
      from public.sales s
      where s.store_id = c.store_id
        and s.customer_id = c.id
        and s.sale_type = 'credit'
        and s.status = 'completed'
    ),0)
    where c.id = v_sale.customer_id
      and c.store_id = v_store_id;
  end if;

  perform public.log_action(
    'record_return_v2','returns',v_return_id,null,
    jsonb_build_object('sale_id',p_sale_id,'refund',v_refund)
  );
  perform private.complete_operation(v_guard_id,v_return_id);
  return v_return_id;
end;
$$;

revoke all on function public.record_return_v2(uuid,jsonb,text,text,text)
  from public, anon, authenticated;
grant execute on function public.record_return_v2(uuid,jsonb,text,text,text)
  to authenticated;
