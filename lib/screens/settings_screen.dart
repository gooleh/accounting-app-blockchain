// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../colors.dart'; // AppColors 임포트

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentThreshold = prefs.getInt('transaction_threshold') ?? 1000000;
      _thresholdController.text = _currentThreshold.toString();
    });
  }

  Future<void> _saveThreshold() async {
    if (_formKey.currentState!.validate()) {
      final newThreshold = int.parse(_thresholdController.text.trim());

      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('transaction_threshold', newThreshold);

      // TransactionProvider에 알림
      if (mounted) {
        Provider.of<TransactionProvider>(context, listen: false)
            .updateThreshold(newThreshold);
      }

      setState(() {
        _currentThreshold = newThreshold;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('기준 금액이 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: Padding(
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
            ],
          ),
        ),
      ),
    );
  }
}
