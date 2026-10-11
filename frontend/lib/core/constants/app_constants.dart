class AppConstants {
  static const String currencySymbol = '₹';

  static String formatCurrency(double amount, {bool showSign = false}) {
    final formatted = '$currencySymbol${amount.abs().toStringAsFixed(2)}';
    if (!showSign) return formatted;
    if (amount > 0.005) return '+$formatted';
    if (amount < -0.005) return '-$formatted';
    return formatted;
  }
}
