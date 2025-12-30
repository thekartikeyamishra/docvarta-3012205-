// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? name;
  final String? role;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? kyc;
  final Map<String, dynamic>? medicalProfile;

  AppUser({
    required this.uid,
    this.email,
    this.name,
    this.role,
    this.profile,
    this.kyc,
    this.medicalProfile,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'],
      name: data['name'],
      role: data['role'],
      profile: data['profile'] as Map<String, dynamic>?,
      kyc: data['kyc'] as Map<String, dynamic>?,
      medicalProfile: data['medicalProfile'] as Map<String, dynamic>?,
    );
  }
}
