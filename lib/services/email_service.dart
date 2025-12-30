// lib/services/email_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

/// Email service for sending call notifications and transcript delivery
/// Uses Firestore to trigger Cloud Functions for actual email sending
class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send call invitation email to patient
  Future<void> sendCallInvitationEmail({
    required String patientEmail,
    required String patientName,
    required String doctorName,
    required String callLink,
    required String appointmentId,
  }) async {
    try {
      await _firestore.collection('mail').add({
        'to': [patientEmail],
        'template': {
          'name': 'call_invitation',
          'data': {
            'patientName': patientName,
            'doctorName': doctorName,
            'callLink': callLink,
            'appointmentId': appointmentId,
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        'Call invitation email queued for: $patientEmail',
        name: 'EmailService',
      );
    } catch (e) {
      developer.log(
        'Error sending call invitation email: $e',
        name: 'EmailService',
        error: e,
      );
    }
  }

  /// Send missed call notification email
  Future<void> sendMissedCallEmail({
    required String patientEmail,
    required String patientName,
    required String doctorName,
    required String appointmentId,
  }) async {
    try {
      await _firestore.collection('mail').add({
        'to': [patientEmail],
        'template': {
          'name': 'missed_call',
          'data': {
            'patientName': patientName,
            'doctorName': doctorName,
            'appointmentId': appointmentId,
            'missedAt': DateTime.now().toIso8601String(),
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        'Missed call email queued for: $patientEmail',
        name: 'EmailService',
      );
    } catch (e) {
      developer.log(
        'Error sending missed call email: $e',
        name: 'EmailService',
        error: e,
      );
    }
  }

  /// Send transcript via email
  Future<void> sendTranscriptEmail({
    required String recipientEmail,
    required String recipientName,
    required String doctorName,
    required String patientName,
    required String transcriptText,
    required String appointmentId,
    required DateTime callDate,
  }) async {
    try {
      await _firestore.collection('mail').add({
        'to': [recipientEmail],
        'template': {
          'name': 'transcript_delivery',
          'data': {
            'recipientName': recipientName,
            'doctorName': doctorName,
            'patientName': patientName,
            'callDate': callDate.toIso8601String(),
            'appointmentId': appointmentId,
            'transcriptText': transcriptText,
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        'Transcript email queued for: $recipientEmail',
        name: 'EmailService',
      );
    } catch (e) {
      developer.log(
        'Error sending transcript email: $e',
        name: 'EmailService',
        error: e,
      );
    }
  }

  /// Generate shareable call link
  String generateCallLink({
    required String callId,
    required String appointmentId,
  }) {
    const baseUrl = 'https://docvartaa.app';
    return '$baseUrl/join-call?callId=$callId&appointmentId=$appointmentId';
  }

  /// Send call link via email
  Future<void> sendCallLinkEmail({
    required String patientEmail,
    required String patientName,
    required String doctorName,
    required String callId,
    required String appointmentId,
  }) async {
    try {
      final callLink = generateCallLink(
        callId: callId,
        appointmentId: appointmentId,
      );

      await _firestore.collection('mail').add({
        'to': [patientEmail],
        'template': {
          'name': 'call_link',
          'data': {
            'patientName': patientName,
            'doctorName': doctorName,
            'callLink': callLink,
            'appointmentId': appointmentId,
            'expiresIn': '30 minutes',
          },
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        'Call link email queued for: $patientEmail',
        name: 'EmailService',
      );
    } catch (e) {
      developer.log(
        'Error sending call link email: $e',
        name: 'EmailService',
        error: e,
      );
    }
  }
}