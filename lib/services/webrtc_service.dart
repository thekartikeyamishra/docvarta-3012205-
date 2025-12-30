// lib/services/webrtc_service.dart
/*
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  DocumentReference<Map<String, dynamic>>? _roomRef;
  StreamSubscription? _roomSub;
  StreamSubscription? _candidatesSub;
  StreamSubscription? _offerCandidatesSub;
  StreamSubscription? _answerCandidatesSub;

  bool _isAudioOn = true;
  bool _isVideoOn = true;
  
  // Connection state
  RTCPeerConnectionState _connectionState = RTCPeerConnectionState.RTCPeerConnectionStateNew;
  RTCIceConnectionState _iceConnectionState = RTCIceConnectionState.RTCIceConnectionStateNew;

  // Callbacks for monitoring
  Function(RTCPeerConnectionState)? onConnectionStateChange;
  Function(RTCIceConnectionState)? onIceConnectionStateChange;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> openUserMedia() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 30},
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      debugPrint('✅ Local media stream opened successfully');
    } catch (e) {
      debugPrint('❌ Error opening user media: $e');
      rethrow; 
    }
  }

  Future<void> _createPeerConnection(String roomId, {required bool isInitiator}) async {
    // Enhanced ICE servers including TURN for NAT traversal
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        // You can add TURN servers here for production
        // {
        //   'urls': 'turn:your-turn-server.com:3478',
        //   'username': 'username',
        //   'credential': 'password'
        // }
      ],
      'iceCandidatePoolSize': 10,
    };
    
    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };
    
    _pc = await createPeerConnection(config, constraints);
    debugPrint('✅ Peer connection created for room: $roomId (isInitiator: $isInitiator)');

    // Register local tracks
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
        debugPrint('✅ Added local track: ${track.kind}');
      });
    }

    // ICE Candidate handling - separate collections for offer and answer
    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_roomRef == null) return;
      
      final candidateData = candidate.toMap();
      final collection = isInitiator ? 'offerCandidates' : 'answerCandidates';
      
      _roomRef!.collection(collection).add(candidateData).then((_) {
        debugPrint('✅ Added ${isInitiator ? "offer" : "answer"} ICE candidate');
      }).catchError((error) {
        debugPrint('❌ Error adding ICE candidate: $error');
      });
    };

    // Remote track handling
    _pc!.onTrack = (RTCTrackEvent event) {
      debugPrint('✅ Received remote track: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        debugPrint('✅ Remote stream set to renderer');
      }
    };

    // Connection state monitoring
    _pc!.onConnectionState = (RTCPeerConnectionState state) {
      _connectionState = state;
      debugPrint('🔄 Connection state changed: $state');
      onConnectionStateChange?.call(state);
    };

    _pc!.onIceConnectionState = (RTCIceConnectionState state) {
      _iceConnectionState = state;
      debugPrint('🔄 ICE connection state changed: $state');
      onIceConnectionStateChange?.call(state);
      
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        debugPrint('❌ ICE connection failed - attempting restart');
        _restartIce();
      }
    };

    _pc!.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('🔄 ICE gathering state: $state');
    };
  }

  Future<void> _restartIce() async {
    if (_pc == null) return;
    try {
      final offer = await _pc!.createOffer({'iceRestart': true});
      await _pc!.setLocalDescription(offer);
      await _roomRef?.update({
        'offer': offer.toMap(),
      });
      debugPrint('✅ ICE restart initiated');
    } catch (e) {
      debugPrint('❌ ICE restart failed: $e');
    }
  }

  // --- Doctor/Initiator calls this ---
  Future<String> createRoom({required String collectionPath}) async {
    _roomRef = _db.collection(collectionPath).doc();
    String roomId = _roomRef!.id;
    debugPrint('📞 Creating room: $roomId');

    await _createPeerConnection(roomId, isInitiator: true);

    // Create Offer
    RTCSessionDescription offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _pc!.setLocalDescription(offer);
    debugPrint('✅ Offer created and set as local description');

    Map<String, dynamic> roomWithOffer = {
      'offer': offer.toMap(),
      'created': FieldValue.serverTimestamp(),
      'status': 'waiting',
      'isActive': true,
    };

    await _roomRef!.set(roomWithOffer);
    debugPrint('✅ Room document created in Firestore');

    // Listen for remote answer
    _roomSub = _roomRef!.snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        debugPrint('⚠️ Room document deleted');
        return;
      }
      
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      
      if (_pc != null && 
          _pc!.getRemoteDescription() == null && 
          data['answer'] != null) {
        debugPrint('✅ Received answer from patient');
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await _pc!.setRemoteDescription(answer);
        debugPrint('✅ Answer set as remote description');
      }
    });

    // Listen for answer candidates
    _listenForAnswerCandidates();

    return roomId;
  }

  // --- Patient/Joiner calls this ---
  Future<void> joinRoom({required String collectionPath, required String roomId}) async {
    _roomRef = _db.collection(collectionPath).doc(roomId);
    debugPrint('📞 Joining room: $roomId');
    
    var roomSnapshot = await _roomRef!.get();

    if (!roomSnapshot.exists) {
      throw Exception('Room $roomId does not exist');
    }

    await _createPeerConnection(roomId, isInitiator: false);

    var data = roomSnapshot.data() as Map<String, dynamic>;
    
    if (data['offer'] == null) {
      throw Exception('No offer found in room');
    }
    
    var offer = data['offer'];
    debugPrint('✅ Received offer from doctor');
    
    await _pc!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    debugPrint('✅ Offer set as remote description');

    // Create Answer
    var answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    debugPrint('✅ Answer created and set as local description');

    await _roomRef!.update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
      'status': 'connected',
    });
    debugPrint('✅ Answer sent to Firestore');

    // Listen for offer candidates
    _listenForOfferCandidates();
  }

  void _listenForOfferCandidates() {
    _offerCandidatesSub = _roomRef!.collection('offerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          debugPrint('✅ Adding offer ICE candidate');
          _pc!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  void _listenForAnswerCandidates() {
    _answerCandidatesSub = _roomRef!.collection('answerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          debugPrint('✅ Adding answer ICE candidate');
          _pc!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  // Toggle Media
  void toggleMic() {
    if (_localStream != null) {
      _isAudioOn = !_isAudioOn;
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = _isAudioOn;
      });
      debugPrint('🎤 Microphone ${_isAudioOn ? "ON" : "OFF"}');
    }
  }

  void toggleCamera() {
    if (_localStream != null) {
      _isVideoOn = !_isVideoOn;
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled = _isVideoOn;
      });
      debugPrint('📹 Camera ${_isVideoOn ? "ON" : "OFF"}');
    }
  }

  bool get isAudioOn => _isAudioOn;
  bool get isVideoOn => _isVideoOn;
  RTCPeerConnectionState get connectionState => _connectionState;
  RTCIceConnectionState get iceConnectionState => _iceConnectionState;

  // Cleanup
  Future<void> hangUp({bool deleteRoom = false}) async {
    debugPrint('📞 Hanging up...');
    
    // Cancel subscriptions
    await _roomSub?.cancel();
    await _offerCandidatesSub?.cancel();
    await _answerCandidatesSub?.cancel();
    
    // Stop tracks
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      _localStream!.dispose();
      _localStream = null;
    }
    
    // Close peer connection
    if (_pc != null) {
      await _pc!.close();
      _pc = null;
    }
    
    // Clear renderers
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    await localRenderer.dispose();
    await remoteRenderer.dispose();

    // Update room status
    if (_roomRef != null) {
      try {
        await _roomRef!.update({
          'isActive': false,
          'endedAt': FieldValue.serverTimestamp(),
        });
        
        if (deleteRoom) {
          // Delete subcollections first
          await _deleteCollection(_roomRef!.collection('offerCandidates'));
          await _deleteCollection(_roomRef!.collection('answerCandidates'));
          
          // Then delete room
          await _roomRef!.delete();
          debugPrint('✅ Room deleted');
        }
      } catch (e) {
        debugPrint('⚠️ Error cleaning up room: $e');
      }
    }
    
    debugPrint('✅ Cleanup complete');
  }

  Future<void> _deleteCollection(CollectionReference collection) async {
    final snapshots = await collection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}
*/

// lib/services/webrtc_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  DocumentReference<Map<String, dynamic>>? _roomRef;
  StreamSubscription? _roomSub;
  StreamSubscription? _offerCandidatesSub;
  StreamSubscription? _answerCandidatesSub;

  bool _isAudioOn = true;
  bool _isVideoOn = true;
  
  // Connection state monitoring
  Function(RTCPeerConnectionState)? onConnectionStateChange;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> openUserMedia() async {
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
      },
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      }
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
    } catch (e) {
      debugPrint('❌ Error opening user media: $e');
      rethrow;
    }
  }

  Future<void> _createPeerConnection(String roomId, {required bool isInitiator}) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };
    
    // Standard WebRTC constraints
    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true}, 
      ],
    };

    _pc = await createPeerConnection(config, constraints);

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _pc!.addTrack(track, _localStream!);
      });
    }

    // Handle ICE candidates
    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_roomRef == null) return;
      final collection = isInitiator ? 'offerCandidates' : 'answerCandidates';
      _roomRef!.collection(collection).add(candidate.toMap());
    };

    // Handle Remote Stream
    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
      }
    };

    // Monitor Connection State
    _pc!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('🔄 Connection state: $state');
      onConnectionStateChange?.call(state);
    };
  }

  // --- Doctor/Initiator Flow ---
  Future<String> createRoom({required String collectionPath}) async {
    _roomRef = _db.collection(collectionPath).doc();
    String roomId = _roomRef!.id;

    await _createPeerConnection(roomId, isInitiator: true);

    // Create Offer
    RTCSessionDescription offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    await _roomRef!.set({
      'offer': offer.toMap(),
      'created': FieldValue.serverTimestamp(),
    });

    // Listen for Answer
    _roomSub = _roomRef!.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      // Fix: Added null check for data
      if (data != null && data['answer'] != null && await _pc!.getRemoteDescription() == null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await _pc!.setRemoteDescription(answer);
      }
    });

    // Listen for Answer Candidates
    _answerCandidatesSub = _roomRef!.collection('answerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          // Fix: Added null check for data before accessing fields
          if (data != null) {
            _pc!.addCandidate(RTCIceCandidate(
              data['candidate'], 
              data['sdpMid'], 
              data['sdpMLineIndex']
            ));
          }
        }
      }
    });

    return roomId;
  }

  // --- Patient/Joiner Flow ---
  Future<void> joinRoom({required String collectionPath, required String roomId}) async {
    _roomRef = _db.collection(collectionPath).doc(roomId);
    var roomSnapshot = await _roomRef!.get();

    if (!roomSnapshot.exists) throw Exception('Room does not exist');

    await _createPeerConnection(roomId, isInitiator: false);

    var data = roomSnapshot.data()!;
    var offer = data['offer'];
    await _pc!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    // Create Answer
    var answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    await _roomRef!.update({
      'answer': {'type': answer.type, 'sdp': answer.sdp}
    });

    // Listen for Offer Candidates
    _offerCandidatesSub = _roomRef!.collection('offerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          // Fix: Added null check for data before accessing fields
          if (data != null) {
            _pc!.addCandidate(RTCIceCandidate(
              data['candidate'], 
              data['sdpMid'], 
              data['sdpMLineIndex']
            ));
          }
        }
      }
    });
  }

  // --- Media Controls ---
  void toggleMic() {
    if (_localStream != null) {
      _isAudioOn = !_isAudioOn;
      _localStream!.getAudioTracks().forEach((track) => track.enabled = _isAudioOn);
    }
  }

  void toggleCamera() {
    if (_localStream != null) {
      _isVideoOn = !_isVideoOn;
      _localStream!.getVideoTracks().forEach((track) => track.enabled = _isVideoOn);
    }
  }

  // --- Cleanup ---
  Future<void> hangUp({bool deleteRoom = false}) async {
    try {
      if (_localStream != null) {
        _localStream!.getTracks().forEach((t) => t.stop());
        await _localStream!.dispose();
        _localStream = null;
      }
      
      if (_pc != null) {
        await _pc!.close();
        _pc = null;
      }

      await _roomSub?.cancel();
      await _offerCandidatesSub?.cancel();
      await _answerCandidatesSub?.cancel();

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();

      if (deleteRoom && _roomRef != null) {
        await _roomRef!.delete(); 
      }
    } catch (e) {
      debugPrint('Error during hangup: $e');
    }
  }
}
