# Dhisme POS — Pilot Test Script

Step-by-step test cases for the pilot store. Run each scenario in order on a real device.
Record pass/fail and any notes for issues to fix before wider rollout.

---

## Setup

- Device: Android 8.0 or higher
- Internet: required (mobile data or WiFi)
- Test accounts: one Owner, one Seller

---

## Scenario 1 — Owner Registration

1. Open the app. The login screen appears.
2. Tap **Register new store**.
3. Fill in: Full name, Store name, Phone, Store phone, Store address.
4. Tap **Register**.
5. **Expected:** Home screen (Owner dashboard) appears showing today's stats at zero.
6. **Check:** `profiles` table in Supabase has a row with `role = 'owner'`.

---

## Scenario 2 — Add Products

1. From the owner dashboard, tap **Products** (or navigate via the products icon).
2. Tap the **+** button to add a product.
3. Enter: Name = "Cement 50kg", Unit = "bag", Buying price = 350, Selling price = 420, Min. selling price = 380, Min. stock = 10, Current stock = 50.
4. Tap **Save**.
5. Add a second product: "Iron Rod 12mm", Unit = "pc", Buying = 85, Selling = 120, Min. selling = 100, Min. stock = 5, Stock = 30.
6. **Expected:** Both products appear in the list with correct stock levels.

---

## Scenario 3 — Add a Category

1. From Products, tap the category menu icon.
2. Add category "Cement & Concrete".
3. Edit "Cement 50kg" and assign it to this category.
4. **Expected:** Category filter shows "Cement & Concrete" and filters correctly.

---

## Scenario 4 — Cash Sale (Cash Payment)

1. From the home screen, tap **New Sale** (POS button).
2. Add "Cement 50kg" × 3 bags.
3. Select payment method: **Cash**. No discount. Tap **Complete Sale**.
4. **Expected:** Receipt screen shows invoice number, total = ETB 1,260.
5. **Check:** Products screen shows Cement stock = 47.
6. **Check:** Dashboard "Today's sales" updated.

---

## Scenario 5 — Cash Sale (Bank Transfer)

1. Start a new sale. Add "Iron Rod 12mm" × 5 pcs.
2. Select payment method: **Bank Transfer**. Enter a reference number.
3. Complete the sale.
4. **Expected:** Receipt shows "Bank Transfer" as payment method.
5. **Check:** Sales History shows the correct payment method label "Bank Transfer".

---

## Scenario 6 — Add a Customer

1. Navigate to **Customers**. Tap **+**.
2. Add: Name = "Abebe Construction", Phone = 0911000001, Location = "Bole".
3. Save.
4. **Expected:** Customer appears in the list.

---

## Scenario 7 — Credit Sale (Owner Approves)

1. New sale. Add "Cement 50kg" × 10. Select customer "Abebe Construction".
2. Tap **Credit Sale**. Enter reason "Regular customer, 30-day terms". Submit.
3. **Expected (seller):** "Approval request submitted" message. Sale not yet in history.
4. Switch to Owner account. Navigate to **Approvals**. The pending request appears.
5. **Expected (owner):** See seller name, customer, items, total.
6. Tap **Approve**.
7. **Expected:** Sale status changes to Completed. Stock reduces by 10 bags.
8. **Check (seller):** Sale now appears in Sales History as completed.

---

## Scenario 8 — Credit Sale (Owner Rejects)

1. New credit sale: "Iron Rod 12mm" × 2. Customer: Abebe Construction. Reason: "Test reject".
2. Owner rejects with comment "Not approved — insufficient history."
3. **Expected (seller):** Sale in history shows "Cancelled". Stock unchanged.

---

## Scenario 9 — Customer Payment

1. Abebe Construction now has an outstanding balance from Scenario 7.
2. Navigate to Customers → Abebe Construction.
3. **Expected:** Balance card shows ETB 4,200 (10 × 420).
4. Tap **Record Payment**. Enter ETB 2,000, method: Cash.
5. **Expected:** Balance updates to ETB 2,200.

---

## Scenario 10 — Credit Limit

1. Owner edits Abebe Construction: Credit limit = ETB 3,000.
2. Try to create a credit sale for ETB 3,500 (more than remaining limit).
3. **Expected:** Error message "Credit limit exceeded."

---

## Scenario 11 — Block Credit

1. Owner edits Abebe Construction: toggle **Block credit sales** ON.
2. Try any credit sale for this customer.
3. **Expected:** Error "This customer is blocked from credit sales."

---

## Scenario 12 — Daily Cash Closing (Seller)

1. Seller opens **Cash Closing** from their home screen.
2. "Today's Summary" card shows expected cash = total from Scenario 4.
3. Enter actual cash (count what's in the drawer). Tap **Submit**.
4. **Expected:** Submission confirmation.

---

## Scenario 13 — Review Cash Closing (Owner)

1. Owner navigates to **Cash Closings**.
2. Submitted closing appears with difference highlighted:
   - Green = surplus, Red = shortage.
3. Tap **Approve**.
4. **Expected:** Status changes to Approved.

---

## Scenario 14 — Sales Reports

1. Owner goes to **Settings → Sales Reports**.
2. Select **This Month**.
3. **Expected:**
   - Revenue card shows correct total.
   - Cash / Bank / Mobile Money bars show correct split.
   - Top Products lists Cement and Iron Rod by revenue.
   - Gross Profit card shows (total revenue − cost of goods = gross profit).

---

## Scenario 15 — Invite a Seller

1. Owner: Settings → Manage Employees → Add Employee → Role: Seller.
2. Copy the invite code. Share it with the test seller.
3. Seller: opens app, taps Register, enters the invite code.
4. **Expected:** Seller profile created, seller sees the Seller home screen.

---

## Scenario 16 — Seller View Restrictions

1. Log in as the seller created in Scenario 15.
2. **Expected:**
   - Seller can see only their own sales in Sales History (not the owner's).
   - Approvals and Reports menu items are NOT visible.
   - Products and Customers are visible (read-only for products, add for customers).

---

## Scenario 17 — PDF Receipt

1. Open any completed sale from Sales History.
2. Tap the **Share/Print** icon.
3. **Expected:** PDF preview opens with store name, invoice number, items, total.
4. Share via WhatsApp or email.

---

## Pass / Fail Log

| Scenario | Pass | Fail | Notes |
|---|---|---|---|
| 1 Owner Registration | | | |
| 2 Add Products | | | |
| 3 Categories | | | |
| 4 Cash Sale | | | |
| 5 Bank Transfer | | | |
| 6 Add Customer | | | |
| 7 Credit Approve | | | |
| 8 Credit Reject | | | |
| 9 Customer Payment | | | |
| 10 Credit Limit | | | |
| 11 Block Credit | | | |
| 12 Cash Closing Seller | | | |
| 13 Cash Closing Owner | | | |
| 14 Reports | | | |
| 15 Invite Seller | | | |
| 16 Seller Restrictions | | | |
| 17 PDF Receipt | | | |
