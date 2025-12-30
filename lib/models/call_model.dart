// lib/models/call_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CallModel {
  final String id;
  final String appointmentId;
  final String doctorId;
  final String patientId;
  final String doctorName;
  final String patientName;
  final String status; // ringing, accepted, declined, ended
  final String? roomId;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? endedAt;

  CallModel({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.patientId,
    required this.doctorName,
    required this.patientName,
    required this.status,
    this.roomId,
    this.createdAt,
    this.acceptedAt,
    this.declinedAt,
    this.endedAt,
  });

  factory CallModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallModel(
      id: doc.id,
      appointmentId: data['appointmentId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      patientId: data['patientId'] ?? '',
      doctorName: data['doctorName'] ?? 'Doctor',
      patientName: data['patientName'] ?? 'Patient',
      status: data['status'] ?? 'ringing',
      roomId: data['roomId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      declinedAt: (data['declinedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'patientId': patientId,
      'doctorName': doctorName,
      'patientName': patientName,
      'status': status,
      if (roomId != null) 'roomId': roomId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (declinedAt != null) 'declinedAt': Timestamp.fromDate(declinedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
    };
  }

  bool get isRinging => status == 'ringing';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isEnded => status == 'ended';
  bool get isActive => isRinging || isAccepted;
}