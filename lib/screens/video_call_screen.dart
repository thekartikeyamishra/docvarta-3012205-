import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallScreen extends StatefulWidget {
  final String appointmentId;
  final String callId;
  final bool isDoctor;

  const VideoCallScreen({
    super.key,
    required this.appointmentId,
    required this.callId,
    required this.isDoctor,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;

  // State
  bool _isInitialized = false;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;
  bool _isConnected = false;
  String? _errorMessage;
  
  // Timers
  Timer? _statusTimer;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  
  // Connection info
  String _connectionStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🎬 INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _initializeCall() async {
    try {
      debugPrint('🎥 Initializing WebRTC video call...');
      debugPrint('   Call ID: ${widget.callId}');
      debugPrint('   Is Doctor: ${widget.isDoctor}');

      setState(() => _connectionStatus = 'Setting up video...');

      // Initialize renderers
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      debugPrint('✅ Renderers initialized');

      setState(() => _connectionStatus = 'Getting camera permission...');

      // Get local media
      await _getUserMedia();
      debugPrint('✅ Local media acquired');

      setState(() => _connectionStatus = 'Creating connection...');

      // Create peer connection
      await _createPeerConnection();
      debugPrint('✅ Peer connection created');

      setState(() => _connectionStatus = 'Connecting...');

      // Set up signaling
      await _setupSignaling();
      debugPrint('✅ Signaling established');

      // Start timers
      _startTimers();

      setState(() {
        _isInitialized = true;
        _connectionStatus = 'Connected';
      });
      
      debugPrint('✅ Video call initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _connectionStatus = 'Failed';
      });
    }
  }

  Future<void> _getUserMedia() async {
    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        }
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
      
      debugPrint('📹 Local stream tracks: ${_localStream!.getTracks().length}');
    } catch (e) {
      throw Exception('Camera/microphone access denied: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(configuration);

      // Add local tracks
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Handle remote tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('🎬 Remote track received: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _isConnected = true;
            _connectionStatus = 'Connected';
          });
        }
      };

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          debugPrint('🧊 New ICE candidate');
          _saveIceCandidate(candidate);
        }
      };

      // Connection state
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('🔗 Connection state: $state');
        setState(() {
          switch (state) {
            case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
              _isConnected = true;
              _connectionStatus = 'Connected';
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
              _connectionStatus = 'Connecting...';
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
              _isConnected = false;
              _connectionStatus = 'Disconnected';
              break;
            case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
              _isConnected = false;
              _connectionStatus = 'Connection Failed';
              break;
            default:
              break;
          }
        });
      };
    } catch (e) {
      throw Exception('Failed to create peer connection: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           📡 SIGNALING (Firestore)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _setupSignaling() async {
    final callDoc = _firestore.collection('calls').doc(widget.callId);

    if (widget.isDoctor) {
      await _createOffer(callDoc);
      _listenForAnswer(callDoc);
    } else {
      _listenForOffer(callDoc);
    }

    _listenForIceCandidates(callDoc);
  }

  Future<void> _createOffer(DocumentReference callDoc) async {
    try {
      debugPrint('👨‍⚕️ Doctor creating offer...');
      
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      await callDoc.set({
        'offer': offer.toMap(),
        'doctorId': _auth.currentUser?.uid,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
        'appointmentId': widget.appointmentId,
      }, SetOptions(merge: true));

      debugPrint('✅ Offer created and saved');
    } catch (e) {
      debugPrint('❌ Failed to create offer: $e');
    }
  }

  void _listenForAnswer(DocumentReference callDoc) {
    callDoc.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data['answer'] != null) {
        try {
          final answer = data['answer'] as Map<String, dynamic>;
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(answer['sdp'], answer['type']),
          );
          debugPrint('✅ Remote description set');
        } catch (e) {
          debugPrint('❌ Failed to set remote description: $e');
        }
      }
    });
  }

  void _listenForOffer(DocumentReference callDoc) {
    callDoc.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data['offer'] != null && data['answer'] == null) {
        try {
          debugPrint('🧑‍⚕️ Patient received offer, creating answer...');
          
          final offer = data['offer'] as Map<String, dynamic>;
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(offer['sdp'], offer['type']),
          );

          final answer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(answer);

          await callDoc.update({
            'answer': answer.toMap(),
            'patientId': _auth.currentUser?.uid,
            'status': 'connected',
            'answeredAt': FieldValue.serverTimestamp(),
          });

          debugPrint('✅ Answer created and saved');
        } catch (e) {
          debugPrint('❌ Failed to create answer: $e');
        }
      }
    });
  }

  void _listenForIceCandidates(DocumentReference callDoc) {
    callDoc.collection('candidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          try {
            final data = change.doc.data()!;
            _peerConnection!.addCandidate(RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ));
            debugPrint('✅ ICE candidate added');
          } catch (e) {
            debugPrint('❌ Failed to add ICE candidate: $e');
          }
        }
      }
    });
  }

  Future<void> _saveIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _firestore
          .collection('calls')
          .doc(widget.callId)
          .collection('candidates')
          .add(candidate.toMap());
    } catch (e) {
      debugPrint('⚠️  Failed to save ICE candidate: $e');
      // Don't throw - continue even if save fails
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🎛️ CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  void _toggleAudio() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final enabled = !_isAudioMuted;
        audioTracks[0].enabled = enabled;
        setState(() => _isAudioMuted = !enabled);
        debugPrint('🎤 Audio ${enabled ? "enabled" : "muted"}');
      }
    }
  }

  void _toggleVideo() {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final enabled = !_isVideoMuted;
        videoTracks[0].enabled = enabled;
        setState(() => _isVideoMuted = !enabled);
        debugPrint('📹 Video ${enabled ? "enabled" : "disabled"}');
      }
    }
  }

  Future<void> _endCall() async {
    debugPrint('📞 Ending call...');
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           ⏱️ TIMERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _startTimers() {
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateCallStatus('active');
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _updateCallStatus(String status) async {
    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'status': status,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating call status: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _cleanup() async {
    debugPrint('🧹 Cleaning up video call...');
    
    _statusTimer?.cancel();
    _durationTimer?.cancel();

    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();

    try {
      await _firestore
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating appointment: $e');
    }
    
    debugPrint('✅ Cleanup complete');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 
        ? '${twoDigits(duration.inHours)}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //                           🎨 UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            _buildRemoteVideo(),

            // Local video (picture-in-picture)
            Positioned(
              top: 16,
              right: 16,
              child: _buildLocalVideo(),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),

            // Connection status overlay
            if (!_isConnected && _isInitialized)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: _buildConnectionIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    return _remoteRenderer.srcObject != null
        ? SizedBox.expand(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          )
        : Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person, size: 100, color: Colors.white30),
                  const SizedBox(height: 16),
                  Text(
                    _connectionStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  if (!_isConnected && _isInitialized) ...[
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
  }

  Widget _buildLocalVideo() {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _localRenderer.srcObject != null
            ? RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white54),
                ),
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_callDuration),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isConnected 
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isConnected ? Colors.green : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'WebRTC',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
            label: _isAudioMuted ? 'Unmute' : 'Mute',
            onPressed: _toggleAudio,
            isActive: !_isAudioMuted,
          ),
          _buildControlButton(
            icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
            label: 'Camera',
            onPressed: _toggleVideo,
            isActive: !_isVideoMuted,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End',
            onPressed: _endCall,
            backgroundColor: Colors.red,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = true,
    bool isDestructive = false,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ??
                (isActive
                    ? Colors.white.withOpacity(0.2)
                    : Colors.red.withOpacity(0.3)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isDestructive ? Colors.white : (isActive ? Colors.white : Colors.red),
              size: 28,
            ),
            onPressed: onPressed,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildConnectionIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _connectionStatus,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(
              _connectionStatus,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call Error'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Cannot Start Video Call',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}