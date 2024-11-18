// lib/screens/stats_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:fl_chart/fl_chart.dart';
import '../models/monthly_summary.dart';
import '../models/transaction.dart' as models;
import '../widgets/chart_legend.dart';
import '../colors.dart'; // AppColors 임포트

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  StatsScreenState createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  List<MonthlySummary> _monthlySummaries = [];
  Map<String, List<models.Transaction>> _monthlyTransactions = {};
  Map<String, double> _categoryExpenses = {};

  // 애니메이션 컨트롤러 추가
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _fetchData();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러 해제
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      firestore.QuerySnapshot snapshot = await firestore
          .FirebaseFirestore.instance
          .collection('transactions')
          .get();

      Map<String, MonthlySummary> summaries = {};
      Map<String, double> categoryExpenses = {};
      Map<String, List<models.Transaction>> monthlyTransactions = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime date = (data['date'] as firestore.Timestamp).toDate();
        String month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        double amount = (data['amount'] as num).toDouble();
        String type = data['type'];
        String category = data['category'] ?? '기타 지출';

        // 월별 합계 계산
        if (!summaries.containsKey(month)) {
          summaries[month] = MonthlySummary(
            month: month,
          );
        }

        if (type == 'income') {
          summaries[month]!.totalIncome += amount;
        } else {
          summaries[month]!.totalExpense += amount;
          // 카테고리별 지출 합계 계산
          categoryExpenses[category] =
              (categoryExpenses[category] ?? 0) + amount;
        }

        // 월별 거래 내역 저장
        if (!monthlyTransactions.containsKey(month)) {
          monthlyTransactions[month] = [];
        }
        models.Transaction transaction =
            models.Transaction.fromMap(data, doc.id);
        monthlyTransactions[month]!.add(transaction);
      }

      setState(() {
        _monthlySummaries = summaries.values.toList();
        _monthlySummaries.sort((a, b) => a.month.compareTo(b.month));
        _categoryExpenses = categoryExpenses;
        _monthlyTransactions = monthlyTransactions;

        // 데이터 로드 후 애니메이션 시작
        _animationController.forward();
      });
    } catch (e) {
      print('데이터 처리 오류: $e');
      // 에러 상태를 사용자에게 알리기 위한 추가 로직 필요 시 구현
    }
  }

  String _getMonthName(String month) {
    List<String> months = [
      '1월',
      '2월',
      '3월',
      '4월',
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
      '11월',
      '12월'
    ];
    int monthIndex = int.parse(month.split('-')[1]) - 1;
    return months[monthIndex];
  }

  List<PieChartSectionData> _buildPieChartSections() {
    List<PieChartSectionData> sections = [];
    final totalExpense = _categoryExpenses.values.fold(0.0, (a, b) => a + b);

    _categoryExpenses.forEach((category, amount) {
      final percentage = (amount / totalExpense) * 100;
      sections.add(
        PieChartSectionData(
          color: _getCategoryColor(category),
          value: percentage,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return sections;
  }

  Color _getCategoryColor(String category) {
    // 카테고리에 따라 색상을 지정합니다.
    switch (category) {
      case '식비':
        return Colors.blue;
      case '교통비':
        return Colors.orange;
      case '쇼핑':
        return Colors.purple;
      case '엔터테인먼트':
        return Colors.red;
      case '기타 지출':
      default:
        return Colors.grey;
    }
  }

  Widget _buildCategoryLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: _categoryExpenses.keys.map((category) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              color: _getCategoryColor(category),
            ),
            const SizedBox(width: 4),
            Text(
              category,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통계'),
      ),
      body: _monthlySummaries.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: FadeTransition(
                opacity: _animation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 월별 수입/지출 라인차트
                    const SizedBox(height: 16),
                    ChartLegend(
                      incomeColor: Colors.greenAccent,
                      expenseColor: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: _monthlySummaries.asMap().entries.map((e) {
                                int index = e.key;
                                MonthlySummary summary = e.value;
                                return FlSpot(
                                  index.toDouble(),
                                  summary.totalIncome,
                                );
                              }).toList(),
                              isCurved: true,
                              color: Colors.greenAccent,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.greenAccent.withOpacity(0.2),
                              ),
                            ),
                            LineChartBarData(
                              spots: _monthlySummaries.asMap().entries.map((e) {
                                int index = e.key;
                                MonthlySummary summary = e.value;
                                return FlSpot(
                                  index.toDouble(),
                                  summary.totalExpense,
                                );
                              }).toList(),
                              isCurved: true,
                              color: Colors.redAccent,
                              barWidth: 2,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.redAccent.withOpacity(0.2),
                              ),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index >= 0 &&
                                      index < _monthlySummaries.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        _getMonthName(
                                            _monthlySummaries[index].month),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  } else {
                                    return const SizedBox.shrink();
                                  }
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: Colors.blueAccent,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  String label =
                                      spot.bar.color == Colors.greenAccent
                                          ? '수입'
                                          : '지출';
                                  return LineTooltipItem(
                                    '$label: ${spot.y.toStringAsFixed(0)}원',
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 카테고리별 지출 파이차트
                    const Text(
                      '카테고리별 지출',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _buildPieChartSections(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                          // 애니메이션 추가
                          pieTouchData: PieTouchData(
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                return;
                              }
                              setState(() {
                                final index = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                                // 선택된 섹션 강조 등의 추가 기능 구현 가능
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryLegend(),
                    const SizedBox(height: 32),
                    // 월별 합계 및 상세 거래 내역
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _monthlySummaries.length,
                      itemBuilder: (context, index) {
                        MonthlySummary summary = _monthlySummaries[index];
                        String month = summary.month;
                        List<models.Transaction> transactions =
                            _monthlyTransactions[month] ?? [];

                        return ExpansionTile(
                          leading: const Icon(
                            Icons.calendar_today,
                            color: Colors.blueAccent,
                          ),
                          title: Text(
                            _getMonthName(month),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '수입: ${summary.totalIncome.toStringAsFixed(0)}원, 지출: ${summary.totalExpense.toStringAsFixed(0)}원',
                          ),
                          children: transactions.map((tx) {
                            // 널 체크는 이미 되어 있으므로 생략
                            return ListTile(
                              leading: Icon(
                                tx.type == 'income'
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: tx.type == 'income'
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                              title: Text(tx.title),
                              subtitle: Text(
                                  '${tx.type == 'income' ? '수입' : '지출'}: ${tx.amount.toStringAsFixed(0)}원'),
                              trailing: Text(
                                '${tx.date.month}월 ${tx.date.day}일',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
