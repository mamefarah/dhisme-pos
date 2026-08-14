-- The products table has never had a notes column, but the Flutter app has
-- always sent one: Product.notes (lib/features/products/models/product.dart),
-- ProductRepository.addProduct()/updateProduct(), and the Notes field on
-- product_form_screen.dart all read/write products.notes. Any product saved
-- with a non-empty Notes value has been failing with
-- "column products.notes does not exist" since the notes field was added to
-- the UI. This adds the missing column so those calls succeed.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor -> paste this file -> Run

alter table public.products add column if not exists notes text;
