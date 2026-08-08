import 'package:dhisme_pos/core/utils/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepts a strong password', () {
      expect(PasswordPolicy.validate('DhismePilot#2026'), isNull);
    });

    test('requires at least 12 characters', () {
      expect(
        PasswordPolicy.validate('Short#2Aa'),
        PasswordPolicyIssue.tooShort,
      );
    });

    test('requires uppercase', () {
      expect(
        PasswordPolicy.validate('dhismepilot#2026'),
        PasswordPolicyIssue.missingUppercase,
      );
    });

    test('requires lowercase', () {
      expect(
        PasswordPolicy.validate('DHISMEPILOT#2026'),
        PasswordPolicyIssue.missingLowercase,
      );
    });

    test('requires a number', () {
      expect(
        PasswordPolicy.validate('DhismePilot#Pass'),
        PasswordPolicyIssue.missingDigit,
      );
    });

    test('requires a symbol', () {
      expect(
        PasswordPolicy.validate('DhismePilot2026'),
        PasswordPolicyIssue.missingSymbol,
      );
    });
  });
}
