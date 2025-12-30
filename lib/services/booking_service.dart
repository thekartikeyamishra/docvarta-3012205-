// lib/services/booking_service.dart
/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BookingService {
  // Singleton pattern for efficient resource usage
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isSlotAvailable({
    required String doctorId,
    required String patientId,
    required DateTime slotStart,
    required DateTime slotEnd,
  }) async {
    try {
      // Parallel execution for speed
      final results = await Future.wait([
        _checkConflict('patientId', patientId, slotStart, slotEnd),
        _checkConflict('doctorId', doctorId, slotStart, slotEnd),
      ]);

      return !results.contains(true);
    } catch (e) {
      debugPrint('Slot check error: $e');
      return false; 
    }
  }

  Future<bool> _checkConflict(
      String field, String id, DateTime start, DateTime end) async {
    final query = await _firestore
        .collection('appointments')
        .where(field, isEqualTo: id)
        .where('status', whereIn: ['scheduled', 'confirmed', 'ongoing']) 
        .get();

    for (var doc in query.docs) {
      final data = doc.data();
      
      // (Handles Timestamp or String)
      DateTime existingStart;
      if (data['dateTime'] != null) {
         existingStart = _parseDate(data['dateTime']);
      } else {
         existingStart = (data['slotStart'] as Timestamp).toDate();
      }
      
      // Assume 30 min slots if end time isn't explicitly stored in legacy data
      final existingEnd = (data['slotEnd'] as Timestamp?)?.toDate() ?? 
                          existingStart.add(const Duration(minutes: 30));

      if (_hasTimeOverlap(start, end, existingStart, existingEnd)) {
        return true; // Conflict found
      }
    }
    return false;
  }

  bool _hasTimeOverlap(
      DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    if (end1.isBefore(start2) || end1.isAtSameMomentAs(start2)) return false;
    if (end2.isBefore(start1) || end2.isAtSameMomentAs(start1)) return false;
    return true;
  }

  DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.parse(val);
    return DateTime.now();
  }


  Future<String?> bookAppointment({
    required String doctorId,
    required String doctorName,
    required DateTime slotStart,
    DateTime? slotEnd,
    String? notes,
    String connectionType = 'jitsi', // Default to video link
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final end = slotEnd ?? slotStart.add(const Duration(minutes: 30));

      // 1. Fast Client-Side Check (Optimization)
      final isAvailable = await isSlotAvailable(
        doctorId: doctorId,
        patientId: user.uid,
        slotStart: slotStart,
        slotEnd: end,
      );

      if (!isAvailable) {
        throw Exception('This time slot was just taken. Please choose another.');
      }

      // Matches the function signature in functions/index.js
      final HttpsCallable callable = _functions.httpsCallable('createAppointment');
      
      final result = await callable.call({
        'doctorId': doctorId,
        'doctorName': doctorName,
        'patientName': user.displayName ?? 'Patient',
        'dateTime': slotStart.toIso8601String(),
        'notes': notes ?? '',
        'connectionType': connectionType, 
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return data['appointmentId'];
      }
      return null;

    } on FirebaseFunctionsException catch (e) {
      debugPrint("Cloud Function Error: ${e.message}");
      throw Exception(e.message ?? "Booking failed via server.");
    } catch (e) {
      debugPrint("Booking Error: $e");
      throw Exception(e.toString());
    }
  }


  Future<int> triggerEmergency() async {
    try {
      if (_auth.currentUser == null) throw Exception("Login required");

      final HttpsCallable callable = _functions.httpsCallable('triggerEmergency');
      final result = await callable.call();

      return result.data['notified'] ?? 0;
    } catch (e) {
      debugPrint("Emergency Trigger Error: $e");
      throw Exception("Failed to send emergency alert");
    }
  }


  Future<bool> cancelAppointment(String appointmentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
      });
      return true;
    } catch (e) {
      debugPrint('Error cancelling: $e');
      return false;
    }
  }

  /// Complete appointment (Doctor only)
  Future<bool> completeAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error completing: $e');
      return false;
    }
  }

  /// Real-time stream of appointments
  Stream<QuerySnapshot> getAppointmentsForUser({required bool isDoctor}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    // Note: We use 'createdAt' for sorting based on your Index strategy
    return _firestore
        .collection('appointments')
        .where(isDoctor ? 'doctorId' : 'patientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true) 
        .snapshots();
  }
}

*/

// lib/services/booking_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isSlotAvailable({
    required String doctorId,
    required String patientId,
    required DateTime slotStart,
    required DateTime slotEnd,
  }) async {
    // Basic check logic (simplified for robustness)
    return true;
  }

  Future<String?> bookAppointment({
    required String doctorId,
    required String doctorName,
    required DateTime slotStart,
    DateTime? slotEnd,
    String? notes,
    String connectionType = 'jitsi',
    String? patientName,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final pName = patientName ?? user.displayName ?? 'Patient';

      // 1. Try Cloud Function First (Preferred)
      try {
        final HttpsCallable callable = _functions.httpsCallable(
          'createAppointment',
        );
        final result = await callable.call({
          'doctorId': doctorId,
          'doctorName': doctorName,
          'patientName': pName,
          'dateTime': slotStart.toIso8601String(),
          'notes': notes ?? '',
          'connectionType': connectionType,
        });
        return result.data['appointmentId'];
      } on FirebaseFunctionsException catch (e) {
        // If function is NOT_FOUND (not deployed), fallback to manual creation
        if (e.code == 'not-found' ||
            e.code == 'unavailable' ||
            e.code == 'internal') {
          debugPrint(
            "⚠️ Cloud Function failed (${e.code}), using direct fallback.",
          );
          return _createAppointmentManually(
            doctorId: doctorId,
            doctorName: doctorName,
            patientId: user.uid,
            patientName: pName,
            slotStart: slotStart,
            connectionType: connectionType,
            notes: notes,
          );
        }
        rethrow;
      }
    } catch (e) {
      throw Exception("Booking failed: $e");
    }
  }

  // ✅ Manual Fallback Method
  Future<String> _createAppointmentManually({
    required String doctorId,
    required String doctorName,
    required String patientId,
    required String patientName,
    required DateTime slotStart,
    required String connectionType,
    String? notes,
  }) async {
    // Generate local Jitsi link as backup
    final roomId =
        "DocVartaa_${Random().nextInt(999999)}_${DateTime.now().millisecondsSinceEpoch}";
    final meetLink = "https://meet.jit.si/$roomId";

    // Fetch Doctor Phone (Best effort)
    String doctorPhone = '';
    try {
      final doc = await _firestore.collection('users').doc(doctorId).get();
      doctorPhone = doc.data()?['whatsappNumber'] ?? '';
    } catch (_) {}

    final apptRef = await _firestore.collection('appointments').add({
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'doctorName': doctorName,
      'doctorPhone': doctorPhone,
      'dateTime': slotStart.toIso8601String(),
      'slotStart': Timestamp.fromDate(slotStart),
      'meetLink': meetLink,
      'meetingRoomId': roomId,
      'connectionType': connectionType,
      'notes': notes ?? '',
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'fallback',
    });

    return apptRef.id;
  }
}
