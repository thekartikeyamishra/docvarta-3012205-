// lib/services/transcript_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Service for managing call transcripts
/// Stores transcripts in Firestore and generates downloadable reports
class TranscriptService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Start a new transcript session for a call
  Future<String> createTranscript({
    required String appointmentId,
    required String doctorId,
    required String patientId,
    String? doctorName,
    String? patientName,
  }) async {
    final transcriptRef = _db.collection('transcripts').doc();
    
    await transcriptRef.set({
      'transcriptId': transcriptRef.id,
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'patientId': patientId,
      'doctorName': doctorName ?? 'Doctor',
      'patientName': patientName ?? 'Patient',
      'startTime': FieldValue.serverTimestamp(),
      'messages': [],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Transcript created: ${transcriptRef.id}');
    return transcriptRef.id;
  }

  /// Add a message to the transcript
  /// speaker: 'doctor' or 'patient'
  Future<void> addMessage({
    required String transcriptId,
    required String speaker,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;

    final messageData = {
      'speaker': speaker,
      'message': message.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _db.collection('transcripts').doc(transcriptId).update({
      'messages': FieldValue.arrayUnion([messageData]),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    debugPrint('📝 Message added to transcript by $speaker');
  }

  /// End the transcript session
  Future<void> endTranscript(String transcriptId) async {
    await _db.collection('transcripts').doc(transcriptId).update({
      'endTime': FieldValue.serverTimestamp(),
      'isActive': false,
    });
    debugPrint('✅ Transcript ended: $transcriptId');
  }

  /// Get transcript document
  Future<DocumentSnapshot<Map<String, dynamic>>> getTranscript(String transcriptId) {
    return _db.collection('transcripts').doc(transcriptId).get();
  }

  /// Get transcripts for an appointment
  Stream<QuerySnapshot<Map<String, dynamic>>> streamTranscriptsForAppointment(String appointmentId) {
    return _db
        .collection('transcripts')
        .where('appointmentId', isEqualTo: appointmentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get all transcripts for a user (doctor or patient)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserTranscripts({
    required String userId,
    required String role, // 'doctor' or 'patient'
  }) {
    final field = role == 'doctor' ? 'doctorId' : 'patientId';
    return _db
        .collection('transcripts')
        .where(field, isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Generate formatted transcript text
  String generateTranscriptText(Map<String, dynamic> transcriptData) {
    final StringBuffer buffer = StringBuffer();
    
    // Header
    buffer.writeln('═══════════════════════════════════════════════');
    buffer.writeln('          CONSULTATION TRANSCRIPT');
    buffer.writeln('═══════════════════════════════════════════════');
    buffer.writeln();
    
    // Metadata
    buffer.writeln('Doctor: ${transcriptData['doctorName'] ?? 'Unknown'}');
    buffer.writeln('Patient: ${transcriptData['patientName'] ?? 'Unknown'}');
    buffer.writeln('Appointment ID: ${transcriptData['appointmentId'] ?? 'N/A'}');
    
    final startTime = transcriptData['startTime'] as Timestamp?;
    final endTime = transcriptData['endTime'] as Timestamp?;
    
    if (startTime != null) {
      buffer.writeln('Start Time: ${_formatDateTime(startTime.toDate())}');
    }
    if (endTime != null) {
      buffer.writeln('End Time: ${_formatDateTime(endTime.toDate())}');
      if (startTime != null) {
        final duration = endTime.toDate().difference(startTime.toDate());
        buffer.writeln('Duration: ${_formatDuration(duration)}');
      }
    }
    
    buffer.writeln();
    buffer.writeln('───────────────────────────────────────────────');
    buffer.writeln('                  CONVERSATION');
    buffer.writeln('───────────────────────────────────────────────');
    buffer.writeln();
    
    // Messages
    final messages = transcriptData['messages'] as List<dynamic>? ?? [];
    
    if (messages.isEmpty) {
      buffer.writeln('[No messages recorded]');
    } else {
      for (var i = 0; i < messages.length; i++) {
        final msg = messages[i] as Map<String, dynamic>;
        final speaker = msg['speaker'] as String;
        final message = msg['message'] as String;
        final timestamp = msg['timestamp'] as Timestamp?;
        
        final speakerLabel = speaker == 'doctor' 
            ? 'Dr. ${transcriptData['doctorName']}'
            : transcriptData['patientName'];
        
        final time = timestamp != null 
            ? '[${_formatTime(timestamp.toDate())}]'
            : '';
        
        buffer.writeln('$time $speakerLabel:');
        buffer.writeln('  $message');
        buffer.writeln();
      }
    }
    
    buffer.writeln('═══════════════════════════════════════════════');
    buffer.writeln('           END OF TRANSCRIPT');
    buffer.writeln('═══════════════════════════════════════════════');
    
    return buffer.toString();
  }

  /// Save transcript to Firebase Storage and return download URL
  Future<String> saveTranscriptToStorage({
    required String transcriptId,
    required String transcriptText,
  }) async {
    final uid = _auth.currentUser!.uid;
    final path = 'transcripts/$uid/$transcriptId.txt';
    final ref = _storage.ref(path);
    
    final bytes = utf8.encode(transcriptText);
    final metadata = SettableMetadata(
      contentType: 'text/plain',
      customMetadata: {'transcriptId': transcriptId},
    );
    
    await ref.putData(Uint8List.fromList(bytes), metadata);
    final url = await ref.getDownloadURL();
    
    // Update transcript document with storage path
    await _db.collection('transcripts').doc(transcriptId).update({
      'storagePath': path,
      'downloadUrl': url,
    });
    
    debugPrint('✅ Transcript saved to storage: $path');
    return url;
  }

  /// Delete transcript
  Future<void> deleteTranscript(String transcriptId) async {
    final doc = await _db.collection('transcripts').doc(transcriptId).get();
    
    if (doc.exists) {
      final data = doc.data();
      final storagePath = data?['storagePath'] as String?;
      
      // Delete from storage if exists
      if (storagePath != null) {
        try {
          await _storage.ref(storagePath).delete();
        } catch (e) {
          debugPrint('⚠️ Could not delete storage file: $e');
        }
      }
      
      // Delete document
      await doc.reference.delete();
      debugPrint('✅ Transcript deleted: $transcriptId');
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}