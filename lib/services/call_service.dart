// lib/services/call_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class CallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new call invitation and notify the patient
  Future<String?> createCallInvitation({
    required String appointmentId,
    required String doctorId,
    required String patientId,
    required String doctorName,
    required String patientName,
  }) async {
    try {
      // Create call document
      final callDoc = await _firestore.collection('calls').add({
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'patientId': patientId,
        'doctorName': doctorName,
        'patientName': patientName,
        'status': 'ringing', // ringing, accepted, declined, ended
        'createdAt': FieldValue.serverTimestamp(),
        'callStartedBy': 'doctor',
      });

      final callId = callDoc.id;

      // Update appointment with call information
      await _firestore.collection('appointments').doc(appointmentId).update({
        'callId': callId,
        'callStatus': 'ringing',
        'callStartedAt': FieldValue.serverTimestamp(),
      });

      developer.log('Call invitation created: $callId', name: 'CallService');
      return callId;
    } catch (e) {
      developer.log('Error creating call invitation: $e', name: 'CallService', error: e);
      return null;
    }
  }

  /// Accept an incoming call
  Future<bool> acceptCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update appointment status
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (callDoc.exists) {
        final appointmentId = callDoc.data()?['appointmentId'];
        if (appointmentId != null) {
          await _firestore.collection('appointments').doc(appointmentId).update({
            'callStatus': 'accepted',
            'status': 'ongoing',
          });
        }
      }

      developer.log('Call accepted: $callId', name: 'CallService');
      return true;
    } catch (e) {
      developer.log('Error accepting call: $e', name: 'CallService', error: e);
      return false;
    }
  }

  /// Decline an incoming call
  Future<bool> declineCall(String callId, {String? reason}) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'declineReason': reason,
      });

      // Update appointment status
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (callDoc.exists) {
        final appointmentId = callDoc.data()?['appointmentId'];
        if (appointmentId != null) {
          await _firestore.collection('appointments').doc(appointmentId).update({
            'callStatus': 'declined',
          });
        }
      }

      developer.log('Call declined: $callId', name: 'CallService');
      return true;
    } catch (e) {
      developer.log('Error declining call: $e', name: 'CallService', error: e);
      return false;
    }
  }

  /// End an active call
  Future<bool> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Update appointment status
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (callDoc.exists) {
        final appointmentId = callDoc.data()?['appointmentId'];
        if (appointmentId != null) {
          await _firestore.collection('appointments').doc(appointmentId).update({
            'callStatus': 'ended',
            'status': 'completed',
          });
        }
      }

      developer.log('Call ended: $callId', name: 'CallService');
      return true;
    } catch (e) {
      developer.log('Error ending call: $e', name: 'CallService', error: e);
      return false;
    }
  }

  /// Listen for incoming calls for the current user (patient)
  Stream<QuerySnapshot> listenForIncomingCalls() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('calls')
        .where('patientId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get call details
  Future<Map<String, dynamic>?> getCallDetails(String callId) async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      developer.log('Error getting call details: $e', name: 'CallService', error: e);
      return null;
    }
  }

  /// Update call room ID (for WebRTC)
  Future<bool> updateCallRoomId(String callId, String roomId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'roomId': roomId,
      });
      return true;
    } catch (e) {
      developer.log('Error updating call room ID: $e', name: 'CallService', error: e);
      return false;
    }
  }
}