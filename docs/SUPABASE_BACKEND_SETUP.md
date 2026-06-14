# SUPABASE BACKEND SETUP

## 1. Create Supabase project

Create a project named:

```text
dhisme-pos
```

Copy:

```text
Project URL
anon public key
```

Never put the service role key inside Flutter.

## 2. Run database migration

Open:

```text
supabase/migrations/001_init.sql
```

Copy all SQL, paste it into Supabase SQL Editor, and run it.

## 3. Create Auth users

Create two users in Supabase Auth:

```text
owner@dhisme.com
seller@dhisme.com
```

Copy each user UUID.

## 4. Create store and profiles

Edit and run this SQL:

```sql
insert into public.stores (id, name, phone, address, currency)
values (
  '00000000-0000-0000-0000-000000000001',
  'Dhisme Materials Store',
  '+251900000000',
  'Jigjiga, Somali Region',
  'ETB'
)
on conflict do nothing;

insert into public.profiles (id, store_id, full_name, phone, role)
values (
  'PASTE_OWNER_AUTH_UUID_HERE',
  '00000000-0000-0000-0000-000000000001',
  'Store Owner',
  '+251900000000',
  'owner'
);

insert into public.profiles (id, store_id, full_name, phone, role)
values (
  'PASTE_SELLER_AUTH_UUID_HERE',
  '00000000-0000-0000-0000-000000000001',
  'Ahmed Seller',
  '+251911111111',
  'seller'
);
```

## 5. Add sample data

Open and run:

```text
supabase/seed.sql
```

If the seed file contains placeholder user IDs, edit them first.

## 6. Test

Login as owner and seller from the APK.

Then test:

- Product list
- Cash sale
- Credit sale request
- Owner approval
- Daily cash closing
