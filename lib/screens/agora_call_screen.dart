// lib/screens/agora_call_screen.dart
// AGORA VIDEO CALLING - Works on Web, Android, iOS
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraCallScreen extends StatefulWidget {
  final String appointmentId;
  final String callId;
  final bool isDoctor;

  const AgoraCallScreen({
    super.key,
    required this.appointmentId,
    required this.callId,
    required this.isDoctor,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Agora
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isAudioMuted = false;
  bool _isVideoMuted = false;

  // User info
  String? _userName;
  String? _userId;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _disposeAgora();
    _updateAppointmentStatus('completed');
    super.dispose();
  }

  Future<void> _initializeAgora() async {
    try {
      // Get Agora App ID
      final appId = dotenv.env['AGORA_APP_ID'];
      if (appId == null || appId.isEmpty) {
        _showError('Agora App ID not configured');
        return;
      }

      // Get user info
      _userId = _auth.currentUser?.uid;
      if (_userId == null) {
        _showError('User not authenticated');
        return;
      }

      final userDoc = await _firestore
          .collection(widget.isDoctor ? 'doctors' : 'users')
          .doc(_userId)
          .get();

      _userName = userDoc.data()?['displayName'] ??
          (widget.isDoctor ? 'Doctor' : 'Patient');

      // Request permissions
      await [Permission.microphone, Permission.camera].request();

      // Create Agora engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Setup event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('Local user joined: ${connection.localUid}');
            setState(() {
              _localUserJoined = true;
            });
            _updateAppointmentStatus('ongoing');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('Remote user joined: $remoteUid');
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            debugPrint('Remote user left: $remoteUid');
            setState(() {
              _remoteUid = null;
            });
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('Agora error: $err - $msg');
          },
        ),
      );

      // Enable video
      await _engine!.enableVideo();
      await _engine!.startPreview();

      // Join channel
      await _engine!.joinChannel(
        token: '', // Use token server in production
        channelId: widget.callId,
        uid: 0, // Auto-assign UID
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Start status monitoring
      _startStatusMonitoring();
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      _showError('Failed to initialize: ${e.toString()}');
    }
  }

  Future<void> _disposeAgora() async {
    await _engine?.leaveChannel();
    await _engine?.release();
  }

  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _firestore
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      }).catchError((e) {
        debugPrint('Status update error: $e');
      });
    });
  }

  Future<void> _updateAppointmentStatus(String status) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'ongoing') {
        updateData['callStartedAt'] = FieldValue.serverTimestamp();
        if (!widget.isDoctor) {
          updateData['patientJoinedAt'] = FieldValue.serverTimestamp();
        }
      } else if (status == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('appointments')
          .doc(widget.appointmentId)
          .update(updateData);
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleAudio() async {
    setState(() {
      _isAudioMuted = !_isAudioMuted;
    });
    await _engine?.muteLocalAudioStream(_isAudioMuted);
  }

  void _toggleVideo() async {
    setState(() {
      _isVideoMuted = !_isVideoMuted;
    });
    await _engine?.muteLocalVideoStream(_isVideoMuted);
  }

  void _switchCamera() async {
    await _engine?.switchCamera();
  }

  void _endCall() async {
    await _updateAppointmentStatus('completed');
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDoctor ? 'Video Consultation' : 'Doctor Call'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Remote video (full screen)
          Center(
            child: _remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine!,
                      canvas: VideoCanvas(uid: _remoteUid),
                      connection: RtcConnection(channelId: widget.callId),
                    ),
                  )
                : Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.isDoctor
                                ? 'Waiting for patient to join...'
                                : 'Waiting for doctor...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Local video (small preview in corner)
          if (_localUserJoined)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _isVideoMuted
                      ? Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        )
                      : AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _engine!,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                ),
              ),
            ),

          // Controls at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mic toggle
                _buildControlButton(
                  icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
                  color: _isAudioMuted ? Colors.red : Colors.white,
                  onPressed: _toggleAudio,
                ),

                // Video toggle
                _buildControlButton(
                  icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                  color: _isVideoMuted ? Colors.red : Colors.white,
                  onPressed: _toggleVideo,
                ),

                // Switch camera
                _buildControlButton(
                  icon: Icons.switch_camera,
                  color: Colors.white,
                  onPressed: _switchCamera,
                ),

                // End call
                _buildControlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: _endCall,
                  size: 64,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        iconSize: size * 0.5,
        onPressed: onPressed,
      ),
    );
  }
}