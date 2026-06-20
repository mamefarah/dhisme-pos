-- Audit remediation phase 4: server-side reports without client limits and
-- a safe own-profile lookup that still works for deactivated accounts.

create or replace function public.get_my_profile_v2()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(p)
  from public.profiles p
  where p.id = auth.uid()
  limit 1
$$;

create or replace function public.sales_summary_v2(
  p_from timestamptz default null,
  p_to timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_total numeric(14,2) := 0;
  v_cash numeric(14,2) := 0;
  v_bank numeric(14,2) := 0;
  v_mobile numeric(14,2) := 0;
  v_credit numeric(14,2) := 0;
  v_returns numeric(14,2) := 0;
  v_count integer := 0;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Reports require owner or manager role'; end if;

  select coalesce(sum(s.total_amount - s.refunded_amount),0),
         coalesce(sum(s.refunded_amount),0),
         count(*)
  into v_total, v_returns, v_count
  from public.sales s
  where s.store_id = v_store_id
    and s.status = 'completed'
    and (p_from is null or s.created_at >= p_from)
    and (p_to is null or s.created_at < p_to);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_cash
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='cash'
    and cl.source_type in ('sale_payment','return_refund')
    and (p_from is null or cl.occurred_at>=p_from)
    and (p_to is null or cl.occurred_at<p_to);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_bank
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='bank'
    and cl.source_type in ('sale_payment','return_refund')
    and (p_from is null or cl.occurred_at>=p_from)
    and (p_to is null or cl.occurred_at<p_to);

  select coalesce(sum(case when cl.direction='inflow' then cl.amount else -cl.amount end),0)
  into v_mobile
  from public.cash_ledger cl
  where cl.store_id=v_store_id and cl.payment_method='mobile_money'
    and cl.source_type in ('sale_payment','return_refund')
    and (p_from is null or cl.occurred_at>=p_from)
    and (p_to is null or cl.occurred_at<p_to);

  select coalesce(sum(s.total_amount-s.refunded_amount),0)
  into v_credit
  from public.sales s
  where s.store_id=v_store_id and s.status='completed' and s.sale_type='credit'
    and (p_from is null or s.created_at>=p_from)
    and (p_to is null or s.created_at<p_to);

  return jsonb_build_object(
    'total',v_total,'count',v_count,'cash',v_cash,'bank',v_bank,
    'mobile_money',v_mobile,'credit',v_credit,'returns',v_returns
  );
end;
$$;

create or replace function public.profit_summary_v2(
  p_from timestamptz default null,
  p_to timestamptz default null
) returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_revenue numeric(14,2) := 0;
  v_cost numeric(14,2) := 0;
  v_profit numeric(14,2) := 0;
  v_expenses numeric(14,2) := 0;
  v_has_cost boolean := false;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Reports require owner or manager role'; end if;

  select coalesce(sum(s.total_amount-s.refunded_amount),0)
  into v_revenue
  from public.sales s
  where s.store_id=v_store_id and s.status='completed'
    and (p_from is null or s.created_at>=p_from)
    and (p_to is null or s.created_at<p_to);

  select coalesce(sum((si.quantity-si.returned_quantity)*coalesce(si.buying_price_at_sale,0)),0),
         bool_or(si.buying_price_at_sale is not null)
  into v_cost,v_has_cost
  from public.sale_items si
  join public.sales s on s.id=si.sale_id
  where s.store_id=v_store_id and s.status='completed'
    and (p_from is null or s.created_at>=p_from)
    and (p_to is null or s.created_at<p_to);

  v_profit := v_revenue-v_cost;

  select coalesce(sum(e.amount),0)
  into v_expenses
  from public.expenses e
  where e.store_id=v_store_id
    and (p_from is null or e.expense_date>=p_from::date)
    and (p_to is null or e.expense_date<p_to::date);

  return jsonb_build_object(
    'total_revenue',v_revenue,'total_cost',v_cost,'gross_profit',v_profit,
    'expenses',v_expenses,'net_profit',v_profit-v_expenses,
    'has_cost_data',coalesce(v_has_cost,false)
  );
end;
$$;

create or replace function public.top_products_v2(
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit integer default 10
) returns jsonb
language plpgsql
security definer
set search_path = public, private
as $$
declare
  v_store_id uuid := public.current_user_store_id();
  v_role text := public.current_user_role();
  v_result jsonb;
begin
  if v_store_id is null then raise exception 'User profile/store not found'; end if;
  if v_role not in ('owner','manager') then raise exception 'Reports require owner or manager role'; end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.total_revenue desc),'[]'::jsonb)
  into v_result
  from (
    select si.product_id, max(si.product_name) as product_name, max(si.unit) as unit,
           sum(greatest(si.quantity-si.returned_quantity,0)) as total_qty,
           sum(greatest(si.quantity-si.returned_quantity,0)*si.unit_price) as total_revenue
    from public.sale_items si
    join public.sales s on s.id=si.sale_id
    where s.store_id=v_store_id and s.status='completed'
      and (p_from is null or s.created_at>=p_from)
      and (p_to is null or s.created_at<p_to)
    group by si.product_id
    having sum(greatest(si.quantity-si.returned_quantity,0))>0
    order by total_revenue desc
    limit greatest(1,least(coalesce(p_limit,10),100))
  ) x;
  return v_result;
end;
$$;

do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in ('get_my_profile_v2','sales_summary_v2','profit_summary_v2','top_products_v2')
  loop
    execute format('revoke all on function %s from public, anon, authenticated',r.signature);
    execute format('grant execute on function %s to authenticated',r.signature);
  end loop;
end $$;
