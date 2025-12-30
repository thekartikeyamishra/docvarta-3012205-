// lib/screens/book_slot_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BookSlotScreen extends StatefulWidget {
  const BookSlotScreen({super.key});

  @override
  State<BookSlotScreen> createState() => _BookSlotScreenState();
}

class _BookSlotScreenState extends State<BookSlotScreen> {
  DateTime? _selected;
  bool _loading = false;
  String? _error;
  String? _doctorId;

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is String) _doctorId = args;
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return;
    setState(() {
      _selected = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _book() async {
    if (_doctorId == null) return;
    if (_selected == null) {
      setState(() => _error = 'Select a date and time');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final slotTimestamp = Timestamp.fromDate(_selected!);
      final docRef = _fire.collection('appointments');

      // Check conflicts: if any appointment exists for same doctor and same slotStart (exact match)
      final q = await docRef
          .where('doctorId', isEqualTo: _doctorId)
          .where('slotStart', isEqualTo: slotTimestamp)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        setState(() => _error = 'Selected time is already booked for this doctor. Choose another slot.');
        return;
      }

      final patient = _auth.currentUser;
      if (patient == null) {
        setState(() => _error = 'You must be signed in to book.');
        return;
      }

      final appt = {
        'doctorId': _doctorId,
        'patientId': patient.uid,
        'patientName': patient.displayName ?? '',
        'slotStart': slotTimestamp,
        'status': 'booked',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.add(appt);

      // Optionally navigate to appointment detail or show confirmation
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment booked')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Booking failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a slot'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(children: [
            if (_doctorId != null) ...[
              Text('Booking with doctor id: $_doctorId', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),
            ],
            ListTile(
              title: const Text('Selected slot'),
              subtitle: Text(_selected == null ? 'No slot selected' : _selected!.toLocal().toString()),
              trailing: ElevatedButton(onPressed: _pickDateTime, child: const Text('Pick')),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _book,
              child: _loading ? const CircularProgressIndicator() : const Text('Confirm booking'),
            )
          ]),
        ),
      ),
    );
  }
}
