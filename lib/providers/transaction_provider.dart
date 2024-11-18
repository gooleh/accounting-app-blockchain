// lib/providers/transaction_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/transaction.dart' as app_models;
import '../services/blockchain_service.dart';
import '../services/ipfs_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences 임포트

class TransactionProvider with ChangeNotifier {
  final List<app_models.Transaction> _transactions = [];
  final CollectionReference _transactionsCollection =
      FirebaseFirestore.instance.collection('transactions');

  List<app_models.Transaction> get transactions => _transactions;
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  final Logger _logger = Logger();
  final IPFSService _ipfsService = IPFSService();

  // 배치 전송을 위한 임시 리스트
  final List<app_models.Transaction> _batchList = [];
  final int _batchSize = 10; // 배치 크기를 10으로 설정

  final BlockchainService _blockchainService;

  // 사용자 설정으로부터 로드되는 기준 금액
  int _thresholdAmount = 1000000; // 기본값 설정

  TransactionProvider(this._blockchainService) {
    fetchTransactions();
    _blockchainService.init(); // BlockchainService 초기화 호출
    _loadThreshold(); // 기준 금액 로드
    _blockchainService.transactionStream.listen((tx) {
      // 새로운 블록체인 거래가 추가되면 Firestore에 업데이트
      _transactionsCollection
          .doc(tx.id)
          .update({'cid': tx.cid}).catchError((e) {
        _logger.e('Firestore 업데이트 에러: $e');
      });
    });
  }

  // SharedPreferences에서 기준 금액을 로드하는 메서드
  Future<void> _loadThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    _thresholdAmount = prefs.getInt('transaction_threshold') ?? 1000000;
    _logger.d('기준 금액 로드 완료: $_thresholdAmount 원');
  }

  // 기준 금액을 업데이트하는 메서드
  void updateThreshold(int newThreshold) {
    _thresholdAmount = newThreshold;
    _logger.d('기준 금액 업데이트: $_thresholdAmount 원');
    notifyListeners();
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
      _logger.e('Firestore 에러: $error');
    });
  }

  /// 배치 트랜잭션을 위한 임시 리스트에 거래 추가
  void addToBatch(app_models.Transaction tx) {
    _batchList.add(tx);
    _logger.d('배치 리스트에 거래 추가: ${tx.id}, 현재 배치 리스트 크기: ${_batchList.length}');

    if (_batchList.length >= _batchSize) {
      _sendBatch();
    }
    // 타이머 기능을 제거하였으므로, 추가 로직은 필요하지 않습니다.
  }

  /// 배치 트랜잭션 전송
  Future<void> _sendBatch() async {
    // 배치 리스트 복사 및 초기화
    List<app_models.Transaction> batch = List.from(_batchList);
    _batchList.clear();

    try {
      _logger.d('배치 트랜잭션 전송 시작: ${batch.length}건');
      // BlockchainService를 사용하여 배치 트랜잭션 전송
      String txHash = await _blockchainService.sendBatchTransaction(batch);
      _logger.d('배치 트랜잭션 전송 완료, 해시: $txHash');
    } catch (e, stackTrace) {
      _logger.e('배치 트랜잭션 전송 에러: $e', e, stackTrace);
      // 에러 발생 시 배치 리스트에 다시 추가하거나 적절한 에러 처리
      _batchList.addAll(batch);
    }
  }

  /// 거래 추가 메서드
  Future<void> addTransaction(app_models.Transaction tx) async {
    try {
      // Firestore에 저장 (date는 Timestamp로 자동 변환)
      await _transactionsCollection.doc(tx.id).set({
        'id': tx.id,
        'title': tx.title,
        'amount': tx.amount,
        'date': tx.date, // Firestore는 DateTime을 Timestamp로 자동 변환
        'type': tx.type,
        'category': tx.category,
        'cid': tx.cid,
        'userId': tx.userId,
      });
      _logger.d('Firestore에 거래 저장 완료: ${tx.id}');

      // 기준 금액 이상이면 블록체인에 저장
      if (tx.amount >= _thresholdAmount) {
        _logger.d('블록체인에 거래 저장 시도: ${tx.id}');

        // 거래 데이터를 Map으로 변환하여 IPFS에 업로드
        Map<String, dynamic> data = tx.toMap();
        String cid = await _ipfsService.uploadData(data);
        _logger.d('IPFS에 데이터 업로드 완료, CID: $cid');

        // CID를 Transaction 객체에 설정
        tx.cid = cid;

        // Firestore에 CID 업데이트
        await _transactionsCollection.doc(tx.id).update({'cid': cid});
        _logger.d('Firestore에 CID 업데이트 완료: ${tx.id}, CID: $cid');

        // 배치 리스트에 추가
        addToBatch(tx);
      }

      // Firestore 실시간 업데이트를 통해 자동으로 _transactions가 업데이트됩니다.
    } catch (e, stackTrace) {
      _error = '거래를 추가하는 중 오류가 발생했습니다.';
      notifyListeners();
      _logger.e('거래 추가 에러: $e', e, stackTrace);
    }
  }

  // 필요에 따라 dispose 메서드에서 타이머 관련 코드를 제거합니다.
  @override
  void dispose() {
    super.dispose();
  }

  // 추가적인 메서드 필요 시 구현
}
