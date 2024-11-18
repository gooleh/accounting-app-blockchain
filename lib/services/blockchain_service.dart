// lib/services/blockchain_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../models/transaction.dart' as app_models;
import 'ipfs_service.dart'; // IPFSService 임포트

class BlockchainService extends ChangeNotifier {
  late Web3Client _client;
  late DeployedContract _contract;
  late ContractFunction _storeTransaction;
  late ContractFunction _storeTransactions;
  late ContractFunction _getTransaction;
  late ContractFunction _getTransactionCount;
  late ContractEvent _transactionStoredEvent;

  // 환경 변수에서 값 가져오기
  final String _rpcUrl = dotenv.env['RPC_URL'] ?? '';
  final String _privateKey = dotenv.env['PRIVATE_KEY'] ?? '';
  final String _contractAddress = dotenv.env['CONTRACT_ADDRESS'] ?? '';

  late Credentials _credentials;
  late EthereumAddress _senderAddress;

  // 이벤트 스트림 컨트롤러
  final StreamController<app_models.Transaction> _transactionController =
      StreamController.broadcast();

  // Logger 인스턴스 생성
  final Logger _logger = Logger();
  final IPFSService _ipfsService = IPFSService(); // IPFSService 인스턴스 생성

  // 외부에서 스트림을 구독할 수 있도록 제공
  Stream<app_models.Transaction> get transactionStream =>
      _transactionController.stream;

  BlockchainService() {
    if (_rpcUrl.isEmpty || _privateKey.isEmpty || _contractAddress.isEmpty) {
      throw Exception('환경 변수가 올바르게 설정되지 않았습니다.');
    }

    // Web3Client 초기화 시 IOClient() 사용
    _client = Web3Client(_rpcUrl, IOClient());

    // Credentials 및 Sender Address 초기화
    _credentials = EthPrivateKey.fromHex(_privateKey);
    _senderAddress = _credentials.address;
    _logger.d('보내는 계정 주소 (개인 키 기반): ${_senderAddress.hex}');
  }

  /// 초기화 함수
  Future<void> init() async {
    try {
      // ABI 로드
      String abiString =
          await rootBundle.loadString('assets/TransactionStorageABI.json');
      _logger.d('Loaded ABI string: $abiString');

      // 스마트 계약 주소
      final contractAddr = EthereumAddress.fromHex(_contractAddress);

      // 계약 ABI 및 인스턴스 생성
      final contractAbi =
          ContractAbi.fromJson(abiString, 'HighValueDataStorage');
      _contract = DeployedContract(
        contractAbi,
        contractAddr,
      );

      // 함수 가져오기
      _storeTransaction = _contract.function('storeTransaction');
      _storeTransactions = _contract.function('storeTransactions');
      _getTransaction = _contract.function('getTransaction');
      _getTransactionCount = _contract.function('getTransactionCount');

      // 이벤트 가져오기
      _transactionStoredEvent = _contract.event('TransactionStored');

      // 보내는 계정 주소 출력
      _logger.d('보내는 계정 주소: ${_senderAddress.hex}');

      // 이벤트 리스닝 시작
      _listenToTransactionEvents();
    } catch (e, stackTrace) {
      _logger.e('스마트 계약 초기화 오류: $e', e, stackTrace);
      rethrow;
    }
  }

  /// 단일 트랜잭션을 보내는 함수
  Future<String> sendTransaction(app_models.Transaction tx) async {
    try {
      // CID가 있는지 확인
      if (tx.cid.isEmpty) {
        throw Exception('CID가 없습니다. IPFS 업로드 후 CID를 받아야 합니다.');
      }

      // 블록체인 전송할 데이터 로깅
      _logger.d('블록체인 전송할 데이터: ${jsonEncode({'id': tx.id, 'cid': tx.cid})}');

      // 트랜잭션 전송
      final result = await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _storeTransaction,
          parameters: [tx.id, tx.cid],
          maxGas: 200000,
          gasPrice: EtherAmount.inWei(BigInt.from(1000000000)), // 1 Gwei
        ),
        chainId: 11155111, // 네트워크에 따라 변경
      );
      _logger.d('트랜잭션 해시: $result');

      return result; // 트랜잭션 해시 반환
    } catch (e, stackTrace) {
      _logger.e('블록체인 트랜잭션 에러: $e', e, stackTrace);
      rethrow;
    }
  }

  /// 배치 트랜잭션을 보내는 함수
  Future<String> sendBatchTransaction(
      List<app_models.Transaction> transactions) async {
    try {
      if (transactions.isEmpty) {
        throw Exception('보낼 거래가 없습니다.');
      }

      // IDs와 CIDs 분리
      List<String> ids = transactions.map((tx) => tx.id).toList();
      List<String> cids = transactions.map((tx) => tx.cid).toList();

      // 블록체인 전송할 데이터 로깅
      _logger.d('블록체인 배치 전송할 데이터: ${jsonEncode({'ids': ids, 'cids': cids})}');

      // 트랜잭션 전송
      final result = await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _storeTransactions,
          parameters: [ids, cids],
          from: _senderAddress,
          // 필요에 따라 가스 한도와 가격을 설정
          gasPrice: EtherAmount.inWei(BigInt.from(1000000000)), // 1 Gwei
          maxGas: 200000 * transactions.length, // 각 거래당 가스 비용을 고려
        ),
        chainId: 11155111, // 네트워크에 따라 변경
      );
      _logger.d('배치 트랜잭션 해시: $result');

      return result; // 트랜잭션 해시 반환
    } catch (e, stackTrace) {
      _logger.e('블록체인 배치 트랜잭션 에러: $e', e, stackTrace);
      rethrow;
    }
  }

  /// 특정 인덱스의 거래를 가져오는 함수
  Future<app_models.Transaction?> getTransactionByIndex(int index) async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTransaction,
        params: [BigInt.from(index)],
      );

      _logger.d(
          'getTransactionByIndex($index) 결과 타입: ${result.runtimeType}, 값: $result');

      if (result.isEmpty) return null;

      // Transaction 객체 생성
      app_models.Transaction transaction =
          app_models.Transaction.fromBlockchain(result);

      // IPFS에서 데이터 가져오기
      Map<String, dynamic> data = await _ipfsService.fetchData(transaction.cid);

      // Transaction 객체 업데이트
      transaction.title = data['title'] ?? '';
      transaction.amount = (data['amount'] ?? 0).toDouble();
      transaction.date =
          DateTime.parse(data['date'] ?? DateTime.now().toString());
      transaction.type = data['type'] ?? '';
      transaction.category = data['category'] ?? '';
      transaction.userId = data['userId'] ?? 'user123';

      return transaction;
    } catch (e, stackTrace) {
      _logger.e('블록체인 트랜잭션 조회 에러: $e', e, stackTrace);
      return null;
    }
  }

  /// 모든 거래를 블록체인에서 가져오는 함수
  Future<List<app_models.Transaction>> fetchAllTransactions() async {
    List<app_models.Transaction> transactions = [];
    try {
      final count = await getTransactionCount();
      _logger.d('총 거래 수: $count');

      for (int i = 0; i < count.toInt(); i++) {
        final tx = await getTransactionByIndex(i);
        if (tx != null) {
          transactions.add(tx);
        }
      }
    } catch (e, stackTrace) {
      _logger.e('모든 거래 불러오기 오류: $e', e, stackTrace);
    }
    return transactions;
  }

  /// 거래 수 가져오기
  Future<BigInt> getTransactionCount() async {
    try {
      final result = await _client.call(
        contract: _contract,
        function: _getTransactionCount,
        params: [],
      );
      _logger.d('getTransactionCount 결과: $result');
      return result.first as BigInt;
    } catch (e, stackTrace) {
      _logger.e('getTransactionCount 호출 에러: $e', e, stackTrace);
      rethrow;
    }
  }

  /// 이벤트 스트림 리스닝 함수
  void _listenToTransactionEvents() {
    final eventStream = _client.events(FilterOptions.events(
      contract: _contract,
      event: _transactionStoredEvent,
    ));

    eventStream.listen((event) async {
      try {
        final decoded =
            _transactionStoredEvent.decodeResults(event.topics!, event.data!);
        _logger.d('Decoded event data: $decoded');

        // decoded는 [id, cid]로 예상
        if (decoded.length != 2) {
          throw Exception('Unexpected number of parameters in event data');
        }

        String id = decoded[0].toString();
        String cid = decoded[1].toString();

        // IPFS에서 데이터 가져오기
        Map<String, dynamic> data = await _ipfsService.fetchData(cid);

        // Transaction 객체 생성
        app_models.Transaction transaction = app_models.Transaction(
          id: id,
          cid: cid,
          title: data['title'] ?? '',
          amount: (data['amount'] ?? 0).toDouble(),
          date: DateTime.parse(data['date'] ?? DateTime.now().toString()),
          type: data['type'] ?? '',
          category: data['category'] ?? '',
          userId: data['userId'] ?? 'user123',
        );

        _logger.d(
            '새로운 블록체인 거래가 저장되었습니다: ID=$id, CID=$cid, Title=${transaction.title}');

        // 스트림에 추가하여 외부에서 구독할 수 있도록 함
        _transactionController.add(transaction);
      } catch (e, stackTrace) {
        _logger.e('이벤트 처리 에러: $e', e, stackTrace);
      }
    });
  }

  @override
  void dispose() {
    _transactionController.close();
    _client.dispose();
    super.dispose();
  }
}
