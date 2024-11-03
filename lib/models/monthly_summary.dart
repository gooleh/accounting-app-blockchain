// models/monthly_summary.dart
class MonthlySummary {
  final String month;
  double totalIncome;
  double totalExpense;

  MonthlySummary({
    required this.month,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
  });
}
