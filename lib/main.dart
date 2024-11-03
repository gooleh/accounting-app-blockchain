// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/transaction_provider.dart';
import 'providers/blockchain_transaction_provider.dart';
import 'screens/home_screen.dart';
import 'screens/blockchain_transactions_screen.dart';
import 'colors.dart'; // AppColors 임포트
import 'package:flutter_dotenv/flutter_dotenv.dart'; // flutter_dotenv 임포트
import 'services/blockchain_service.dart'; // BlockchainService 임포트
import 'package:logger/logger.dart'; // Logger 임포트

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // 메서드 호출 수
    errorMethodCount: 5, // 에러 시 메서드 호출 수
    lineLength: 50, // 한 줄의 길이
    colors: true, // 색상 사용
    printEmojis: true, // 이모지 사용
    printTime: false, // 시간 출력 여부
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // dotenv 초기화 (모바일 용: fileName 생략, .env는 프로젝트 루트에 위치)
    await dotenv.load();

    // 환경 변수 로드 확인 (디버깅용)
    _logger.d('dotenv 파일이 성공적으로 로드되었습니다.');
    _logger.d('RPC_URL: ${dotenv.env['RPC_URL']}');
    _logger.d('PRIVATE_KEY: ${dotenv.env['PRIVATE_KEY']}');
    _logger.d('CONTRACT_ADDRESS: ${dotenv.env['CONTRACT_ADDRESS']}');
  } catch (e) {
    _logger.e('dotenv 파일을 로드하지 못했습니다. 오류: $e');
    // dotenv 로드 실패 시 로깅만 하고 앱을 계속 실행하도록 함
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.d('Firebase 초기화 완료');
  } catch (e) {
    _logger.e('Firebase 초기화 오류: $e');
    // Firebase 초기화 실패 시 로깅만 하고 앱을 계속 실행하도록 함
  }

  // Initialize BlockchainService before providing
  BlockchainService blockchainService;
  try {
    blockchainService = BlockchainService();
    await blockchainService.init();
    _logger.d('BlockchainService 초기화 완료');

    // RPC 연결 테스트 (선택 사항)
    // await blockchainService.testRpcConnection();
  } catch (e) {
    _logger.e('BlockchainService 초기화 오류: $e');
    // BlockchainService 초기화 실패 시 앱 실행을 중단합니다.
    return; // Exit if blockchainService cannot be initialized
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider<BlockchainService>.value(
          value: blockchainService,
        ),
        ChangeNotifierProxyProvider<BlockchainService,
            BlockchainTransactionProvider>(
          create: (_) => BlockchainTransactionProvider(),
          update: (context, blockchainService, previous) {
            if (previous == null) {
              final provider = BlockchainTransactionProvider();
              provider.update(blockchainService);
              return provider;
            } else {
              previous.update(blockchainService);
              return previous;
            }
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Remove FutureBuilder as blockchainService is already initialized
    return MaterialApp(
      title: '가계부 앱',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.kBackgroundColor,
        scaffoldBackgroundColor: AppColors.kBackgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.kBackgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.kAccentColor),
          titleTextStyle: TextStyle(
              color: AppColors.kTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.kCardColor,
          selectedItemColor: AppColors.kAccentColor,
          unselectedItemColor: AppColors.kSecondaryTextColor,
        ),
        cardColor: AppColors.kCardColor,
        textTheme: const TextTheme(
          headlineSmall: TextStyle(color: AppColors.kTextColor, fontSize: 18),
          bodyLarge: TextStyle(color: AppColors.kTextColor, fontSize: 16),
          bodyMedium:
              TextStyle(color: AppColors.kSecondaryTextColor, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: AppColors.kAccentColor),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.kAccentColor,
            foregroundColor: AppColors.kBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: AppColors.kTextColor),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.kAccentColor),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.kAccentColor),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      home: const HomeScreen(),
      routes: {
        '/blockchain_transactions': (context) =>
            const BlockchainTransactionsScreen(),
      },
    );
  }
}
