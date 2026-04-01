import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  StreamSubscription? _callDocSub;
  StreamSubscription? _candidateSub;

  final _onRemoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get onRemoteStream => _onRemoteStreamController.stream;

  final _onCallEndedController = StreamController<void>.broadcast();
  Stream<void> get onCallEnded => _onCallEndedController.stream;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> dispose() async {
    await hangUp();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    _onRemoteStreamController.close();
    _onCallEndedController.close();
  }

  /// Get local media stream (audio only or audio+video).
  Future<MediaStream> _getUserMedia(bool video) async {
    final constraints = {
      'audio': true,
      'video': video
          ? {'facingMode': 'user', 'width': 640, 'height': 480}
          : false,
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  /// Create a peer connection with event handlers.
  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(_iceServers);

    pc.onIceCandidate = (candidate) {
      // Will be sent to Firestore by the caller/callee
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        _onRemoteStreamController.add(_remoteStream!);
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _onCallEndedController.add(null);
      }
    };

    return pc;
  }

  /// Initiate a call (caller side). Creates offer and writes to Firestore.
  Future<void> startCall({
    required String roomId,
    required String callerId,
    required bool video,
  }) async {
    _localStream = await _getUserMedia(video);
    localRenderer.srcObject = _localStream;

    _peerConnection = await _createPeerConnection();

    // Add local tracks
    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Collect ICE candidates
    final callDoc = _db.collection('chatRooms').doc(roomId).collection('calls').doc('active');
    final callerCandidates = callDoc.collection('callerCandidates');

    _peerConnection!.onIceCandidate = (candidate) {
      callerCandidates.add(candidate.toMap());
    };

    // Create offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await callDoc.set({
      'callerId': callerId,
      'type': video ? 'video' : 'voice',
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Listen for answer
    _callDocSub = callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      if (data['ended'] == true) {
        _onCallEndedController.add(null);
        return;
      }

      if (data['answer'] != null && _peerConnection != null) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        final remoteDesc = await _peerConnection!.getRemoteDescription();
        if (remoteDesc == null) {
          await _peerConnection!.setRemoteDescription(answer);
        }
      }
    });

    // Listen for callee ICE candidates
    _candidateSub = callDoc
        .collection('calleeCandidates')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  /// Answer an incoming call (callee side).
  Future<void> answerCall({
    required String roomId,
    required bool video,
  }) async {
    final callDoc = _db.collection('chatRooms').doc(roomId).collection('calls').doc('active');
    final callSnapshot = await callDoc.get();
    final callData = callSnapshot.data();
    if (callData == null) return;

    final isVideo = callData['type'] == 'video';
    _localStream = await _getUserMedia(video || isVideo);
    localRenderer.srcObject = _localStream;

    _peerConnection = await _createPeerConnection();

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // Collect ICE candidates
    final calleeCandidates = callDoc.collection('calleeCandidates');
    _peerConnection!.onIceCandidate = (candidate) {
      calleeCandidates.add(candidate.toMap());
    };

    // Set remote description (the offer)
    final offer = RTCSessionDescription(
      callData['offer']['sdp'],
      callData['offer']['type'],
    );
    await _peerConnection!.setRemoteDescription(offer);

    // Create answer
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await callDoc.update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });

    // Listen for caller ICE candidates
    _candidateSub = callDoc
        .collection('callerCandidates')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });

    // Listen for call end
    _callDocSub = callDoc.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data?['ended'] == true) {
        _onCallEndedController.add(null);
      }
    });
  }

  /// Hang up and clean up resources.
  Future<void> hangUp({String? roomId}) async {
    _callDocSub?.cancel();
    _candidateSub?.cancel();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _remoteStream = null;

    // Mark call as ended in Firestore
    if (roomId != null) {
      try {
        await _db
            .collection('chatRooms')
            .doc(roomId)
            .collection('calls')
            .doc('active')
            .update({'ended': true});
      } catch (_) {}
    }
  }

  /// Decline an incoming call without answering. Marks call as ended in Firestore.
  Future<void> declineCall({required String roomId}) async {
    try {
      await _db
          .collection('chatRooms')
          .doc(roomId)
          .collection('calls')
          .doc('active')
          .update({'ended': true, 'declined': true});
    } catch (_) {}
  }

  /// Toggle mute on the local audio track.
  bool toggleMute() {
    if (_localStream == null) return false;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return false;
    final enabled = !audioTracks[0].enabled;
    audioTracks[0].enabled = enabled;
    return !enabled; // returns true if muted
  }

  /// Toggle local camera on/off.
  bool toggleCamera() {
    if (_localStream == null) return false;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return false;
    final enabled = !videoTracks[0].enabled;
    videoTracks[0].enabled = enabled;
    return !enabled; // returns true if camera off
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;
    await Helper.switchCamera(videoTracks[0]);
  }

  /// Check if there's an incoming call for this room.
  Stream<Map<String, dynamic>?> listenForIncomingCall(String roomId) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('calls')
        .doc('active')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null || data['ended'] == true || data['answer'] != null) {
        return null;
      }
      return data;
    });
  }
}
