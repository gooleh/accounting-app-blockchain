// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart'; // SettingsProvider 임포트
import '../providers/transaction_provider.dart';
import '../providers/meta_mask_provider.dart';
import '../colors.dart'; // AppColors 임포트
import 'package:flutter/services.dart'; // 추가된 임포트

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _thresholdController = TextEditingController();
  int _currentThreshold = 1000000; // 기본값 설정

  @override
  void initState() {
    super.initState();
    _loadThreshold();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadThreshold() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      _currentThreshold = settingsProvider.transactionThreshold;
      _thresholdController.text = _currentThreshold.toString();
    });
  }

  Future<void> _saveThreshold() async {
    if (_formKey.currentState!.validate()) {
      final newThreshold = int.parse(_thresholdController.text.trim());

      // SettingsProvider에 설정 변경
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.setTransactionThreshold(newThreshold);

      // TransactionProvider에 알림
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      transactionProvider.updateThreshold(newThreshold); // await 제거

      if (!mounted) return;

      setState(() {
        _currentThreshold = newThreshold;
      });

      // 키패드 내림
      FocusScope.of(context).unfocus();

      // 사용자에게 변경 완료 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기준 금액이 저장되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: GestureDetector(
        onTap: () {
          // 화면 외부를 탭하면 키패드를 내림
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '고액 거래 기준 금액을 설정하세요.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _thresholdController,
                  decoration: InputDecoration(
                    labelText: '기준 금액 (원)',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // 숫자만 입력 가능
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '금액을 입력해주세요.';
                    }
                    if (int.tryParse(value.trim()) == null ||
                        int.parse(value.trim()) <= 0) {
                      return '유효한 금액을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveThreshold,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kAccentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '저장',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // MetaMask 연결 상태 표시
                Consumer<MetaMaskProvider>(
                  builder: (context, metaMask, child) {
                    bool isConnected = metaMask.walletAddress.isNotEmpty;
                    return Row(
                      children: [
                        Icon(
                          isConnected ? Icons.check_circle : Icons.error,
                          color: isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isConnected
                                ? 'MetaMask 연결됨: ${_shortenAddress(metaMask.walletAddress)}'
                                : 'MetaMask 연결되지 않음',
                            style: TextStyle(
                              color: isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isConnected)
                          ElevatedButton(
                            onPressed: () async {
                              await metaMask.connect();
                            },
                            child: const Text('연결'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.kAccentColor,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 지갑 주소를 간략하게 표시하는 헬퍼 메서드
  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
