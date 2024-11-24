// lib/models/transaction.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  String id;
  String title;
  double amount;
  DateTime date;
  String type; // 'income' or 'expense'
  String category;
  String cid; // IPFS CID
  String userId;
  String txHash;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    required this.cid,
    required this.userId,
    required this.txHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type,
      'category': category,
      'cid': cid,
      'userId': userId,
      'txHash': txHash,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map, String documentId) {
    return Transaction(
      id: documentId,
      title: map['title'] ?? '',
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      type: map['type'] ?? '',
      category: map['category'] ?? '',
      cid: map['cid'] ?? '',
      userId: map['userId'] ?? '',
      txHash: map['txHash'] ?? '',
    );
  }

  // 블록체인에서 가져온 데이터로부터 객체 생성
  factory Transaction.fromBlockchain(List<dynamic> result) {
    return Transaction(
      id: result[0],
      cid: result[1],
      txHash: '', // txHash는 이후에 설정합니다.
      title: '', // IPFS에서 가져올 예정
      amount: 0.0, // IPFS에서 가져올 예정
      date: DateTime.now(), // IPFS에서 가져올 예정
      type: '', // IPFS에서 가져올 예정
      category: '', // IPFS에서 가져올 예정
      userId: '', // IPFS에서 가져올 예정
    );
  }
}
