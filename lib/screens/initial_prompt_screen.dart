import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/meta_mask_provider.dart';
import 'home_screen.dart';

class InitialPromptScreen extends StatefulWidget {
  const InitialPromptScreen({super.key});

  @override
  State<InitialPromptScreen> createState() => _InitialPromptScreenState();
}

class _InitialPromptScreenState extends State<InitialPromptScreen> {
  late SettingsProvider _settingsProvider;
  late MetaMaskProvider _metaMaskProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkConnection());
  }

  Future<void> _checkConnection() async {
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _metaMaskProvider = Provider.of<MetaMaskProvider>(context, listen: false);

    if (_metaMaskProvider.walletAddress.isNotEmpty) {
      // 이미 연결된 경우 바로 홈 화면으로 이동
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (!_settingsProvider.hasSeenMetaMaskPrompt) {
      // 프롬프트를 아직 보지 않은 경우 프롬프트 표시
      _showMetaMaskPrompt();
    } else {
      // 프롬프트를 이미 보았지만 연결되지 않은 경우 홈 화면으로 이동
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _showMetaMaskPrompt() async {
    // 다이얼로그를 표시하기 전에 위젯이 마운트되어 있는지 확인
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false, // 사용자가 외부를 눌러 닫지 못하게 함
      builder: (BuildContext dialogContext) {
        // 다이얼로그의 context는 dialogContext로 이름 변경
        return AlertDialog(
          title: const Text('MetaMask 연결'),
          content: const Text('MetaMask 지갑을 연결하여 블록체인 기능을 사용할 수 있습니다.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () async {
                await _settingsProvider.setHasSeenMetaMaskPrompt(true);
                if (!mounted) return;
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
            TextButton(
              child: const Text('Connect Now'),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                await _metaMaskProvider.connect();
                await _settingsProvider.setHasSeenMetaMaskPrompt(true);
                if (!mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 초기 프롬프트 화면은 빈 스캐폴드로 유지
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
