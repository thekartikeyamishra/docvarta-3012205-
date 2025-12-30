// lib/screens/doctor_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'doctor_wallet_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _saveFcmToken(); // ✅ Save Token for Emergency Alerts
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🔔 NOTIFICATIONS & SETUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Saves the FCM Token to Firestore so the backend can send Emergency Alerts
  Future<void> _saveFcmToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Request Permission
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get Token
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(uid).update({
            'fcmToken': token,
          });
        }
      }
    } catch (e) {
      debugPrint("Error saving FCM Token: $e");
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🔐 LOGOUT FUNCTION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await _auth.signOut();
      // AuthWrapper in main.dart will automatically redirect
    }
  }

  // ✅ Helper to open Jitsi/External links
  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           📑 APPOINTMENTS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAppointmentsTab() {
    final doctorId = _auth.currentUser?.uid;
    if (doctorId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true) // Show newest first
          .limit(20)
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No appointments yet'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Create Schedule'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final doc = appointments[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildAppointmentCard(data, doc.id);
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(
    Map<String, dynamic> data,
    String appointmentId,
  ) {
    final patientName = data['patientName'] ?? 'Patient';
    final status = data['status'] ?? 'pending';
    final type = data['connectionType'] ?? 'jitsi';
    final meetLink = data['meetLink'] as String?;
    final roomId = data['meetingRoomId'] as String?;
    final notes = data['notes'] as String?; // Check for SOS notes

    // Check if Emergency
    final isEmergency = notes != null && notes.contains('EMERGENCY');

    // Date Parsing
    DateTime? slotStart;
    if (data['dateTime'] != null) {
      // Handle both Timestamp and String
      if (data['dateTime'] is Timestamp) {
        slotStart = (data['dateTime'] as Timestamp).toDate();
      } else {
        slotStart = DateTime.tryParse(data['dateTime'].toString());
      }
    } else if (data['slotStart'] != null) {
      slotStart = (data['slotStart'] as Timestamp).toDate();
    }

    // ✅ DYNAMIC DOCTOR ACTIONS
    Widget actionButton;

    if (type == 'whatsapp') {
      actionButton = OutlinedButton.icon(
        icon: const Icon(Icons.chat),
        label: const Text('Wait for WhatsApp'),
        onPressed: null,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
      );
    } else if (type == 'in_app') {
      actionButton = ElevatedButton.icon(
        icon: const Icon(Icons.videocam),
        label: Text(isEmergency ? 'JOIN EMERGENCY' : 'Start Call'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEmergency ? Colors.red : Colors.blue,
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.pushNamed(
          context,
          '/video-call',
          arguments: {
            'callId': roomId,
            'appointmentId': appointmentId,
            'isDoctor': true,
          },
        ),
      );
    } else {
      actionButton = ElevatedButton.icon(
        icon: const Icon(Icons.link),
        label: const Text('Start Link Call'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        onPressed: () => _launchUrl(meetLink ?? ''),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isEmergency ? Colors.red.shade50 : null, // Highlight Emergency
      shape: isEmergency
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.red, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEmergency)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'EMERGENCY SOS',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (slotStart != null)
                        Text(
                          DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(slotStart),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusChip(status),
                    const SizedBox(height: 4),
                    Text(
                      type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/appointment-details',
                      arguments: {'appointmentId': appointmentId},
                    );
                  },
                  child: const Text('Details'),
                ),
                const SizedBox(width: 8),
                if (status == 'confirmed' ||
                    status == 'ongoing' ||
                    status == 'pending')
                  actionButton,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
        color = Colors.green;
        break;
      case 'ongoing':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.schedule, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Manage Your Schedule',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create time slots for patient appointments',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/doctor-schedule');
              },
              icon: const Icon(Icons.add_circle),
              label: const Text('Open Schedule Manager'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = _auth.currentUser;
    final userId = user?.uid;

    if (userId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('doctors').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final displayName =
            data['displayName'] ?? user?.displayName ?? 'Doctor';
        final specialization = data['specialization'] ?? '';
        final city = data['city'] ?? '';
        final kycVerified = data['kycVerified'] == true;
        final available = data['available'] == true;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue[100],
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$specialization${city.isNotEmpty ? ' • $city' : ''}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              if (kycVerified)
                Chip(
                  label: const Text('Verified'),
                  backgroundColor: Colors.green[100],
                  avatar: const Icon(
                    Icons.verified,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Available for Appointments'),
                        subtitle: Text(
                          available
                              ? 'Patients can book appointments'
                              : 'Not accepting new appointments',
                        ),
                        value: available,
                        onChanged: (value) {
                          _firestore.collection('doctors').doc(userId).update({
                            'available': value,
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/doctor-profile',
                    arguments: userId,
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Manage Schedule'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushNamed(context, '/doctor-schedule');
                },
              ),

              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('Earnings & Wallet'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DoctorWalletScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      _buildAppointmentsTab(),
      _buildScheduleTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          // ✅ Wallet Button
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'My Earnings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoctorWalletScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
