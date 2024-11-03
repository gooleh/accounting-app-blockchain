// lib/models/transaction.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  String id;
  String title;
  double amount; // 원 단위
  DateTime date;
  String type; // 'income' 또는 'expense'
  String category; // 카테고리 필드 추가
  String userId; // 고정된 값 설정

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category, // 생성자에 추가
    this.userId = 'user123', // 기본값 설정
  });

  // Firestore에서 데이터를 모델로 변환
  factory Transaction.fromMap(Map<String, dynamic> map, String documentId) {
    return Transaction(
      id: map['id'] ?? documentId, // Firestore의 documentId를 기본 ID로 사용
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] ?? 'expense',
      category: map['category'] ?? '기타 지출', // 기본값 설정
      userId: map['userId'] ?? 'user123', // 기본값 설정
    );
  }

  // 모델을 Firestore에 저장할 수 있는 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id, // 블록체인에 저장할 때 사용
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'type': type,
      'category': category,
      'userId': userId,
    };
  }

  // 블록체인에서 데이터를 모델로 변환 (수정된 메서드)
  factory Transaction.fromBlockchain(List<dynamic> data) {
    // 이중 리스트 처리
    if (data.isNotEmpty && data[0] is List) {
      data = data[0]; // 이중 리스트를 단일 리스트로 변환
    }

    if (data.length >= 5) {
      return Transaction(
        id: data[0].toString(),
        title: '', // Firestore에서 'title'을 가져올 것이므로 빈 값
        amount: (data[1] as BigInt).toDouble(), // 원 단위로 처리
        date: DateTime.fromMillisecondsSinceEpoch(
            (data[2] as BigInt).toInt() * 1000),
        type: data[3].toString(),
        category: data[4].toString(),
        userId: 'user123', // 고정된 값
      );
    } else {
      throw Exception('Invalid data format from blockchain');
    }
  }
}
