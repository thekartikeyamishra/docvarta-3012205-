// G:\docvartaa\lib\screens\auth\doctor_signup.dart
// ✅ PRODUCTION-READY: Doctor Signup with WhatsApp Integration & KYC
// Created: 2025-01-30

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class DoctorSignUpScreen extends StatefulWidget {
  const DoctorSignUpScreen({super.key});

  @override
  State<DoctorSignUpScreen> createState() => _DoctorSignUpScreenState();
}

class _DoctorSignUpScreenState extends State<DoctorSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specializationController = TextEditingController();
  final _cityController = TextEditingController();
  final _clinicController = TextEditingController();
  final _licenseController = TextEditingController();
  final _phoneController = TextEditingController(); // WhatsApp Number

  bool _isLoading = false;
  bool _obscurePassword = true;
  final List<XFile> _kycFiles = [];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _specializationController.dispose();
    _cityController.dispose();
    _clinicController.dispose();
    _licenseController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🔍 SEARCH KEYWORDS GENERATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  List<String> generateSearchKeywords(String name, String specialization, String city) {
    final tokens = <String>{};
    
    void addParts(String s) {
      final normalized = s.toLowerCase().trim();
      if (normalized.isEmpty) return;
      
      final parts = normalized.split(RegExp(r'\s+'));
      String accum = '';
      
      for (final p in parts) {
        accum = accum.isEmpty ? p : '$accum $p';
        tokens.add(p);
        tokens.add(accum);
      }
      
      // Add exact match prefixes
      for (int i = 1; i <= normalized.length; i++) {
        tokens.add(normalized.substring(0, i));
      }
    }
    
    addParts(name);
    addParts(specialization);
    addParts(city);
    
    return tokens.toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           📁 KYC FILE HANDLING
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _pickKycFiles() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600, // Optimize image size before upload
        imageQuality: 85,
      );
      
      if (file != null) {
        setState(() => _kycFiles.add(file));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<List<String>> _uploadKycFiles(String uid) async {
    final uploadedUrls = <String>[];
    
    for (final file in _kycFiles) {
      try {
        final ext = file.name.split('.').last;
        final storageRef = _storage.ref().child(
          'kyc/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        
        if (kIsWeb) {
          // Web upload
          final bytes = await file.readAsBytes();
          await storageRef.putData(bytes);
        } else {
          // Mobile upload
          await storageRef.putFile(File(file.path));
        }
        
        final url = await storageRef.getDownloadURL();
        uploadedUrls.add(url);
      } catch (e) {
        debugPrint('Error uploading file ${file.name}: $e');
      }
    }
    
    return uploadedUrls;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           ✅ VALIDATION LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your WhatsApp number';
    }
    // Regex: Allow only digits, length 10-15
    final phoneRegex = RegExp(r'^[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number (10-15 digits)';
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           📝 FORM SUBMISSION
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_kycFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one KYC document (Medical License)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Step 1: Create Firebase Auth account
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final uid = cred.user!.uid;

      // Step 2: Upload KYC files
      final kycUrls = await _uploadKycFiles(uid);
      
      // Step 3: Generate search keywords
      final keywords = generateSearchKeywords(
        _nameController.text,
        _specializationController.text,
        _cityController.text,
      );

      // Step 4: Prepare Data
      // ✅ We store 'whatsappNumber' in both collections for consistent access
      final String whatsappNumber = _phoneController.text.trim();

      // Doctor Profile (Detailed)
      final doctorDoc = {
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'whatsappNumber': whatsappNumber, // Critical for patient-doctor chat
        'phone': whatsappNumber, // Legacy support
        'specialization': _specializationController.text.trim(),
        'specializationLower': _specializationController.text.trim().toLowerCase(),
        'city': _cityController.text.trim(),
        'cityLower': _cityController.text.trim().toLowerCase(),
        'clinic': _clinicController.text.trim(),
        'medicalLicense': _licenseController.text.trim(),
        'kycFiles': kycUrls,
        'kycVerified': false, // Must be verified by admin
        'searchKeywords': keywords,
        'available': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // User Profile (Auth & Role)
      final userDoc = {
        'uid': uid,
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'whatsappNumber': whatsappNumber, // Critical for generic user lookup
        'role': 'doctor',
        'isOnline': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Step 6: Batch write to Firestore (Atomic Operation)
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(uid), userDoc);
      batch.set(_firestore.collection('doctors').doc(uid), doctorDoc);
      await batch.commit();

      // Step 7: Update display name
      await cred.user!.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor account created. Pending Verification.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // ✅ Navigate to doctor home
        Navigator.of(context).pushReplacementNamed('/doctorHome');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      
      if (e.code == 'weak-password') {
        message = 'The password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Registration'),
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  color: Colors.blue[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please provide accurate information for verification',
                            style: TextStyle(fontSize: 13, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Personal Info Section
                const Text(
                  'Personal Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name (Dr.) *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.contains('@') ? null : 'Invalid Email',
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                ),
                
                const SizedBox(height: 12),
                
                // ✅ UPDATED WHATSAPP NUMBER FIELD
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number *',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                    border: OutlineInputBorder(),
                    helperText: 'For appointment updates & patient connection',
                    hintText: '9876543210'
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                
                const SizedBox(height: 24),
                
                // Professional Info Section
                const Text(
                  'Professional Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _specializationController,
                  decoration: const InputDecoration(
                    labelText: 'Specialization (e.g. Cardiologist) *',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _clinicController,
                  decoration: const InputDecoration(
                    labelText: 'Clinic/Hospital Name (Optional)',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _licenseController,
                  decoration: const InputDecoration(
                    labelText: 'Medical License Number *',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required for verification' : null,
                ),
                
                const SizedBox(height: 24),
                
                // KYC Upload Section
                const Text(
                  'Upload Medical License / ID (KYC)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickKycFiles,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Select Document Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.black87,
                            elevation: 0,
                          ),
                        ),
                        if (_kycFiles.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _kycFiles.map((f) => Chip(
                              label: Text(
                                f.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _kycFiles.remove(f));
                              },
                              backgroundColor: Colors.blue[50],
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Register & Submit KYC',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Back to Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/sign-in');
                      },
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}