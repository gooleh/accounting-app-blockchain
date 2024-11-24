// lib/services/blockchain_service.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:logger/logger.dart';
import '../models/transaction.dart' as app_models;
import 'ipfs_service.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoadingStatus {
  final int current;
  final int total;
  final String message;
  final DateTime timestamp;

  LoadingStatus({
    required this.current,
    required this.total,
    required this.message,
    required this.timestamp,
  });
}

class BlockchainService extends ChangeNotifier {
  late Web3Client _client;
  late DeployedContract _contract;
  late ContractFunction _getTransaction;
  late ContractFunction _getTransactionCount;
  late ContractEvent _transactionStoredEvent;

  final String _rpcUrl =
      dotenv.env['RPC_URL'] ?? (throw Exception('RPC_URL이 설정되지 않았습니다.'));
  final String _contractAddress = dotenv.env['CONTRACT_ADDRESS'] ??
      (throw Exception('CONTRACT_ADDRESS가 설정되지 않았습니다.'));

  final Logger _logger = Logger();
  final IPFSService _ipfsService;
  final Client _httpClient = Client();

  final StreamController<app_models.Transaction> _transactionController =
      StreamController.broadcast();
  final StreamController<LoadingStatus> _loadingStatusController =
      StreamController<LoadingStatus>.broadcast();

  Stream<app_models.Transaction> get transactionStream =>
      _transactionController.stream;
  Stream<LoadingStatus> get loadingStatusStream =>
      _loadingStatusController.stream;

  bool _isInitialized = false;
  bool _isLoading = false;

  // 메모리 캐시
  final Map<String, app_models.Transaction> _transactionCache = {};

  BlockchainService({IPFSService? ipfsService})
      : _ipfsService = ipfsService ?? IPFSService() {
    _client = Web3Client(_rpcUrl, _httpClient);
  }

  DeployedContract get contract => _contract;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isLoading = true;
      notifyListeners();

      String abiString =
          await rootBundle.loadString('assets/TransactionStorageABI.json');
      _logger.d('ABI 로드 완료');

      final contractAddr = EthereumAddress.fromHex(_contractAddress);
      final contractAbi =
          ContractAbi.fromJson(abiString, 'HighValueDataStorage');
      _contract = DeployedContract(contractAbi, contractAddr);

      _getTransaction = _contract.function('getTransaction');
      _getTransactionCount = _contract.function('getTransactionCount');
      _transactionStoredEvent = _contract.event('TransactionStored');

      _listenToTransactionEvents();

      _isInitialized = true;
      _logger.d('BlockchainService 초기화 완료');
    } catch (e, stackTrace) {
      _logger.e('초기화 오류: $e', e, stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 페이지네이션을 지원하는 트랜잭션 조회 메서드
  Future<List<app_models.Transaction>> fetchTransactions({
    required int start,
    required int limit,
  }) async {
    if (!_isInitialized) await init();

    try {
      _isLoading = true;
      notifyListeners();

      BigInt count = await getTransactionCount();
      int totalCount = count.toInt();

      if (totalCount == 0 || start >= totalCount) {
        return [];
      }

      _loadingStatusController.add(LoadingStatus(
        current: start,
        total: totalCount,
        message: '트랜잭션 조회 중...',
        timestamp: DateTime.now(),
      ));

      List<app_models.Transaction> transactions = [];

      // 가장 최근 트랜잭션부터 가져오기 위해 인덱스 계산
      int endIndex = totalCount - 1 - start;
      int startIndex = endIndex - limit + 1;
      if (startIndex < 0) {
        startIndex = 0;
      }

      // 병렬 처리로 트랜잭션 조회 속도 향상
      List<Future<app_models.Transaction?>> futures = [];
      for (int i = endIndex; i >= startIndex; i--) {
        futures.add(getTransactionByIndex(i));
      }

      final results = await Future.wait(futures);

      for (var tx in results) {
        if (tx != null) {
          transactions.add(tx);
        }
      }

      _loadingStatusController.add(LoadingStatus(
        current: totalCount - startIndex,
        total: totalCount,
        message: '트랜잭션 로드 완료',
        timestamp: DateTime.now(),
      ));

      return transactions;
    } catch (e, stackTrace) {
      _logger.e('트랜잭션 조회 오류: $e', e, stackTrace);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BigInt> getTransactionCount() async {
    if (!_isInitialized) await init();

    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTransactionCount,
        params: [],
      );

      if (result.isEmpty) {
        throw Exception('스마트 컨트랙트로부터 예상치 못한 응답을 받았습니다.');
      }

      _logger.d('전체 트랜잭션 수 조회 결과: ${result[0]}');
      return result[0] as BigInt;
    } catch (e, stackTrace) {
      _logger.e('트랜잭션 수 조회 오류: $e', e, stackTrace);
      rethrow;
    }
  }

  Future<app_models.Transaction?> getTransactionByIndex(int index) async {
    if (!_isInitialized) await init();

    try {
      // 캐시 확인
      if (_transactionCache.containsKey(index.toString())) {
        return _transactionCache[index.toString()];
      }

      final result = await _client.call(
        contract: _contract,
        function: _getTransaction,
        params: [BigInt.from(index)],
      );

      if (result.isEmpty || result.length < 2) return null;

      String id = result[0].toString();
      String cid = result[1].toString();

      if (cid.isEmpty) {
        final dbData = await fetchFromDatabase(id);
        if (dbData == null) return null;

        final transaction = app_models.Transaction.fromMap(dbData, id);
        _transactionCache[index.toString()] = transaction;
        return transaction;
      }

      // IPFS 데이터 가져오기
      Map<String, dynamic>? ipfsData;
      try {
        ipfsData = await _ipfsService.fetchData(cid);
      } catch (e) {
        _logger.e('IPFS 데이터 가져오기 오류: $e');
        // 예외를 다시 던지거나 null을 반환하여 호출자가 처리하도록 할 수 있습니다.
        return null;
      }

      if (ipfsData == null) return null;

      final transaction = app_models.Transaction(
        id: id,
        cid: cid,
        txHash: '',
        title: ipfsData['title'] ?? '',
        amount: double.tryParse(ipfsData['amount'].toString()) ?? 0.0,
        date: DateTime.tryParse(ipfsData['date'] ?? '') ?? DateTime.now(),
        type: ipfsData['type'] ?? '',
        category: ipfsData['category'] ?? '',
        userId: ipfsData['userId'] ?? 'userId',
      );

      _transactionCache[index.toString()] = transaction;
      return transaction;
    } catch (e, stackTrace) {
      _logger.e('트랜잭션 조회 오류: $e', e, stackTrace);
      return null;
    }
  }

  void _listenToTransactionEvents() {
    final eventStream = _client.events(FilterOptions.events(
      contract: _contract,
      event: _transactionStoredEvent,
    ));

    eventStream.listen(
      (event) async {
        try {
          final decoded =
              _transactionStoredEvent.decodeResults(event.topics!, event.data!);
          if (decoded.length != 2) throw Exception('잘못된 이벤트 데이터');

          String id = decoded[0].toString();
          String cid = decoded[1].toString();
          String txHash = event.transactionHash ?? '';

          final ipfsData = await _ipfsService.fetchData(cid);
          if (ipfsData == null) return;

          final transaction = app_models.Transaction(
            id: id,
            cid: cid,
            txHash: txHash,
            title: ipfsData['title'] ?? '',
            amount: double.tryParse(ipfsData['amount'].toString()) ?? 0.0,
            date: DateTime.tryParse(ipfsData['date'] ?? '') ?? DateTime.now(),
            type: ipfsData['type'] ?? '',
            category: ipfsData['category'] ?? '',
            userId: ipfsData['userId'] ?? 'userId',
          );

          _transactionCache[id] = transaction;
          _transactionController.add(transaction);
        } catch (e, stackTrace) {
          _logger.e('이벤트 처리 오류: $e', e, stackTrace);
        }
      },
      onError: (error) => _logger.e('이벤트 스트림 오류: $error'),
      onDone: () => _logger.d('이벤트 스트림 종료'),
    );
  }

  Future<Map<String, dynamic>?> fetchFromDatabase(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(id)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e) {
      _logger.e('Firestore 조회 오류: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _transactionController.close();
    _loadingStatusController.close();
    _client.dispose();
    _httpClient.close();
    super.dispose();
  }

  /// 캐시 초기화
  void clearCache() {
    _transactionCache.clear();
    notifyListeners();
  }
}
