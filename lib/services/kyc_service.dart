// G:\docvartaa\lib\services/kyc_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KycService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload a single file to storage under `kyc/{uid}/{timestamp}_{filename}`
  /// Returns download URL and storage path.
  Future<Map<String, String>> uploadKycFile(File file, {required String filename, Function(double)? onProgress}) async {
    final uid = _auth.currentUser!.uid;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'kyc/$uid/${ts}_$filename';
    final ref = _storage.ref(path);

    final uploadTask = ref.putFile(file);
    uploadTask.snapshotEvents.listen((event) {
      if (onProgress != null && event.totalBytes > 0) {
        onProgress(event.bytesTransferred / event.totalBytes);
      }
    });

    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();
    return {'downloadUrl': url, 'path': path, 'name': filename};
  }

  /// Save kyc metadata under users/{uid}.doctorProfile.kycFiles array (lean)
  Future<void> saveKycMeta({required String downloadUrl, required String storagePath, required String filename}) async {
    final uid = _auth.currentUser!.uid;
    final fileMeta = {
      'url': downloadUrl,
      'storagePath': storagePath,
      'name': filename,
      'uploadedAt': FieldValue.serverTimestamp(),
      'status': 'pending' // pending / approved / rejected
    };

    final docRef = _db.collection('users').doc(uid);
    await docRef.set({'doctorProfile': {'kycFiles': FieldValue.arrayUnion([fileMeta])}}, SetOptions(merge: true));
    // Also set a lightweight flag to show pending status
    await docRef.set({'doctorProfile': {'kycPending': true}}, SetOptions(merge: true));
  }

  /// Used by admin to set verification on doctor:
  Future<void> setDoctorKycVerified({required String doctorUid, required bool verified}) async {
    final userDoc = _db.collection('users').doc(doctorUid);
    final doctorDoc = _db.collection('doctors').doc(doctorUid);

    await userDoc.set({'doctorProfile': {'kycVerified': verified, 'kycPending': false}}, SetOptions(merge: true));
    await doctorDoc.set({'kycVerified': verified}, SetOptions(merge: true));
  }

  /// Delete a KYC file both from storage and metadata (admin or owner)
  Future<void> deleteKycFile({required String doctorUid, required String storagePath}) async {
    // Delete from storage
    await _storage.ref(storagePath).delete();

    // Remove from user's kycFiles
    final docRef = _db.collection('users').doc(doctorUid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final doc = snapshot.data()!;
    final files = ((doc['doctorProfile'] ?? {})['kycFiles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final remaining = files.where((f) => f['storagePath'] != storagePath).toList();

    await docRef.set({'doctorProfile': {'kycFiles': remaining}}, SetOptions(merge: true));
  }
}
