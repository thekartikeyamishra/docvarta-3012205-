// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadKycFile(String uid, File file, String filename) async {
    final ref = _storage.ref().child('kyc/$uid/$filename');
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadAvatar(String uid, File file) async {
    final ref = _storage.ref().child('avatars/$uid.jpg');
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }
}
