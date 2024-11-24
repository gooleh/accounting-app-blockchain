// lib/providers/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class SettingsProvider with ChangeNotifier {
  static const String _keyAmountCriteria = 'amount_criteria';
  static const String _keyHasSeenMetaMaskPrompt = 'has_seen_metamask_prompt';
  static const String _keyTransactionThreshold = 'transaction_threshold';

  double _amountCriteria = 0.0;
  bool _hasSeenMetaMaskPrompt = false;
  int _transactionThreshold = 1000000; // 기본값 설정

  double get amountCriteria => _amountCriteria;
  bool get hasSeenMetaMaskPrompt => _hasSeenMetaMaskPrompt;
  int get transactionThreshold => _transactionThreshold;

  final Logger _logger = Logger();

  SettingsProvider() {
    _loadSettings();
  }

  // SharedPreferences에서 설정 로드
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _amountCriteria = prefs.getDouble(_keyAmountCriteria) ?? 0.0;
      _hasSeenMetaMaskPrompt =
          prefs.getBool(_keyHasSeenMetaMaskPrompt) ?? false;
      _transactionThreshold = prefs.getInt(_keyTransactionThreshold) ?? 1000000;
      _logger.d(
          'Settings loaded: amountCriteria=$_amountCriteria, hasSeenMetaMaskPrompt=$_hasSeenMetaMaskPrompt, transactionThreshold=$_transactionThreshold');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to load settings: $e');
    }
  }

  // 금액 기준 설정
  Future<void> setAmountCriteria(double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _amountCriteria = amount;
      await prefs.setDouble(_keyAmountCriteria, amount);
      _logger.d('Amount criteria set to $_amountCriteria');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to set amount criteria: $e');
    }
  }

  // MetaMask 프롬프트 시청 여부 설정
  Future<void> setHasSeenMetaMaskPrompt(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenMetaMaskPrompt = value;
      await prefs.setBool(_keyHasSeenMetaMaskPrompt, value);
      _logger.d('Has seen MetaMask prompt set to $_hasSeenMetaMaskPrompt');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to set hasSeenMetaMaskPrompt: $e');
    }
  }

  // 거래 기준 금액 설정
  Future<void> setTransactionThreshold(int threshold) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _transactionThreshold = threshold;
      await prefs.setInt(_keyTransactionThreshold, threshold);
      _logger.d('Transaction threshold set to $_transactionThreshold');
      notifyListeners();
    } catch (e) {
      _logger.e('Failed to set transaction threshold: $e');
    }
  }
}
