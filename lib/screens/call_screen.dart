// lib/screens/call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/webrtc_service.dart';
import '../services/transcript_service.dart';

class CallScreen extends StatefulWidget {
  final bool isInitiator;
  final String? appointmentDocId; 
  final String? joinRoomId;       

  const CallScreen({
    super.key, 
    required this.isInitiator, 
    this.appointmentDocId, 
    this.joinRoomId
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webrtc = WebRTCService();
  final TranscriptService _transcriptService = TranscriptService();
  
  String? _roomId;
  String? _transcriptId;
  bool _loading = true;
  bool _micOn = true;
  bool _camOn = true;
  String _connectionStatus = 'Connecting...';
  bool _isConnected = false;
  
  final TextEditingController _noteController = TextEditingController();
  bool _showTranscriptInput = false;

  @override
  void initState() {
    super.initState();
    _startCall();
    
    _webrtc.onConnectionStateChange = (state) {
      if (mounted) {
        setState(() {
          switch (state) {
            case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
              _connectionStatus = 'Connected';
              _isConnected = true;
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
              _connectionStatus = 'Failed';
              _isConnected = false;
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
              _connectionStatus = 'Disconnected';
              _isConnected = false;
              break;
            default:
              _connectionStatus = 'Connecting...';
          }
        });
      }
    };
  }

  Future<void> _startCall() async {
    try {
      setState(() => _loading = true);
      await _webrtc.initRenderers();
      await _webrtc.openUserMedia();

      if (widget.isInitiator) {
        // Doctor: Create Room
        final roomId = await _webrtc.createRoom(collectionPath: 'calls');
        setState(() => _roomId = roomId);

        // CRITICAL: Update Appointment to notify patient
        if (widget.appointmentDocId != null) {
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(widget.appointmentDocId)
              .update({
            'meetingRoomId': roomId,
            'status': 'ongoing', // Triggers patient UI
            'callStartedAt': FieldValue.serverTimestamp(),
          });
          
          _createTranscriptSession();
        }
      } else {
        // Patient: Join Room
        if (widget.joinRoomId == null) {
          throw Exception("No Room ID provided to join");
        }
        await _webrtc.joinRoom(collectionPath: 'calls', roomId: widget.joinRoomId!);
        setState(() => _roomId = widget.joinRoomId);
      }
    } catch (e) {
      debugPrint("Call Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection failed: $e")));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _endCall() async {
    try {
      // End transcript
      if (_transcriptId != null) {
        await _transcriptService.endTranscript(_transcriptId!);
      }
      
      // Update appointment status to completed
      if (widget.appointmentDocId != null) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentDocId)
            .update({
          'status': 'completed',
          'callEndedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await _webrtc.hangUp(deleteRoom: widget.isInitiator);
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error ending call: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _createTranscriptSession() async {
    try {
        final apptDoc = await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentDocId).get();
        if (apptDoc.exists) {
          final data = apptDoc.data()!;
          _transcriptId = await _transcriptService.createTranscript(
            appointmentId: widget.appointmentDocId!,
            doctorId: data['doctorId'],
            patientId: data['patientId'],
            doctorName: data['doctorName'] ?? 'Doctor',
            patientName: data['patientName'] ?? 'Patient',
          );
        }
    } catch (e) {
      debugPrint("Transcript creation failed: $e");
    }
  }

  void _toggleMic() {
    _webrtc.toggleMic();
    setState(() => _micOn = !_micOn);
  }

  void _toggleCamera() {
    _webrtc.toggleCamera();
    setState(() => _camOn = !_camOn);
  }

  void _toggleTranscriptInput() {
    setState(() => _showTranscriptInput = !_showTranscriptInput);
  }

  Future<void> _addTranscriptNote() async {
    if (_transcriptId == null || _noteController.text.trim().isEmpty) return;
    final speaker = widget.isInitiator ? 'doctor' : 'patient';
    await _transcriptService.addMessage(
      transcriptId: _transcriptId!,
      speaker: speaker,
      message: _noteController.text.trim(),
    );
    _noteController.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note added')));
  }

  @override
  void dispose() {
    _noteController.dispose();
    _webrtc.hangUp(deleteRoom: false); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Replaced WillPopScope (deprecated) with PopScope
    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('End Call?'),
            content: const Text('Do you want to end this consultation?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true), 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('End Call')
              ),
            ],
          ),
        );
        
        if (shouldPop == true) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _loading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // Remote Video
                Positioned.fill(
                  child: RTCVideoView(
                    _webrtc.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
                // Local Video
                Positioned(
                  top: 50, right: 20, width: 100, height: 140,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(8), color: Colors.black54),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: RTCVideoView(_webrtc.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    ),
                  ),
                ),
                // Connection Status
                Positioned(
                  top: 50, left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _isConnected ? Colors.green : Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Text(_connectionStatus, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                // Transcript Input
                if (_showTranscriptInput)
                  Positioned(
                    bottom: 120, left: 20, right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Add Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: 'Type here...', hintStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white12),
                          ),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton(onPressed: () => setState(() => _showTranscriptInput = false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: _addTranscriptNote, child: const Text('Save')),
                          ]),
                        ],
                      ),
                    ),
                  ),

                // Controls
                Positioned(
                  bottom: 30, left: 0, right: 0,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FloatingActionButton(heroTag: "mic", backgroundColor: _micOn ? Colors.white : Colors.red, child: Icon(_micOn ? Icons.mic : Icons.mic_off, color: Colors.black), onPressed: () { _toggleMic(); }),
                          FloatingActionButton(heroTag: "end", backgroundColor: Colors.red, child: const Icon(Icons.call_end, color: Colors.white), onPressed: _endCall),
                          FloatingActionButton(heroTag: "cam", backgroundColor: _camOn ? Colors.white : Colors.red, child: Icon(_camOn ? Icons.videocam : Icons.videocam_off, color: Colors.black), onPressed: () { _toggleCamera(); }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FloatingActionButton.small(heroTag: "notes", backgroundColor: Colors.white24, child: const Icon(Icons.note_add, color: Colors.white), onPressed: _toggleTranscriptInput),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}