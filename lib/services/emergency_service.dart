// lib/services/emergency_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'booking_service.dart';

class EmergencyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BookingService _bookingService = BookingService();

  // Configuration Constants
  static const double EMERGENCY_FEE = 500.0;
  static const double PLATFORM_FEE_PERCENT = 0.10; // 10% to Platform, 90% to Doctor

  /// Main function to find a doctor, process payment, and book the slot.
  Future<Map<String, dynamic>> findAndBookEmergencyDoctor({String? preferredGender}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'success': false, 'message': 'Login required'};

      // ═══════════════════════════════════════════════════════════════════════
      // 1. FIND AVAILABLE DOCTOR
      // ═══════════════════════════════════════════════════════════════════════
      
      // Query doctors who are explicitly marked 'available'
      Query query = _db.collection('doctors').where('available', isEqualTo: true);
      
      final snapshot = await query.get();
      List<QueryDocumentSnapshot> availableDocs = snapshot.docs;

      // Filter by Gender (Client-side)
      if (preferredGender != null && preferredGender != 'Any') {
        final filtered = availableDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docGender = data['gender'] as String? ?? '';
          return docGender.toLowerCase() == preferredGender.toLowerCase();
        }).toList();
        
        // Use filtered list if matches found. If not, fail (or fallback depending on preference).
        // Here we fail to respect the user's explicit choice.
        if (filtered.isNotEmpty) {
          availableDocs = filtered;
        } else {
           return {
             'success': false, 
             'message': 'No $preferredGender emergency doctors available right now.'
           };
        }
      }

      if (availableDocs.isEmpty) {
        return {'success': false, 'message': 'No emergency doctors are currently active.'};
      }

      // Pick a Random Doctor to distribute load
      final random = Random();
      final selectedDoc = availableDocs[random.nextInt(availableDocs.length)];
      final doctorData = selectedDoc.data() as Map<String, dynamic>;
      final doctorId = selectedDoc.id;
      final doctorName = doctorData['displayName'] ?? 'Emergency Doctor';

      // ═══════════════════════════════════════════════════════════════════════
      // 2. PROCESS PAYMENT (ATOMIC TRANSACTION)
      // ═══════════════════════════════════════════════════════════════════════
      
      final double doctorEarning = EMERGENCY_FEE * (1 - PLATFORM_FEE_PERCENT); // ₹450
      
      bool transactionSuccess = false;

      try {
        await _db.runTransaction((transaction) async {
          final userRef = _db.collection('users').doc(user.uid);
          final doctorRef = _db.collection('doctors').doc(doctorId);

          final userSnap = await transaction.get(userRef);
          
          if (!userSnap.exists) throw Exception('User profile not found');

          final userBal = (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

          // Check Balance
          if (userBal < EMERGENCY_FEE) {
            throw Exception('Low Balance');
          }

          // A. Deduct from Patient
          transaction.update(userRef, {
            'walletBalance': userBal - EMERGENCY_FEE
          });

          // B. Credit to Doctor (Virtual Earnings)
          // Uses FieldValue.increment to be safe against concurrent updates
          transaction.update(doctorRef, {
            'walletBalance': FieldValue.increment(doctorEarning)
          });
          
          // C. (Optional) Log Transaction for Audit
          // Creating a doc reference inside transaction for write
          final txRef = _db.collection('transactions').doc();
          transaction.set(txRef, {
            'userId': user.uid,
            'doctorId': doctorId,
            'amount': EMERGENCY_FEE,
            'doctorEarning': doctorEarning,
            'platformFee': EMERGENCY_FEE - doctorEarning,
            'type': 'service_fee',
            'status': 'success',
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Emergency Consultation'
          });
        });
        
        transactionSuccess = true;

      } catch (e) {
        if (e.toString().contains('Low Balance')) {
          return {
            'success': false, 
            'message': 'Insufficient balance. Required: ₹$EMERGENCY_FEE', 
            'errorType': 'wallet'
          };
        }
        return {'success': false, 'message': 'Transaction Error: ${e.toString()}'};
      }

      if (!transactionSuccess) {
        return {'success': false, 'message': 'Payment transaction failed.'};
      }

      // ═══════════════════════════════════════════════════════════════════════
      // 3. BOOK APPOINTMENT
      // ═══════════════════════════════════════════════════════════════════════

      final now = DateTime.now();
      final apptId = await _bookingService.bookAppointment(
        doctorId: doctorId,
        doctorName: doctorName,
        patientName: user.displayName ?? 'Emergency Patient',
        slotStart: now,
        slotEnd: now.add(const Duration(minutes: 30)), 
        notes: '🚨 EMERGENCY SOS CALL (Paid)',
        connectionType: 'in_app', // Forces In-App Video Call
      );

      // ═══════════════════════════════════════════════════════════════════════
      // 4. HANDLE SUCCESS OR REFUND
      // ═══════════════════════════════════════════════════════════════════════

      if (apptId != null) {
        return {
          'success': true,
          'appointmentId': apptId,
          'doctorName': doctorName,
          'message': 'Emergency doctor found! Connecting...'
        };
      } else {
        // ⚠️ CRITICAL: Booking failed AFTER money was deducted.
        // We must attempt a refund to maintain integrity.
        await _processRefund(user.uid, doctorId, doctorEarning);
        
        return {
          'success': false, 
          'message': 'Booking failed. Amount has been refunded to your wallet.'
        };
      }

    } catch (e) {
      return {'success': false, 'message': 'System Error: $e'};
    }
  }

  /// Helper to reverse the transaction if booking fails
  Future<void> _processRefund(String userId, String doctorId, double doctorDebitAmount) async {
    try {
      await _db.runTransaction((transaction) async {
        final userRef = _db.collection('users').doc(userId);
        final doctorRef = _db.collection('doctors').doc(doctorId);

        // Refund User
        transaction.update(userRef, {
          'walletBalance': FieldValue.increment(EMERGENCY_FEE)
        });

        // Debit Doctor (Reverse the earning)
        transaction.update(doctorRef, {
          'walletBalance': FieldValue.increment(-doctorDebitAmount)
        });
        
        // Log Refund
        final txRef = _db.collection('transactions').doc();
        transaction.set(txRef, {
          'userId': userId,
          'amount': EMERGENCY_FEE,
          'type': 'refund',
          'status': 'success',
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Refund for failed emergency booking'
        });
      });
    } catch (e) {
      // In a real production app, this error should be sent to Sentry/Crashlytics
      // because it means a user paid but wasn't refunded automatically.
      print("CRITICAL REFUND FAILURE: $e");
    }
  }
}