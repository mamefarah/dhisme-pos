-- Recovery remediation: the live project contains a corrected
-- record_cash_adjustment_v2 definition that was not represented by the
-- committed migration chain. Capture it so fresh deployment and disaster
-- recovery match production.

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
  if p_amount <= 0 then raise exception 'Amount must be positive'; end if;

  v_direction := case
    when p_adjustment_type in ('opening_float','other_inflow') then 'inflow'
    else 'outflow'
  end;

  v_claim := private.claim_operation(v_store_id,'cash_adjustment',p_idempotency_key,auth.uid());
  if not (v_claim->>'claimed')::boolean then
    return (v_claim->>'result_id')::uuid;
  end if;
  v_guard_id := (v_claim->>'guard_id')::uuid;

  insert into public.cash_adjustments(
    id,store_id,adjustment_type,direction,amount,adjustment_date,
    reference_no,notes,created_by
  ) values (
    v_id,v_store_id,p_adjustment_type,v_direction,p_amount,
    coalesce(p_adjustment_date,current_date),p_reference_no,p_notes,auth.uid()
  );

  insert into public.cash_ledger(
    store_id,user_id,direction,payment_method,amount,
    source_type,source_id,description,occurred_at
  ) values (
    v_store_id,auth.uid(),v_direction,'cash',p_amount,
    'cash_adjustment',v_id,p_adjustment_type,
    coalesce(p_adjustment_date,current_date)::timestamptz
  );

  perform private.complete_operation(v_guard_id,v_id);
  return v_id;
end;
$$;

revoke all on function public.record_cash_adjustment_v2(text,numeric,date,text,text,text)
  from public, anon, authenticated;
grant execute on function public.record_cash_adjustment_v2(text,numeric,date,text,text,text)
  to authenticated;
