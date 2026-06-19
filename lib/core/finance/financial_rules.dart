class FinancialRules {
  const FinancialRules._();

  /// Currency comparisons permit one cent of rounding variation.
  static const double moneyTolerance = 0.01;

  /// Percentages and physical quantities use only floating-point epsilon.
  static const double strictTolerance = 1e-9;

  static bool paymentSplitMatches({
    required double saleTotal,
    required Iterable<double> paymentAmounts,
  }) {
    if (saleTotal <= 0) return false;
    final amounts = paymentAmounts.toList(growable: false);
    if (amounts.isEmpty || amounts.any((amount) => amount <= 0)) return false;
    final sum = amounts.fold<double>(0, (total, amount) => total + amount);
    return (sum - saleTotal).abs() <= moneyTolerance;
  }

  static String purchasePaymentStatus({
    required double total,
    required double paid,
  }) {
    if (total <= 0) throw ArgumentError.value(total, 'total', 'Must be positive');
    if (paid < 0 || paid - total > moneyTolerance) {
      throw ArgumentError.value(paid, 'paid', 'Must be between zero and total');
    }
    if (paid <= moneyTolerance) return 'unpaid';
    if ((paid - total).abs() <= moneyTolerance) return 'paid';
    return 'partial';
  }

  static double effectiveUnitPrice({
    required double unitPrice,
    required double discountRate,
  }) {
    if (unitPrice < 0) throw ArgumentError.value(unitPrice, 'unitPrice');
    if (discountRate < 0 || discountRate > 1) {
      throw ArgumentError.value(discountRate, 'discountRate');
    }
    return unitPrice * (1 - discountRate);
  }

  static bool respectsMinimumPrice({
    required double unitPrice,
    required double minimumUnitPrice,
    required double discountRate,
  }) {
    if (minimumUnitPrice < 0) return false;
    return effectiveUnitPrice(
          unitPrice: unitPrice,
          discountRate: discountRate,
        ) +
        moneyTolerance >=
        minimumUnitPrice;
  }

  static bool discountAllowedForRole({
    required String role,
    required double subtotal,
    required double discount,
  }) {
    if (subtotal <= 0 || discount < 0 || discount >= subtotal) return false;
    final rate = discount / subtotal;
    switch (role) {
      case 'owner':
        return true;
      case 'manager':
        return rate <= 0.05 + strictTolerance;
      case 'seller':
        return rate <= 0.02 + strictTolerance;
      default:
        return false;
    }
  }

  static double remainingReturnable({
    required double sold,
    required double alreadyReturned,
  }) {
    if (sold < 0 || alreadyReturned < 0) {
      throw ArgumentError('Quantities cannot be negative');
    }
    return (sold - alreadyReturned).clamp(0.0, double.infinity).toDouble();
  }

  static bool returnQuantityAllowed({
    required double sold,
    required double alreadyReturned,
    required double requested,
  }) {
    if (requested <= 0) return false;
    return requested <=
        remainingReturnable(
              sold: sold,
              alreadyReturned: alreadyReturned,
            ) +
            strictTolerance;
  }

  static double expectedCash({
    required Iterable<double> inflows,
    required Iterable<double> outflows,
  }) {
    final incoming = inflows.fold<double>(0, (total, value) => total + value);
    final outgoing = outflows.fold<double>(0, (total, value) => total + value);
    return incoming - outgoing;
  }
}
