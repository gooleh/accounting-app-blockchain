import 'package:flutter/material.dart';
import '../services/meta_mask_service.dart';

class MetaMaskProvider with ChangeNotifier {
  final MetaMaskService _metaMaskService = MetaMaskService();

  String get walletAddress => _metaMaskService.walletAddress;

  bool get isConnected => _metaMaskService.isConnected;

  Future<void> connect() async {
    await _metaMaskService.connect();
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _metaMaskService.disconnect();
    notifyListeners();
  }

  Future<String?> sendTransaction(Map<String, dynamic> transactionData) async {
    return await _metaMaskService.sendTransaction(transactionData);
  }
}
