// main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/transaction_provider.dart';
import 'providers/meta_mask_provider.dart'; // MetaMaskProvider 임포트
import 'providers/settings_provider.dart'; // SettingsProvider 임포트
import 'providers/blockchain_transaction_provider.dart'; // BlockchainTransactionProvider 임포트
import 'screens/home_screen.dart';
import 'screens/blockchain_transactions_screen.dart';
import 'screens/meta_mask_demo_screen.dart'; // MetaMaskDemoScreen 임포트
import 'screens/initial_prompt_screen.dart'; // InitialPromptScreen 임포트
import 'screens/settings_screen.dart'; // SettingsScreen 임포트
import 'colors.dart'; // AppColors 임포트
import 'package:flutter_dotenv/flutter_dotenv.dart'; // flutter_dotenv 임포트
import 'package:logger/logger.dart'; // Logger 임포트
import 'services/navigation_service.dart'; // NavigationService 임포트
import 'services/blockchain_service.dart'; // BlockchainService 임포트

final Logger _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 50,
    colors: true,
    printEmojis: true,
    printTime: false,
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();

    _logger.d('dotenv 파일이 성공적으로 로드되었습니다.');
    // 민감한 정보는 로그에 남기지 않도록 주의
    _logger.d('RPC_URL: [REDACTED]');
    _logger.d('CONTRACT_ADDRESS: [REDACTED]');
    _logger.d('PINATA_API_KEY: [REDACTED]');
    _logger.d('PINATA_SECRET_API_KEY: [REDACTED]');
    _logger.d('WALLETCONNECT_PROJECT_ID: [REDACTED]');
  } catch (e) {
    _logger.e('dotenv 파일을 로드하지 못했습니다. 오류: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.d('Firebase 초기화 완료');
  } catch (e) {
    _logger.e('Firebase 초기화 오류: $e');
  }

  // BlockchainService 초기화
  BlockchainService blockchainService;
  try {
    blockchainService = BlockchainService();
    await blockchainService.init();
    _logger.d('BlockchainService 초기화 완료');
  } catch (e) {
    _logger.e('BlockchainService 초기화 오류: $e');
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        // 1. SettingsProvider 등록
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        // 2. MetaMaskProvider 등록
        ChangeNotifierProvider(
          create: (_) => MetaMaskProvider(),
        ),
        // 3. BlockchainService 등록 (ChangeNotifierProvider 사용)
        ChangeNotifierProvider<BlockchainService>.value(
          value: blockchainService,
        ),
        // 4. TransactionProvider를 ProxyProvider로 등록하여 SettingsProvider와 MetaMaskProvider의 변경을 반영
        ChangeNotifierProxyProvider3<SettingsProvider, MetaMaskProvider,
            BlockchainService, TransactionProvider>(
          create: (context) => TransactionProvider(
            Provider.of<BlockchainService>(context, listen: false),
            Provider.of<MetaMaskProvider>(context, listen: false),
            Provider.of<SettingsProvider>(context, listen: false)
                .transactionThreshold,
          ),
          update: (context, settingsProvider, metaMaskProvider,
              blockchainService, transactionProvider) {
            if (transactionProvider == null) {
              return TransactionProvider(
                blockchainService,
                metaMaskProvider,
                settingsProvider.transactionThreshold,
              );
            } else {
              transactionProvider
                  .updateThreshold(settingsProvider.transactionThreshold);
              return transactionProvider;
            }
          },
        ),
        // 5. BlockchainTransactionProvider 등록
        ChangeNotifierProvider<BlockchainTransactionProvider>(
          create: (context) {
            // BlockchainService를 받아와서 생성자에 전달
            BlockchainService blockchainService =
                Provider.of<BlockchainService>(context, listen: false);
            return BlockchainTransactionProvider(blockchainService);
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
    return MaterialApp(
      title: '가계부 앱',
      navigatorKey: NavigationService.navigatorKey, // 글로벌 Navigator Key 할당
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
          labelStyle: const TextStyle(color: AppColors.kTextColor),
          prefixIconColor: AppColors.kAccentColor,
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.kAccentColor),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.kAccentColor),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      home: const InitialPromptScreen(), // 초기 프롬프트 화면으로 설정
      routes: {
        '/blockchain_transactions': (context) =>
            const BlockchainTransactionsScreen(),
        '/meta_mask_demo': (context) =>
            const MetaMaskDemoScreen(), // MetaMaskDemoScreen 라우트 추가
        '/home': (context) => const HomeScreen(), // 홈 화면 라우트 추가
        '/settings': (context) =>
            const SettingsScreen(), // SettingsScreen 라우트 추가
      },
    );
  }
}
