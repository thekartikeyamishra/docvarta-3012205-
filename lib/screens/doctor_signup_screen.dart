// lib/screens/sign_up_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/primary_button.dart';
import '../widgets/custom_card.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic Info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _aadharController = TextEditingController(); // Government ID
  
  // Location
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _nationController = TextEditingController(); // Country
  
  // Medical Profile (Optional)
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _historyController = TextEditingController();
  
  String _gender = 'Male';
  String _bloodGroup = 'Unknown';
  String _sugar = 'No'; // "Yes" or "No"
  String _bp = 'No';    // "Yes" or "No"

  bool _loading = false;
  bool _obscurePassword = true;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _aadharController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _nationController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 1. Create Auth User
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      final uid = credential.user!.uid;
      final name = _nameController.text.trim();

      // 2. Prepare Patient Data
      final patientData = {
        'uid': uid,
        'role': 'patient',
        'displayName': name,
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'gender': _gender,
        'governmentId': _aadharController.text.trim(), // Aadhar/ID
        'address': {
          'street': _addressController.text.trim(),
          'state': _stateController.text.trim(),
          'nation': _nationController.text.trim(),
        },
        'patientProfile': { // Specific medical info
          'bloodGroup': _bloodGroup,
          'hasDiabetes': _sugar == 'Yes',
          'hasBP': _bp == 'Yes',
          'height': _heightController.text.trim(),
          'weight': _weightController.text.trim(),
          'pastMedicalHistory': _historyController.text.trim(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'kycVerified': true, // Patients auto-verified for now (or set false if manual check needed)
      };

      // 3. Save to Firestore (users collection)
      await _db.collection('users').doc(uid).set(patientData);

      // 4. Update Display Name
      await credential.user!.updateDisplayName(name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient account created successfully!')),
        );
        Navigator.pushReplacementNamed(context, '/patientHome');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Signup failed'), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Sign Up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create your patient profile to connect with doctors.', style: TextStyle(color: Colors.grey)),
                
                _buildSectionTitle('Basic Details'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        decoration: const InputDecoration(labelText: 'Age *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: ['Male', 'Female', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number *', prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _aadharController,
                  decoration: const InputDecoration(labelText: 'Aadhar / Gov ID Number *', prefixIcon: Icon(Icons.badge)),
                  validator: (v) => v!.isEmpty ? 'Required for verification' : null,
                ),

                _buildSectionTitle('Account Login'),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email (Optional)', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (v) => (v != null && v.length < 6) ? 'Min 6 chars' : null,
                ),

                _buildSectionTitle('Location'),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Full Address *', prefixIcon: Icon(Icons.home)),
                  maxLines: 2,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _stateController, decoration: const InputDecoration(labelText: 'State *'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _nationController, decoration: const InputDecoration(labelText: 'Nation *'))),
                  ],
                ),

                _buildSectionTitle('Medical Profile (Optional)'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _bloodGroup,
                        decoration: const InputDecoration(labelText: 'Blood Group'),
                        items: ['Unknown', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _bloodGroup = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sugar,
                        decoration: const InputDecoration(labelText: 'Diabetes (Sugar)'),
                        items: ['Yes', 'No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _sugar = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _bp,
                        decoration: const InputDecoration(labelText: 'Blood Pressure'),
                        items: ['Yes', 'No'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _bp = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _heightController, decoration: const InputDecoration(labelText: 'Height (cm)'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _weightController, decoration: const InputDecoration(labelText: 'Weight (kg)'), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _historyController,
                  decoration: const InputDecoration(labelText: 'Past Medical History (Brief)', alignLabelWithHint: true),
                  maxLines: 3,
                ),

                const SizedBox(height: 30),
                PrimaryButton(
                  label: _loading ? 'Creating Account...' : 'Create Patient Account',
                  onPressed: _loading ? null : _signUp,
                ),
                const SizedBox(height: 20),
                
                // Link to doctor signup
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Are you a Doctor? "),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/doctor-signup'),
                      child: const Text("Register Here"),
                    ),
                  ],
                ),
                
                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/sign-in'),
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