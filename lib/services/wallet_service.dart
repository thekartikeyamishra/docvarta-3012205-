// lib/services/wallet_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/withdrawal_model.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  //                           👤 PATIENT WALLET LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the current wallet balance for the logged-in PATIENT (User).
  Future<double> getBalance() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0.0;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data()!.containsKey('walletBalance')) {
        return (doc.data()!['walletBalance'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      // In production, log this error to Crashlytics
      return 0.0;
    }
  }

  /// Add money to PATIENT wallet (e.g., via Razorpay).
  /// Uses a Batch write to ensure the Balance update and Transaction Log happen together.
  Future<void> addMoney(double amount, {String? paymentId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    if (amount <= 0) throw Exception('Amount must be greater than zero');

    final batch = _db.batch();
    
    // 1. Increment Balance in User Profile
    final userRef = _db.collection('users').doc(uid);
    batch.set(userRef, {
      'walletBalance': FieldValue.increment(amount)
    }, SetOptions(merge: true));
    
    // 2. Record Transaction Ledger (Audit Trail)
    final txRef = _db.collection('transactions').doc();
    batch.set(txRef, {
      'userId': uid,
      'amount': amount,
      'type': 'credit', // Money coming IN
      'source': 'razorpay',
      'paymentId': paymentId ?? 'simulated',
      'timestamp': FieldValue.serverTimestamp(),
      'description': 'Wallet Recharge',
      'status': 'success'
    });

    await batch.commit();
  }

  /// Deduct money for emergency consultation from PATIENT.
  /// Uses a Transaction to ensure balance never drops below zero (Atomic).
  Future<bool> deductMoney(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    if (amount <= 0) return false;

    try {
      return await _db.runTransaction((transaction) async {
        final docRef = _db.collection('users').doc(uid);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) return false;

        final currentBalance = (snapshot.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        if (currentBalance >= amount) {
          final newBalance = currentBalance - amount;
          
          // 1. Update Balance
          transaction.update(docRef, {'walletBalance': newBalance});
          
          // 2. Log the Debit Transaction
          final txRef = _db.collection('transactions').doc();
          transaction.set(txRef, {
            'userId': uid,
            'amount': -amount, // Negative for debit
            'type': 'debit',
            'source': 'service_fee',
            'timestamp': FieldValue.serverTimestamp(),
            'description': 'Emergency Call Fee',
            'status': 'success'
          });

          return true; // Deduction successful
        } else {
          return false; // Insufficient funds
        }
      });
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           👨‍⚕️ DOCTOR WALLET & PAYOUT LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get DOCTOR'S current earnings balance.
  Future<double> getDoctorBalance() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0.0;
    
    try {
      final doc = await _db.collection('doctors').doc(uid).get();
      return (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Update Doctor's Payout Settings (UPI or Bank Details).
  Future<void> updatePayoutSettings({String? upiId, Map<String, String>? bankDetails}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final Map<String, dynamic> updates = {};
    if (upiId != null) updates['upiId'] = upiId;
    if (bankDetails != null) updates['bankDetails'] = bankDetails;
    
    if (updates.isNotEmpty) {
      await _db.collection('doctors').doc(uid).update(updates);
    }
  }

  /// Request a Payout/Withdrawal for DOCTOR.
  /// 1. Checks balance > requested amount.
  /// 2. Checks if payment details exist.
  /// 3. Deducts balance immediately.
  /// 4. Creates a 'pending' withdrawal request.
  /// 5. Logs the transaction in the ledger.
  Future<Map<String, dynamic>> requestWithdrawal(double amount, String method) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'success': false, 'message': 'Auth Error'};
    if (amount <= 0) return {'success': false, 'message': 'Invalid amount'};

    try {
      return await _db.runTransaction((transaction) async {
        // 1. Read Doctor Data
        final doctorRef = _db.collection('doctors').doc(uid);
        final doctorSnap = await transaction.get(doctorRef);
        
        if (!doctorSnap.exists) throw Exception("Doctor profile not found");
        
        final currentBal = (doctorSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final upiId = doctorSnap.data()?['upiId'] as String?;
        final bankDetails = doctorSnap.data()?['bankDetails'];

        // 2. Validation
        if (currentBal < amount) throw Exception("Insufficient balance");
        if (amount < 100) throw Exception("Minimum withdrawal is ₹100"); 

        Map<String, dynamic> payoutDetails = {};
        if (method == 'upi') {
          if (upiId == null || upiId.isEmpty) throw Exception("Please add UPI ID in settings first");
          payoutDetails = {'upiId': upiId};
        } else {
          if (bankDetails == null) throw Exception("Please add Bank Details in settings first");
          payoutDetails = Map<String, dynamic>.from(bankDetails);
        }

        // 3. Deduct Balance Immediately (Atomic)
        transaction.update(doctorRef, {
          'walletBalance': FieldValue.increment(-amount)
        });

        // 4. Create Withdrawal Request (For Admin to see)
        final withdrawalRef = _db.collection('withdrawals').doc();
        transaction.set(withdrawalRef, {
          'doctorId': uid,
          'amount': amount,
          'status': 'pending', // Pending Admin Approval
          'method': method,
          'details': payoutDetails,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 5. Create Transaction Ledger Entry (For Doctor's History)
        final txRef = _db.collection('transactions').doc();
        transaction.set(txRef, {
          'userId': uid, // Using doctor's UID so it shows in their history
          'amount': -amount, // Negative because it's a debit
          'type': 'withdrawal',
          'source': 'payout',
          'timestamp': FieldValue.serverTimestamp(),
          'description': 'Withdrawal Request',
          'status': 'pending', // Matches withdrawal status
          'relatedWithdrawalId': withdrawalRef.id
        });

        return {'success': true, 'message': 'Withdrawal request submitted successfully'};
      });
    } catch (e) {
      // Clean up error message for UI
      String msg = e.toString().replaceAll('Exception:', '').trim();
      return {'success': false, 'message': msg};
    }
  }

  /// Get History of Withdrawal Requests for the Doctor.
  Stream<List<WithdrawalModel>> getWithdrawalHistory() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db.collection('withdrawals')
        .where('doctorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => WithdrawalModel.fromFirestore(d)).toList());
  }
}