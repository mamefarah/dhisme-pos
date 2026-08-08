# Dhisme POS — Controlled Pilot Test Script

Run this script on real Android devices against a **staging/pilot database reconstructed from all committed migrations**. Record pass/fail and evidence for every scenario before wider rollout.

## Test setup

Prepare:

- Two stores: **Store A** and **Store B**.
- Store A accounts: one Owner, one Manager, two Sellers.
- Store B account: one Owner.
- At least two Android phones.
- Reliable internet plus one brief connectivity interruption for retry testing.
- Products with buying price, selling price, minimum selling price, and stock thresholds.
- A customer with a credit limit.
- A supplier.

Do not test against irreplaceable production data.

---

## 1. Owner registration and tenant creation

1. Register Store A owner through the intended onboarding flow.
2. Confirm the owner dashboard loads.
3. Confirm the profile role is `owner` and its `store_id` matches Store A.
4. Repeat for Store B.

**Expected:** each owner belongs to exactly one distinct store and cannot see the other store's data.

## 2. Employee invitations and roles

1. Store A owner creates Seller and Manager invite codes.
2. Register the test Seller and Manager with those codes.
3. Confirm each receives the correct role and Store A membership.
4. Try reusing an invite code.

**Expected:** correct role assignment; single-use/expired-code rules are enforced.

## 3. Product and category management

1. Create category `Cement & Concrete`.
2. Add `Cement 50kg`: buying 350, selling 420, minimum selling 380, initial stock 50, minimum stock 10.
3. Add `Iron Rod 12mm`: buying 85, selling 120, minimum selling 100, initial stock 30, minimum stock 5.
4. Edit names/prices/category where permitted.

**Expected:** products and category filters render correctly and values persist after reload.

## 4. Stock adjustment

1. As Owner/Manager, add 5 Cement bags with a reason.
2. Remove 2 with a reason.
3. Try removing more than available stock.
4. Review stock movement history.

**Expected:** valid adjustments change stock once and are logged; negative stock is rejected.

## 5. Supplier creation and editing

1. Add supplier `Jigjiga Building Supply` with phone/contact/address.
2. Edit the supplier.
3. Reload the list.

**Expected:** supplier is automatically assigned to Store A; `total_balance` starts at zero and cannot be supplied by the client.

## 6. Paid purchase

1. Record a paid purchase from the supplier.
2. Add 10 Cement bags at the chosen unit cost.
3. Select Cash/Bank/Mobile Money as appropriate.

**Expected:** stock increases by 10, purchase shows paid, supplier debt does not increase incorrectly, and financial records reconcile.

## 7. Unpaid supplier purchase

1. Record an unpaid purchase linked to the supplier.
2. Reload supplier details.

**Expected:** purchase balance and supplier aggregate debt increase by the same amount.

## 8. Partial supplier purchase

1. Record a purchase total of a known amount.
2. Enter a valid partial paid amount.
3. Try zero, negative, and an amount equal to/exceeding total when status is partial.

**Expected:** only a true partial amount is accepted; purchase `paid_amount`, `balance_amount`, and supplier debt reconcile.

## 9. Supplier payment allocation

1. With multiple unpaid/partial purchases, record a supplier payment.
2. Verify FIFO allocation across purchases.
3. Retry the same operation after simulating a slow connection/double tap.

**Expected:** payment is recorded once, allocations reconcile, and supplier balance decreases exactly once.

## 10. Cash sale

1. Add Cement × 3 to POS.
2. Pay Cash.
3. Complete the sale.

**Expected:** total is correct, stock decrements once, receipt opens, and cash ledger receives one inflow.

## 11. Bank and mobile-money sales

1. Complete one Bank sale with a reference.
2. Complete one Mobile Money sale.

**Expected:** payment methods and references persist correctly in history/reports.

## 12. Mixed payment sale

1. Create a sale with Cash + Bank + Mobile Money splits that exactly equal the total.
2. Try a split total below the sale total.
3. Try a split total above the sale total.
4. Try negative/zero invalid split values.

**Expected:** only the exactly reconciled positive split is accepted.

## 13. Discount enforcement

1. As Seller, test discount at and above the seller limit.
2. As Manager, test discount at and above the manager limit.
3. Attempt a discount that places a product below minimum selling price.
4. Attempt a zero-value final sale.

**Expected:** server rules reject unauthorized/unsafe discounts regardless of UI manipulation.

## 14. Customer creation

1. Create `Abebe Construction` with phone/location/notes.
2. Reload and edit permitted details.

**Expected:** customer starts with zero aggregate debt; direct client creation cannot inject a custom `total_balance`.

## 15. Credit controls

1. Owner/Manager sets customer credit limit and credit days.
2. Seller views customer.
3. Confirm Seller cannot edit credit-control fields.
4. Toggle credit block and test a credit request.

**Expected:** role restrictions and credit block are enforced in UI and backend.

## 16. Credit request and approval

1. Seller submits a valid credit sale request.
2. Owner reviews and approves it.
3. Repeat with a second request and reject it.

**Expected:** approval-time credit limit is rechecked; approved sale changes stock/debt exactly once; rejected request does not incorrectly reduce stock.

## 17. Credit exposure race check

1. Create two near-simultaneous credit requests that together would exceed the customer's limit.
2. Attempt to approve both.

**Expected:** row locking/approval recheck prevents final exposure above the configured limit.

## 18. Customer payment allocation

1. Create two unpaid credit invoices for the customer.
2. Record a payment smaller than total debt.
3. Verify FIFO allocation.
4. Retry/double-tap the payment submission.

**Expected:** payment posts once; invoice and aggregate customer balances reconcile.

## 19. Customer statement permissions

1. Owner/Manager opens customer statement PDF.
2. Seller opens the same customer detail.

**Expected:** statement access is available to authorized roles only; Seller does not receive the statement action.

## 20. Partial return

1. Open a completed sale with multiple quantities.
2. Return part of one line.
3. Verify stock restoration and refund amount.
4. Review reports and ledger.

**Expected:** only returned quantity is restored; net sales/profit and money movement reflect the return.

## 21. Multiple partial returns and exact final cents

1. Return the same sale line in several partial quantities.
2. Return the final remaining quantity.
3. Sum every refund for that line.

**Expected:** cumulative refunds equal the original net line total exactly, with the final return absorbing any rounding cents; quantity cannot exceed remaining returnable units.

## 22. Credit return

1. Return part of an unpaid credit sale using credit adjustment.
2. Attempt credit adjustment on a non-credit sale.

**Expected:** valid credit return reduces outstanding debt; invalid refund method is rejected.

## 23. Expense recording

1. Owner/Manager records Cash, Bank, and Mobile Money expenses.
2. Try zero/negative amount.
3. Confirm Seller cannot record expenses if the role policy forbids it.

**Expected:** valid expense creates one ledger outflow and appears in financial reporting.

## 24. Daily cash closing

1. Seller completes cash-generating transactions and relevant refunds.
2. Submit daily closing with actual cash.
3. Manager repeats for their own transactions if permitted.
4. Owner reviews and approves.
5. Attempt to overwrite an approved closing.

**Expected:** expected cash is derived from net ledger movements; approved closing cannot be overwritten.

## 25. Financial report reconciliation

For a controlled sample day, independently calculate:

- gross sales;
- returns;
- net sales;
- COGS;
- gross profit;
- expenses;
- net profit;
- Cash/Bank/Mobile Money net movements;
- customer debt;
- supplier debt.

**Expected:** app/server report equals the manual reconciliation.

## 26. Idempotency and retry safety

For each operation below, double-tap or interrupt/retry the same request:

- sale;
- credit request;
- customer payment;
- purchase;
- supplier payment;
- expense;
- return.

**Expected:** each logical operation changes business state once, not twice.

## 27. Role restrictions

As Seller, verify the UI does not expose unauthorized:

- approvals;
- financial reports;
- customer statement PDF;
- supplier Edit/Pay actions;
- customer credit-control editing;
- owner/manager-only configuration.

Then attempt equivalent direct API requests where practical.

**Expected:** UI is consistent with backend denial; backend remains authoritative.

## 28. Cross-store tenant isolation

While signed in to Store A, attempt to read or mutate known Store B IDs for:

- products;
- customers;
- suppliers;
- sales;
- purchases;
- payments;
- reports/RPCs.

**Expected:** Store B data is never disclosed or changed.

## 29. Aggregate balance tampering test

Using an authenticated client token, attempt direct PostgREST:

- INSERT customer with non-zero `total_balance`;
- UPDATE customer `total_balance`;
- INSERT supplier with non-zero `total_balance`;
- UPDATE supplier `total_balance`.

Then perform legitimate RPC-based credit/purchase/payment flows.

**Expected:** all four direct balance mutations are denied; trusted RPCs still update balances correctly.

## 30. Deactivation and session behavior

1. Owner deactivates a Seller.
2. On the Seller device, refresh/relaunch and try protected operations.

**Expected:** deactivated account cannot continue protected business operations.

## 31. PDF receipt and statement

1. Open a normal paid sale, discounted sale, and credit sale.
2. Generate/share 80mm receipt PDFs.
3. Generate an authorized customer statement.

**Expected:** amounts, payment state, store/invoice metadata, items, discounts, and amount due are correct.

## 32. Android lifecycle and connectivity

1. Background/resume the app during normal navigation.
2. Rotate/reopen where applicable.
3. Briefly disable network during a safe retry test.
4. Relaunch after force-close.

**Expected:** no setState-after-dispose/context crashes; failed requests show understandable errors and financial retries remain idempotent.

---

## Pass / fail log

| # | Scenario | Pass | Fail | Evidence / notes |
| ---: | --- | :---: | :---: | --- |
| 1 | Owner registration / tenants | | | |
| 2 | Invitations / roles | | | |
| 3 | Products / categories | | | |
| 4 | Stock adjustment | | | |
| 5 | Supplier create/edit | | | |
| 6 | Paid purchase | | | |
| 7 | Unpaid purchase | | | |
| 8 | Partial purchase | | | |
| 9 | Supplier payment | | | |
| 10 | Cash sale | | | |
| 11 | Bank/mobile sale | | | |
| 12 | Mixed payment | | | |
| 13 | Discount controls | | | |
| 14 | Customer create/edit | | | |
| 15 | Credit controls | | | |
| 16 | Credit approval/rejection | | | |
| 17 | Credit race check | | | |
| 18 | Customer payment | | | |
| 19 | Statement permissions | | | |
| 20 | Partial return | | | |
| 21 | Exact cumulative returns | | | |
| 22 | Credit return | | | |
| 23 | Expenses | | | |
| 24 | Cash closing | | | |
| 25 | Financial reconciliation | | | |
| 26 | Idempotency/retry | | | |
| 27 | Role restrictions | | | |
| 28 | Cross-store isolation | | | |
| 29 | Balance tampering | | | |
| 30 | Deactivation/session | | | |
| 31 | PDFs | | | |
| 32 | Android lifecycle/connectivity | | | |

**Pilot sign-off requires every financial-integrity, security, and tenant-isolation scenario to pass.** Any failure in scenarios 8–29 blocks wider rollout until investigated and retested.
