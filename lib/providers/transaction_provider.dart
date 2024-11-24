import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/transaction.dart' as app_models;
import '../services/blockchain_service.dart';
import '../services/ipfs_service.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';
import '../providers/meta_mask_provider.dart'; // MetaMaskProvider 임포트
import '../services/navigation_service.dart'; // NavigationService 임포트

class TransactionProvider with ChangeNotifier {
  final List<app_models.Transaction> _transactions = [];
  final CollectionReference _transactionsCollection =
      FirebaseFirestore.instance.collection('transactions');

  List<app_models.Transaction> get transactions => _transactions;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  final Logger _logger = Logger();
  final IPFSService _ipfsService = IPFSService();

  // 배치 전송을 위한 임시 리스트
  final List<app_models.Transaction> _batchList = [];
  final int _batchSize = 3; // 배치 크기 설정

  final BlockchainService _blockchainService;
  final MetaMaskProvider _metaMaskProvider; // MetaMaskProvider 인스턴스

  // 사용자 설정으로부터 로드되는 기준 금액
  int _thresholdAmount = 1000000; // 기본값 설정
  int get thresholdAmount => _thresholdAmount;

  TransactionProvider(
      this._blockchainService, this._metaMaskProvider, this._thresholdAmount) {
    fetchTransactions();
    _blockchainService.init(); // BlockchainService 초기화 호출
    _blockchainService.transactionStream.listen((tx) {
      // 새로운 블록체인 거래가 추가되면 Firestore에 업데이트
      _transactionsCollection
          .doc(tx.id)
          .update({'txHash': tx.txHash, 'status': 'confirmed'}).catchError((e) {
        _logger.e('Firestore 업데이트 에러: $e');
      });
    });
  }

  // 기준 금액을 업데이트하는 메서드
  void updateThreshold(int newThreshold) {
    _thresholdAmount = newThreshold;
    _logger.d('기준 금액 업데이트: $_thresholdAmount 원');
    notifyListeners();
  }

  void fetchTransactions() {
    _isLoading = true;
    notifyListeners();

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

  /// 배치 전송을 위한 임시 리스트에 거래 추가
  Future<bool> addTransaction(app_models.Transaction tx) async {
    _batchList.add(tx);
    _logger.d('배치 리스트에 거래 추가: ${tx.id}, 현재 배치 리스트 크기: ${_batchList.length}');
    notifyListeners();

    if (_batchList.length >= _batchSize) {
      // 배치가 준비되었으므로 배치 트랜잭션을 전송
      _logger.d('배치 트랜잭션 전송 시작.');
      sendBatchTransaction(); // await 제거하여 비동기 처리
      _logger.d('배치 트랜잭션 전송 요청 완료.');
      return true; // 배치 전송이 발생했음을 알림
    }
    return false; // 배치 전송이 발생하지 않았음을 알림
  }

  /// 배치 트랜잭션 데이터 준비
  Map<String, dynamic> prepareBatchTransactionData() {
    List<String> ids = _batchList.map((tx) => tx.id).toList();
    List<String> cids = _batchList.map((tx) => tx.cid).toList();

    String connectedAddress = _metaMaskProvider.walletAddress;
    _logger.d('연결된 지갑 주소: $connectedAddress');
    if (connectedAddress.isEmpty) {
      throw Exception('연결된 MetaMask 지갑 주소가 없습니다.');
    }

    final data = _blockchainService.contract
        .function('storeTransactions')
        .encodeCall([ids, cids]);

    final tx = {
      'from': connectedAddress,
      'to': _blockchainService.contract.address.hex,
      'data': bytesToHex(data, include0x: true),
      'gas': '0x${(200000 * ids.length).toRadixString(16)}',
      'gasPrice': '0x${BigInt.from(1000000000).toRadixString(16)}',
    };

    _logger.d('트랜잭션 객체: $tx');

    return tx;
  }

  /// 배치 트랜잭션을 MetaMask를 통해 전송하는 메서드
  Future<void> sendBatchTransaction() async {
    _isLoading = true;
    notifyListeners();

    try {
      Map<String, dynamic> txData = prepareBatchTransactionData();

      // MetaMaskProvider를 통해 트랜잭션 전송
      _logger.d('트랜잭션 전송 요청: $txData');
      await _metaMaskProvider.sendTransaction(txData);

      // 사용자에게 MetaMask로 이동하라는 안내 표시
      final BuildContext? context =
          NavigationService.navigatorKey.currentState?.context;
      if (context != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('MetaMask에서 승인 필요'),
              content: const Text('MetaMask 앱으로 이동하여 트랜잭션을 승인해주세요.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('확인'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }

      // 트랜잭션 결과를 기다리지 않고 즉시 반환합니다.
      // 배치 리스트는 그대로 유지하거나, 필요에 따라 초기화
      // _batchList.clear();
      // notifyListeners();

      _logger.d('배치 트랜잭션 전송 요청 완료.');
    } catch (e, stackTrace) {
      _error = '트랜잭션 전송 중 오류가 발생했습니다: $e';
      notifyListeners();
      _logger.e('트랜잭션 전송 에러: $e', e, stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 거래 추가 메서드
  /// Returns true if a batch was sent, false otherwise
  Future<bool> addTransactionFirestore(app_models.Transaction tx) async {
    try {
      // Firestore에 저장 (date는 Timestamp로 자동 변환)
      await _transactionsCollection.doc(tx.id).set({
        'id': tx.id,
        'title': tx.title,
        'amount': tx.amount,
        'date': Timestamp.fromDate(tx.date),
        'type': tx.type,
        'category': tx.category,
        'cid': tx.cid,
        'userId': tx.userId,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });
      _logger.d('Firestore에 거래 저장 완료: ${tx.id}');

      // 기준 금액 이상인지 로그 추가
      _logger.d('거래 금액: ${tx.amount}, 기준 금액: $_thresholdAmount');

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
        bool batchSent = await addTransaction(tx);
        if (batchSent) {
          _logger.d('배치 트랜잭션 전송 완료');
          return true;
        }
      }

      // Firestore 실시간 업데이트를 통해 자동으로 _transactions가 업데이트됩니다.
      return false;
    } catch (e, stackTrace) {
      _error = '거래를 추가하는 중 오류가 발생했습니다: $e';
      notifyListeners();
      _logger.e('거래 추가 에러: $e', e, stackTrace);

      return false;
    }
  }

  // 배치 리스트의 크기 반환
  int get batchCount => _batchList.length;

  /// 배치 ID 생성 메서드
  String _generateBatchId() {
    return const Uuid().v4();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 블록체인 트랜잭션을 처리하고 Firestore를 업데이트하는 메서드
  Future<void> handleBlockchainTransaction(app_models.Transaction tx) async {
    try {
      await _transactionsCollection.doc(tx.id).update({
        'status': 'confirmed',
        'txHash': tx.txHash,
        'updatedAt': Timestamp.now(),
      });
      _logger.d('Firestore에 트랜잭션 상태 업데이트 완료: ${tx.id}');
    } catch (e, stackTrace) {
      _logger.e('블록체인 트랜잭션 처리 에러: $e', e, stackTrace);
    }
  }
}
