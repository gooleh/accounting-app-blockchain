// lib/models/transaction.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  String id;
  String title;
  double amount;
  DateTime date;
  String type;
  String category;
  String cid;
  String userId;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.cid = '',
    this.userId = '',
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory Transaction.fromMap(Map<String, dynamic> map, String documentId) {
    return Transaction(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] ?? '',
      category: map['category'] ?? '',
      cid: map['cid'] ?? '',
      userId: map['userId'] ?? '',
    );
  }

  // 블록체인에서 데이터를 가져올 때 사용
  factory Transaction.fromBlockchain(List<dynamic> data) {
    return Transaction(
      id: data[0] as String,
      cid: data[1] as String,
      title: '',
      amount: 0.0,
      date: DateTime.now(),
      type: '',
      category: '',
      userId: '',
    );
  }

  // 데이터를 Firestore에 저장하거나 IPFS에 업로드할 때 사용
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(), // DateTime을 ISO8601 문자열로 변환
      'type': type,
      'category': category,
      'cid': cid,
      'userId': userId,
    };
  }

  // JSON 인코딩 시 필요한 메서드
  Map<String, dynamic> toJson() {
    return toMap();
  }
}
