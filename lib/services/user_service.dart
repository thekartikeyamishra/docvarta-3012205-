// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final _db = FirebaseFirestore.instance;
  final _users = FirebaseFirestore.instance.collection('users');
  final _doctors = FirebaseFirestore.instance.collection('doctors');

  Future<void> createBasicUserDoc(String uid, String email) async {
    await _users.doc(uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'kyc': {'status': 'none'}
    }, SetOptions(merge: true));
  }

  Future<String?> getRole(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return (snap.data()?['role'] as String?);
  }

  Stream<AppUser> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((s) => AppUser.fromDoc(s));
  }

  Future<AppUser?> getUserById(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromDoc(snap);
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> profile) async {
    await _users.doc(uid).set({'profile': profile}, SetOptions(merge: true));
  }

  Future<void> setRole(String uid, String role) async {
    await _users.doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  Future<void> setKycPending(String uid, Map<String, dynamic> kycPayload) async {
    await _users.doc(uid).set({'kyc': kycPayload}, SetOptions(merge: true));
  }

  Future<void> setKycStatus(String uid, String status, Map<String, dynamic>? meta) async {
    final payload = {
      'kyc.status': status,
      'kyc.verifiedAt': status == 'verified' ? FieldValue.serverTimestamp() : FieldValue.delete(),
      if (meta != null) 'kyc.meta': meta,
    };
    await _users.doc(uid).set(payload, SetOptions(merge: true));
  }

  // ✅ New Method: Delete User Data
  Future<void> deleteUserAccount(String uid) async {
    final batch = _db.batch();
    
    // 1. Delete User Doc
    batch.delete(_users.doc(uid));
    
    // 2. Delete Doctor Doc (if exists)
    batch.delete(_doctors.doc(uid));

    // Note: Deleting subcollections (appointments, slots) requires Cloud Functions
    // or a recursive delete loop client-side (not recommended for large data).
    // For MVP, deleting the main profile is often sufficient to "hide" the user.
    
    await batch.commit();
  }
}