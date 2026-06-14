-- Edit UUID values before running.
-- First create Auth users in Supabase Dashboard, then paste their UUIDs below.

insert into public.stores (id, name, phone, address, currency)
values ('00000000-0000-0000-0000-000000000001', 'Dhisme Materials Store', '+251900000000', 'Jigjiga, Somali Region', 'ETB')
on conflict do nothing;

-- Replace these Auth UUIDs with real Supabase Auth user IDs.
-- insert into public.profiles (id, store_id, full_name, phone, role)
-- values ('OWNER_AUTH_UUID', '00000000-0000-0000-0000-000000000001', 'Store Owner', '+251900000000', 'owner');

-- insert into public.profiles (id, store_id, full_name, phone, role)
-- values ('SELLER_AUTH_UUID', '00000000-0000-0000-0000-000000000001', 'Ahmed Seller', '+251911111111', 'seller');

insert into public.categories (store_id, name)
values
('00000000-0000-0000-0000-000000000001', 'Cement'),
('00000000-0000-0000-0000-000000000001', 'Steel/Rebar'),
('00000000-0000-0000-0000-000000000001', 'Sand and Gravel'),
('00000000-0000-0000-0000-000000000001', 'Blocks'),
('00000000-0000-0000-0000-000000000001', 'Paint'),
('00000000-0000-0000-0000-000000000001', 'Plumbing'),
('00000000-0000-0000-0000-000000000001', 'Electrical')
on conflict do nothing;

insert into public.products (store_id, name, unit, buying_price, selling_price, minimum_selling_price, current_stock, minimum_stock)
values
('00000000-0000-0000-0000-000000000001', 'Dangote Cement', 'bag', 1100, 1250, 1200, 200, 40),
('00000000-0000-0000-0000-000000000001', 'Muger Cement', 'bag', 1080, 1230, 1180, 150, 30),
('00000000-0000-0000-0000-000000000001', 'Rebar 12mm', 'piece', 520, 600, 570, 300, 50),
('00000000-0000-0000-0000-000000000001', 'Hollow Concrete Block', 'piece', 25, 35, 32, 2000, 300),
('00000000-0000-0000-0000-000000000001', 'River Sand', 'm3', 900, 1200, 1100, 45, 10),
('00000000-0000-0000-0000-000000000001', 'Gravel', 'm3', 1000, 1350, 1250, 40, 10)
on conflict do nothing;

insert into public.customers (store_id, name, phone, location)
values
('00000000-0000-0000-0000-000000000001', 'Abdi Construction', '+251922222222', 'Jigjiga'),
('00000000-0000-0000-0000-000000000001', 'Ahmed Builder', '+251933333333', 'Kebri Beyah Road')
on conflict do nothing;
