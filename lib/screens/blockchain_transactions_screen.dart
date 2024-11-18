// lib/screens/blockchain_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_transaction_provider.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';
import '../colors.dart';

class BlockchainTransactionsScreen extends StatelessWidget {
  const BlockchainTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('블록체인 거래 내역'),
      ),
      body: Consumer<BlockchainTransactionProvider>(
        builder: (context, blockchainProvider, child) {
          if (blockchainProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (blockchainProvider.error != null) {
            return Center(child: Text(blockchainProvider.error!));
          }

          if (blockchainProvider.blockchainTransactions.isEmpty) {
            return const Center(child: Text('블록체인에 저장된 거래가 없습니다.'));
          }

          return ListView.builder(
            itemCount: blockchainProvider.blockchainTransactions.length,
            itemBuilder: (context, index) {
              final Transaction tx =
                  blockchainProvider.blockchainTransactions[index];

              return Card(
                color: AppColors.kCardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    tx.type.toLowerCase() == 'income'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: tx.type.toLowerCase() == 'income'
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  title: Text(
                    tx.title.isNotEmpty ? tx.title : '제목 없음',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '금액: ${tx.amount.toStringAsFixed(0)} 원',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '날짜: ${DateFormat('yyyy-MM-dd').format(tx.date)}',
                      ),
                      const SizedBox(height: 4),
                      Text('타입: ${tx.type}'),
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
