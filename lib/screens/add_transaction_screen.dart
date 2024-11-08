// lib/screens/add_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart' as app_models; // 별칭 사용
import 'package:uuid/uuid.dart';
import '../services/blockchain_service.dart'; // BlockchainService 임포트

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  AddTransactionScreenState createState() => AddTransactionScreenState();
}

class AddTransactionScreenState extends State<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedType = 'expense';
  String _selectedCategory = '기타 지출'; // 기본 카테고리
  final _formKey = GlobalKey<FormState>();
  final _uuid = Uuid();

  final List<String> _expenseCategories = [
    '식비',
    '교통비',
    '쇼핑',
    '엔터테인먼트',
    '기타 지출',
  ];

  final List<String> _incomeCategories = [
    '급여',
    '보너스',
    '기타 수입',
  ];

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

    final enteredTitle = _titleController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text.trim());

    if (enteredAmount == null || enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('유효한 금액을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
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
    );

    try {
      // BlockchainService 인스턴스 가져오기
      final blockchainService =
          Provider.of<BlockchainService>(context, listen: false);

      await Provider.of<TransactionProvider>(context, listen: false)
          .addTransaction(newTransaction, blockchainService); // 두 번째 인자 추가

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('거래가 성공적으로 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('거래 추가 중 오류가 발생했습니다: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> get _availableCategories {
    return _selectedType == 'income' ? _incomeCategories : _expenseCategories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 추가'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16), // 패딩 조정
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // 위젯 너비 조정
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: '제목'),
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
                decoration: const InputDecoration(labelText: '금액'),
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                    _selectedCategory =
                        _selectedType == 'income' ? '기타 수입' : '기타 지출';
                  });
                },
                decoration: const InputDecoration(labelText: '타입'),
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
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              const SizedBox(height: 32), // 간격 조정
              ElevatedButton(
                onPressed: _submitData,
                child: const Text('추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
