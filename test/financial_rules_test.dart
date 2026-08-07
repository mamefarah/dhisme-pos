import 'package:dhisme_pos/core/finance/financial_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('payment splits', () {
    test('accepts exact mixed-payment total', () {
      expect(
        FinancialRules.paymentSplitMatches(
          saleTotal: 1000,
          paymentAmounts: const [400, 350, 250],
        ),
        isTrue,
      );
    });

    test('rejects underpayment, overpayment, and zero lines', () {
      expect(
        FinancialRules.paymentSplitMatches(
          saleTotal: 1000,
          paymentAmounts: const [400, 500],
        ),
        isFalse,
      );
      expect(
        FinancialRules.paymentSplitMatches(
          saleTotal: 1000,
          paymentAmounts: const [700, 400],
        ),
        isFalse,
      );
      expect(
        FinancialRules.paymentSplitMatches(
          saleTotal: 1000,
          paymentAmounts: const [1000, 0],
        ),
        isFalse,
      );
    });
  });

  group('purchase payment states', () {
    test('derives paid, partial, and unpaid correctly', () {
      expect(FinancialRules.purchasePaymentStatus(total: 1000, paid: 0), 'unpaid');
      expect(FinancialRules.purchasePaymentStatus(total: 1000, paid: 250), 'partial');
      expect(FinancialRules.purchasePaymentStatus(total: 1000, paid: 1000), 'paid');
    });

    test('rejects negative and excess payment', () {
      expect(
        () => FinancialRules.purchasePaymentStatus(total: 1000, paid: -1),
        throwsArgumentError,
      );
      expect(
        () => FinancialRules.purchasePaymentStatus(total: 1000, paid: 1001),
        throwsArgumentError,
      );
    });
  });

  group('discount controls', () {
    test('seller and manager caps are enforced', () {
      expect(
        FinancialRules.discountAllowedForRole(
          role: 'seller',
          subtotal: 10000,
          discount: 200,
        ),
        isTrue,
      );
      expect(
        FinancialRules.discountAllowedForRole(
          role: 'seller',
          subtotal: 10000,
          discount: 201,
        ),
        isFalse,
      );
      expect(
        FinancialRules.discountAllowedForRole(
          role: 'manager',
          subtotal: 10000,
          discount: 500,
        ),
        isTrue,
      );
      expect(
        FinancialRules.discountAllowedForRole(
          role: 'manager',
          subtotal: 10000,
          discount: 501,
        ),
        isFalse,
      );
    });

    test('zero-value sale discount is rejected', () {
      expect(
        FinancialRules.discountAllowedForRole(
          role: 'owner',
          subtotal: 10000,
          discount: 10000,
        ),
        isFalse,
      );
    });

    test('effective price cannot fall below minimum', () {
      expect(
        FinancialRules.respectsMinimumPrice(
          unitPrice: 100,
          minimumUnitPrice: 95,
          discountRate: 0.05,
        ),
        isTrue,
      );
      expect(
        FinancialRules.respectsMinimumPrice(
          unitPrice: 100,
          minimumUnitPrice: 96,
          discountRate: 0.05,
        ),
        isFalse,
      );
    });
  });

  group('returns', () {
    test('only remaining sold quantity can be returned', () {
      expect(
        FinancialRules.returnQuantityAllowed(
          sold: 10,
          alreadyReturned: 4,
          requested: 6,
        ),
        isTrue,
      );
      expect(
        FinancialRules.returnQuantityAllowed(
          sold: 10,
          alreadyReturned: 4,
          requested: 6.01,
        ),
        isFalse,
      );
    });

    test('final return receives remaining cents exactly', () {
      final first = FinancialRules.lineRefundAmount(
        lineTotal: 10,
        soldQuantity: 3,
        alreadyReturnedQuantity: 0,
        alreadyRefundedAmount: 0,
        requestedQuantity: 1,
      );
      final second = FinancialRules.lineRefundAmount(
        lineTotal: 10,
        soldQuantity: 3,
        alreadyReturnedQuantity: 1,
        alreadyRefundedAmount: first,
        requestedQuantity: 1,
      );
      final finalReturn = FinancialRules.lineRefundAmount(
        lineTotal: 10,
        soldQuantity: 3,
        alreadyReturnedQuantity: 2,
        alreadyRefundedAmount: first + second,
        requestedQuantity: 1,
      );

      expect(first, 3.33);
      expect(second, 3.33);
      expect(finalReturn, 3.34);
      expect(first + second + finalReturn, 10);
    });

    test('full remaining quantity refunds exact remaining line amount', () {
      expect(
        FinancialRules.lineRefundAmount(
          lineTotal: 10,
          soldQuantity: 3,
          alreadyReturnedQuantity: 1,
          alreadyRefundedAmount: 3.33,
          requestedQuantity: 2,
        ),
        6.67,
      );
    });
  });

  test('expected cash includes all inflows and outflows', () {
    expect(
      FinancialRules.expectedCash(
        inflows: const [1000, 500, 200],
        outflows: const [100, 50, 25],
      ),
      1525,
    );
  });
}
