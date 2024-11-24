// lib/screens/blockchain_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_transaction_provider.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';
import '../colors.dart';

class BlockchainTransactionsScreen extends StatefulWidget {
  const BlockchainTransactionsScreen({super.key});

  @override
  State<BlockchainTransactionsScreen> createState() =>
      _BlockchainTransactionsScreenState();
}

class _BlockchainTransactionsScreenState
    extends State<BlockchainTransactionsScreen> {
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'ko_KR',
    symbol: '₩',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refreshTransactions();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final provider = context.read<BlockchainTransactionProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.loadMore();
      }
    }
  }

  Future<void> _refreshTransactions() async {
    await context.read<BlockchainTransactionProvider>().refreshTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('블록체인 거래 내역'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshTransactions,
          ),
        ],
      ),
      body: Consumer<BlockchainTransactionProvider>(
        builder: (context, provider, child) {
          if (provider.loadingState == LoadingState.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.loadingState == LoadingState.error &&
              provider.transactions.isEmpty) {
            return _buildErrorWidget(provider.error ?? '알 수 없는 오류가 발생했습니다.');
          }

          if (provider.transactions.isEmpty) {
            return const Center(
              child: Text('블록체인에 저장된 거래가 없습니다.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshTransactions,
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.transactions.length + 1,
              itemBuilder: (context, index) {
                if (index == provider.transactions.length) {
                  return _buildLoadingIndicator(provider);
                }
                return _buildTransactionCard(provider.transactions[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction tx) {
    return Card(
      color: AppColors.kCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showTransactionDetails(tx),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    tx.type.toLowerCase() == 'income'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: tx.type.toLowerCase() == 'income'
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx.title.isNotEmpty ? tx.title : '제목 없음',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(tx.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tx.type.toLowerCase() == 'income'
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(tx.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tx.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(BlockchainTransactionProvider provider) {
    if (!provider.hasMore) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshTransactions,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _TransactionDetailsSheet(
          transaction: tx,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;
  final ScrollController scrollController;

  const _TransactionDetailsSheet({
    required this.transaction,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '거래 상세 정보',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _buildDetailRow('제목', transaction.title),
          _buildDetailRow(
              '금액',
              NumberFormat.currency(
                locale: 'ko_KR',
                symbol: '₩',
                decimalDigits: 0,
              ).format(transaction.amount)),
          _buildDetailRow(
              '날짜', DateFormat('yyyy-MM-dd HH:mm').format(transaction.date)),
          _buildDetailRow('유형', transaction.type),
          _buildDetailRow('카테고리', transaction.category),
          _buildDetailRow('거래 ID', transaction.id),
          if (transaction.cid.isNotEmpty)
            _buildDetailRow('IPFS CID', transaction.cid),
          if (transaction.txHash.isNotEmpty)
            _buildDetailRow('트랜잭션 해시', transaction.txHash),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
