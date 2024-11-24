// lib/screens/meta_mask_demo_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meta_mask_provider.dart';

class MetaMaskDemoScreen extends StatelessWidget {
  const MetaMaskDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MetaMask 연동 데모'),
      ),
      body: Center(
        child: Consumer<MetaMaskProvider>(
          builder: (context, metaMaskProvider, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                metaMaskProvider.walletAddress.isNotEmpty
                    ? Text(
                        '연결된 지갑 주소: ${metaMaskProvider.walletAddress}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      )
                    : const Text(
                        '지갑이 연결되지 않았습니다.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: metaMaskProvider.walletAddress.isEmpty
                      ? () async {
                          await metaMaskProvider.connect();
                        }
                      : () async {
                          await metaMaskProvider.disconnect();
                        },
                  child: Text(metaMaskProvider.walletAddress.isEmpty
                      ? '지갑 연결'
                      : '지갑 연결 해제'),
                ),
                // 필요에 따라 추가 기능 구현 가능
              ],
            );
          },
        ),
      ),
    );
  }
}
