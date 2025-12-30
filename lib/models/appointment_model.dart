// lib/models/appointment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentModel {
  final String id;
  final String doctorId;
  final String patientId;
  final String patientName;
  final DateTime dateTime;
  final String meetLink;
  final String status;
  final DateTime createdAt;
  final String connectionType; // 'whatsapp', 'jitsi', 'in_app'
  final String doctorPhone;    // Required for WhatsApp redirection

  AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.patientName,
    required this.dateTime,
    required this.meetLink,
    required this.status,
    required this.createdAt,
    this.connectionType = 'jitsi',
    this.doctorPhone = '',
  });

  /// Factory constructor to create an AppointmentModel from Firestore Data
  factory AppointmentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AppointmentModel(
      id: documentId,
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Unknown',
      
      // Handle legacy 'slotStart' or new 'dateTime' fields
      dateTime: _parseDateTime(map['dateTime'] ?? map['slotStart']),
      
      meetLink: map['meetLink'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: _parseDateTime(map['createdAt']),
      
      // New fields for connection logic
      connectionType: map['connectionType'] ?? 'jitsi',
      doctorPhone: map['doctorPhone'] ?? '',
    );
  }

  /// Helper method to safely parse dynamic date formats (Timestamp or String)
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Method to convert AppointmentModel to Map for Firestore upload
  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'dateTime': Timestamp.fromDate(dateTime),
      'meetLink': meetLink,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'connectionType': connectionType,
      'doctorPhone': doctorPhone,
    };
  }

  /// CopyWith method for efficient state updates
  AppointmentModel copyWith({
    String? id,
    String? doctorId,
    String? patientId,
    String? patientName,
    DateTime? dateTime,
    String? meetLink,
    String? status,
    DateTime? createdAt,
    String? connectionType,
    String? doctorPhone,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      dateTime: dateTime ?? this.dateTime,
      meetLink: meetLink ?? this.meetLink,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      connectionType: connectionType ?? this.connectionType,
      doctorPhone: doctorPhone ?? this.doctorPhone,
    );
  }
}