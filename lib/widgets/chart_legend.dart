// lib/widgets/chart_legend.dart

import 'package:flutter/material.dart';

class ChartLegend extends StatelessWidget {
  final Color incomeColor;
  final Color expenseColor;

  const ChartLegend({
    Key? key,
    required this.incomeColor,
    required this.expenseColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 수입 레전드
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: incomeColor,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '수입',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // 지출 레전드
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: expenseColor,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '지출',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
