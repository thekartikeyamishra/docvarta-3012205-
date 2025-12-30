// G:\docvartaa\lib\screens\doctor_analytics_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DoctorAnalyticsScreen extends StatefulWidget {
  const DoctorAnalyticsScreen({super.key});

  @override
  State<DoctorAnalyticsScreen> createState() => _DoctorAnalyticsScreenState();
}

class _DoctorAnalyticsScreenState extends State<DoctorAnalyticsScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  Future<Map<String, dynamic>> _computeAnalytics() async {
    // total appointments
    final apptSnap = await _db.collection('appointments').where('doctorId', isEqualTo: _uid).get();
    final total = apptSnap.size;
    final completed = apptSnap.docs.where((d) => (d.data()['status'] ?? '') == 'completed').length;

    // completed calls durations: in calls collection we expect started/ended timestamps
    final callsSnap = await _db.collection('calls').where('doctorId', isEqualTo: _uid).where('isActive', isEqualTo: false).get();
    int callCount = 0;
    int totalSeconds = 0;
    for (final doc in callsSnap.docs) {
      final d = doc.data();
      final createdAt = d['createdAt'] as Timestamp?;
      final endedAt = d['endedAt'] as Timestamp?;
      if (createdAt != null && endedAt != null) {
        final seconds = endedAt.toDate().difference(createdAt.toDate()).inSeconds;
        totalSeconds += seconds;
        callCount++;
      }
    }

    final avgDurationSeconds = callCount > 0 ? (totalSeconds ~/ callCount) : 0;

    return {
      'totalAppointments': total,
      'completedAppointments': completed,
      'callCount': callCount,
      'avgDurationSeconds': avgDurationSeconds,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _computeAnalytics(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final data = snap.data!;
            final avgDur = data['avgDurationSeconds'] as int;
            final avgMinutes = (avgDur ~/ 60);
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Card(child: ListTile(title: const Text('Total appointments'), trailing: Text('${data['totalAppointments']}'))),
                const SizedBox(height: 8),
                Card(child: ListTile(title: const Text('Completed appointments'), trailing: Text('${data['completedAppointments']}'))),
                const SizedBox(height: 8),
                Card(child: ListTile(title: const Text('Total completed calls'), trailing: Text('${data['callCount']}'))),
                const SizedBox(height: 8),
                Card(child: ListTile(title: const Text('Average call duration'), trailing: Text('$avgMinutes min'))),
              ]),
            );
          },
        ),
      ),
    );
  }
}
