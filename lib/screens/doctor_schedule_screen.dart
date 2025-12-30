// G:\docvartaa\lib\screens\doctor_schedule_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late final String _uid;
  bool _loading = true;

  // slot creation controllers
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _durationCtrl = TextEditingController(text: '30'); // minutes

  @override
  void initState() {
    super.initState();
    final u = _auth.currentUser;
    if (u == null) throw Exception('Not authenticated');
    _uid = u.uid;
    _loading = false;
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _createSlot() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose date and time')));
      return;
    }
    final minutes = int.tryParse(_durationCtrl.text) ?? 30;
    final slotStart = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
    final slotEnd = slotStart.add(Duration(minutes: minutes));

    // slot doc in doctors/{uid}/slots
    final slotRef = _db.collection('doctors').doc(_uid).collection('slots').doc();
    await slotRef.set({
      'slotId': slotRef.id,
      'doctorId': _uid,
      'slotStart': Timestamp.fromDate(slotStart),
      'slotEnd': Timestamp.fromDate(slotEnd),
      'durationMinutes': minutes,
      'published': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // optional: create a lightweight index doc in root slots collection for search across doctors (if needed)
    await _db.collection('slots_index').doc(slotRef.id).set({
      'slotId': slotRef.id,
      'doctorId': _uid,
      'slotStart': Timestamp.fromDate(slotStart),
      'slotEnd': Timestamp.fromDate(slotEnd),
      'published': true,
    });

    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _durationCtrl.text = '30';
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot published')));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _slotsStream() {
    return _db.collection('doctors').doc(_uid).collection('slots').orderBy('slotStart').snapshots();
  }

  Future<void> _togglePublish(String slotId, bool current) async {
    await _db.collection('doctors').doc(_uid).collection('slots').doc(slotId).update({'published': !current});
    await _db.collection('slots_index').doc(slotId).update({'published': !current});
  }

  Future<void> _deleteSlot(String slotId) async {
    await _db.collection('doctors').doc(_uid).collection('slots').doc(slotId).delete();
    await _db.collection('slots_index').doc(slotId).delete();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule & Slots')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            CustomCard(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Create a slot', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(_selectedDate == null ? 'Select date' : DateFormat.yMMMd().format(_selectedDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTime,
                      child: Text(_selectedTime == null ? 'Select time' : _selectedTime!.format(context)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextFormField(controller: _durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)')),
                const SizedBox(height: 8),
                PrimaryButton(label: 'Publish slot', onPressed: _createSlot),
              ]),
            ),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Your slots', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _slotsStream(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text('No slots yet'));
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final m = d.data();
                      final slotStart = (m['slotStart'] as Timestamp).toDate();
                      final slotEnd = (m['slotEnd'] as Timestamp).toDate();
                      final published = m['published'] == true;
                      final slotId = d.id;
                      return CustomCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(DateFormat.yMMMEd().add_jm().format(slotStart), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('Duration: ${m['durationMinutes'] ?? 30} minutes'),
                            const SizedBox(height: 6),
                            Text(published ? 'Published' : 'Unpublished', style: TextStyle(color: published ? Colors.green : Colors.orange)),
                          ])),
                          Column(children: [
                            ElevatedButton(onPressed: () => _togglePublish(slotId, published), child: Text(published ? 'Unpublish' : 'Publish')),
                            TextButton(onPressed: () => _deleteSlot(slotId), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ])
                        ]),
                      );
                    },
                  );
                },
              ),
            )
          ]),
        ),
      ),
    );
  }
}
