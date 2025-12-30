// lib/screens/patient_appointments_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Required for Jitsi/WhatsApp
import '../widgets/primary_button.dart';
import '../widgets/custom_card.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  State<PatientAppointmentsScreen> createState() => _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  // Track active dialog to prevent stacking
  String? _activeCallDialogApptId;

  // ✅ Robust Date Parser
  DateTime? _parseDateTime(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  // ✅ Launch External Links (WhatsApp / Jitsi)
  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Link is empty')),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(url);
      // Force external application (Browser or WhatsApp App)
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ Join In-App WebRTC Call
  void _joinInAppCall(String callId, String apptId) {
    Navigator.pushNamed(
      context,
      '/video-call',
      arguments: {
        'callId': callId,
        'appointmentId': apptId,
        'isDoctor': false,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Please log in to view appointments.")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          // 1. Error Handling
          if (snap.hasError) {
             if (snap.error.toString().contains('permission-denied')) {
               return const Center(child: CircularProgressIndicator());
             }
             return Center(child: Text('Error: ${snap.error}'));
          }
          
          // 2. Loading State
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          
          // Check for incoming calls (Post-frame)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkForIncomingCalls(docs);
          });

          // 3. Empty State
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No appointments found.'),
                ],
              ),
            );
          }

          // 4. List
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final status = (data['status'] ?? 'pending') as String;
              final connectionType = (data['connectionType'] ?? 'jitsi') as String;
              final meetLink = data['meetLink'] as String?;
              final doctorPhone = data['doctorPhone'] as String?;
              final roomId = data['meetingRoomId'] as String?;
              
              final dateObj = _parseDateTime(data['dateTime'] ?? data['slotStart']);
              final dateStr = dateObj != null 
                  ? DateFormat('MMM d, y • h:mm a').format(dateObj) 
                  : 'Date Pending';
                  
              final isOngoing = status == 'ongoing';
              
              // Logic: Allow join if confirmed OR ongoing
              final canJoin = (status == 'confirmed' || isOngoing);

              // 🌟 DYNAMIC BUTTON LOGIC
              Widget actionButton;
              
              if (connectionType == 'whatsapp') {
                actionButton = PrimaryButton(
                  label: 'Chat on WhatsApp',
                  icon: Icons.chat,
                  onPressed: canJoin && doctorPhone != null
                      ? () => _launchUrl("https://wa.me/${doctorPhone.replaceAll(RegExp(r'\D'), '')}")
                      : null,
                );
              } else if (connectionType == 'in_app') {
                actionButton = PrimaryButton(
                  label: isOngoing ? 'Join Call Now' : 'Enter Waiting Room',
                  icon: Icons.videocam,
                  onPressed: canJoin && roomId != null
                      ? () => _joinInAppCall(roomId, docs[i].id)
                      : null,
                );
              } else {
                // Default: Jitsi / Video Link
                actionButton = PrimaryButton(
                  label: isOngoing ? 'Join Call Now' : 'Open Video Link',
                  icon: Icons.video_camera_front,
                  onPressed: canJoin && meetLink != null
                      ? () => _launchUrl(meetLink)
                      : null,
                );
              }

              return CustomCard(
                color: isOngoing ? Colors.green.shade50 : null,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Badge
                    if (isOngoing)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('LIVE NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Dr. ${data['doctorName'] ?? 'Specialist'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(dateStr, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                              const SizedBox(height: 4),
                              // Connection Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text(
                                  _formatConnectionType(connectionType),
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: _getStatusColor(status))),
                          backgroundColor: _getStatusColor(status).withOpacity(0.1),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 16),

                    // Dynamic Action Button
                    SizedBox(width: double.infinity, child: actionButton),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ✅ Smart Incoming Call Monitor
  void _checkForIncomingCalls(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    try {
      // Find an ongoing call
      final ongoingCall = docs.firstWhere(
        (d) => d.data()['status'] == 'ongoing',
        orElse: () => docs.firstWhere((d) => false, orElse: () => docs.first), 
      );
      
      // If no call found, reset dialog state
      if (!ongoingCall.exists || ongoingCall.data()['status'] != 'ongoing') {
        _activeCallDialogApptId = null;
        return;
      }

      final apptId = ongoingCall.id;
      final data = ongoingCall.data();
      final type = data['connectionType'] ?? 'jitsi';
      final meetLink = data['meetLink'] as String?;
      final roomId = data['meetingRoomId'] as String?;

      // Show dialog only if not already showing
      if (_activeCallDialogApptId != apptId) {
        _activeCallDialogApptId = apptId;
        
        // Don't show incoming call dialog for WhatsApp (it happens externally)
        if (type == 'whatsapp') return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.ring_volume, color: Colors.green, size: 28), SizedBox(width: 12), Text('Incoming Call')]),
            content: const Text('Your doctor has started the consultation.\nJoin the call now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text('Later', style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.video_call),
                label: const Text('Join Now'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () { 
                  Navigator.pop(ctx);
                  // Smart Join Logic
                  if (type == 'in_app' && roomId != null) {
                    _joinInAppCall(roomId, apptId);
                  } else if (meetLink != null) {
                    _launchUrl(meetLink); 
                  }
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking calls: $e");
    }
  }

  String _formatConnectionType(String type) {
    switch (type) {
      case 'whatsapp': return 'WhatsApp Call';
      case 'in_app': return 'In-App Video';
      case 'jitsi': return 'Secure Link';
      default: return 'Video Call';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'ongoing': return Colors.blue;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }
}