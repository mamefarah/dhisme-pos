# Dhisme POS Testing Checklist

## Authentication

- [ ] Owner can login and is routed to Owner Dashboard.
- [ ] Seller can login and is routed to Seller Dashboard.
- [ ] User without profile sees profile-missing screen.

## Products

- [ ] Owner can create product.
- [ ] Owner can edit product price and stock.
- [ ] Seller can view product list.
- [ ] Seller cannot open product edit screen.
- [ ] Low stock badge appears when `current_stock <= minimum_stock`.

## Customers

- [ ] Owner/seller can add customer.
- [ ] Customer debt starts at 0.

## Cash sale

- [ ] Seller adds product to cart.
- [ ] Seller cannot submit empty cart.
- [ ] Sale succeeds when stock is enough.
- [ ] Sale fails when stock is not enough.
- [ ] Product stock reduces after completed sale.
- [ ] Payment row is created.
- [ ] Stock movement row is created.
- [ ] Audit log row is created.

## Credit sale

- [ ] Seller cannot request credit sale without customer.
- [ ] Seller cannot request credit sale without reason.
- [ ] Credit request creates draft sale.
- [ ] Credit request creates approval request.
- [ ] Owner can approve.
- [ ] Approved credit sale becomes completed.
- [ ] Customer debt increases.
- [ ] Stock reduces only after approval.
- [ ] Owner can reject.
- [ ] Rejected credit sale becomes cancelled.

## Daily cash closing

- [ ] Seller submits actual cash.
- [ ] Backend calculates expected cash.
- [ ] Difference is stored.
- [ ] Owner can approve/reject closing.

## Security / RLS

- [ ] User from another store cannot read data.
- [ ] Seller cannot insert product via direct table insert.
- [ ] Seller cannot directly update sales.
- [ ] Owner-only RPC operations reject seller.

## APK build

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] `flutter build apk --release` succeeds.
