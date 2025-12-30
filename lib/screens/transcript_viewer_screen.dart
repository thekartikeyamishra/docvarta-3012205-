// lib/screens/transcript_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/transcript_service.dart';
import '../widgets/custom_card.dart';

class TranscriptViewerScreen extends StatefulWidget {
  final String? appointmentId; // If provided, show transcripts for this appointment
  
  const TranscriptViewerScreen({super.key, this.appointmentId});

  @override
  State<TranscriptViewerScreen> createState() => _TranscriptViewerScreenState();
}

class _TranscriptViewerScreenState extends State<TranscriptViewerScreen> {
  final TranscriptService _transcriptService = TranscriptService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (mounted && doc.exists) {
      setState(() => _userRole = doc.data()?['role']);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getTranscriptsStream() {
    if (widget.appointmentId != null) {
      return _transcriptService.streamTranscriptsForAppointment(widget.appointmentId!);
    } else if (_userRole != null) {
      return _transcriptService.streamUserTranscripts(
        userId: _uid,
        role: _userRole!,
      );
    }
    return const Stream.empty();
  }

  Future<void> _viewTranscript(String transcriptId) async {
    final doc = await _transcriptService.getTranscript(transcriptId);
    
    if (!doc.exists || !mounted) return;
    
    final data = doc.data()!;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TranscriptDetailScreen(transcriptData: data),
      ),
    );
  }

  Future<void> _downloadTranscript(String transcriptId) async {
    try {
      final doc = await _transcriptService.getTranscript(transcriptId);
      
      if (!doc.exists) {
        throw Exception('Transcript not found');
      }
      
      final data = doc.data()!;
      
      // Check if already saved to storage
      final existingUrl = data['downloadUrl'] as String?;
      
      if (existingUrl != null) {
        _openUrl(existingUrl);
      } else {
        // Generate and save
        final transcriptText = _transcriptService.generateTranscriptText(data);
        final url = await _transcriptService.saveTranscriptToStorage(
          transcriptId: transcriptId,
          transcriptText: transcriptText,
        );
        _openUrl(url);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening transcript...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareTranscript(String transcriptId) async {
    try {
      final doc = await _transcriptService.getTranscript(transcriptId);
      
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final transcriptText = _transcriptService.generateTranscriptText(data);
      
      await Share.share(transcriptText, subject: 'Consultation Transcript');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  Future<void> _deleteTranscript(String transcriptId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transcript?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _transcriptService.deleteTranscript(transcriptId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transcript deleted')),
        );
      }
    }
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointmentId != null 
          ? 'Consultation Transcripts' 
          : 'My Transcripts'
        ),
      ),
      body: SafeArea(
        child: _userRole == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getTranscriptsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No transcripts available'),
                      ],
                    ),
                  );
                }
                
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final transcriptId = doc.id;
                    
                    final startTime = data['startTime'] as Timestamp?;
                    final endTime = data['endTime'] as Timestamp?;
                    final messages = data['messages'] as List? ?? [];
                    final isActive = data['isActive'] == true;
                    
                    return CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dr. ${data['doctorName'] ?? 'Unknown'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Patient: ${data['patientName'] ?? 'Unknown'}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (startTime != null)
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  _formatDateTime(startTime.toDate()),
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                ),
                              ],
                            ),
                          if (endTime != null && startTime != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Duration: ${_formatDuration(endTime.toDate().difference(startTime.toDate()))}',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.notes, size: 16, color: Colors.blue),
                              const SizedBox(width: 6),
                              Text(
                                '${messages.length} notes',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _viewTranscript(transcriptId),
                                icon: const Icon(Icons.visibility, size: 18),
                                label: const Text('View'),
                              ),
                              const SizedBox(width: 8),
                              if (!isActive) ...[
                                TextButton.icon(
                                  onPressed: () => _downloadTranscript(transcriptId),
                                  icon: const Icon(Icons.download, size: 18),
                                  label: const Text('Download'),
                                ),
                                PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share),
                                          SizedBox(width: 8),
                                          Text('Share'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'share') {
                                      _shareTranscript(transcriptId);
                                    } else if (value == 'delete') {
                                      _deleteTranscript(transcriptId);
                                    }
                                  },
                                ),
                              ],
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

// Detail screen showing full transcript
class TranscriptDetailScreen extends StatelessWidget {
  final Map<String, dynamic> transcriptData;
  
  const TranscriptDetailScreen({super.key, required this.transcriptData});

  @override
  Widget build(BuildContext context) {
    final messages = transcriptData['messages'] as List? ?? [];
    final startTime = transcriptData['startTime'] as Timestamp?;
    final endTime = transcriptData['endTime'] as Timestamp?;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final service = TranscriptService();
              final text = service.generateTranscriptText(transcriptData);
              Share.share(text);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${transcriptData['doctorName'] ?? 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text('Patient: ${transcriptData['patientName'] ?? 'Unknown'}'),
                    const SizedBox(height: 12),
                    if (startTime != null)
                      Text('Started: ${_formatDateTime(startTime.toDate())}'),
                    if (endTime != null)
                      Text('Ended: ${_formatDateTime(endTime.toDate())}'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Messages
              const Text(
                'Conversation Notes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              if (messages.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No notes recorded'),
                  ),
                )
              else
                ...messages.map((msg) {
                  final speaker = msg['speaker'] as String;
                  final message = msg['message'] as String;
                  final timestamp = msg['timestamp'] as Timestamp?;
                  
                  final isDoctor = speaker == 'doctor';
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CustomCard(
                      padding: const EdgeInsets.all(12),
                      color: isDoctor ? Colors.blue.shade50 : Colors.green.shade50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isDoctor ? 'Doctor' : 'Patient',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDoctor ? Colors.blue : Colors.green,
                                ),
                              ),
                              if (timestamp != null)
                                Text(
                                  _formatTime(timestamp.toDate()),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(message),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}