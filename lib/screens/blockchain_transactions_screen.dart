// lib/screens/blockchain_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_transaction_provider.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅 추가
import 'package:logger/logger.dart'; // Logger 패키지 임포트

class BlockchainTransactionsScreen extends StatelessWidget {
  const BlockchainTransactionsScreen({super.key}); // super.key로 변경

  @override
  Widget build(BuildContext context) {
    final Logger _logger = Logger();
    return Scaffold(
      // 앱 바 설정
      appBar: AppBar(
        title: const Text('블록체인 거래 내역'),
      ),
      // 본문
      body: Consumer<BlockchainTransactionProvider>(
        builder: (context, blockchainProvider, child) {
          if (blockchainProvider.blockchainTransactions.isEmpty) {
            return const Center(child: Text('블록체인에 저장된 거래가 없습니다.'));
          }
          return ListView.builder(
            itemCount: blockchainProvider.blockchainTransactions.length,
            itemBuilder: (context, index) {
              final Transaction tx =
                  blockchainProvider.blockchainTransactions[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    tx.type == 'income'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: tx.type == 'income'
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  title: Text('제목: ${tx.title}'), // 'ID'에서 '제목'으로 변경
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '금액: ${tx.amount.toStringAsFixed(0)} 원'), // 'ETH'에서 '원'으로 변경
                      Text(
                        '날짜: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(tx.date)}',
                      ), // 날짜 포맷팅
                      Text('타입: ${tx.type}'),
                      Text('카테고리: ${tx.category}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
