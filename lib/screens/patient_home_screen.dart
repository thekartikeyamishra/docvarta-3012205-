// lib/screens/patient_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_service.dart';
import 'wallet_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // ✅ Services & State
  final EmergencyService _emergencyService = EmergencyService();
  bool _isProcessingEmergency = false;

  @override
  void initState() {
    super.initState();
    _checkForIncomingCalls();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🚨 EMERGENCY SOS LOGIC
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _triggerEmergency() async {
    // 1. Ask for Gender Preference
    final gender = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('Emergency Doctor Preference'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Any'), 
            child: const Row(children: [Icon(Icons.bolt, color: Colors.orange), SizedBox(width: 10), Text('Any Doctor (Fastest)')])
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Female'), 
            child: const Row(children: [Icon(Icons.female, color: Colors.pink), SizedBox(width: 10), Text('Female Doctor')])
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'Male'), 
            child: const Row(children: [Icon(Icons.male, color: Colors.blue), SizedBox(width: 10), Text('Male Doctor')])
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, null), 
                child: const Text('Cancel', style: TextStyle(color: Colors.red))
              ),
            ),
          ),
        ],
      ),
    );

    if (gender == null) return;

    setState(() => _isProcessingEmergency = true);

    // 2. Call Emergency Service
    final result = await _emergencyService.findAndBookEmergencyDoctor(preferredGender: gender);

    if (!mounted) return;
    setState(() => _isProcessingEmergency = false);

    if (result['success'] == true) {
       // 3a. Success - Navigate to Appointment Details
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(result['message']), backgroundColor: Colors.green)
       );
       Navigator.pushNamed(
         context, 
         '/appointment-details', 
         arguments: {'appointmentId': result['appointmentId']}
       );
    } else {
       // 3b. Failure or Wallet Issue
       if (result['errorType'] == 'wallet') {
         _showWalletDialog();
       } else {
         _showErrorDialog(result['message']);
       }
    }
  }

  /// Shows a dialog prompting the user to recharge their wallet
  void _showWalletDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Insufficient Wallet Balance'),
      content: const Text('Emergency consultation requires ₹500.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async { 
            Navigator.pop(ctx); 
            // Pass the required amount so WalletScreen triggers payment immediately
            final success = await Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const WalletScreen(rechargeAmount: 500.0))
            );
            
            // If returned with success, prompt retry
            if (success == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recharge successful! Tap "Connect Now" to try again.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                )
              );
            }
          }, 
          child: const Text('Add ₹500 & Connect')
        ),
      ],
    ));
  }

  void _showErrorDialog(String msg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Emergency Failed'),
      content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           📞 INCOMING CALL LISTENER
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _checkForIncomingCalls() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                // Ensure we don't show multiple dialogs
                if (Navigator.canPop(context)) { 
                  // Close existing dialogs if any (optional safety)
                }
                _showIncomingCallDialog(data, change.doc.id);
              }
            }
          }
        });
  }

  void _showIncomingCallDialog(Map<String, dynamic> callData, String callId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Incoming Video Call', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.green,
              child: Icon(Icons.videocam, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Dr. ${callData['callerName'] ?? 'Doctor'} is calling...', 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          FloatingActionButton(
            backgroundColor: Colors.red,
            onPressed: () {
              Navigator.pop(context);
              _firestore.collection('calls').doc(callId).update({'status': 'rejected'});
            },
            child: const Icon(Icons.call_end),
          ),
          FloatingActionButton(
            backgroundColor: Colors.green,
            onPressed: () {
              Navigator.pop(context);
              _firestore.collection('calls').doc(callId).update({'status': 'accepted'});
              Navigator.pushNamed(
                context,
                '/video-call',
                arguments: {
                  'callId': callData['roomId'] ?? callId,
                  'appointmentId': callData['appointmentId'],
                  'isDoctor': false,
                },
              );
            },
            child: const Icon(Icons.call),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🔐 LOGOUT & UTILS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await _auth.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           📱 BUILD UI
  // ═══════════════════════════════════════════════════════════════════════════
  
  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DocVartaa', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // ✅ Wallet Button
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            tooltip: 'Wallet',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/patient-profile'),
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('Please login'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 🚨 EMERGENCY SOS CARD
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Need Urgent Help?', 
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                                  ),
                                  Text('Find an emergency doctor instantly.', 
                                    style: TextStyle(color: Colors.white70, fontSize: 13)
                                  ),
                                ],
                              )
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'Consultation Fee: ₹500 for 30 mins', 
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessingEmergency ? null : _triggerEmergency,
                            icon: _isProcessingEmergency 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                              : const Icon(Icons.call, color: Colors.red),
                            label: Text(
                              _isProcessingEmergency ? ' FINDING DOCTOR...' : 'CONNECT NOW',
                              style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white, 
                              foregroundColor: Colors.red, 
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  // 🔎 SEARCH BAR
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, '/search-doctors'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(12), 
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))]
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey), 
                            const SizedBox(width: 12), 
                            Text('Search doctors, specialties...', 
                              style: TextStyle(color: Colors.grey[600], fontSize: 15)
                            )
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft, 
                      child: Text('My Appointments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                    ),
                  ),

                  // 📅 APPOINTMENTS LIST
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('appointments')
                        .where('patientId', isEqualTo: userId)
                        .orderBy('createdAt', descending: true)
                        .limit(5) 
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final appointments = snapshot.data?.docs ?? [];

                      if (appointments.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: const Column(
                            children: [
                              Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 48),
                              SizedBox(height: 12),
                              Text('No upcoming appointments', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final doc = appointments[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildAppointmentCard(data, doc.id);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data, String appointmentId) {
    final status = data['status'] ?? 'scheduled';
    final doctorName = data['doctorName'] ?? 'Doctor';
    final type = data['connectionType'] ?? 'jitsi';
    final meetLink = data['meetLink'] as String?;
    final roomId = data['meetingRoomId'] as String?; // Only for in_app calls (Emergency)
    
    DateTime? date;
    if (data['dateTime'] != null) {
       date = (data['dateTime'] is Timestamp) 
          ? (data['dateTime'] as Timestamp).toDate() 
          : DateTime.tryParse(data['dateTime'].toString());
    } else if (data['slotStart'] != null) {
       date = (data['slotStart'] as Timestamp).toDate();
    }

    final isOngoing = status == 'ongoing';
    final isConfirmed = status == 'confirmed';
    final canJoin = isConfirmed || isOngoing;

    Color statusColor;
    if (status == 'completed') statusColor = Colors.blue;
    else if (status == 'cancelled') statusColor = Colors.red;
    else statusColor = Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.medical_services, color: statusColor),
        ),
        title: Text('Dr. $doctorName', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (date != null) 
              Row(children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(DateFormat('MMM dd, hh:mm a').format(date), style: const TextStyle(fontSize: 12)),
              ]),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)
              ),
              child: Text(
                type == 'whatsapp' ? 'Wait for Call' : status.toUpperCase(), 
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)
              ),
            ),
          ],
        ),
        trailing: (canJoin && type != 'whatsapp') 
          ? ElevatedButton(
              onPressed: () {
                if (type == 'in_app' && roomId != null) {
                  // For Emergency / In-App Video
                  Navigator.pushNamed(
                    context, 
                    '/video-call', 
                    arguments: {'callId': roomId, 'appointmentId': appointmentId, 'isDoctor': false}
                  );
                } else if (meetLink != null) {
                  // For Standard Jitsi
                  _launchUrl(meetLink);
                }
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: isOngoing ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16)
              ),
              child: Text(isOngoing ? 'Join Now' : 'Join')
            )
          : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => Navigator.pushNamed(context, '/appointment-details', arguments: {'appointmentId': appointmentId}),
      ),
    );
  }
}