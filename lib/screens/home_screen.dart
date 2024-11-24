import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'transaction_list_screen.dart';
import 'add_transaction_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../providers/transaction_provider.dart';
import '../providers/meta_mask_provider.dart'; // MetaMaskProvider 임포트
import '../models/transaction.dart' as models;
import '../colors.dart';
import '../icons.dart'; // CategoryIcons 임포트
import 'package:fl_chart/fl_chart.dart'; // 그래프를 위해 추가
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const TransactionListScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  // 애니메이션 컨트롤러
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 애니메이션 시작
    _animationController.forward();
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러 해제
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가계부 앱'),
      ),
      body: _screens[_currentIndex],
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                  ),
                );
              },
              backgroundColor: AppColors.kAccentColor,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '거래내역'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '통계'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;

            // 새로운 탭으로 전환 시 애니메이션 재생
            _animationController.reset();
            _animationController.forward();
          });
        },
      ),
    );
  }
}

// 업그레이드된 홈 탭 위젯
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  HomeTabState createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  // 애니메이션 컨트롤러
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 애니메이션 시작
    _animationController.forward();
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러 해제
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, MetaMaskProvider>(
      builder: (context, transactionProvider, metaMaskProvider, child) {
        if (transactionProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (transactionProvider.error != null) {
          return Center(
            child: Text(
              transactionProvider.error!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        final transactions = transactionProvider.transactions;

        // 총 수입 및 지출 계산
        double totalIncome = transactions
            .where((tx) => tx.type == 'income')
            .fold(0.0, (sum, tx) => sum + tx.amount);

        double totalExpense = transactions
            .where((tx) => tx.type == 'expense')
            .fold(0.0, (sum, tx) => sum + tx.amount);

        double balance = totalIncome - totalExpense;

        // 최근 거래 내역 최대 5개
        List<models.Transaction> recentTransactions = transactions.length <= 5
            ? transactions
            : transactions.sublist(0, 5);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0), // 패딩 추가
            child: FadeTransition(
              opacity: _animationController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // MetaMask 연결 상태 표시
                  _buildMetaMaskStatus(metaMaskProvider),
                  const SizedBox(height: 16),
                  // 잔액 카드
                  _buildBalanceCard(balance),
                  const SizedBox(height: 16),
                  // 수입 및 지출 카드
                  _buildIncomeExpenseCards(totalIncome, totalExpense),
                  const SizedBox(height: 16),
                  // 월별 수입/지출 그래프
                  _buildIncomeExpenseChart(transactions),
                  const SizedBox(height: 16),
                  // 최근 거래 내역
                  _buildRecentTransactions(recentTransactions),
                  const SizedBox(height: 16),
                  // 블록체인 거래 보기 버튼 추가
                  ElevatedButton.icon(
                    icon: const Icon(Icons.block),
                    label: const Text('블록체인 거래 보기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/blockchain_transactions');
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // MetaMask 연결 상태 표시 위젯
  Widget _buildMetaMaskStatus(MetaMaskProvider metaMaskProvider) {
    bool isConnected = metaMaskProvider.isConnected;
    return Row(
      children: [
        Icon(
          isConnected ? Icons.check_circle : Icons.error,
          color: isConnected ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isConnected
                ? 'MetaMask 연결됨: ${_shortenAddress(metaMaskProvider.walletAddress)}'
                : 'MetaMask 연결되지 않음',
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (!isConnected)
          ElevatedButton(
            onPressed: () async {
              await metaMaskProvider.connect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kAccentColor,
            ),
            child: const Text('연결'),
          ),
      ],
    );
  }

  // 지갑 주소를 간략하게 표시하는 헬퍼 메서드
  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Widget _buildBalanceCard(double balance) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
      child: Card(
        color: AppColors.kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('현재 잔액', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${balance.toStringAsFixed(0)} 원',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseCards(double totalIncome, double totalExpense) {
    return Row(
      children: [
        Expanded(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
              ),
            ),
            child: Card(
              color: AppColors.kCardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  children: [
                    const Icon(FontAwesomeIcons.circleArrowDown,
                        color: Colors.greenAccent, size: 30),
                    const SizedBox(height: 8),
                    Text('총 수입', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text(
                      '${totalIncome.toStringAsFixed(0)} 원',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
              ),
            ),
            child: Card(
              color: AppColors.kCardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  children: [
                    const Icon(FontAwesomeIcons.circleArrowUp,
                        color: Colors.redAccent, size: 30),
                    const SizedBox(height: 8),
                    Text('총 지출', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text(
                      '${totalExpense.toStringAsFixed(0)} 원',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeExpenseChart(List<models.Transaction> transactions) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
      child: Card(
        color: AppColors.kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 200,
            child: LineChart(
              _buildLineChartData(transactions),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(List<models.Transaction> recentTransactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 거래 내역',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentTransactions.length,
          itemBuilder: (context, index) {
            final tx = recentTransactions[index];
            IconData iconData =
                CategoryIcons.icons[tx.category] ?? Icons.help_outline;
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    0.6 + (index * 0.1),
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              child: Card(
                color: AppColors.kCardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    iconData,
                    color: AppColors.kAccentColor,
                  ),
                  title: Text(tx.title,
                      style: Theme.of(context).textTheme.bodyLarge),
                  subtitle: Text(
                      '${tx.type == 'income' ? '수입' : '지출'}: ${tx.amount.toStringAsFixed(0)} 원'),
                  trailing: Text(
                    '${tx.date.month}월 ${tx.date.day}일',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  LineChartData _buildLineChartData(List<models.Transaction> transactions) {
    // 월별 수입 및 지출 데이터를 계산합니다.
    Map<String, double> monthlyIncome = {};
    Map<String, double> monthlyExpense = {};

    for (var tx in transactions) {
      String month =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      if (tx.type == 'income') {
        monthlyIncome[month] = (monthlyIncome[month] ?? 0) + tx.amount;
      } else {
        monthlyExpense[month] = (monthlyExpense[month] ?? 0) + tx.amount;
      }
    }

    // 월별로 정렬된 리스트를 만듭니다.
    List<String> months =
        monthlyIncome.keys.toSet().union(monthlyExpense.keys.toSet()).toList();
    months.sort();

    // 그래프에 표시할 데이터 포인트를 생성합니다.
    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];

    for (int i = 0; i < months.length; i++) {
      String month = months[i];
      incomeSpots.add(FlSpot(
        i.toDouble(),
        monthlyIncome[month] ?? 0,
      ));
      expenseSpots.add(FlSpot(
        i.toDouble(),
        monthlyExpense[month] ?? 0,
      ));
    }

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: incomeSpots,
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
          spots: expenseSpots,
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
              if (index >= 0 && index < months.length) {
                // 월 이름 변환
                String monthName = _getMonthName(months[index]);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    monthName,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              } else {
                return const Text('');
              }
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: false, // y축 레이블 숨기기
          ),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      minY: 0,
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      // 터치 툴팁 추가
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.blueAccent,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              String label = spot.bar.color == Colors.greenAccent ? '수입' : '지출';
              return LineTooltipItem(
                '$label: ${spot.y.toStringAsFixed(0)} 원',
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
    );
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
}
