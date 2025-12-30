// lib/models/withdrawal_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawalModel {
  final String id;
  final String doctorId;
  final double amount;
  final String status; // 'pending', 'approved', 'rejected'
  final String method; // 'upi', 'bank'
  final Map<String, dynamic> details; // Snapshot of payment details
  final DateTime createdAt;
  final DateTime? processedAt;

  WithdrawalModel({
    required this.id,
    required this.doctorId,
    required this.amount,
    required this.status,
    required this.method,
    required this.details,
    required this.createdAt,
    this.processedAt,
  });

  /// Convert model to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'amount': amount,
      'status': status,
      'method': method,
      'details': details,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
    };
  }

  /// Factory constructor to create a WithdrawalModel from Firestore
  factory WithdrawalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return WithdrawalModel(
      id: doc.id,
      doctorId: data['doctorId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'pending',
      method: data['method'] ?? 'upi',
      details: data['details'] as Map<String, dynamic>? ?? {},
      
      // Safe parsing for timestamps to prevent crashes on null
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// CopyWith for efficient state updates (Immutable pattern)
  WithdrawalModel copyWith({
    String? id,
    String? doctorId,
    double? amount,
    String? status,
    String? method,
    Map<String, dynamic>? details,
    DateTime? createdAt,
    DateTime? processedAt,
  }) {
    return WithdrawalModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      method: method ?? this.method,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}