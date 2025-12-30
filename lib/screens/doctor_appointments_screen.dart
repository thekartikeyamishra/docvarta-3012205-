// lib/screens/doctor_appointments_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Required for Jitsi
import '../widgets/custom_card.dart';

class DoctorAppointmentsScreen extends StatelessWidget {
  const DoctorAppointmentsScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _appointmentsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true) // Show newest first
        .limit(50)
        .snapshots();
  }

  // ✅ FIX: Universal Link Launcher (Jitsi Optimized)
  Future<void> _launchMeeting(BuildContext context, String url, String apptId) async {
    if (url.isEmpty) return;
    try {
      // 1. Mark as Ongoing (Triggers "Live Now" on Patient Side)
      await FirebaseFirestore.instance.collection('appointments').doc(apptId).update({'status': 'ongoing'});
      
      // 2. Launch Jitsi in External Browser
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Helper to complete appointment
  Future<void> _markComplete(String apptId) async {
    await FirebaseFirestore.instance.collection('appointments').doc(apptId).update({'status': 'completed'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _appointmentsStream(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('No appointments yet'));

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data();
                final apptId = d.id;
                
                final patientName = data['patientName'] ?? 'Patient';
                final status = data['status'] ?? 'pending';
                final meetLink = data['meetLink'] as String?;
                final isVideo = meetLink != null && meetLink.isNotEmpty;

                // Robust Date Parsing
                DateTime? slotDate;
                if (data['dateTime'] is String) {
                  slotDate = DateTime.tryParse(data['dateTime']);
                } else if (data['slotStart'] is Timestamp) {
                  slotDate = (data['slotStart'] as Timestamp).toDate();
                }
                
                final dateStr = slotDate != null 
                    ? DateFormat('MMM d, h:mm a').format(slotDate) 
                    : 'Date Pending';

                return CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isVideo ? Icons.videocam : Icons.location_on, 
                                      size: 14, 
                                      color: Colors.grey
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$dateStr • ${isVideo ? 'Video' : 'Clinic'}", 
                                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _statusChip(status),
                        ],
                      ),
                      
                      // Notes Section (If available)
                      if (data['notes'] != null && (data['notes'] as String).isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Note: ${data['notes']}",
                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Details Button
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed(
                              '/appointment-details', // Ensure this route exists in main.dart
                              arguments: {'appointmentId': apptId} // Pass as Map
                            ),
                            child: const Text('Details'),
                          ),
                          
                          const SizedBox(width: 8),

                          // Primary Actions based on Status
                          if (status == 'scheduled' || status == 'confirmed' || status == 'ongoing') ...[
                            if (isVideo)
                              ElevatedButton.icon(
                                onPressed: () => _launchMeeting(context, meetLink!, apptId),
                                icon: const Icon(Icons.video_call),
                                label: Text(status == 'ongoing' ? 'Rejoin' : 'Start Call'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            
                            const SizedBox(width: 8),
                            
                            // Mark Done Button
                            OutlinedButton(
                              onPressed: () => _markComplete(apptId),
                              child: const Text('Mark Done'),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'confirmed': color = Colors.green; break;
      case 'ongoing': color = Colors.blue; break;
      case 'completed': color = Colors.grey; break;
      case 'cancelled': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}