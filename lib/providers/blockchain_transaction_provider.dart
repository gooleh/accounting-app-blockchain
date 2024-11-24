// lib/providers/blockchain_transaction_provider.dart

import 'package:flutter/foundation.dart';
import '../models/transaction.dart' as app_models;
import '../services/blockchain_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';

enum LoadingState { initial, loading, loaded, error, noMore }

class BlockchainTransactionProvider extends ChangeNotifier {
  final BlockchainService _blockchainService;
  final Logger _logger = Logger();

  List<app_models.Transaction> _transactions = [];
  LoadingState _loadingState = LoadingState.initial;
  String? _error;

  // 페이지네이션 관련 변수
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _hasMoreData = true;

  // 스트림 구독
  StreamSubscription<app_models.Transaction>? _transactionSubscription;
  StreamSubscription<LoadingStatus>? _loadingStatusSubscription;

  // Getters
  List<app_models.Transaction> get transactions => _transactions;
  LoadingState get loadingState => _loadingState;
  String? get error => _error;
  bool get hasMore => _hasMoreData;
  bool get isLoading => _loadingState == LoadingState.loading;

  BlockchainTransactionProvider(this._blockchainService) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!_blockchainService.isInitialized) {
        await _blockchainService.init();
      }

      _setupSubscriptions();
      await refreshTransactions();
    } catch (e, stackTrace) {
      _logger.e('초기화 오류: $e', e, stackTrace);
      _setError('블록체인 서비스 초기화 중 오류가 발생했습니다.');
    }
  }

  void _setupSubscriptions() {
    // 새로운 트랜잭션 이벤트 구독
    _transactionSubscription?.cancel();
    _transactionSubscription = _blockchainService.transactionStream.listen(
      (transaction) {
        _addNewTransaction(transaction);
      },
      onError: (error) {
        _logger.e('트랜잭션 스트림 에러: $error');
        _setError('새로운 트랜잭션 모니터링 중 오류가 발생했습니다.');
      },
    );

    // 로딩 상태 구독
    _loadingStatusSubscription?.cancel();
    _loadingStatusSubscription = _blockchainService.loadingStatusStream.listen(
      (status) {
        _logger.d(
            '로딩 상태 업데이트: ${status.message} (${status.current}/${status.total})');
      },
      onError: (error) {
        _logger.e('로딩 상태 스트림 에러: $error');
      },
    );
  }

  Future<void> refreshTransactions() async {
    if (_loadingState == LoadingState.loading) return;

    try {
      _setLoadingState(LoadingState.loading);
      _currentPage = 0;
      _hasMoreData = true;
      _transactions.clear();

      await _loadMoreTransactions();

      _setLoadingState(
          _transactions.isEmpty ? LoadingState.noMore : LoadingState.loaded);
    } catch (e) {
      _logger.e('거래 새로고침 오류: $e');
      _setError('거래 목록을 새로고침하는 중 오류가 발생했습니다.');
    }
  }

  Future<void> loadMore() async {
    if (_loadingState == LoadingState.loading || !_hasMoreData) return;

    try {
      _setLoadingState(LoadingState.loading);
      await _loadMoreTransactions();

      _setLoadingState(
          _hasMoreData ? LoadingState.loaded : LoadingState.noMore);
    } catch (e) {
      _logger.e('추가 거래 로딩 오류: $e');
      _setError('추가 거래를 불러오는 중 오류가 발생했습니다.');
    }
  }

  Future<void> _loadMoreTransactions() async {
    final start = _currentPage * _pageSize;
    final transactions = await _blockchainService.fetchTransactions(
      start: start,
      limit: _pageSize,
    );

    if (transactions.isEmpty) {
      _hasMoreData = false;
    } else {
      _transactions.addAll(transactions);
      _currentPage++;
      _hasMoreData = transactions.length >= _pageSize;
    }

    notifyListeners();
  }

  void _addNewTransaction(app_models.Transaction transaction) {
    // 중복 체크
    if (!_transactions.any((tx) => tx.id == transaction.id)) {
      _transactions.insert(0, transaction);
      notifyListeners();
    }
  }

  void _setLoadingState(LoadingState state) {
    _loadingState = state;
    _error = null;
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    _loadingState = LoadingState.error;
    notifyListeners();
  }

  /// 트랜잭션 필터링 메서드
  List<app_models.Transaction> filterTransactions({
    String? category,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
  }) {
    return _transactions.where((tx) {
      bool matches = true;

      if (category != null && category.isNotEmpty) {
        matches &= tx.category == category;
      }

      if (type != null && type.isNotEmpty) {
        matches &= tx.type == type;
      }

      if (startDate != null) {
        matches &=
            tx.date.isAfter(startDate) || tx.date.isAtSameMomentAs(startDate);
      }

      if (endDate != null) {
        matches &=
            tx.date.isBefore(endDate) || tx.date.isAtSameMomentAs(endDate);
      }

      if (minAmount != null) {
        matches &= tx.amount >= minAmount;
      }

      if (maxAmount != null) {
        matches &= tx.amount <= maxAmount;
      }

      return matches;
    }).toList();
  }

  Future<void> retryLastOperation() async {
    if (_loadingState == LoadingState.error) {
      await refreshTransactions();
    }
  }

  void clearError() {
    _error = null;
    if (_loadingState == LoadingState.error) {
      _loadingState = LoadingState.initial;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _loadingStatusSubscription?.cancel();
    super.dispose();
  }
}
