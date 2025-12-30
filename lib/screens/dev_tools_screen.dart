// lib/screens/dev_tools_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DevToolsScreen extends StatefulWidget {
  const DevToolsScreen({super.key});

  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String _status = '';

  void _log(String msg) => setState(() => _status = msg);

  // ---------------- PATIENT TOOLS ----------------
  Future<void> _addMockMoney(double amount) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return _log("Not logged in");

    await _db.collection('users').doc(uid).set({
      'walletBalance': FieldValue.increment(amount)
    }, SetOptions(merge: true));
    
    // Log fake transaction
    await _db.collection('transactions').add({
      'userId': uid,
      'amount': amount,
      'type': 'credit',
      'source': 'DEV_TOOLS',
      'paymentId': 'TEST_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': FieldValue.serverTimestamp(),
      'description': 'Developer Mock Credit',
      'status': 'success'
    });

    _log("Added ₹$amount to Wallet");
  }

  Future<void> _resetWallet() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'walletBalance': 0});
    _log("Wallet reset to ₹0");
  }

  // ---------------- DOCTOR TOOLS ----------------
  Future<void> _verifyMeAsDoctor() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('doctors').doc(uid).update({
      'kycVerified': true,
      'available': true,
    });
    _log("You are now VERIFIED & AVAILABLE");
  }

  // ---------------- ADMIN TOOLS (Simulated) ----------------
  Future<void> _approveAllWithdrawals() async {
    final snaps = await _db.collection('withdrawals')
        .where('status', isEqualTo: 'pending')
        .get();
    
    int count = 0;
    final batch = _db.batch();
    
    for (var doc in snaps.docs) {
      batch.update(doc.reference, {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
        'adminNote': 'Auto-approved via DevTools'
      });
      count++;
    }
    
    await batch.commit();
    _log("Approved $count pending withdrawal requests");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Developer Tools 🛠️'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.redAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.amber,
              margin: const EdgeInsets.only(bottom: 20),
              child: Text(_status, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),

          const _SectionHeader('Patient Tools (Test Wallet)'),
          _DevButton(
            label: 'Add ₹500 (Min Balance)',
            color: Colors.green,
            onTap: () => _addMockMoney(500),
          ),
          _DevButton(
            label: 'Add ₹5000 (Rich Patient)',
            color: Colors.green,
            onTap: () => _addMockMoney(5000),
          ),
          _DevButton(
            label: 'Reset Wallet to ₹0',
            color: Colors.red,
            onTap: _resetWallet,
          ),

          const SizedBox(height: 30),
          const _SectionHeader('Doctor Tools (Bypass Admin)'),
          _DevButton(
            label: 'Verify Me (KYC = true)',
            color: Colors.blue,
            onTap: _verifyMeAsDoctor,
          ),
          
          const SizedBox(height: 30),
          const _SectionHeader('Admin Simulation'),
          _DevButton(
            label: 'Approve Pending Withdrawals',
            color: Colors.orange,
            onTap: _approveAllWithdrawals,
          ),
          
          const SizedBox(height: 30),
          const Text(
            '⚠️ REMOVE THIS SCREEN BEFORE PRODUCTION', 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.white38)
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }
}

class _DevButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DevButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 16)
        ),
        child: Text(label),
      ),
    );
  }
}