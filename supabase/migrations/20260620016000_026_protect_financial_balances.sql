-- Migration to protect aggregate financial balances on customers and suppliers
-- from direct arbitrary modifications via PostgREST / direct table updates.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> Paste -> Run

create or replace function private.protect_customer_balance()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  -- Block direct client-side updates from the 'authenticated' role.
  -- SECURE DEFINER transactional functions run as the database owner, allowing them to pass.
  if current_user = 'authenticated' and NEW.total_balance is distinct from OLD.total_balance then
    raise exception 'Direct modification of customer total_balance is restricted. Use secure transactions.';
  end if;
  return NEW;
end;
$$;

create or replace function private.protect_supplier_balance()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  -- Block direct client-side updates from the 'authenticated' role.
  -- SECURE DEFINER transactional functions run as the database owner, allowing them to pass.
  if current_user = 'authenticated' and NEW.total_balance is distinct from OLD.total_balance then
    raise exception 'Direct modification of supplier total_balance is restricted. Use secure transactions.';
  end if;
  return NEW;
end;
$$;

-- Drop triggers if they exist to be repeatable
drop trigger if exists trg_protect_customer_balance on public.customers;
create trigger trg_protect_customer_balance
before update on public.customers
for each row
execute function private.protect_customer_balance();

drop trigger if exists trg_protect_supplier_balance on public.suppliers;
create trigger trg_protect_supplier_balance
before update on public.suppliers
for each row
execute function private.protect_supplier_balance();
