-- Recovery remediation: the live project contains a corrected record_expense_v2
-- definition that was not represented by the committed migration chain.
-- Capture it so fresh deployment and disaster recovery match production.

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
  if p_category is null or length(trim(p_category)) < 2 then raise exception 'Expense category is required'; end if;
  if p_amount <= 0 then raise exception 'Expense amount must be positive'; end if;
  if p_payment_method not in ('cash','bank','mobile_money') then raise exception 'Invalid payment method'; end if;

  v_claim := private.claim_operation(v_store_id,'expense',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then
    return (v_claim->>'result_id')::uuid;
  end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  insert into public.expenses(
    id,store_id,category,amount,expense_date,payment_method,
    reference_no,notes,created_by
  ) values (
    v_id,v_store_id,trim(p_category),p_amount,
    coalesce(p_expense_date,current_date),p_payment_method,
    nullif(trim(coalesce(p_reference_no,'')),''),
    nullif(trim(coalesce(p_notes,'')),''),auth.uid()
  );

  insert into public.cash_ledger(
    store_id,user_id,direction,payment_method,amount,
    source_type,source_id,description,occurred_at
  ) values (
    v_store_id,auth.uid(),'outflow',p_payment_method,p_amount,
    'expense',v_id,trim(p_category),
    coalesce(p_expense_date,current_date)::timestamptz
  );

  perform public.log_action(
    'record_expense_v2','expenses',v_id,null,
    jsonb_build_object('amount',p_amount,'category',p_category)
  );
  perform private.complete_operation(v_guard_id,v_id);
  return v_id;
end;
$$;

revoke all on function public.record_expense_v2(text,numeric,text,date,text,text,text)
  from public, anon, authenticated;
grant execute on function public.record_expense_v2(text,numeric,text,date,text,text,text)
  to authenticated;
