// lib/screens/patient_profile_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();

  // State variables
  String? _uid;
  String? _gender; // Nullable to allow "Not Set"
  String? _bloodGroup; // Nullable to allow "Not Set"
  bool _isLoading = true;
  bool _isSaving = false;

  // Dropdown Options
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _initUserAndLoadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _historyCtrl.dispose();
    super.dispose();
  }

  Future<void> _initUserAndLoadProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
      }
      return;
    }

    setState(() {
      _uid = user.uid;
    });

    await _loadProfile(user);
  }

  Future<void> _loadProfile(User user) async {
    try {
      if (_uid == null) return;

      final doc = await _db.collection('users').doc(_uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _nameCtrl.text = data['displayName'] ?? user.displayName ?? '';
        
        final profile = data['patientProfile'] is Map<String, dynamic>
            ? data['patientProfile'] as Map<String, dynamic>
            : data;

        _ageCtrl.text = profile['age']?.toString() ?? '';
        _phoneCtrl.text = profile['phone'] ?? profile['whatsappNumber'] ?? user.phoneNumber ?? '';
        
        final addr = profile['address'];
        _addressCtrl.text = addr is String ? addr : (addr is Map ? addr['street'] ?? '' : '');
            
        _historyCtrl.text = profile['pastMedicalHistory'] ?? '';

        // Safe Dropdown Initialization
        String? loadedGender = profile['gender'];
        if (loadedGender != null && _genders.contains(loadedGender)) {
          setState(() => _gender = loadedGender);
        }

        String? loadedBlood = profile['bloodGroup'];
        if (loadedBlood != null && _bloodGroups.contains(loadedBlood)) {
          setState(() => _bloodGroup = loadedBlood);
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _uid == null) return;

    setState(() => _isSaving = true);
    try {
      final profileData = {
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _gender,
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'bloodGroup': _bloodGroup,
        'pastMedicalHistory': _historyCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();
      final userRef = _db.collection('users').doc(_uid);

      batch.update(userRef, {
        'displayName': _nameCtrl.text.trim(),
        'patientProfile': profileData,
        'phone': _phoneCtrl.text.trim(),
        'whatsappNumber': _phoneCtrl.text.trim(),
      });

      await batch.commit();
      await _auth.currentUser?.updateDisplayName(_nameCtrl.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_uid == null) return const Scaffold(body: Center(child: Text("Not logged in")));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Personal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageCtrl,
                              decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              hint: const Text('Select Gender'),
                              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                              items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Medical Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _bloodGroup,
                      hint: const Text('Select Blood Group'),
                      decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                      items: _bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _bloodGroup = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _historyCtrl,
                      decoration: const InputDecoration(labelText: 'History', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save Profile',
                  onPressed: _isSaving ? null : _saveProfile,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Log Out', style: TextStyle(color: Colors.red)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}