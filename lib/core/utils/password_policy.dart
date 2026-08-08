enum PasswordPolicyIssue {
  tooShort,
  missingUppercase,
  missingLowercase,
  missingDigit,
  missingSymbol,
}

class PasswordPolicy {
  const PasswordPolicy._();

  static const int minimumLength = 12;

  static PasswordPolicyIssue? validate(String value) {
    if (value.length < minimumLength) return PasswordPolicyIssue.tooShort;
    if (!RegExp(r'[A-Z]').hasMatch(value)) return PasswordPolicyIssue.missingUppercase;
    if (!RegExp(r'[a-z]').hasMatch(value)) return PasswordPolicyIssue.missingLowercase;
    if (!RegExp(r'[0-9]').hasMatch(value)) return PasswordPolicyIssue.missingDigit;
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) return PasswordPolicyIssue.missingSymbol;
    return null;
  }
}
