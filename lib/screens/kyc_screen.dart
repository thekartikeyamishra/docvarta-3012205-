// lib/screens/kyc_screen.dart
/*
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/kyc_service.dart';

class KycScreen extends StatefulWidget {
  final String type; // 'doctor_license' or 'aadhaar' etc.
  KycScreen({required this.type});
  @override State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  File? front, back, selfie;
  final _license = TextEditingController();
  final picker = ImagePicker();
  bool submitting = false;
  final _kyc = KycService();
  final uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> pickImage(Function(File) setFile) async {
    final p = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (p == null) return;
    setState(() => setFile(File(p.path)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KYC (${widget.type})')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          TextField(controller: _license, decoration: InputDecoration(labelText: widget.type=='doctor_license' ? 'License number' : 'ID number (optional)')),
          SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => pickImage((f) => front = f), child: Text('Pick front'))),
            SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: () => pickImage((f) => back = f), child: Text('Pick back'))),
          ]),
          SizedBox(height: 8),
          ElevatedButton(onPressed: () => pickImage((f) => selfie = f), child: Text('Pick selfie')),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: submitting ? null : () async {
              setState(() => submitting = true);
              try {
                await _kyc.submitKyc(
                  uid: uid,
                  type: widget.type,
                  licenseNumber: _license.text.trim(),
                  frontImage: front,
                  backImage: back,
                  selfie: selfie,
                );
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KYC submitted')));
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              } finally {
                setState(() => submitting = false);
              }
            },
            child: submitting ? CircularProgressIndicator() : Text('Submit KYC'),
          ),
        ]),
      ),
    );
  }
}
*/