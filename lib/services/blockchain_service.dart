// lib/services/blockchain_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/io_client.dart'; // Client 대신 IOClient 임포트
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // 접두사 추가
import 'package:logger/logger.dart'; // Logger 패키지 임포트
import '../models/transaction.dart' as app_models; // 사용자 정의 Transaction 모델 임포트

class BlockchainService extends ChangeNotifier {
  late Web3Client _client;
  late DeployedContract _contract;
  late ContractFunction _storeTransaction;
  late ContractFunction _getTransaction;
  late ContractFunction _getTransactionCount; // 추가: getTransactionCount 함수
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
      // ABI 로드 (ABI-only 파일을 사용)
      String abiString =
          await rootBundle.loadString('assets/TransactionStorageABI.json');
      _logger.d('Loaded ABI string: $abiString');
      final abiJson = jsonDecode(abiString);

      // 스마트 계약 주소
      final contractAddr = EthereumAddress.fromHex(_contractAddress);

      // 계약 ABI 및 인스턴스 생성
      final contractAbi = ContractAbi.fromJson(
          abiString, 'TransactionStorage'); // 수정: abiString 사용
      _contract = DeployedContract(
        contractAbi,
        contractAddr,
      );

      // 함수 가져오기
      _storeTransaction = _contract.function('storeTransaction');
      _getTransaction = _contract.function('getTransaction');
      _getTransactionCount = _contract
          .function('getTransactionCount'); // 추가: getTransactionCount 함수 초기화

      // 이벤트 가져오기
      _transactionStoredEvent = _contract.event('TransactionStored');

      // 보내는 계정 주소 출력
      _logger.d('보내는 계정 주소: ${_senderAddress.hex}');

      // 이벤트 리스닝 시작
      _listenToTransactionEvents();
    } catch (e, stackTrace) {
      _logger.e('스마트 계약 초기화 오류: $e', e, stackTrace);
      rethrow; // 스택 트레이스를 유지하면서 예외를 다시 던짐
    }
  }

  /// 트랜잭션을 보내는 함수
  Future<String> sendTransaction(
    String id,
    String title, // title 추가
    double amount,
    DateTime date,
    String transactionType,
    String category,
  ) async {
    try {
      // 디버깅 로그 추가
      _logger.d('sendTransaction called with:');
      _logger.d('id: $id (type: ${id.runtimeType})');
      _logger.d('title: $title (type: ${title.runtimeType})');
      _logger.d('amount: $amount (type: ${amount.runtimeType})');
      _logger.d('date: $date (type: ${date.runtimeType})');
      _logger.d(
          'transactionType: $transactionType (type: ${transactionType.runtimeType})');
      _logger.d('category: $category (type: ${category.runtimeType})');

      // 보내는 계정의 잔액 확인
      EtherAmount balance = await getBalance();
      EtherAmount gasPrice = await _client.getGasPrice();
      BigInt txCost = BigInt.from(600000) * gasPrice.getInWei;

      if (balance.getInWei < txCost) {
        _logger.e('보내는 계정의 잔액이 부족합니다. 로컬 Ganache 네트워크에서 테스트 ETH를 충전하세요.');
        return 'Insufficient balance';
      }

      // amount를 원 단위로 저장 (BigInt로 변환)
      BigInt amountInWon;
      try {
        amountInWon = BigInt.from(amount.toInt()); // 소수점 제거
      } catch (e, stackTrace) {
        _logger.e('amountInWon 변환 오류: $e', e, stackTrace);
        rethrow;
      }

      // date를 Unix timestamp (초 단위)로 변환
      BigInt dateUnix = BigInt.from(date.millisecondsSinceEpoch ~/ 1000);

      // 디버깅 로그 추가
      _logger.d(
          'Converted amountInWon: $amountInWon (type: ${amountInWon.runtimeType})');
      _logger
          .d('Converted dateUnix: $dateUnix (type: ${dateUnix.runtimeType})');

      // 트랜잭션 전송
      final result = await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: _storeTransaction,
          parameters: [id, amountInWon, dateUnix, transactionType, category],
          maxGas: 600000,
          gasPrice: gasPrice,
        ),
        chainId: 1337, // Ganache의 실제 네트워크 ID로 수정 (5777 -> 1337)
      );
      _logger.d('트랜잭션 해시: $result');

      return result; // 트랜잭션 해시 반환
    } catch (e, stackTrace) {
      _logger.e('블록체인 트랜잭션 에러: $e', e, stackTrace);
      rethrow; // 스택 트레이스를 유지하면서 예외를 다시 던짐
    }
  }

  /// 잔액을 확인하고 반환합니다.
  Future<EtherAmount> getBalance() async {
    try {
      EtherAmount balance = await _client.getBalance(_senderAddress);
      _logger.d('보내는 계정 잔액: ${balance.getValueInUnit(EtherUnit.ether)} ETH');
      return balance;
    } catch (e, stackTrace) {
      _logger.e('잔액 조회 오류: $e', e, stackTrace);
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

      // 이중 리스트 처리
      List<dynamic> transactionData =
          result.isNotEmpty && result[0] is List ? result[0] : result;

      app_models.Transaction transaction =
          app_models.Transaction.fromBlockchain(transactionData);

      // Firestore에서 title 가져오기
      if (transaction.id.isNotEmpty) {
        final doc = await firestore.FirebaseFirestore.instance
            .collection('transactions')
            .doc(transaction.id)
            .get();
        if (doc.exists) {
          String title = doc.get('title') as String? ?? '';
          transaction.title = title;
        }
      }

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

        // decoded는 [id, amount, date, transactionType, category]로 예상
        if (decoded.length != 5) {
          throw Exception('Unexpected number of parameters in event data');
        }

        String id = decoded[0].toString();
        BigInt amountBigInt = decoded[1] as BigInt;
        BigInt dateUnix = decoded[2] as BigInt;
        String transactionType = decoded[3].toString();
        String category = decoded[4].toString();

        double amount = amountBigInt.toDouble();
        DateTime date =
            DateTime.fromMillisecondsSinceEpoch(dateUnix.toInt() * 1000);

        // Firestore에서 title 가져오기
        String title = '';
        if (id.isNotEmpty) {
          firestore.DocumentSnapshot doc = await firestore
              .FirebaseFirestore.instance
              .collection('transactions')
              .doc(id)
              .get();
          if (doc.exists) {
            title = doc.get('title') as String? ?? '';
          }
        }

        // Transaction 객체에 title 설정
        app_models.Transaction transaction = app_models.Transaction(
          id: id,
          title: title,
          amount: amount,
          date: date,
          type: transactionType,
          category: category,
          userId: 'user123', // 고정된 값
        );

        _logger.d(
            '새로운 블록체인 거래가 저장되었습니다: ID=$id, Title=$title, Amount=$amount, Date=$date, Type=$transactionType, Category=$category');

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
