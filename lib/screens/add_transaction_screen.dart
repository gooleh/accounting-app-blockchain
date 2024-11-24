import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/transaction_provider.dart';
import '../providers/meta_mask_provider.dart'; // MetaMaskProvider 임포트
import '../colors.dart'; // AppColors가 정의되어 있다고 가정
import '../models/transaction.dart'
    as app_models; // Transaction 클래스 임포트 및 접두사 사용

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({Key? key}) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final Uuid _uuid = const Uuid();

  String _selectedType = 'expense';
  String _selectedCategory = '기타 지출';

  final List<String> _incomeCategories = [
    '급여',
    '보너스',
    '기타 수입',
  ];

  final List<String> _expenseCategories = [
    '식비',
    '교통비',
    '쇼핑',
    '엔터테인먼트',
    '기타 지출',
  ];

  bool _isLoading = false; // 로딩 상태 추가

  @override
  void initState() {
    super.initState();
    // 추가 초기화가 필요하다면 여기에 작성
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true; // 로딩 시작
    });

    final enteredTitle = _titleController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text.trim());

    if (enteredAmount == null || enteredAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('유효한 금액을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false; // 로딩 종료
      });
      return;
    }

    final now = DateTime.now();
    final String category = _selectedCategory;

    // UUID를 사용하여 고유 ID 생성
    final String transactionId = _uuid.v4();

    final app_models.Transaction newTransaction = app_models.Transaction(
      id: transactionId,
      title: enteredTitle,
      amount: enteredAmount,
      date: now,
      type: _selectedType,
      category: category,
      cid: '', // 초기 CID는 빈 문자열로 설정
      userId: 'userId', // 사용자 ID는 실제 사용자 ID로 대체
      txHash: '', // txHash 초기화
    );

    try {
      // MetaMask가 연결되어 있는지 확인
      final metaMaskProvider =
          Provider.of<MetaMaskProvider>(context, listen: false);
      if (metaMaskProvider.walletAddress.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MetaMask가 연결되어 있지 않습니다. 연결해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false; // 로딩 종료
        });
        return;
      }

      // 거래 추가 (Firestore에 저장하고 필요 시 배치에 추가)
      bool batchSent =
          await Provider.of<TransactionProvider>(context, listen: false)
              .addTransactionFirestore(newTransaction);

      if (mounted) {
        if (batchSent) {
          // 배치가 준비되었음을 알림
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('배치 트랜잭션이 준비되었습니다. MetaMask에서 승인을 진행해주세요.'),
              backgroundColor: Colors.blue,
            ),
          );

          // MetaMask 앱으로 이동하라는 안내 메시지 표시
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('MetaMask 승인 필요'),
                content: const Text('MetaMask 앱으로 이동하여 트랜잭션을 승인해주세요.'),
                actions: [
                  TextButton(
                    child: const Text('확인'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // 화면 닫기
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        } else {
          // 거래 추가 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('거래가 성공적으로 추가되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );

          // 화면 닫기
          Navigator.of(context).pop();
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('거래 추가 중 오류가 발생했습니다: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // 로그 기록은 별도로 처리 (예: Logger 사용)
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // 로딩 종료
        });
        // 키패드 내림
        FocusScope.of(context).unfocus();
      }
    }
  }

  List<String> get _availableCategories {
    return _selectedType == 'income' ? _incomeCategories : _expenseCategories;
  }

  @override
  Widget build(BuildContext context) {
    // Optionally, show loading indicator based on provider's isLoading
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 추가'),
        actions: [
          Consumer<TransactionProvider>(
            builder: (context, transactionProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.batch_prediction, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '${transactionProvider.batchCount} / 3',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 화면 외부를 탭하면 키패드를 내림
          FocusScope.of(context).unfocus();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16), // 패딩 조정
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, // 위젯 너비 조정
                    children: [
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: '제목',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        controller: _titleController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '제목을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16), // 간격 추가
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: '금액',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '금액을 입력해주세요.';
                          }
                          if (double.tryParse(value.trim()) == null ||
                              double.parse(value.trim()) <= 0) {
                            return '유효한 금액을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        items: const [
                          DropdownMenuItem(
                            value: 'expense',
                            child: Text('지출'),
                          ),
                          DropdownMenuItem(
                            value: 'income',
                            child: Text('수입'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            _selectedCategory = _availableCategories.first;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: '타입',
                          prefixIcon: const Icon(Icons.swap_horiz),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: _availableCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: '카테고리',
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32), // 간격 조정
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            // 트랜잭션 전송
                            await _submitData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.kAccentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '추가',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
