// lib/providers/blockchain_transaction_provider.dart

import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/blockchain_service.dart';
import 'package:logger/logger.dart';

class BlockchainTransactionProvider extends ChangeNotifier {
  final List<Transaction> _blockchainTransactions = [];
  final Logger _logger = Logger();
  bool _isListening = false;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<Transaction> get blockchainTransactions => _blockchainTransactions;

  BlockchainTransactionProvider();

  /// BlockchainService의 스트림을 구독하여 새로운 거래를 추가
  void update(BlockchainService blockchainService) {
    // 기존 거래 불러오기
    blockchainService.fetchAllTransactions().then((transactions) {
      _blockchainTransactions
        ..clear()
        ..addAll(transactions);
      _logger.d('기존 거래 불러오기 완료: ${transactions.length}건');
      _isLoading = false;
      _error = null;
      notifyListeners();
    }).catchError((error) {
      // 에러 처리 로직 추가
      _error = '블록체인 거래를 불러오는 중 오류가 발생했습니다.';
      _isLoading = false;
      _logger.e('기존 거래 불러오기 오류: $error');
      notifyListeners();
    });

    // 새로운 거래 이벤트 리스닝 (이미 리스닝 중인지 확인)
    if (!_isListening) {
      blockchainService.transactionStream.listen((transaction) {
        _blockchainTransactions.insert(0, transaction);
        _logger.d('새로운 거래 추가: ${transaction.id}');
        notifyListeners();
      }, onError: (error) {
        _error = '새로운 거래 이벤트를 수신하는 중 오류가 발생했습니다.';
        _logger.e('새로운 거래 이벤트 리스닝 오류: $error');
        notifyListeners();
      });
      _isListening = true;
    }
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
