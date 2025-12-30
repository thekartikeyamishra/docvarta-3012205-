import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? doctorId;
  bool _startingCall = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is String) doctorId = args;
  }

  Future<void> _toggleAvailability(bool v) async {
    if (doctorId == null) return;
    await _fire.collection('doctors').doc(doctorId).set({'available': v}, SetOptions(merge: true));
  }

  // Unified start call logic
  void _startCallAsDoctor() {
    setState(() => _startingCall = true);
    // In a real flow, this should create a call room via WebRTC service
    // For now, we simulate starting by navigating to appointments
    Navigator.of(context).pushNamed('/doctorAppointments');
    setState(() => _startingCall = false);
  }

  @override
  Widget build(BuildContext context) {
    if (doctorId == null) {
      return const Scaffold(body: Center(child: Text('No doctor selected')));
    }
    final docRef = _fire.collection('doctors').doc(doctorId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: docRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            
            final data = snap.data!.data() as Map<String, dynamic>? ?? {};
            final displayName = data['displayName'] ?? 'Doctor';
            final specialization = data['specialization'] ?? '';
            final city = data['city'] ?? '';
            final verified = data['kycVerified'] == true;
            final available = data['available'] == true;
            final license = data['licenseNumber'] ?? '-';
            final ownerUid = snap.data!.id;
            final isOwner = _auth.currentUser?.uid == ownerUid;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 36, child: Text((displayName as String).isNotEmpty ? displayName[0].toUpperCase() : 'D')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(displayName.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('$specialization • $city'),
                    ]),
                  ),
                  if (verified)
                    const Column(children: [Icon(Icons.verified, color: Colors.blue), Text('Verified', style: TextStyle(fontSize: 12))]),
                ]),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('License: $license'),
                      Text('Availability: ${available ? 'Available' : 'Not available'}'),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                // Actions
                if (isOwner)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startingCall ? null : _startCallAsDoctor,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Manage Schedule'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Active'),
                      Switch(
                        value: available,
                        onChanged: (v) => _toggleAvailability(v),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Correctly route to booking screen with arguments
                        // Use a map if PatientSlotsScreen expects arguments, or just route name if it fetches by itself
                        // Assuming PatientSlotsScreen displays ALL slots, but we want to filter for this doctor.
                        // For Phase 2 simplicity, we route to slots list.
                        Navigator.pushNamed(context, '/bookSlot', arguments: doctorId);
                      },
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Book Appointment'),
                    ),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}