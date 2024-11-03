// lib/models/category_summary.dart

class CategorySummary {
  final String category;
  double totalExpense;

  CategorySummary({
    required this.category,
    this.totalExpense = 0.0,
  });
}
