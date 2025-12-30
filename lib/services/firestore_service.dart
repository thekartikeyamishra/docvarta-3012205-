// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _doctors => _db.collection('doctors');
  CollectionReference<Map<String, dynamic>> get _appointments => _db.collection('appointments');

  // --- User / Patient Methods ---

  /// Get a user's document by UID
  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _users.doc(uid).get();
  }

  /// Create or Merge user data
  Future<void> saveUser(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Update specific fields in a user document
  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).update(data);
  }

  /// Update just the patient profile map within the user document
  Future<void> updatePatientProfile(String uid, Map<String, dynamic> profileData) {
    return _users.doc(uid).set({
      'patientProfile': profileData,
      'meta': {'updatedAt': FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  // --- Doctor Methods ---

  /// Get public doctor profile
  Future<DocumentSnapshot<Map<String, dynamic>>> getDoctor(String uid) {
    return _doctors.doc(uid).get();
  }

  /// Update doctor availability
  Future<void> setDoctorAvailability(String uid, bool available) {
    return _doctors.doc(uid).update({'available': available});
  }

  // --- Appointment Methods ---

  /// Stream appointments for a specific user (doctor or patient)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAppointments({
    required String uid,
    required String role, // 'doctor' or 'patient'
  }) {
    final field = role == 'doctor' ? 'doctorId' : 'patientId';
    return _appointments
        .where(field, isEqualTo: uid)
        .orderBy('slotStart', descending: false)
        .snapshots();
  }

  /// Get appointment details
  Future<DocumentSnapshot<Map<String, dynamic>>> getAppointment(String id) {
    return _appointments.doc(id).get();
  }
}