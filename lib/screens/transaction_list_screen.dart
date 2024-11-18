// lib/screens/transaction_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../colors.dart';
import '../icons.dart'; // CategoryIcons 임포트

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Text(
          provider.error!,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final transactions = provider.transactions;

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (ctx, i) {
        final tx = transactions[i];
        IconData iconData =
            CategoryIcons.icons[tx.category] ?? Icons.help_outline;
        return Card(
          color: AppColors.kCardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(
              iconData,
              color: AppColors.kAccentColor,
            ),
            title: Text(tx.title, style: Theme.of(context).textTheme.bodyLarge),
            subtitle: Text(
              '${tx.amount.toStringAsFixed(0)}원',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            trailing: Text(
              '${tx.date.month}/${tx.date.day}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }
}
