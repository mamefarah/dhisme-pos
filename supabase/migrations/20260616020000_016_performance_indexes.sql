-- Phase 16: Performance Indexes
--
-- Adds missing FK and FK-join indexes beyond what 001_init.sql already covered.
-- Every index uses IF NOT EXISTS so this is safe to run more than once.
--
-- How to run:
--   Supabase CLI:       supabase db push
--   Supabase Dashboard: SQL Editor → paste → Run

-- approval_requests
CREATE INDEX IF NOT EXISTS idx_approval_requested_by ON public.approval_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_approval_approved_by  ON public.approval_requests(approved_by);

-- audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_store   ON public.audit_logs(store_id);
CREATE INDEX IF NOT EXISTS idx_audit_user    ON public.audit_logs(user_id);

-- customers
CREATE INDEX IF NOT EXISTS idx_customers_store ON public.customers(store_id);

-- daily_cash_closings
CREATE INDEX IF NOT EXISTS idx_closings_seller      ON public.daily_cash_closings(seller_id);
CREATE INDEX IF NOT EXISTS idx_closings_reviewed_by ON public.daily_cash_closings(reviewed_by);

-- notifications
CREATE INDEX IF NOT EXISTS idx_notifications_store ON public.notifications(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user  ON public.notifications(user_id, is_read);

-- payments
CREATE INDEX IF NOT EXISTS idx_payments_sale_id     ON public.payments(sale_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer    ON public.payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_seller      ON public.payments(seller_id, created_at DESC);

-- products
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category_id);

-- purchase_items
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON public.purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_product  ON public.purchase_items(product_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_store    ON public.purchase_items(store_id);

-- purchases
CREATE INDEX IF NOT EXISTS idx_purchases_supplier    ON public.purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchases_recorded_by ON public.purchases(recorded_by);

-- sale_items
CREATE INDEX IF NOT EXISTS idx_sale_items_sale    ON public.sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product ON public.sale_items(product_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_store   ON public.sale_items(store_id);

-- sales
CREATE INDEX IF NOT EXISTS idx_sales_customer ON public.sales(customer_id);

-- stock_movements
CREATE INDEX IF NOT EXISTS idx_stock_movements_product    ON public.stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_by ON public.stock_movements(created_by);
CREATE INDEX IF NOT EXISTS idx_stock_movements_store      ON public.stock_movements(store_id, created_at DESC);

-- store_invites
CREATE INDEX IF NOT EXISTS idx_invites_created_by ON public.store_invites(created_by);
CREATE INDEX IF NOT EXISTS idx_invites_used_by    ON public.store_invites(used_by);
