-- Keep installed APKs compatible while routing all mutations through the corrected v2 API.

create or replace function public.dashboard_stats_v2()
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_user_id uuid := auth.uid();
  v_today date := current_date;
  v_sales numeric(14,2) := 0;
  v_cash numeric(14,2) := 0;
  v_bank numeric(14,2) := 0;
  v_mobile numeric(14,2) := 0;
  v_credit numeric(14,2) := 0;
  v_pending integer := 0;
  v_low_stock integer := 0;
  v_customer_debt numeric(14,2) := 0;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager','seller') then raise exception 'Not allowed'; end if;

  select coalesce(sum(s.total_amount-s.refunded_amount),0)
  into v_sales
  from public.sales s
  where s.store_id=v_store_id and s.status='completed' and s.created_at::date=v_today
    and (v_role in ('owner','manager') or s.seller_id=v_user_id);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_cash
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='cash' and cl.occurred_at::date=v_today
    and (v_role in ('owner','manager') or cl.user_id=v_user_id);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_bank
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='bank' and cl.occurred_at::date=v_today
    and (v_role in ('owner','manager') or cl.user_id=v_user_id);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_mobile
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='mobile_money' and cl.occurred_at::date=v_today
    and (v_role in ('owner','manager') or cl.user_id=v_user_id);

  select coalesce(sum(s.total_amount-s.refunded_amount),0)
  into v_credit
  from public.sales s
  where s.store_id=v_store_id and s.status='completed' and s.sale_type='credit'
    and s.created_at::date=v_today
    and (v_role in ('owner','manager') or s.seller_id=v_user_id);

  select count(*) into v_pending
  from public.approval_requests a
  where a.store_id=v_store_id and a.status='pending'
    and (v_role in ('owner','manager') or a.requested_by=v_user_id);

  select count(*) into v_low_stock
  from public.products p
  where p.store_id=v_store_id and p.is_active=true and p.current_stock<=p.reorder_level;

  if v_role in ('owner','manager') then
    select coalesce(sum(c.total_balance),0) into v_customer_debt
    from public.customers c where c.store_id=v_store_id and c.is_active=true;
  end if;

  return jsonb_build_object(
    'today_sales',v_sales,'today_cash',v_cash,'today_bank',v_bank,
    'today_mobile_money',v_mobile,'today_credit',v_credit,
    'pending_approvals',v_pending,'low_stock_items',v_low_stock,
    'customer_debt',v_customer_debt,
    'scope',case when v_role='seller' then 'own' else 'store' end
  );
end;
$$;

create or replace function public.dashboard_stats()
returns jsonb
language sql
security definer
set search_path = public, private
as $$ select public.dashboard_stats_v2() $$;

create or replace function public.create_cash_sale(
  p_customer_id uuid,
  p_items jsonb,
  p_payment_method text,
  p_reference_no text default null,
  p_discount numeric default 0,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if p_payment_method='mixed' then
    raise exception 'Update the app to enter mixed-payment splits';
  end if;
  return public.create_cash_sale_v2(
    p_customer_id,
    p_items,
    jsonb_build_array(jsonb_build_object(
      'payment_method',p_payment_method,
      'amount',(
        select round(sum((item->>'quantity')::numeric*p.selling_price)-coalesce(p_discount,0),2)
        from jsonb_array_elements(p_items) item
        join public.products p on p.id=(item->>'product_id')::uuid
        where p.store_id=public.current_user_store_id()
      ),
      'reference_no',p_reference_no
    )),
    p_discount,
    p_notes,
    'legacy-sale-'||gen_random_uuid()::text
  );
end;
$$;

create or replace function public.request_credit_sale(
  p_customer_id uuid,
  p_items jsonb,
  p_reason text,
  p_discount numeric default 0,
  p_notes text default null
) returns uuid
language sql
security definer
set search_path = public, private
as $$
  select public.request_credit_sale_v2(
    p_customer_id,p_items,p_reason,p_discount,p_notes,
    'legacy-credit-'||gen_random_uuid()::text
  )
$$;

create or replace function public.record_customer_payment(
  p_customer_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_no text default null,
  p_notes text default null
) returns uuid
language sql
security definer
set search_path = public, private
as $$
  select public.record_customer_payment_v2(
    p_customer_id,p_amount,p_payment_method,p_reference_no,p_notes,
    'legacy-customer-payment-'||gen_random_uuid()::text
  )
$$;

create or replace function public.record_purchase(
  p_items jsonb,
  p_supplier_id uuid,
  p_invoice_ref text,
  p_purchase_date date,
  p_payment_status text,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_total numeric(14,2);
  v_paid numeric(14,2);
begin
  if p_payment_status='partial' then
    raise exception 'Update the app to enter the actual partial payment amount';
  end if;
  select coalesce(sum((item->>'quantity')::numeric*(item->>'unit_cost')::numeric),0)
  into v_total from jsonb_array_elements(p_items) item;
  v_paid := case when p_payment_status='paid' then v_total else 0 end;
  return public.record_purchase_v2(
    p_items,p_supplier_id,p_invoice_ref,p_purchase_date,v_paid,'cash',p_notes,
    'legacy-purchase-'||gen_random_uuid()::text
  );
end;
$$;

create or replace function public.record_supplier_payment(
  p_supplier_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_no text default null,
  p_notes text default null
) returns uuid
language sql
security definer
set search_path = public, private
as $$
  select public.record_supplier_payment_v2(
    p_supplier_id,p_amount,p_payment_method,p_reference_no,p_notes,
    'legacy-supplier-payment-'||gen_random_uuid()::text
  )
$$;

create or replace function public.record_expense(
  p_category text,
  p_amount numeric,
  p_payment_method text,
  p_expense_date date,
  p_reference_no text default null,
  p_notes text default null
) returns uuid
language sql
security definer
set search_path = public, private
as $$
  select public.record_expense_v2(
    p_category,p_amount,p_payment_method,p_expense_date,p_reference_no,p_notes,
    'legacy-expense-'||gen_random_uuid()::text
  )
$$;

create or replace function public.record_return(
  p_sale_id uuid,
  p_items jsonb,
  p_refund_method text,
  p_reason text
) returns uuid
language sql
security definer
set search_path = public, private
as $$
  select public.record_return_v2(
    p_sale_id,p_items,p_refund_method,p_reason,
    'legacy-return-'||gen_random_uuid()::text
  )
$$;

create or replace function public.submit_daily_cash_closing(
  p_closing_date date,
  p_actual_cash numeric,
  p_notes text default null
) returns uuid
language sql
security definer
set search_path = public, private
as $$
  select public.submit_daily_cash_closing_v2(p_closing_date,p_actual_cash,p_notes)
$$;

create or replace function public.customer_statement(
  p_customer_id uuid,
  p_from date default null,
  p_to date default null
) returns jsonb
language sql
security definer
set search_path = public, private
as $$
  select public.customer_statement_v2(p_customer_id,p_from,p_to)
$$;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'dashboard_stats','dashboard_stats_v2','create_cash_sale','request_credit_sale',
        'record_customer_payment','record_purchase','record_supplier_payment',
        'record_expense','record_return','submit_daily_cash_closing','customer_statement'
      )
  loop
    execute format('revoke all on function %s from public,anon,authenticated',r.signature);
    execute format('grant execute on function %s to authenticated',r.signature);
  end loop;
end $$;
