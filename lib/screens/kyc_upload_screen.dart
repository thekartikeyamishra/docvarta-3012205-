// G:\docvartaa\lib/screens/kyc_upload_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/kyc_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KycUploadScreen extends StatefulWidget {
  const KycUploadScreen({super.key});

  @override
  State<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends State<KycUploadScreen> {
  final _picker = ImagePicker();
  final KycService _kycService = KycService();
  final _auth = FirebaseAuth.instance;
  bool _uploading = false;
  double _progress = 0.0;
  List<Map<String, dynamic>> _existingFiles = [];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final uid = _auth.currentUser!.uid;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    final files = ((data?['doctorProfile'] ?? {})['kycFiles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    setState(() => _existingFiles = files);
  }

  Future<void> _pickAndUpload() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
    // You can also allow gallery or pdf picking via file_picker package
    if (picked == null) return;

    final file = File(picked.path);
    final filename = picked.name;

    setState(() {
      _uploading = true;
      _progress = 0.0;
    });

    try {
      final result = await _kycService.uploadKycFile(file, filename: filename, onProgress: (p) {
        setState(() => _progress = p);
      });

      await _kycService.saveKycMeta(downloadUrl: result['downloadUrl']!, storagePath: result['path']!, filename: result['name']!);
      await _loadExisting();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KYC uploaded and saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
        _uploading = false;
        _progress = 0.0;
      });
      }
    }
  }

  Future<void> _submitForReview() async {
    final uid = _auth.currentUser!.uid;
    // If you want a dedicated field to indicate request for review, set it:
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'doctorProfile': {'kycPending': true}
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for review')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload KYC (Doctor)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Upload your medical license or government ID. Take a clear photo or upload a PDF.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _uploading ? null : _pickAndUpload, icon: const Icon(Icons.camera_alt), label: const Text('Capture document')),
            const SizedBox(height: 12),
            if (_uploading)
              Column(children: [
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 6),
                Text('${(_progress * 100).toStringAsFixed(0)}%'),
              ]),
            const SizedBox(height: 12),
            const Text('Uploaded files:'),
            Expanded(
              child: ListView.builder(
                itemCount: _existingFiles.length,
                itemBuilder: (context, i) {
                  final f = _existingFiles[i];
                  return ListTile(
                    title: Text(f['name'] ?? 'Document'),
                    subtitle: Text(f['status'] ?? 'pending'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () {
                          final url = f['url'] as String?;
                          if (url != null) {
                            // open url using url_launcher in real app
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          // allow owner to delete; uses KycService.deleteKycFile (owner permitted)
                          await _kycService.deleteKycFile(doctorUid: _auth.currentUser!.uid, storagePath: f['storagePath']);
                          await _loadExisting();
                        },
                      ),
                    ]),
                  );
                },
              ),
            ),
            ElevatedButton(onPressed: _submitForReview, child: const Text('Submit for review')),
          ],
        ),
      ),
    );
  }
}
