import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription? _signalSubscription;
  StreamSubscription? _iceCandidateSubscription;
  
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;

  Future<void> initialize({required bool video}) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(config, constraints);

    _peerConnection!.onIceCandidate = (candidate) {
      // Will be sent via Firestore in _listenForIceCandidates
    };

    _peerConnection!.onTrack = (event) {
      print('onTrack called with ${event.streams.length} streams');
      if (event.streams.isNotEmpty) {
        print('Adding remote stream');
        _remoteStreamController.add(event.streams[0]);
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('ICE connection state: $state');
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });

    _localStream!.getTracks().forEach((track) {
      print('Adding local track: ${track.kind}');
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  MediaStream? get localStream => _localStream;

  Future<void> createOffer(String roomId, String userId, bool isVideo) async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Start listening for ICE candidates immediately
    _listenForIceCandidates(roomId, userId);

    await _firestore.collection('chat_rooms').doc(roomId).update({
      'call': {
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
          'from': userId,
          'video': isVideo,
        },
        'status': 'calling',
      },
    });

    _listenForAnswer(roomId, userId);
  }

  Future<void> handleOffer(String roomId, String userId, Map<String, dynamic> offer) async {
    // Start listening for ICE candidates immediately
    _listenForIceCandidates(roomId, userId);
    
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _firestore.collection('chat_rooms').doc(roomId).update({
      'call.answer': {
        'sdp': answer.sdp,
        'type': answer.type,
        'to': offer['from'],
      },
      'call.status': 'active',
    });
  }

  void _listenForAnswer(String roomId, String userId) {
    bool answerProcessed = false;
    
    _signalSubscription = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .snapshots()
        .listen((snapshot) async {
      final data = snapshot.data();
      if (data != null && data['call']?['answer'] != null && !answerProcessed) {
        final answer = data['call']['answer'];
        if (answer['to'] == userId) {
          answerProcessed = true;
          try {
            await _peerConnection!.setRemoteDescription(
              RTCSessionDescription(answer['sdp'], answer['type']),
            );
          } catch (e) {
            print('Error setting remote description: $e');
          }
        }
      }
    });
  }

  void _listenForIceCandidates(String roomId, String userId) {
    _iceCandidateSubscription = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('ice_candidates')
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null && data['from'] != userId) {
            try {
              await _peerConnection!.addCandidate(
                RTCIceCandidate(
                  data['candidate'],
                  data['sdpMid'],
                  data['sdpMLineIndex'],
                ),
              );
            } catch (e) {
              print('Error adding ICE candidate: $e');
            }
          }
        }
      }
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _firestore
            .collection('chat_rooms')
            .doc(roomId)
            .collection('ice_candidates')
            .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'from': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    };
  }

  Future<void> endCall(String roomId) async {
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'call': FieldValue.delete(),
    });
    
    // Clean up ICE candidates
    final candidates = await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('ice_candidates')
        .get();
    
    for (final doc in candidates.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> toggleAudio() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        videoTracks.first.enabled = !videoTracks.first.enabled;
      }
    }
  }

  bool get isAudioEnabled => 
      _localStream?.getAudioTracks().firstOrNull?.enabled ?? false;

  bool get isVideoEnabled =>
      _localStream?.getVideoTracks().firstOrNull?.enabled ?? false;

  Future<void> dispose() async {
    await _signalSubscription?.cancel();
    await _iceCandidateSubscription?.cancel();
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _remoteStreamController.close();
  }
}
