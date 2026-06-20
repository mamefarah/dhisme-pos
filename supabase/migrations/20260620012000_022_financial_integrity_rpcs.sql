-- Audit remediation phase 3: v2 transactional APIs.
-- These functions are additive so the existing APK remains compatible during rollout.

create or replace function public.create_cash_sale_v2(
  p_customer_id uuid,
  p_items jsonb,
  p_payments jsonb,
  p_discount numeric default 0,
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_sale_id uuid := gen_random_uuid();
  v_invoice text := public.new_invoice_no();
  v_subtotal numeric(14,2) := 0;
  v_total numeric(14,2);
  v_payment_total numeric(14,2) := 0;
  v_discount_rate numeric := 0;
  v_item jsonb;
  v_pay jsonb;
  v_product public.products%rowtype;
  v_qty numeric(14,2);
  v_line_gross numeric(14,2);
  v_line_net numeric(14,2);
  v_effective_unit numeric(14,4);
  v_method text;
  v_amount numeric(14,2);
  v_payment_count integer := 0;
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager','seller') then raise exception 'Not allowed'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then
    raise exception 'Sale items are required';
  end if;
  if p_payments is null or jsonb_typeof(p_payments) <> 'array' or jsonb_array_length(p_payments)=0 then
    raise exception 'At least one payment is required';
  end if;
  if coalesce(p_discount,0) < 0 then raise exception 'Discount cannot be negative'; end if;

  v_claim := private.claim_operation(v_store_id, 'cash_sale', p_idempotency_key, auth.uid());
  if not (v_claim->>'claimed')::boolean then
    return (v_claim->>'result_id')::uuid;
  end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  if p_customer_id is not null and not exists (
    select 1 from public.customers
    where id=p_customer_id and store_id=v_store_id and is_active=true
  ) then
    raise exception 'Customer not found in this store';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty <= 0 then raise exception 'Quantity must be positive'; end if;

    select * into v_product
    from public.products
    where id=(v_item->>'product_id')::uuid
      and store_id=v_store_id
      and is_active=true
    for update;

    if not found then raise exception 'Product not found'; end if;
    if v_product.current_stock < v_qty then raise exception 'Insufficient stock for %', v_product.name; end if;

    v_subtotal := v_subtotal + round(v_qty * v_product.selling_price,2);
  end loop;

  if p_discount > v_subtotal then raise exception 'Discount cannot exceed subtotal'; end if;
  if v_subtotal <= 0 then raise exception 'Sale total must be positive'; end if;

  v_total := round(v_subtotal - coalesce(p_discount,0),2);
  if v_total <= 0 then raise exception 'Zero-value sales are not allowed'; end if;
  v_discount_rate := coalesce(p_discount,0) / v_subtotal;

  if v_role='seller' and v_discount_rate > 0.02 then
    raise exception 'Seller discount exceeds the 2%% limit';
  elsif v_role='manager' and v_discount_rate > 0.05 then
    raise exception 'Manager discount exceeds the 5%% limit';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_product from public.products
    where id=(v_item->>'product_id')::uuid and store_id=v_store_id for update;
    v_line_gross := round(v_qty * v_product.selling_price,2);
    v_line_net := round(v_line_gross * (1-v_discount_rate),2);
    v_effective_unit := v_line_net / v_qty;
    if v_effective_unit < v_product.minimum_selling_price then
      raise exception 'Discount places % below its minimum selling price', v_product.name;
    end if;
  end loop;

  for v_pay in select * from jsonb_array_elements(p_payments) loop
    v_method := v_pay->>'payment_method';
    v_amount := (v_pay->>'amount')::numeric;
    if v_method not in ('cash','bank','mobile_money') then raise exception 'Invalid payment method'; end if;
    if v_amount <= 0 then raise exception 'Payment amount must be positive'; end if;
    v_payment_total := v_payment_total + v_amount;
    v_payment_count := v_payment_count + 1;
  end loop;

  if abs(v_payment_total-v_total) > 0.01 then
    raise exception 'Payment split (%) must equal sale total (%)', v_payment_total, v_total;
  end if;

  insert into public.sales(
    id,store_id,seller_id,customer_id,invoice_no,sale_type,subtotal,discount,total_amount,
    paid_amount,balance_amount,payment_status,approval_status,status,notes,payment_method,refunded_amount
  ) values (
    v_sale_id,v_store_id,auth.uid(),p_customer_id,v_invoice,'cash',v_subtotal,coalesce(p_discount,0),v_total,
    v_total,0,'paid','not_required','completed',p_notes,
    case when v_payment_count>1 then 'mixed' else (p_payments->0->>'payment_method') end,0
  );

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_product from public.products
    where id=(v_item->>'product_id')::uuid and store_id=v_store_id for update;
    v_line_gross := round(v_qty * v_product.selling_price,2);
    v_line_net := round(v_line_gross * (1-v_discount_rate),2);
    v_effective_unit := v_line_net / v_qty;

    insert into public.sale_items(
      store_id,sale_id,product_id,product_name,unit,quantity,unit_price,total_price,
      buying_price_at_sale,gross_profit,returned_quantity
    ) values (
      v_store_id,v_sale_id,v_product.id,v_product.name,v_product.unit,v_qty,
      round(v_effective_unit,2),v_line_net,v_product.buying_price,
      round(v_line_net-(v_product.buying_price*v_qty),2),0
    );

    insert into public.stock_movements(
      store_id,product_id,movement_type,quantity,previous_stock,new_stock,reference_id,
      created_by,approval_status,notes
    ) values (
      v_store_id,v_product.id,'sale',v_qty,v_product.current_stock,v_product.current_stock-v_qty,
      v_sale_id,auth.uid(),'not_required','Sale '||v_invoice
    );

    update public.products
    set current_stock=current_stock-v_qty, updated_at=now()
    where id=v_product.id;
  end loop;

  for v_pay in select * from jsonb_array_elements(p_payments) loop
    v_method := v_pay->>'payment_method';
    v_amount := (v_pay->>'amount')::numeric;
    declare
      v_payment_id uuid := gen_random_uuid();
    begin
      insert into public.payments(id,store_id,sale_id,customer_id,seller_id,amount,payment_method,reference_no,notes)
      values (
        v_payment_id,v_store_id,v_sale_id,p_customer_id,auth.uid(),v_amount,v_method,
        nullif(trim(coalesce(v_pay->>'reference_no','')),''),p_notes
      );
      insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description)
      values (v_store_id,auth.uid(),'inflow',v_method,v_amount,'sale_payment',v_payment_id,'Sale '||v_invoice);
    end;
  end loop;

  perform public.log_action('create_cash_sale_v2','sales',v_sale_id,null,
    jsonb_build_object('invoice_no',v_invoice,'total',v_total,'payment_count',v_payment_count));
  perform private.complete_operation(v_guard_id,v_sale_id);
  return v_sale_id;
end;
$$;

create or replace function public.request_credit_sale_v2(
  p_customer_id uuid,
  p_items jsonb,
  p_reason text,
  p_discount numeric default 0,
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_sale_id uuid := gen_random_uuid();
  v_request_id uuid := gen_random_uuid();
  v_invoice text := public.new_invoice_no();
  v_subtotal numeric(14,2):=0;
  v_total numeric(14,2);
  v_pending numeric(14,2):=0;
  v_discount_rate numeric:=0;
  v_item jsonb;
  v_product public.products%rowtype;
  v_customer public.customers%rowtype;
  v_qty numeric(14,2);
  v_line_gross numeric(14,2);
  v_line_net numeric(14,2);
  v_effective_unit numeric(14,4);
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager','seller') then raise exception 'Not allowed'; end if;
  if p_customer_id is null then raise exception 'Credit sale requires customer'; end if;
  if p_reason is null or length(trim(p_reason))<3 then raise exception 'Reason is required'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Sale items are required'; end if;

  v_claim := private.claim_operation(v_store_id,'credit_sale_request',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then return (v_claim->>'result_id')::uuid; end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  select * into v_customer from public.customers
  where id=p_customer_id and store_id=v_store_id and is_active=true
  for update;
  if not found then raise exception 'Customer not found'; end if;
  if v_customer.credit_blocked then raise exception 'Customer is blocked from credit sales'; end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty<=0 then raise exception 'Quantity must be positive'; end if;
    select * into v_product from public.products
    where id=(v_item->>'product_id')::uuid and store_id=v_store_id and is_active=true;
    if not found then raise exception 'Product not found'; end if;
    if v_product.current_stock<v_qty then raise exception 'Insufficient stock for %',v_product.name; end if;
    v_subtotal := v_subtotal + round(v_qty*v_product.selling_price,2);
  end loop;

  if coalesce(p_discount,0)<0 or p_discount>v_subtotal then raise exception 'Invalid discount'; end if;
  v_total := round(v_subtotal-coalesce(p_discount,0),2);
  if v_total<=0 then raise exception 'Zero-value credit sales are not allowed'; end if;
  v_discount_rate := coalesce(p_discount,0)/v_subtotal;
  if v_role='seller' and v_discount_rate>0.02 then raise exception 'Seller discount exceeds the 2%% limit'; end if;
  if v_role='manager' and v_discount_rate>0.05 then raise exception 'Manager discount exceeds the 5%% limit'; end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_product from public.products
    where id=(v_item->>'product_id')::uuid and store_id=v_store_id;
    v_line_gross := round(v_qty*v_product.selling_price,2);
    v_line_net := round(v_line_gross*(1-v_discount_rate),2);
    v_effective_unit := v_line_net/v_qty;
    if v_effective_unit<v_product.minimum_selling_price then
      raise exception 'Discount places % below its minimum selling price',v_product.name;
    end if;
  end loop;

  select coalesce(sum(s.balance_amount),0) into v_pending
  from public.sales s
  where s.store_id=v_store_id and s.customer_id=p_customer_id
    and s.sale_type='credit' and s.status='draft' and s.approval_status='pending';

  if v_customer.credit_limit>0 and (v_customer.total_balance+v_pending+v_total)>v_customer.credit_limit then
    raise exception 'Credit exposure would exceed the customer limit';
  end if;

  insert into public.sales(
    id,store_id,seller_id,customer_id,invoice_no,sale_type,subtotal,discount,total_amount,
    paid_amount,balance_amount,payment_status,approval_status,status,notes,payment_method,refunded_amount
  ) values (
    v_sale_id,v_store_id,auth.uid(),p_customer_id,v_invoice,'credit',v_subtotal,coalesce(p_discount,0),v_total,
    0,v_total,'unpaid','pending','draft',p_notes,null,0
  );

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_product from public.products
    where id=(v_item->>'product_id')::uuid and store_id=v_store_id;
    v_line_gross := round(v_qty*v_product.selling_price,2);
    v_line_net := round(v_line_gross*(1-v_discount_rate),2);
    v_effective_unit := v_line_net/v_qty;
    insert into public.sale_items(
      store_id,sale_id,product_id,product_name,unit,quantity,unit_price,total_price,
      buying_price_at_sale,gross_profit,returned_quantity
    ) values (
      v_store_id,v_sale_id,v_product.id,v_product.name,v_product.unit,v_qty,
      round(v_effective_unit,2),v_line_net,v_product.buying_price,
      round(v_line_net-(v_product.buying_price*v_qty),2),0
    );
  end loop;

  insert into public.approval_requests(id,store_id,requested_by,request_type,reference_id,amount,reason)
  values (v_request_id,v_store_id,auth.uid(),'credit_sale',v_sale_id,v_total,trim(p_reason));

  insert into public.notifications(store_id,user_id,title,message,type)
  select v_store_id,id,'Credit sale approval needed',
         'A credit sale of ETB '||v_total||' needs approval.','approval'
  from public.profiles
  where store_id=v_store_id and role='owner' and is_active=true;

  perform public.log_action('request_credit_sale_v2','approval_requests',v_request_id,null,
    jsonb_build_object('sale_id',v_sale_id,'total',v_total));
  perform private.complete_operation(v_guard_id,v_request_id);
  return v_request_id;
end;
$$;

-- Replaces the legacy approval function with a credit-limit recheck under lock.
create or replace function public.decide_approval_request(
  p_request_id uuid,
  p_decision text,
  p_owner_comment text default null
) returns void
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_req public.approval_requests%rowtype;
  v_sale public.sales%rowtype;
  v_item public.sale_items%rowtype;
  v_product public.products%rowtype;
  v_customer public.customers%rowtype;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role<>'owner' then raise exception 'Only owner can approve requests'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Invalid decision'; end if;

  select * into v_req from public.approval_requests
  where id=p_request_id and store_id=v_store_id and status='pending'
  for update;
  if not found then raise exception 'Pending request not found'; end if;

  if v_req.request_type='credit_sale' then
    select * into v_sale from public.sales
    where id=v_req.reference_id and store_id=v_store_id and status='draft'
    for update;
    if not found then raise exception 'Draft sale not found'; end if;

    if p_decision='rejected' then
      update public.approval_requests set status='rejected',approved_by=auth.uid(),owner_comment=p_owner_comment,decided_at=now()
      where id=p_request_id;
      update public.sales set approval_status='rejected',status='cancelled' where id=v_sale.id;
      perform public.log_action('reject_credit_sale','sales',v_sale.id,null,jsonb_build_object('request_id',p_request_id));
      return;
    end if;

    select * into v_customer from public.customers
    where id=v_sale.customer_id and store_id=v_store_id
    for update;
    if not found or v_customer.credit_blocked then raise exception 'Customer is unavailable for credit'; end if;
    if v_customer.credit_limit>0 and (v_customer.total_balance+v_sale.balance_amount)>v_customer.credit_limit then
      raise exception 'Credit limit exceeded at approval time';
    end if;

    for v_item in select * from public.sale_items where sale_id=v_sale.id loop
      select * into v_product from public.products
      where id=v_item.product_id and store_id=v_store_id for update;
      if not found then raise exception 'Product not found'; end if;
      if v_product.current_stock<v_item.quantity then raise exception 'Insufficient stock for % at approval time',v_product.name; end if;
    end loop;

    for v_item in select * from public.sale_items where sale_id=v_sale.id loop
      select * into v_product from public.products
      where id=v_item.product_id and store_id=v_store_id for update;
      insert into public.stock_movements(store_id,product_id,movement_type,quantity,previous_stock,new_stock,reference_id,created_by,approval_status,notes)
      values (v_store_id,v_product.id,'sale',v_item.quantity,v_product.current_stock,v_product.current_stock-v_item.quantity,v_sale.id,v_sale.seller_id,'approved','Credit sale approved '||v_sale.invoice_no);
      update public.products set current_stock=current_stock-v_item.quantity,updated_at=now() where id=v_product.id;
    end loop;

    update public.sales set approval_status='approved',status='completed' where id=v_sale.id;
    update public.customers set total_balance=total_balance+v_sale.balance_amount where id=v_sale.customer_id and store_id=v_store_id;
    update public.approval_requests set status='approved',approved_by=auth.uid(),owner_comment=p_owner_comment,decided_at=now() where id=p_request_id;
    insert into public.notifications(store_id,user_id,title,message,type)
    values (v_store_id,v_sale.seller_id,'Credit sale approved','Your credit sale '||v_sale.invoice_no||' was approved.','approval_decision');
    perform public.log_action('approve_credit_sale','sales',v_sale.id,null,jsonb_build_object('request_id',p_request_id));
  else
    update public.approval_requests set status=p_decision,approved_by=auth.uid(),owner_comment=p_owner_comment,decided_at=now()
    where id=p_request_id;
  end if;
end;
$$;

create or replace function public.record_customer_payment_v2(
  p_customer_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_no text default null,
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_payment_id uuid := gen_random_uuid();
  v_customer public.customers%rowtype;
  v_sale record;
  v_remaining numeric(14,2);
  v_allocate numeric(14,2);
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager','seller') then raise exception 'Not allowed'; end if;
  if p_amount<=0 then raise exception 'Payment amount must be greater than zero'; end if;
  if p_payment_method not in ('cash','bank','mobile_money') then raise exception 'Invalid payment method'; end if;

  v_claim := private.claim_operation(v_store_id,'customer_payment',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then return (v_claim->>'result_id')::uuid; end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  select * into v_customer from public.customers
  where id=p_customer_id and store_id=v_store_id for update;
  if not found then raise exception 'Customer not found'; end if;
  if p_amount>v_customer.total_balance then raise exception 'Payment exceeds outstanding balance'; end if;

  insert into public.customer_payments(id,store_id,customer_id,received_by,amount,payment_method,reference_no,notes)
  values (v_payment_id,v_store_id,p_customer_id,auth.uid(),p_amount,p_payment_method,
          nullif(trim(coalesce(p_reference_no,'')),''),nullif(trim(coalesce(p_notes,'')),''));

  v_remaining := p_amount;
  for v_sale in
    select id,balance_amount
    from public.sales
    where store_id=v_store_id and customer_id=p_customer_id and sale_type='credit'
      and status='completed' and balance_amount>0
    order by created_at,id
    for update
  loop
    exit when v_remaining<=0;
    v_allocate := least(v_remaining,v_sale.balance_amount);
    insert into public.customer_payment_allocations(store_id,payment_id,sale_id,amount)
    values (v_store_id,v_payment_id,v_sale.id,v_allocate);
    update public.sales
    set paid_amount=paid_amount+v_allocate,
        balance_amount=balance_amount-v_allocate,
        payment_status=case when balance_amount-v_allocate=0 then 'paid' else 'partial' end
    where id=v_sale.id;
    v_remaining := v_remaining-v_allocate;
  end loop;
  if v_remaining>0.01 then raise exception 'Could not allocate the entire customer payment'; end if;

  update public.customers c
  set total_balance=coalesce((select sum(s.balance_amount) from public.sales s
    where s.store_id=c.store_id and s.customer_id=c.id and s.sale_type='credit' and s.status='completed'),0)
  where c.id=p_customer_id and c.store_id=v_store_id;

  insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description)
  values (v_store_id,auth.uid(),'inflow',p_payment_method,p_amount,'customer_payment',v_payment_id,'Customer payment');

  perform public.log_action('record_customer_payment_v2','customer_payments',v_payment_id,null,
    jsonb_build_object('customer_id',p_customer_id,'amount',p_amount));
  perform private.complete_operation(v_guard_id,v_payment_id);
  return v_payment_id;
end;
$$;

create or replace function public.record_purchase_v2(
  p_items jsonb,
  p_supplier_id uuid,
  p_invoice_ref text,
  p_purchase_date date,
  p_paid_amount numeric,
  p_payment_method text,
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_purchase_id uuid := gen_random_uuid();
  v_supplier_payment_id uuid;
  v_total numeric(14,2):=0;
  v_balance numeric(14,2);
  v_status text;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty numeric(14,2);
  v_cost numeric(14,2);
  v_line numeric(14,2);
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Only owner or manager can record purchases'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Purchase items are required'; end if;
  if coalesce(p_paid_amount,0)<0 then raise exception 'Paid amount cannot be negative'; end if;
  if coalesce(p_paid_amount,0)>0 and p_payment_method not in ('cash','bank','mobile_money') then raise exception 'Invalid payment method'; end if;

  v_claim := private.claim_operation(v_store_id,'purchase',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then return (v_claim->>'result_id')::uuid; end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  if p_supplier_id is not null and not exists(select 1 from public.suppliers where id=p_supplier_id and store_id=v_store_id and is_active=true) then
    raise exception 'Supplier not found in this store';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    v_cost := (v_item->>'unit_cost')::numeric;
    if v_qty<=0 or v_cost<0 then raise exception 'Invalid purchase item'; end if;
    select * into v_product from public.products
    where id=(v_item->>'product_id')::uuid and store_id=v_store_id for update;
    if not found then raise exception 'Product not found'; end if;
    v_total := v_total+round(v_qty*v_cost,2);
  end loop;

  if coalesce(p_paid_amount,0)>v_total then raise exception 'Paid amount cannot exceed purchase total'; end if;
  v_balance := v_total-coalesce(p_paid_amount,0);
  if v_balance>0 and p_supplier_id is null then raise exception 'A supplier is required for unpaid or partial purchases'; end if;
  v_status := case when v_balance=0 then 'paid' when coalesce(p_paid_amount,0)=0 then 'unpaid' else 'partial' end;

  insert into public.purchases(id,store_id,supplier_id,invoice_ref,purchase_date,payment_status,total_amount,paid_amount,balance_amount,payment_method,notes,recorded_by)
  values (v_purchase_id,v_store_id,p_supplier_id,nullif(trim(coalesce(p_invoice_ref,'')),''),coalesce(p_purchase_date,current_date),
          v_status,v_total,coalesce(p_paid_amount,0),v_balance,case when p_paid_amount>0 then p_payment_method else null end,p_notes,auth.uid());

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    v_cost := (v_item->>'unit_cost')::numeric;
    select * into v_product from public.products
    where id=(v_item->>'product_id')::uuid and store_id=v_store_id for update;
    v_line := round(v_qty*v_cost,2);
    insert into public.purchase_items(store_id,purchase_id,product_id,product_name,unit,quantity,unit_cost,total_cost)
    values (v_store_id,v_purchase_id,v_product.id,v_product.name,v_product.unit,v_qty,v_cost,v_line);
    insert into public.stock_movements(store_id,product_id,movement_type,quantity,previous_stock,new_stock,reference_id,created_by,approval_status,notes)
    values (v_store_id,v_product.id,'purchase',v_qty,v_product.current_stock,v_product.current_stock+v_qty,v_purchase_id,auth.uid(),'not_required','Purchase stock-in');
    update public.products set current_stock=current_stock+v_qty,buying_price=v_cost,updated_at=now() where id=v_product.id;
  end loop;

  if p_supplier_id is not null then
    update public.suppliers set total_balance=total_balance+v_balance,updated_at=now() where id=p_supplier_id;
  end if;

  if coalesce(p_paid_amount,0)>0 and p_supplier_id is not null then
    v_supplier_payment_id := gen_random_uuid();
    insert into public.supplier_payments(id,store_id,supplier_id,amount,payment_method,reference_no,notes,paid_by)
    values (v_supplier_payment_id,v_store_id,p_supplier_id,p_paid_amount,p_payment_method,p_invoice_ref,'Initial purchase payment',auth.uid());
    insert into public.supplier_payment_allocations(store_id,payment_id,purchase_id,amount)
    values (v_store_id,v_supplier_payment_id,v_purchase_id,p_paid_amount);
    insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description)
    values (v_store_id,auth.uid(),'outflow',p_payment_method,p_paid_amount,'purchase_payment',v_supplier_payment_id,'Purchase payment');
  elsif coalesce(p_paid_amount,0)>0 then
    insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description)
    values (v_store_id,auth.uid(),'outflow',p_payment_method,p_paid_amount,'purchase_payment',v_purchase_id,'Purchase payment');
  end if;

  perform public.log_action('record_purchase_v2','purchases',v_purchase_id,null,jsonb_build_object('total',v_total,'paid',p_paid_amount,'balance',v_balance));
  perform private.complete_operation(v_guard_id,v_purchase_id);
  return v_purchase_id;
end;
$$;

create or replace function public.record_supplier_payment_v2(
  p_supplier_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_no text default null,
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_payment_id uuid := gen_random_uuid();
  v_supplier public.suppliers%rowtype;
  v_purchase record;
  v_remaining numeric(14,2);
  v_allocate numeric(14,2);
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Only owner or manager can pay suppliers'; end if;
  if p_amount<=0 then raise exception 'Payment amount must be positive'; end if;
  if p_payment_method not in ('cash','bank','mobile_money') then raise exception 'Invalid payment method'; end if;

  v_claim := private.claim_operation(v_store_id,'supplier_payment',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then return (v_claim->>'result_id')::uuid; end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  select * into v_supplier from public.suppliers
  where id=p_supplier_id and store_id=v_store_id for update;
  if not found then raise exception 'Supplier not found'; end if;
  if p_amount>v_supplier.total_balance then raise exception 'Payment exceeds supplier balance'; end if;

  insert into public.supplier_payments(id,store_id,supplier_id,amount,payment_method,reference_no,notes,paid_by)
  values (v_payment_id,v_store_id,p_supplier_id,p_amount,p_payment_method,
          nullif(trim(coalesce(p_reference_no,'')),''),nullif(trim(coalesce(p_notes,'')),''),auth.uid());

  v_remaining := p_amount;
  for v_purchase in
    select id,balance_amount
    from public.purchases
    where store_id=v_store_id and supplier_id=p_supplier_id and balance_amount>0
    order by purchase_date,created_at,id
    for update
  loop
    exit when v_remaining<=0;
    v_allocate := least(v_remaining,v_purchase.balance_amount);
    insert into public.supplier_payment_allocations(store_id,payment_id,purchase_id,amount)
    values (v_store_id,v_payment_id,v_purchase.id,v_allocate);
    update public.purchases
    set paid_amount=paid_amount+v_allocate,
        balance_amount=balance_amount-v_allocate,
        payment_status=case when balance_amount-v_allocate=0 then 'paid' else 'partial' end
    where id=v_purchase.id;
    v_remaining := v_remaining-v_allocate;
  end loop;
  if v_remaining>0.01 then raise exception 'Could not allocate the entire supplier payment'; end if;

  update public.suppliers s
  set total_balance=coalesce((select sum(p.balance_amount) from public.purchases p
    where p.store_id=s.store_id and p.supplier_id=s.id),0),updated_at=now()
  where s.id=p_supplier_id and s.store_id=v_store_id;

  insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description)
  values (v_store_id,auth.uid(),'outflow',p_payment_method,p_amount,'supplier_payment',v_payment_id,'Supplier payment');

  perform public.log_action('record_supplier_payment_v2','supplier_payments',v_payment_id,null,jsonb_build_object('supplier_id',p_supplier_id,'amount',p_amount));
  perform private.complete_operation(v_guard_id,v_payment_id);
  return v_payment_id;
end;
$$;

create or replace function public.record_expense_v2(
  p_category text,
  p_amount numeric,
  p_payment_method text,
  p_expense_date date,
  p_reference_no text default null,
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_id uuid := gen_random_uuid();
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Only owner or manager can record expenses'; end if;
  if p_category is null or length(trim(p_category))<2 then raise exception 'Expense category is required'; end if;
  if p_amount<=0 then raise exception 'Expense amount must be positive'; end if;
  if p_payment_method not in ('cash','bank','mobile_money') then raise exception 'Invalid payment method'; end if;

  v_claim := private.claim_operation(v_store_id,'expense',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then return (v_claim->>'result_id')::uuid; end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  insert into public.expenses(id,store_id,category,amount,expense_date,payment_method,reference_no,notes,created_by)
  values (v_id,v_store_id,trim(p_category),p_amount,coalesce(p_expense_date,current_date),p_payment_method,
          nullif(trim(coalesce(p_reference_no,'')),''),nullif(trim(coalesce(p_notes,'')),''),auth.uid());

  insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description,occurred_at)
  values (v_store_id,auth.uid(),'outflow',p_payment_method,p_amount,'expense',v_id,trim(p_category),
          coalesce(p_expense_date,current_date)::timestamptz + current_time);

  perform public.log_action('record_expense_v2','expenses',v_id,null,jsonb_build_object('amount',p_amount,'category',p_category));
  perform private.complete_operation(v_guard_id,v_id);
  return v_id;
end;
$$;

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
  v_refund numeric(14,2):=0;
  v_new_balance numeric(14,2);
  v_new_paid numeric(14,2);
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Only owner or manager can process returns'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Return items are required'; end if;
  if p_refund_method not in ('cash','bank','mobile_money','credit_adjustment') then raise exception 'Invalid refund method'; end if;
  if p_reason is null or length(trim(p_reason))<3 then raise exception 'Return reason is required'; end if;

  v_claim := private.claim_operation(v_store_id,'return',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then return (v_claim->>'result_id')::uuid; end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  select * into v_sale from public.sales
  where id=p_sale_id and store_id=v_store_id and status='completed'
  for update;
  if not found then raise exception 'Completed sale not found'; end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty<=0 then raise exception 'Return quantity must be positive'; end if;
    select * into v_sale_item from public.sale_items
    where id=(v_item->>'sale_item_id')::uuid and sale_id=p_sale_id and store_id=v_store_id
    for update;
    if not found then raise exception 'Sale item not found'; end if;
    if v_sale_item.returned_quantity+v_qty>v_sale_item.quantity then raise exception 'Return quantity exceeds remaining sold quantity for %',v_sale_item.product_name; end if;
    v_refund := v_refund+round(v_qty*v_sale_item.unit_price,2);
  end loop;

  if p_refund_method='credit_adjustment' then
    if v_sale.sale_type<>'credit' then raise exception 'Credit adjustment is only valid for credit sales'; end if;
    if v_refund>v_sale.balance_amount then raise exception 'Credit adjustment exceeds the outstanding invoice balance'; end if;
  else
    if v_refund>v_sale.paid_amount then raise exception 'Cash/bank refund exceeds the amount paid'; end if;
  end if;

  insert into public.returns(id,store_id,sale_id,customer_id,seller_id,return_no,subtotal,refund_amount,refund_method,reason,status,created_by)
  values (v_return_id,v_store_id,p_sale_id,v_sale.customer_id,v_sale.seller_id,v_return_no,v_refund,v_refund,p_refund_method,trim(p_reason),'completed',auth.uid());

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_sale_item from public.sale_items
    where id=(v_item->>'sale_item_id')::uuid and sale_id=p_sale_id and store_id=v_store_id
    for update;
    select * into v_product from public.products where id=v_sale_item.product_id and store_id=v_store_id for update;

    insert into public.return_items(store_id,return_id,sale_item_id,product_id,product_name,unit,quantity,unit_price,total_price)
    values (v_store_id,v_return_id,v_sale_item.id,v_sale_item.product_id,v_sale_item.product_name,v_sale_item.unit,v_qty,v_sale_item.unit_price,round(v_qty*v_sale_item.unit_price,2));
    update public.sale_items set returned_quantity=returned_quantity+v_qty where id=v_sale_item.id;
    insert into public.stock_movements(store_id,product_id,movement_type,quantity,previous_stock,new_stock,reference_id,created_by,approval_status,notes)
    values (v_store_id,v_product.id,'return',v_qty,v_product.current_stock,v_product.current_stock+v_qty,v_return_id,auth.uid(),'not_required','Return '||v_return_no);
    update public.products set current_stock=current_stock+v_qty,updated_at=now() where id=v_product.id;
  end loop;

  if p_refund_method='credit_adjustment' then
    v_new_balance := v_sale.balance_amount-v_refund;
    v_new_paid := v_sale.paid_amount;
  else
    v_new_balance := v_sale.balance_amount;
    v_new_paid := v_sale.paid_amount-v_refund;
    insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description)
    values (v_store_id,auth.uid(),'outflow',p_refund_method,v_refund,'return_refund',v_return_id,'Return '||v_return_no);
  end if;

  update public.sales
  set refunded_amount=refunded_amount+v_refund,
      paid_amount=v_new_paid,
      balance_amount=v_new_balance,
      payment_status=case when v_new_balance=0 then 'paid' when v_new_paid>0 then 'partial' else 'unpaid' end
  where id=p_sale_id;

  if v_sale.customer_id is not null then
    update public.customers c
    set total_balance=coalesce((select sum(s.balance_amount) from public.sales s
      where s.store_id=c.store_id and s.customer_id=c.id and s.sale_type='credit' and s.status='completed'),0)
    where c.id=v_sale.customer_id and c.store_id=v_store_id;
  end if;

  perform public.log_action('record_return_v2','returns',v_return_id,null,jsonb_build_object('sale_id',p_sale_id,'refund',v_refund));
  perform private.complete_operation(v_guard_id,v_return_id);
  return v_return_id;
end;
$$;

create or replace function public.record_cash_adjustment_v2(
  p_adjustment_type text,
  p_amount numeric,
  p_adjustment_date date,
  p_reference_no text default null,
  p_notes text default null,
  p_idempotency_key text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_id uuid := gen_random_uuid();
  v_direction text;
  v_claim jsonb;
  v_guard_id uuid;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Only owner or manager can record cash adjustments'; end if;
  if p_adjustment_type not in ('opening_float','cash_deposit','owner_withdrawal','other_inflow','other_outflow') then raise exception 'Invalid adjustment type'; end if;
  if p_amount<=0 then raise exception 'Amount must be positive'; end if;
  v_direction := case when p_adjustment_type in ('opening_float','other_inflow') then 'inflow' else 'outflow' end;

  v_claim := private.claim_operation(v_store_id,'cash_adjustment',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then return (v_claim->>'result_id')::uuid; end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  insert into public.cash_adjustments(id,store_id,adjustment_type,direction,amount,adjustment_date,reference_no,notes,created_by)
  values (v_id,v_store_id,p_adjustment_type,v_direction,p_amount,coalesce(p_adjustment_date,current_date),p_reference_no,p_notes,auth.uid());
  insert into public.cash_ledger(store_id,user_id,direction,payment_method,amount,source_type,source_id,description,occurred_at)
  values (v_store_id,auth.uid(),v_direction,'cash',p_amount,'cash_adjustment',v_id,p_adjustment_type,
          coalesce(p_adjustment_date,current_date)::timestamptz+current_time);
  perform private.complete_operation(v_guard_id,v_id);
  return v_id;
end;
$$;

create or replace function public.submit_daily_cash_closing_v2(
  p_closing_date date,
  p_actual_cash numeric,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_id uuid;
  v_cash numeric(14,2):=0;
  v_bank numeric(14,2):=0;
  v_mobile numeric(14,2):=0;
  v_credit numeric(14,2):=0;
  v_existing_status text;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager','seller') then raise exception 'Not allowed'; end if;
  if p_actual_cash<0 then raise exception 'Actual cash cannot be negative'; end if;

  select status into v_existing_status from public.daily_cash_closings
  where store_id=v_store_id and seller_id=auth.uid() and closing_date=p_closing_date;
  if v_existing_status='approved' then raise exception 'An approved closing cannot be overwritten'; end if;

  select coalesce(sum(case when direction='inflow' then amount else -amount end),0)
  into v_cash from public.cash_ledger
  where store_id=v_store_id and user_id=auth.uid() and payment_method='cash'
    and occurred_at::date=p_closing_date;
  select coalesce(sum(case when direction='inflow' then amount else -amount end),0)
  into v_bank from public.cash_ledger
  where store_id=v_store_id and user_id=auth.uid() and payment_method='bank'
    and occurred_at::date=p_closing_date;
  select coalesce(sum(case when direction='inflow' then amount else -amount end),0)
  into v_mobile from public.cash_ledger
  where store_id=v_store_id and user_id=auth.uid() and payment_method='mobile_money'
    and occurred_at::date=p_closing_date;
  select coalesce(sum(total_amount-refunded_amount),0)
  into v_credit from public.sales
  where store_id=v_store_id and seller_id=auth.uid() and sale_type='credit' and status='completed'
    and created_at::date=p_closing_date;

  insert into public.daily_cash_closings(store_id,seller_id,closing_date,expected_cash,actual_cash,cash_difference,bank_total,mobile_money_total,credit_sales_total,notes,status)
  values (v_store_id,auth.uid(),p_closing_date,v_cash,p_actual_cash,p_actual_cash-v_cash,v_bank,v_mobile,v_credit,p_notes,'submitted')
  on conflict (store_id,seller_id,closing_date) do update
  set expected_cash=excluded.expected_cash,actual_cash=excluded.actual_cash,cash_difference=excluded.cash_difference,
      bank_total=excluded.bank_total,mobile_money_total=excluded.mobile_money_total,credit_sales_total=excluded.credit_sales_total,
      notes=excluded.notes,status='submitted',reviewed_by=null,reviewed_at=null
  returning id into v_id;
  perform public.log_action('submit_daily_cash_closing_v2','daily_cash_closings',v_id,null,jsonb_build_object('expected_cash',v_cash,'actual_cash',p_actual_cash));
  return v_id;
end;
$$;

create or replace function public.financial_summary_v2(p_from timestamptz, p_to timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_gross_sales numeric(14,2);
  v_returns numeric(14,2);
  v_net_sales numeric(14,2);
  v_cogs numeric(14,2);
  v_gross_profit numeric(14,2);
  v_expenses numeric(14,2);
  v_cash numeric(14,2);
  v_bank numeric(14,2);
  v_mobile numeric(14,2);
  v_customer_debt numeric(14,2);
  v_supplier_debt numeric(14,2);
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Financial reports require owner or manager role'; end if;

  select coalesce(sum(total_amount),0),coalesce(sum(refunded_amount),0)
  into v_gross_sales,v_returns
  from public.sales
  where store_id=v_store_id and status='completed' and created_at>=p_from and created_at<p_to;
  v_net_sales := v_gross_sales-v_returns;

  select coalesce(sum((si.quantity-si.returned_quantity)*coalesce(si.buying_price_at_sale,0)),0)
  into v_cogs
  from public.sale_items si join public.sales s on s.id=si.sale_id
  where s.store_id=v_store_id and s.status='completed' and s.created_at>=p_from and s.created_at<p_to;
  v_gross_profit := v_net_sales-v_cogs;

  select coalesce(sum(amount),0) into v_expenses
  from public.expenses where store_id=v_store_id and expense_date>=p_from::date and expense_date<p_to::date;

  select coalesce(sum(case when direction='inflow' then amount else -amount end),0)
  into v_cash from public.cash_ledger where store_id=v_store_id and payment_method='cash' and occurred_at>=p_from and occurred_at<p_to;
  select coalesce(sum(case when direction='inflow' then amount else -amount end),0)
  into v_bank from public.cash_ledger where store_id=v_store_id and payment_method='bank' and occurred_at>=p_from and occurred_at<p_to;
  select coalesce(sum(case when direction='inflow' then amount else -amount end),0)
  into v_mobile from public.cash_ledger where store_id=v_store_id and payment_method='mobile_money' and occurred_at>=p_from and occurred_at<p_to;

  select coalesce(sum(total_balance),0) into v_customer_debt from public.customers where store_id=v_store_id and is_active=true;
  select coalesce(sum(total_balance),0) into v_supplier_debt from public.suppliers where store_id=v_store_id and is_active=true;

  return jsonb_build_object(
    'gross_sales',v_gross_sales,'returns',v_returns,'net_sales',v_net_sales,
    'cost_of_goods',v_cogs,'gross_profit',v_gross_profit,'expenses',v_expenses,
    'net_profit',v_gross_profit-v_expenses,'cash_net',v_cash,'bank_net',v_bank,
    'mobile_money_net',v_mobile,'customer_debt',v_customer_debt,'supplier_debt',v_supplier_debt
  );
end;
$$;

create or replace function public.customer_statement_v2(
  p_customer_id uuid,
  p_from date default null,
  p_to date default null
) returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_customer jsonb;
  v_sales jsonb;
  v_payments jsonb;
  v_returns jsonb;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Customer statements require owner or manager role'; end if;
  select to_jsonb(c) into v_customer from public.customers c where c.id=p_customer_id and c.store_id=v_store_id;
  if v_customer is null then raise exception 'Customer not found'; end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]'::jsonb) into v_sales
  from (
    select s.id,s.invoice_no,s.total_amount,s.refunded_amount,s.paid_amount,s.balance_amount,s.payment_status,s.created_at
    from public.sales s
    where s.store_id=v_store_id and s.customer_id=p_customer_id and s.sale_type='credit' and s.status='completed'
      and (p_from is null or s.created_at::date>=p_from)
      and (p_to is null or s.created_at::date<=p_to)
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]'::jsonb) into v_payments
  from (
    select cp.id,cp.amount,cp.payment_method,cp.reference_no,cp.notes,cp.created_at,
           coalesce((select jsonb_agg(jsonb_build_object('sale_id',a.sale_id,'amount',a.amount))
                     from public.customer_payment_allocations a where a.payment_id=cp.id),'[]'::jsonb) as allocations
    from public.customer_payments cp
    where cp.store_id=v_store_id and cp.customer_id=p_customer_id
      and (p_from is null or cp.created_at::date>=p_from)
      and (p_to is null or cp.created_at::date<=p_to)
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]'::jsonb) into v_returns
  from (
    select r.id,r.return_no,r.sale_id,r.refund_amount,r.refund_method,r.reason,r.created_at
    from public.returns r
    where r.store_id=v_store_id and r.customer_id=p_customer_id and r.status='completed'
      and (p_from is null or r.created_at::date>=p_from)
      and (p_to is null or r.created_at::date<=p_to)
  ) x;

  return jsonb_build_object('customer',v_customer,'sales',v_sales,'payments',v_payments,'returns',v_returns);
end;
$$;

-- Least-privilege grants for v2 API.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'create_cash_sale_v2','request_credit_sale_v2','record_customer_payment_v2',
      'record_purchase_v2','record_supplier_payment_v2','record_expense_v2','record_return_v2',
      'record_cash_adjustment_v2','submit_daily_cash_closing_v2','financial_summary_v2','customer_statement_v2',
      'decide_approval_request'
    )
  loop
    execute format('revoke all on function %s from public, anon, authenticated',r.signature);
    execute format('grant execute on function %s to authenticated',r.signature);
  end loop;
end $$;
