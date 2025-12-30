// lib/services/transcript_service_realtime.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'dart:developer' as developer;

/// Real-time transcript service with speaker identification
class TranscriptServiceRealtime {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  bool _isListening = false;
  String? _currentTranscriptId;
  String? _currentSpeaker;
  List<TranscriptEntry> _entries = [];
  Timer? _saveTimer;

  bool get isListening => _isListening;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    try {
      final available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      
      if (available) {
        developer.log('Speech recognition initialized', name: 'Transcript');
      } else {
        developer.log('Speech recognition not available', name: 'Transcript');
      }
      
      return available;
    } catch (e) {
      developer.log('Error initializing speech: $e', name: 'Transcript', error: e);
      return false;
    }
  }

  /// Start real-time transcription
  Future<String?> startTranscription({
    required String callId,
    required String appointmentId,
    required String doctorId,
    required String patientId,
    required String doctorName,
    required String patientName,
    required bool isDoctor,
  }) async {
    try {
      // Create transcript document
      final transcriptDoc = await _firestore.collection('transcripts').add({
        'callId': callId,
        'appointmentId': appointmentId,
        'doctorId': doctorId,
        'patientId': patientId,
        'doctorName': doctorName,
        'patientName': patientName,
        'startedAt': FieldValue.serverTimestamp(),
        'status': 'recording',
        'entries': [],
      });

      _currentTranscriptId = transcriptDoc.id;
      _currentSpeaker = isDoctor ? 'doctor' : 'patient';
      _entries = [];

      // Start listening
      await _startListening();

      // Auto-save every 10 seconds
      _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _saveCurrentTranscript();
      });

      developer.log(
        'Started transcription: $_currentTranscriptId',
        name: 'Transcript',
      );

      return _currentTranscriptId;
    } catch (e) {
      developer.log('Error starting transcription: $e', name: 'Transcript', error: e);
      return null;
    }
  }

  /// Start speech-to-text listening
  Future<void> _startListening() async {
    if (!_isListening && _speechToText.isAvailable) {
      _isListening = true;
      
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(minutes: 60), // Max duration
        pauseFor: const Duration(seconds: 3), // Pause detection
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
      
      developer.log('Started listening', name: 'Transcript');
    }
  }

  /// Handle speech recognition results
  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    if (result.finalResult) {
      final text = result.recognizedWords.trim();
      
      if (text.isNotEmpty) {
        final entry = TranscriptEntry(
          speaker: _currentSpeaker!,
          text: text,
          timestamp: DateTime.now(),
          confidence: result.confidence,
        );
        
        _entries.add(entry);
        
        developer.log(
          'Transcript entry: ${_currentSpeaker}: $text',
          name: 'Transcript',
        );
      }
    }
  }

  /// Handle speech recognition status
  void _onSpeechStatus(String status) {
    developer.log('Speech status: $status', name: 'Transcript');
    
    if (status == 'done' && _isListening) {
      // Restart listening if still in call
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isListening) {
          _startListening();
        }
      });
    }
  }

  /// Handle speech recognition errors
  void _onSpeechError(dynamic error) {
    developer.log('Speech error: $error', name: 'Transcript', error: error);
  }

  /// Save current transcript to Firestore
  Future<void> _saveCurrentTranscript() async {
    if (_currentTranscriptId == null || _entries.isEmpty) return;

    try {
      await _firestore
          .collection('transcripts')
          .doc(_currentTranscriptId)
          .update({
        'entries': _entries.map((e) => e.toMap()).toList(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      developer.log(
        'Saved ${_entries.length} transcript entries',
        name: 'Transcript',
      );
    } catch (e) {
      developer.log('Error saving transcript: $e', name: 'Transcript', error: e);
    }
  }

  /// Stop transcription
  Future<void> stopTranscription() async {
    _isListening = false;
    _saveTimer?.cancel();
    
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }

    // Final save
    await _saveCurrentTranscript();

    // Mark as completed
    if (_currentTranscriptId != null) {
      await _firestore
          .collection('transcripts')
          .doc(_currentTranscriptId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'totalEntries': _entries.length,
      });
    }

    developer.log('Stopped transcription', name: 'Transcript');

    _currentTranscriptId = null;
    _currentSpeaker = null;
    _entries = [];
  }

  /// Get transcript stream
  Stream<List<TranscriptEntry>> getTranscriptStream(String transcriptId) {
    return _firestore
        .collection('transcripts')
        .doc(transcriptId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];

      final data = snapshot.data();
      if (data == null || !data.containsKey('entries')) return [];

      final entries = data['entries'] as List;
      return entries
          .map((e) => TranscriptEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Get formatted transcript text
  Future<String> getFormattedTranscript(String transcriptId) async {
    try {
      final doc = await _firestore
          .collection('transcripts')
          .doc(transcriptId)
          .get();

      if (!doc.exists) return '';

      final data = doc.data()!;
      final entries = (data['entries'] as List)
          .map((e) => TranscriptEntry.fromMap(e as Map<String, dynamic>))
          .toList();

      final buffer = StringBuffer();
      buffer.writeln('CONSULTATION TRANSCRIPT');
      buffer.writeln('Date: ${DateTime.now().toString().split('.')[0]}');
      buffer.writeln('Doctor: ${data['doctorName']}');
      buffer.writeln('Patient: ${data['patientName']}');
      buffer.writeln('\n${'=' * 50}\n');

      for (var entry in entries) {
        final speakerLabel = entry.speaker == 'doctor' 
            ? 'Dr. ${data['doctorName']}'
            : data['patientName'];
        
        buffer.writeln('[$speakerLabel]:');
        buffer.writeln(entry.text);
        buffer.writeln('');
      }

      return buffer.toString();
    } catch (e) {
      developer.log('Error formatting transcript: $e', name: 'Transcript', error: e);
      return '';
    }
  }

  /// Download transcript as text file
  String downloadTranscriptAsText(String transcriptText) {
    return transcriptText;
  }

  /// Dispose resources
  void dispose() {
    _saveTimer?.cancel();
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
  }
}

/// Transcript entry model
class TranscriptEntry {
  final String speaker; // 'doctor' or 'patient'
  final String text;
  final DateTime timestamp;
  final double confidence;

  TranscriptEntry({
    required this.speaker,
    required this.text,
    required this.timestamp,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'speaker': speaker,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'confidence': confidence,
    };
  }

  factory TranscriptEntry.fromMap(Map<String, dynamic> map) {
    return TranscriptEntry(
      speaker: map['speaker'] as String,
      text: map['text'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  String get speakerLabel => speaker == 'doctor' ? 'Doctor' : 'Patient';
}