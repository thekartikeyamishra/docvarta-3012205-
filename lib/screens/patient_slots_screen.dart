// lib/screens/patient_slots_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart'; // Required for catching specific errors

import '../widgets/custom_card.dart';
import '../services/booking_service.dart';

class PatientSlotsScreen extends StatefulWidget {
  const PatientSlotsScreen({super.key});

  @override
  State<PatientSlotsScreen> createState() => _PatientSlotsScreenState();
}

class _PatientSlotsScreenState extends State<PatientSlotsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final BookingService _bookingService = BookingService();
  
  String? _uid;
  String? _targetDoctorId; // ✅ Filter variable
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ FIX 1: Get doctor ID from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _targetDoctorId = args;
    }
  }

  @override
  void initState() {
    super.initState();
    final u = _auth.currentUser;
    if (u != null) _uid = u.uid;
    if (mounted) setState(() => _loading = false);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _publishedSlotsStream() {
    // ✅ FIX 2: Strict Filtering
    Query<Map<String, dynamic>> query = _db.collection('slots_index');

    // If we opened this page for a specific doctor, ONLY show their slots
    if (_targetDoctorId != null) {
      query = query.where('doctorId', isEqualTo: _targetDoctorId);
    }

    return query
        .where('published', isEqualTo: true)
        .where('slotStart', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('slotStart')
        .snapshots();
  }

  Future<Map<String, dynamic>?> _fetchDoctor(String doctorId) async {
    try {
      final snap = await _db.collection('doctors').doc(doctorId).get();
      return snap.exists ? snap.data() : null;
    } catch (_) { return null; }
  }

  // ✅ FIX 3: Robust Booking with Fallback
  Future<void> _bookSlot(Map<String, dynamic> slotDoc, String doctorName) async {
    if (_uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in')));
      return;
    }

    // Ask Connection Type
    final connectionType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Connect via'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'jitsi'), child: const Text('Video Link (Browser)')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'whatsapp'), child: const Text('WhatsApp Call')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'in_app'), child: const Text('In-App Video')),
        ],
      ),
    );
    if (connectionType == null) return;

    setState(() => _loading = true);

    final slotId = slotDoc['slotId'];
    final doctorId = slotDoc['doctorId'];
    final slotStart = (slotDoc['slotStart'] as Timestamp).toDate();
    final slotEnd = (slotDoc['slotEnd'] as Timestamp).toDate();

    try {
      // Attempt to book via Service (Cloud Function)
      await _bookingService.bookAppointment(
        doctorId: doctorId,
        doctorName: doctorName, 
        slotStart: slotStart,
        slotEnd: slotEnd,
        notes: 'Booked via Slot',
        connectionType: connectionType,
      );

      await _finalizeSlot(doctorId, slotId);

    } catch (e) {
      // ✅ FALLBACK LOGIC
      // If Cloud Function fails (NOT_FOUND), write directly to Firestore
      String errorMsg = e.toString();
      if (errorMsg.contains('NOT_FOUND') || errorMsg.contains('unavailable')) {
        debugPrint("⚠️ Cloud Function unavailable. Using direct fallback.");
        await _fallbackDirectBooking(
          doctorId: doctorId,
          doctorName: doctorName,
          slotStart: slotStart,
          connectionType: connectionType,
        );
        await _finalizeSlot(doctorId, slotId); // Mark slot as taken
      } else {
        // Genuine error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $errorMsg'), backgroundColor: Colors.red));
          setState(() => _loading = false);
          return;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking Confirmed!'), backgroundColor: Colors.green)
      );
      Navigator.pop(context);
    }
  }

  // Helper: Mark slot as taken
  Future<void> _finalizeSlot(String doctorId, String slotId) async {
    final batch = _db.batch();
    batch.update(
      _db.collection('doctors').doc(doctorId).collection('slots').doc(slotId), 
      {'published': false}
    );
    batch.delete(_db.collection('slots_index').doc(slotId));
    await batch.commit();
  }

  // Helper: Direct Write Fallback
  Future<void> _fallbackDirectBooking({
    required String doctorId,
    required String doctorName,
    required DateTime slotStart,
    required String connectionType,
  }) async {
    // Fetch Doctor Phone for WhatsApp Fallback
    String doctorPhone = '';
    try {
       final doc = await _db.collection('users').doc(doctorId).get();
       doctorPhone = doc.data()?['whatsappNumber'] ?? '';
    } catch (_) {}

    // Generate local link
    final roomId = "DocVartaa_${DateTime.now().millisecondsSinceEpoch}";
    
    await _db.collection('appointments').add({
      'doctorId': doctorId,
      'patientId': _uid,
      'patientName': _auth.currentUser?.displayName ?? 'Patient',
      'doctorName': doctorName,
      'doctorPhone': doctorPhone,
      'dateTime': slotStart.toIso8601String(),
      'slotStart': Timestamp.fromDate(slotStart),
      'meetLink': "https://meet.jit.si/$roomId",
      'meetingRoomId': roomId,
      'connectionType': connectionType,
      'notes': 'Booked via Fallback',
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Widget _slotTile(Map<String, dynamic> s, Map<String, dynamic>? doctorData) {
    final start = (s['slotStart'] as Timestamp).toDate();
    final doctorName = doctorData?['displayName'] ?? 'Doctor';
    final specialization = doctorData?['specialization'] ?? '';

    return CustomCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Text(
            doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
          )
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doctorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(specialization, style: TextStyle(color: Colors.grey[700])),
            Text(DateFormat('MMM d, h:mm a').format(start), style: const TextStyle(color: Colors.blue)),
          ]),
        ),
        ElevatedButton(
          onPressed: () => _bookSlot(s, doctorName),
          child: const Text('Book'),
        )
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_targetDoctorId == null ? 'All Slots' : 'Available Slots')),
      body: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _publishedSlotsStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  String err = snap.error.toString();
                  if (err.contains('permission-denied')) {
                    return const Center(child: Text('Please log in.'));
                  }
                  return Center(child: Text('Error loading slots: $err'));
                }
                
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No slots available'));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final s = docs[i].data();
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchDoctor(s['doctorId']),
                      builder: (ctx, dsnap) {
                        if (!dsnap.hasData) return const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(height: 80, child: Center(child: LinearProgressIndicator())),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _slotTile(s, dsnap.data),
                        );
                      },
                    );
                  },
                );
              },
            ),
            if (_loading)
              Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator()))
          ],
        ),
      ),
    );
  }
}