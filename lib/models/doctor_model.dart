// lib/models/doctor_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorModel {
  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final String whatsappNumber;
  final String gender;
  final String specialization;
  final String city;
  final String clinic;
  final String bio;
  final String avatarUrl;
  final String medicalLicense;
  final bool available;
  final bool kycVerified;
  final double walletBalance;
  final List<String> searchKeywords;
  
  // ✅ Payout Details
  final String? upiId;
  final Map<String, String>? bankDetails; // {accountNumber, ifsc, bankName, holderName}
  final DateTime? createdAt;

  DoctorModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.whatsappNumber,
    required this.gender,
    required this.specialization,
    required this.city,
    required this.clinic,
    required this.bio,
    required this.avatarUrl,
    required this.medicalLicense,
    required this.available,
    required this.kycVerified,
    required this.walletBalance,
    required this.searchKeywords,
    this.upiId,
    this.bankDetails,
    this.createdAt,
  });

  /// Factory constructor to create a DoctorModel from Firestore DocumentSnapshot
  factory DoctorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return DoctorModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      whatsappNumber: data['whatsappNumber'] ?? '',
      
      // ✅ Handle Gender with default fallback
      gender: data['gender'] ?? 'Unknown',
      
      specialization: data['specialization'] ?? '',
      city: data['city'] ?? '',
      clinic: data['clinic'] ?? '',
      bio: data['bio'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      medicalLicense: data['medicalLicense'] ?? '',
      
      available: data['available'] ?? false,
      kycVerified: data['kycVerified'] ?? false,
      
      // ✅ Handle Wallet Balance safely (int/double conversion)
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      
      // ✅ Parse Payout Details safely
      upiId: data['upiId'],
      bankDetails: data['bankDetails'] != null 
          ? (data['bankDetails'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()))
          : null,
          
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert DoctorModel to Map for Firestore operations
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'phone': phone,
      'whatsappNumber': whatsappNumber,
      'gender': gender,
      'specialization': specialization,
      'specializationLower': specialization.toLowerCase(), // Helper for search
      'city': city,
      'cityLower': city.toLowerCase(), // Helper for search
      'clinic': clinic,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'medicalLicense': medicalLicense,
      'available': available,
      'kycVerified': kycVerified,
      'walletBalance': walletBalance,
      'searchKeywords': searchKeywords,
      'upiId': upiId,
      'bankDetails': bankDetails,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  /// CopyWith for easy state updates (Immutable pattern)
  DoctorModel copyWith({
    String? displayName,
    String? email,
    String? phone,
    String? whatsappNumber,
    String? gender,
    String? specialization,
    String? city,
    String? clinic,
    String? bio,
    String? avatarUrl,
    String? medicalLicense,
    bool? available,
    bool? kycVerified,
    double? walletBalance,
    List<String>? searchKeywords,
    String? upiId,
    Map<String, String>? bankDetails,
  }) {
    return DoctorModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      gender: gender ?? this.gender,
      specialization: specialization ?? this.specialization,
      city: city ?? this.city,
      clinic: clinic ?? this.clinic,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      medicalLicense: medicalLicense ?? this.medicalLicense,
      available: available ?? this.available,
      kycVerified: kycVerified ?? this.kycVerified,
      walletBalance: walletBalance ?? this.walletBalance,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      upiId: upiId ?? this.upiId,
      bankDetails: bankDetails ?? this.bankDetails,
      createdAt: createdAt,
    );
  }
}