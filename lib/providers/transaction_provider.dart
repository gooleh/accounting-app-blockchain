// lib/providers/transaction_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart'; // Logger 패키지 임포트
import '../models/transaction.dart' as app_models;
import '../services/blockchain_service.dart';

class TransactionProvider with ChangeNotifier {
  final List<app_models.Transaction> _transactions = [];
  final CollectionReference _transactionsCollection =
      FirebaseFirestore.instance.collection('transactions');

  List<app_models.Transaction> get transactions => _transactions;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  final Logger _logger = Logger(); // Logger 인스턴스 생성

  TransactionProvider() {
    fetchTransactions();
  }

  void fetchTransactions() {
    _transactionsCollection
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      _transactions.clear();
      for (var doc in snapshot.docs) {
        _transactions.add(
          app_models.Transaction.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        );
      }
      _isLoading = false;
      _error = null;
      notifyListeners();
      _logger.d('Firestore 거래 불러오기 완료: ${_transactions.length}건');
    }, onError: (error) {
      _error = '데이터를 불러오는 중 오류가 발생했습니다.';
      _isLoading = false;
      notifyListeners();
      _logger.e('Firestore 에러: $error'); // Logger 추가
    });
  }

  Future<void> addTransaction(
      app_models.Transaction tx, BlockchainService blockchainService) async {
    try {
      // 먼저 Firestore에 저장
      await _transactionsCollection.doc(tx.id).set(tx.toMap());
      _logger.d('Firestore에 거래 저장 완료: ${tx.id}');

      // 그 다음, amount >= 1000000이면 블록체인에 저장
      if (tx.amount >= 1000000) {
        _logger.d('블록체인에 거래 저장 시도: ${tx.id}');
        String txHash = await blockchainService.sendTransaction(
          tx.id,
          tx.title, // title 전달
          tx.amount,
          tx.date,
          tx.type,
          tx.category,
        );
        _logger.d('블록체인 트랜잭션 해시: $txHash');
      }

      // Firestore 실시간 업데이트를 통해 자동으로 _transactions가 업데이트됩니다.
    } catch (e, stackTrace) {
      _error = '거래를 추가하는 중 오류가 발생했습니다.';
      notifyListeners();
      _logger.e('거래 추가 에러: $e', e, stackTrace); // Logger 추가
    }
  }

  // 추가적인 메서드 (예: 거래 삭제 등) 필요 시 구현
}
