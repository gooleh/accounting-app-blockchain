// lib/providers/blockchain_transaction_provider.dart

import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/blockchain_service.dart';
import 'package:logger/logger.dart';

class BlockchainTransactionProvider extends ChangeNotifier {
  final List<Transaction> _blockchainTransactions = [];
  final Logger _logger = Logger();

  List<Transaction> get blockchainTransactions => _blockchainTransactions;

  BlockchainTransactionProvider();

  /// BlockchainService의 스트림을 구독하여 새로운 거래를 추가
  void update(BlockchainService blockchainService) {
    // 기존 거래 불러오기
    blockchainService.fetchAllTransactions().then((transactions) {
      _blockchainTransactions.clear();
      _blockchainTransactions.addAll(transactions);
      _logger.d('기존 거래 불러오기 완료: ${transactions.length}건');
      notifyListeners();
    }).catchError((error) {
      // 에러 처리 로직 추가 가능
      _logger.e('기존 거래 불러오기 오류: $error');
    });

    // 새로운 거래 이벤트 리스닝
    blockchainService.transactionStream.listen((transaction) {
      _blockchainTransactions.insert(0, transaction);
      _logger.d('새로운 거래 추가: ${transaction.id}');
      notifyListeners();
    }, onError: (error) {
      _logger.e('새로운 거래 이벤트 리스닝 오류: $error');
    });
  }

  void addTransaction(Transaction transaction) {
    _blockchainTransactions.insert(0, transaction); // 최신 거래를 맨 앞에 추가
    notifyListeners();
  }

  void setTransactions(List<Transaction> transactions) {
    _blockchainTransactions.clear();
    _blockchainTransactions.addAll(transactions);
    notifyListeners();
  }
}
