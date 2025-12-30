/*
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math'; // Required for random room generation

class BookingService {
  // Singleton pattern for efficient resource usage
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------------------------------------------------------------------------
  // 1. SLOT VALIDATION (Client-Side Optimization)
  // ---------------------------------------------------------------------------

  /// Checks if a slot is valid and non-overlapping.
  Future<bool> isSlotAvailable({
    required String doctorId,
    required String patientId,
    required DateTime slotStart,
    required DateTime slotEnd,
  }) async {
    try {
      // Parallel execution for speed
      final results = await Future.wait([
        _checkConflict('patientId', patientId, slotStart, slotEnd),
        _checkConflict('doctorId', doctorId, slotStart, slotEnd),
      ]);

      // If either has a conflict (true), the slot is NOT available (return false)
      return !results.contains(true);
    } catch (e) {
      debugPrint('Slot check error: $e');
      return false; // Fail safe
    }
  }

  /// Helper to check conflicts in Firestore
  Future<bool> _checkConflict(
      String field, String id, DateTime start, DateTime end) async {
    final query = await _firestore
        .collection('appointments')
        .where(field, isEqualTo: id)
        .where('status', whereIn: ['scheduled', 'confirmed', 'ongoing'])
        .get();

    for (var doc in query.docs) {
      final data = doc.data();
      
      DateTime existingStart;
      if (data['dateTime'] != null) {
         existingStart = _parseDate(data['dateTime']);
      } else {
         existingStart = (data['slotStart'] as Timestamp).toDate();
      }
      
      final existingEnd = (data['slotEnd'] as Timestamp?)?.toDate() ?? 
                          existingStart.add(const Duration(minutes: 30));

      if (_hasTimeOverlap(start, end, existingStart, existingEnd)) {
        return true; // Conflict found
      }
    }
    return false;
  }

  bool _hasTimeOverlap(
      DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    if (end1.isBefore(start2) || end1.isAtSameMomentAs(start2)) return false;
    if (end2.isBefore(start1) || end2.isAtSameMomentAs(start1)) return false;
    return true;
  }

  DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.parse(val);
    return DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // 2. BOOKING ACTION (Cloud Function + Fallback)
  // ---------------------------------------------------------------------------

  /// Books appointment via Cloud Function.
  /// Falls back to direct Firestore write if function is missing.
  Future<String?> bookAppointment({
    required String doctorId,
    required String doctorName,
    required DateTime slotStart,
    DateTime? slotEnd,
    String? notes,
    String connectionType = 'jitsi',
    String? patientName, // Optional override
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final end = slotEnd ?? slotStart.add(const Duration(minutes: 30));
      final pName = patientName ?? user.displayName ?? 'Patient';

      // 1. Fast Client-Side Check
      final isAvailable = await isSlotAvailable(
        doctorId: doctorId,
        patientId: user.uid,
        slotStart: slotStart,
        slotEnd: end,
      );

      if (!isAvailable) {
        throw Exception('This time slot was just taken. Please choose another.');
      }

      // 2. Try Cloud Function First (Preferred)
      try {
        final HttpsCallable callable = _functions.httpsCallable('createAppointment');
        
        final result = await callable.call({
          'doctorId': doctorId,
          'doctorName': doctorName,
          'patientName': pName,
          'dateTime': slotStart.toIso8601String(),
          'notes': notes ?? '',
          'connectionType': connectionType,
        });

        final data = result.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['appointmentId'];
        }
        return null;

      } on FirebaseFunctionsException catch (e) {
        // ✅ CRITICAL FIX: Fallback if function is missing/error
        // Codes: not-found (function doesn't exist), unavailable (network/server down)
        if (e.code == 'not-found' || e.code == 'unavailable' || e.code == 'internal') {
          debugPrint("⚠️ Cloud Function failed (${e.code}), using direct fallback.");
          return _createAppointmentManually(
             doctorId: doctorId, 
             doctorName: doctorName, 
             patientId: user.uid, 
             patientName: pName,
             slotStart: slotStart, 
             connectionType: connectionType, 
             notes: notes
          );
        }
        rethrow; // Throw other errors (like auth issues) normally
      }

    } catch (e) {
      debugPrint("Booking Error: $e");
      throw Exception(e.toString());
    }
  }

  // ✅ Manual Fallback Method
  // Used when Cloud Function is not deployed or reachable
  Future<String> _createAppointmentManually({
    required String doctorId, 
    required String doctorName, 
    required String patientId,
    required String patientName, 
    required DateTime slotStart, 
    required String connectionType, 
    String? notes
  }) async {
    // Generate local Jitsi link as backup so video calls still work
    final roomId = "DocVartaa_${Random().nextInt(999999)}_${DateTime.now().millisecondsSinceEpoch}";
    final meetLink = "https://meet.jit.si/$roomId";
    
    // Fetch Doctor Phone (Best effort for WhatsApp)
    String doctorPhone = '';
    try {
      final doc = await _firestore.collection('users').doc(doctorId).get();
      doctorPhone = doc.data()?['whatsappNumber'] ?? doc.data()?['phone'] ?? '';
    } catch (_) {
      debugPrint("Could not fetch doctor phone for manual booking");
    }

    final apptRef = await _firestore.collection('appointments').add({
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'doctorName': doctorName,
      'doctorPhone': doctorPhone,
      'dateTime': slotStart.toIso8601String(), // Store as string to match CF format
      'slotStart': Timestamp.fromDate(slotStart), // Store as timestamp for queries
      'meetLink': meetLink,
      'meetingRoomId': roomId,
      'connectionType': connectionType,
      'notes': notes ?? '',
      'status': 'confirmed', // Auto-confirm since manual
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'fallback', // Mark as fallback for debugging
    });
    
    return apptRef.id;
  }

  // ---------------------------------------------------------------------------
  // 3. EMERGENCY FEATURE
  // ---------------------------------------------------------------------------
  Future<int> triggerEmergency() async {
    try {
      if (_auth.currentUser == null) throw Exception("Login required");

      final HttpsCallable callable = _functions.httpsCallable('triggerEmergency');
      final result = await callable.call();

      return result.data['notified'] ?? 0;
    } catch (e) {
      debugPrint("Emergency Trigger Error: $e");
      throw Exception("Failed to send emergency alert");
    }
  }

  // ---------------------------------------------------------------------------
  // 4. MANAGEMENT METHODS
  // ---------------------------------------------------------------------------
  Future<bool> cancelAppointment(String appointmentId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
      });
      return true;
    } catch (e) {
      debugPrint('Error cancelling: $e');
      return false;
    }
  }
}
*/

// lib/screens/booking_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added for fetching doctor phone
import '../services/booking_service.dart';

class BookingScreen extends StatefulWidget {
  final String patientId;
  final String doctorId;
  final String doctorName;

  const BookingScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
    this.doctorName = 'Doctor',
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? _selectedDateTime;
  String _connectionType = 'jitsi';
  bool _isLoading = false;
  String? _doctorPhone; // ✅ Store doctor's phone number

  final BookingService _bookingService = BookingService();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDoctorDetails(); // ✅ Fetch phone on init
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ✅ Fetch Doctor's WhatsApp Number
  Future<void> _fetchDoctorDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doctorId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _doctorPhone =
              data?['whatsappNumber'] ?? data?['phone'] ?? 'Not Available';
        });
      }
    } catch (e) {
      debugPrint("Error fetching doctor details: $e");
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour + 1, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submitBooking() async {
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an appointment time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notePrefix = _connectionType == 'whatsapp'
          ? '[WHATSAPP]'
          : _connectionType == 'in_app'
          ? '[APP CALL]'
          : '[VIDEO LINK]';

      final fullNotes = "$notePrefix ${_notesController.text.trim()}";

      final slotEnd = _selectedDateTime!.add(const Duration(minutes: 30));
      final appointmentId = await _bookingService.bookAppointment(
        doctorId: widget.doctorId,
        doctorName: widget.doctorName,
        slotStart: _selectedDateTime!,
        slotEnd: slotEnd,
        notes: fullNotes,
        connectionType: _connectionType,
      );

      if (!mounted) return;

      if (appointmentId != null) {
        final message = _connectionType == 'whatsapp'
            ? 'Booking Confirmed! Check WhatsApp for updates.'
            : _connectionType == 'in_app'
            ? 'Booking Confirmed! Join via App at time.'
            : 'Video Link Generated! Check Appointments.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, MMM d • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text('Book with ${widget.doctorName}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Date & Time Selection
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.blue),
                ),
                title: Text(
                  _selectedDateTime == null
                      ? 'Select Appointment Time'
                      : fmt.format(_selectedDateTime!),
                  style: TextStyle(
                    fontWeight: _selectedDateTime == null
                        ? FontWeight.normal
                        : FontWeight.bold,
                    color: _selectedDateTime == null
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                subtitle: _selectedDateTime != null
                    ? const Text('30 Minute Session')
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _pickDateTime,
              ),
            ),

            const SizedBox(height: 20),

            // 2. Platform/Mode Selection
            const Text(
              'How do you want to connect?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildOption(
              value: 'jitsi',
              icon: Icons.link,
              title: 'Video Link (No App Needed)',
              subtitle: 'Receive a secure link to join via browser.',
            ),
            const SizedBox(height: 12),
            _buildOption(
              value: 'whatsapp',
              icon: Icons.chat,
              title: 'WhatsApp',
              subtitle: 'Doctor will contact you on WhatsApp.',
            ),

            // ✅ WhatsApp Specific Message
            if (_connectionType == 'whatsapp')
              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Doctor ${widget.doctorName} will contact with this whatsapp number ${_doctorPhone ?? '...'} with slot details.",
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),
            _buildOption(
              value: 'in_app',
              icon: Icons.videocam,
              title: 'In-App Video Call',
              subtitle: 'High quality video call within this app.',
            ),

            const SizedBox(height: 20),

            // 3. Notes
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes for Doctor (Optional)',
                hintText: 'Briefly describe your symptoms...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 32),

            // 4. Submit Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirm Booking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Helper Text for Jitsi
            if (_connectionType == 'jitsi')
              const Center(
                child: Text(
                  'ℹ️ A secure video link will be generated automatically.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _connectionType == value;
    return GestureDetector(
      onTap: () => setState(() => _connectionType = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
