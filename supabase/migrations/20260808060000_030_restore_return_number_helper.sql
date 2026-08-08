-- Recovery remediation: capture a production helper that existed as schema drift.
-- record_return_v2() depends on public.new_return_no(); without this migration a
-- clean database reconstruction fails when the return RPC is first executed.

create or replace function public.new_return_no()
returns text
language sql
security definer
set search_path = public
as $$
  select 'RET-' || to_char(now(), 'YYYYMMDD-HH24MISS') || '-' ||
         upper(substring(gen_random_uuid()::text, 1, 6))
$$;

-- Internal helper only. The SECURITY DEFINER record_return_v2() function can
-- invoke it as its owner; API client roles do not need direct EXECUTE access.
revoke all on function public.new_return_no() from public;
revoke execute on function public.new_return_no() from anon, authenticated;
