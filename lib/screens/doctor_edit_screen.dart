// lib/screens/doctor_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../widgets/primary_button.dart';

class DoctorEditScreen extends StatefulWidget {
  const DoctorEditScreen({super.key});

  @override 
  State<DoctorEditScreen> createState() => _DoctorEditScreenState();
}

class _DoctorEditScreenState extends State<DoctorEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameCtrl = TextEditingController();
  final _specialityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController(); // ✅ Added
  final _cityCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  File? _avatar;
  String? _currentAvatarUrl;
  
  final StorageService _storage = StorageService();
  final UserService _userService = UserService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specialityCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _cityCtrl.dispose();
    _clinicCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await _db.collection('doctors').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameCtrl.text = data['displayName'] ?? '';
        _specialityCtrl.text = data['specialization'] ?? '';
        _bioCtrl.text = data['bio'] ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
        _whatsappCtrl.text = data['whatsappNumber'] ?? ''; // ✅ Load WA Number
        _cityCtrl.text = data['city'] ?? '';
        _clinicCtrl.text = data['clinic'] ?? '';
        _licenseCtrl.text = data['licenseNumber'] ?? '';
        _currentAvatarUrl = data['avatarUrl'];
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (p == null) return;
    setState(() => _avatar = File(p.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? avatarUrl = _currentAvatarUrl;
      if (_avatar != null) {
        avatarUrl = await _storage.uploadAvatar(uid, _avatar!);
      }

      // Generate keywords for search
      final keywords = _generateKeywords(
        _nameCtrl.text, 
        _specialityCtrl.text, 
        _cityCtrl.text
      );

      final updateData = {
        'displayName': _nameCtrl.text.trim(),
        'specialization': _specialityCtrl.text.trim(),
        'specializationLower': _specialityCtrl.text.trim().toLowerCase(),
        'bio': _bioCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'whatsappNumber': _whatsappCtrl.text.trim(), // ✅ Save WA Number
        'city': _cityCtrl.text.trim(),
        'cityLower': _cityCtrl.text.trim().toLowerCase(),
        'clinic': _clinicCtrl.text.trim(),
        'licenseNumber': _licenseCtrl.text.trim(),
        'avatarUrl': avatarUrl,
        'searchKeywords': keywords,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update Doctors Collection
      await _db.collection('doctors').doc(uid).update(updateData);
      
      // Sync basic info to Users Collection
      await _db.collection('users').doc(uid).update({
        'displayName': _nameCtrl.text.trim(),
        'whatsappNumber': _whatsappCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action cannot be undone. All your data will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently')
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true); // Show loading
      try {
        await _userService.deleteUserAccount(uid);
        await FirebaseAuth.instance.currentUser?.delete();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
          setState(() => _isSaving = false);
        }
      }
    }
  }

  // Helper for search keywords
  List<String> _generateKeywords(String name, String spec, String city) {
    Set<String> keywords = {};
    void addSubstrings(String word) {
      String temp = "";
      for (int i = 0; i < word.length; i++) {
        temp = temp + word[i];
        keywords.add(temp.toLowerCase());
      }
    }
    for (var w in "$name $spec $city".split(' ')) addSubstrings(w);
    return keywords.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _avatar != null 
                          ? FileImage(_avatar!) 
                          : (_currentAvatarUrl != null ? NetworkImage(_currentAvatarUrl!) : null) as ImageProvider?,
                      child: (_avatar == null && _currentAvatarUrl == null) 
                          ? const Icon(Icons.camera_alt, size: 30, color: Colors.grey) 
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name (Dr.)', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _specialityCtrl,
                        decoration: const InputDecoration(labelText: 'Specialization', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _licenseCtrl,
                        decoration: const InputDecoration(labelText: 'License No.', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ✅ WhatsApp Number Field (Critical)
                TextFormField(
                  controller: _whatsappCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number', 
                    prefixIcon: Icon(Icons.chat, color: Colors.green),
                    border: OutlineInputBorder(),
                    helperText: 'Visible to patients for "Chat" option',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v != null && v.length < 10) ? 'Enter valid number' : null,
                ),
                
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Alternative Phone', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _clinicCtrl,
                        decoration: const InputDecoration(labelText: 'Clinic Name', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(labelText: 'Bio / About', border: OutlineInputBorder(), alignLabelWithHint: true),
                  maxLines: 4,
                ),

                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save Changes',
                  onPressed: _isSaving ? null : _save,
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                
                // ✅ Delete Account Button
                TextButton.icon(
                  onPressed: _isSaving ? null : _deleteAccount,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}