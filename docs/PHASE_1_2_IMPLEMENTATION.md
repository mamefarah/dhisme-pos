# DUKAAN DHISME POS - PHASE 1 AND PHASE 2 IMPLEMENTATION

Status: Partly implemented and partly prepared for UI connection.
Date: 2026-06-17

## PHASE 1 - SECURITY AND RELEASE SIGNING

### Completed in Supabase

A production database migration was applied to project `uzhnzkgigmqzzgfyndlg`.

It completed these changes:

- Revoked anonymous RPC execution from key business functions.
- Kept authenticated RPC access for app-required functions.
- Kept internal helper RPCs `log_action` and `new_invoice_no` unavailable for direct authenticated calls.
- Added missing indexes for `customer_payments.store_id` and `customer_payments.received_by`.

Key RPCs secured from anonymous execution:

- `adjust_stock`
- `create_cash_sale`
- `create_store_invite`
- `dashboard_stats`
- `decide_approval_request`
- `record_customer_payment`
- `record_purchase`
- `register_owner`
- `register_with_invite`
- `request_credit_sale`
- `review_daily_cash_closing`
- `submit_daily_cash_closing`

### Still manual in Supabase dashboard

Enable leaked password protection:

1. Open Supabase dashboard.
2. Go to Authentication.
3. Open Providers or Security settings.
4. Enable leaked password protection.

## RELEASE SIGNING

GitHub Actions now supports optional APK signing.

Add these GitHub repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow signs the APK only when all four secrets exist. If the secrets are missing, the build still continues normally.

## PHASE 2 - BUSINESS MODULES

### Completed in Supabase

The production database now has backend support for:

- Expenses.
- Supplier debt.
- Supplier payments.
- Returns and refunds.
- Customer statement data.

New tables:

- `expenses`
- `supplier_payments`
- `returns`
- `return_items`

Updated tables:

- `suppliers.total_balance`
- `purchases.paid_amount`
- `purchases.balance_amount`

New RPCs:

- `record_expense`
- `record_supplier_payment`
- `record_return`
- `customer_statement`

Updated RPC:

- `record_purchase` now maintains supplier debt when purchases are unpaid or partially paid.

## NEXT UI WORK

The database is ready. The next UI layer should connect these modules:

- Expenses screen and add expense form.
- Supplier detail screen with supplier balance and payment form.
- Return/refund screen from receipt or sales history.
- Customer statement PDF button from customer detail.

## SAFETY NOTE

Do not remove existing indexes immediately just because Supabase marks them unused. Wait until the app has real usage data for at least 2 to 4 weeks.
