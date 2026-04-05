import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

enum RoomStatus {
  active,
  partnerLeft,
  deleted,
}

class AnonymousChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;
  String? _currentRoomId;
  StreamSubscription? _roomListener;
  Timer? _heartbeatTimer;
  Timer? _chatHeartbeatTimer;

  String get userId => _currentUserId ??= _generateUserId();
  String? get roomId => _currentRoomId;

  String _generateUserId() {
    final random = Random();
    return 'anon_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(9999)}';
  }

  // Start looking for a match
  Future<String> findMatch() async {
    final uid = userId;
    
    // First, clean up any stale matchmaking entry from previous session
    try {
      await _firestore.collection('matchmaking').doc(uid).delete();
    } catch (e) {
      // Ignore if doesn't exist
    }
    
    // Clean up stale entries (older than 30 seconds) before searching
    await _cleanupStaleEntries();
    
    // Try to find an existing waiting user with recent heartbeat
    final cutoffTime = DateTime.now().subtract(const Duration(seconds: 10));
    final waitingQuery = await _firestore
        .collection('matchmaking')
        .where('status', isEqualTo: 'waiting')
        .where('lastHeartbeat', isGreaterThan: Timestamp.fromDate(cutoffTime))
        .limit(5)
        .get();

    if (waitingQuery.docs.isNotEmpty) {
      // Try each waiting user until we find a valid one
      for (final doc in waitingQuery.docs) {
        final partnerId = doc.id;
        
        // Skip if it's somehow our own ID
        if (partnerId == uid) continue;
        
        // Verify the doc still exists and is still waiting
        final partnerDoc = await _firestore.collection('matchmaking').doc(partnerId).get();
        if (!partnerDoc.exists || partnerDoc.data()?['status'] != 'waiting') {
          continue;
        }
        
        // Valid partner found, create room
        final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';
        
        try {
          // Create chat room
          await _firestore.collection('chat_rooms').doc(roomId).set({
            'participants': [uid, partnerId],
            'createdAt': FieldValue.serverTimestamp(),
            'leftBy': [],
            'closedBy': [],
            'heartbeats': {}, // Track active users
            'typing': {}, // Track who is typing
            'call': null, // WebRTC call state
          });

          // Update partner's matchmaking doc so they know they're matched
          await _firestore.collection('matchmaking').doc(partnerId).update({
            'status': 'matched',
            'roomId': roomId,
          });
          
          // Delete our own matchmaking doc
          await _firestore.collection('matchmaking').doc(uid).delete();
          
          _currentRoomId = roomId;
          return roomId;
        } catch (e) {
          // Failed to create room or update partner, try next
          continue;
        }
      }
      
      // All waiting users were stale, fall through to waiting mode
    }
    
    // No valid waiting users - add ourselves to the queue
    await _firestore.collection('matchmaking').doc(uid).set({
      'status': 'waiting',
      'timestamp': FieldValue.serverTimestamp(),
      'lastHeartbeat': FieldValue.serverTimestamp(),
    });

    // Start heartbeat to keep our entry fresh
    _startHeartbeat();

    // Listen for when we get matched
    final completer = Completer<String>();
    _roomListener = _firestore
        .collection('matchmaking')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data?['status'] == 'matched' && data?['roomId'] != null) {
          final roomId = data!['roomId'] as String;
          _currentRoomId = roomId;
          _roomListener?.cancel();
          _stopHeartbeat();
          
          // Delete our matchmaking doc now that we're matched
          _firestore.collection('matchmaking').doc(uid).delete();
          
          if (!completer.isCompleted) {
            completer.complete(roomId);
          }
        }
      }
    });

    return completer.future;
  }

  // Clean up stale matchmaking entries
  Future<void> _cleanupStaleEntries() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(seconds: 30));
      final staleQuery = await _firestore
          .collection('matchmaking')
          .where('lastHeartbeat', isLessThan: Timestamp.fromDate(cutoffTime))
          .limit(10) // Clean up 10 at a time to avoid overload
          .get();
      
      for (final doc in staleQuery.docs) {
        try {
          await doc.reference.delete();
        } catch (e) {
          // Ignore individual delete errors
        }
      }
    } catch (e) {
      // Ignore cleanup errors, not critical
    }
    
    // Also clean up abandoned chat rooms
    await _cleanupAbandonedRooms();
  }

  // Clean up abandoned chat rooms (both users have stale heartbeats)
  Future<void> _cleanupAbandonedRooms() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 5));
      final roomsQuery = await _firestore
          .collection('chat_rooms')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffTime))
          .limit(5) // Clean up 5 at a time
          .get();
      
      for (final roomDoc in roomsQuery.docs) {
        try {
          final data = roomDoc.data();
          final participants = (data['participants'] as List?)?.cast<String>() ?? [];
          final heartbeats = data['heartbeats'] as Map<String, dynamic>? ?? {};
          final closedBy = (data['closedBy'] as List?)?.cast<String>() ?? [];
          
          // Check if both users have closed
          if (closedBy.length >= participants.length) {
            // Delete room and messages
            final messagesSnapshot = await roomDoc.reference.collection('messages').get();
            for (final msg in messagesSnapshot.docs) {
              await msg.reference.delete();
            }
            await roomDoc.reference.delete();
            continue;
          }
          
          // Check if all participants have stale heartbeats (force quit)
          bool allStale = true;
          for (final participantId in participants) {
            if (heartbeats.containsKey(participantId)) {
              final heartbeat = heartbeats[participantId] as Timestamp?;
              if (heartbeat != null) {
                final age = DateTime.now().difference(heartbeat.toDate());
                if (age.inMinutes < 5) {
                  allStale = false;
                  break;
                }
              }
            }
          }
          
          // If all participants are stale, delete the room
          if (allStale && participants.isNotEmpty) {
            final messagesSnapshot = await roomDoc.reference.collection('messages').get();
            for (final msg in messagesSnapshot.docs) {
              await msg.reference.delete();
            }
            await roomDoc.reference.delete();
          }
        } catch (e) {
          // Ignore individual room errors
        }
      }
    } catch (e) {
      // Ignore cleanup errors, not critical
    }
  }

  // Cancel matchmaking
  Future<void> cancelMatchmaking() async {
    _stopHeartbeat();
    await _roomListener?.cancel();
    await _firestore.collection('matchmaking').doc(userId).delete();
  }

  // Start heartbeat to keep matchmaking entry alive
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        await _firestore.collection('matchmaking').doc(userId).update({
          'lastHeartbeat': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Doc might be deleted if we got matched, stop heartbeat
        _stopHeartbeat();
      }
    });
  }

  // Stop heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Start chat heartbeat to detect force quits
  void _startChatHeartbeat(String roomId) {
    _stopChatHeartbeat();
    // Update immediately
    _updateChatHeartbeat(roomId);
    // Then update every 5 seconds
    _chatHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _updateChatHeartbeat(roomId);
    });
  }

  // Update chat heartbeat
  void _updateChatHeartbeat(String roomId) async {
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'heartbeats.$userId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Room might be deleted, stop heartbeat
      _stopChatHeartbeat();
    }
  }

  // Stop chat heartbeat
  void _stopChatHeartbeat() {
    _chatHeartbeatTimer?.cancel();
    _chatHeartbeatTimer = null;
  }

  // Send a message
  Future<void> sendMessage(String roomId, String text) async {
    if (text.trim().isEmpty) return;
    
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .add({
      'text': text.trim(),
      'senderId': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Update our heartbeat when sending a message
    _updateChatHeartbeat(roomId);
    
    // Clear typing indicator after sending
    await setTyping(roomId, false);
  }

  // Set typing indicator
  Future<void> setTyping(String roomId, bool isTyping) async {
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'typing.$userId': isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } catch (e) {
      // Room might be deleted, ignore
    }
  }

  // Check if partner is typing
  Stream<bool> isPartnerTyping(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      
      final data = snapshot.data();
      if (data == null) return false;
      
      final typing = data['typing'] as Map<String, dynamic>?;
      if (typing == null) return false;
      
      final participants = (data['participants'] as List?)?.cast<String>() ?? [];
      final partnerId = participants.firstWhere(
        (id) => id != userId,
        orElse: () => '',
      );
      
      if (partnerId.isEmpty || !typing.containsKey(partnerId)) return false;
      
      final partnerTypingTime = typing[partnerId] as Timestamp?;
      if (partnerTypingTime == null) return false;
      
      // Consider typing if timestamp is within last 3 seconds
      final age = DateTime.now().difference(partnerTypingTime.toDate());
      return age.inSeconds < 3;
    });
  }

  // Listen to messages
  Stream<List<ChatMessage>> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Leave chat and cleanup
  Future<void> leaveChat() async {
    if (_currentRoomId != null) {
      // Delete the entire room and its messages
      final roomRef = _firestore.collection('chat_rooms').doc(_currentRoomId);
      
      try {
        final messagesSnapshot = await roomRef.collection('messages').get();
        
        for (final doc in messagesSnapshot.docs) {
          await doc.reference.delete();
        }
        
        await roomRef.delete();
      } catch (e) {
        // Ignore errors if room is already deleted
      }
      
      _currentRoomId = null;
    }
    
    await cancelMatchmaking();
    await _roomListener?.cancel();
  }

  // Cleanup only if both users have left
  Future<void> cleanupIfBothLeft() async {
    if (_currentRoomId != null) {
      try {
        final roomDoc = await _firestore.collection('chat_rooms').doc(_currentRoomId).get();
        
        if (roomDoc.exists) {
          final data = roomDoc.data();
          final leftBy = (data?['leftBy'] as List?)?.cast<String>() ?? [];
          final closedBy = (data?['closedBy'] as List?)?.cast<String>() ?? [];
          final participants = (data?['participants'] as List?)?.cast<String>() ?? [];
          final heartbeats = data?['heartbeats'] as Map<String, dynamic>? ?? {};
          
          // Mark that we've closed/moved on from this chat
          await roomDoc.reference.update({
            'closedBy': FieldValue.arrayUnion([userId]),
          });
          
          // Check if both users have closed OR if partner has stale heartbeat
          bool bothClosed = closedBy.length + 1 >= participants.length;
          bool partnerStale = false;
          
          // Find partner and check their heartbeat
          final partnerId = participants.firstWhere(
            (id) => id != userId,
            orElse: () => '',
          );
          
          if (partnerId.isNotEmpty && heartbeats.containsKey(partnerId)) {
            final partnerHeartbeat = heartbeats[partnerId] as Timestamp?;
            if (partnerHeartbeat != null) {
              final age = DateTime.now().difference(partnerHeartbeat.toDate());
              partnerStale = age.inSeconds > 30; // Partner hasn't updated in 30 sec
            }
          } else if (partnerId.isNotEmpty && !heartbeats.containsKey(partnerId)) {
            // Partner never sent a heartbeat (force quit before entering chat)
            partnerStale = true;
          }
          
          // Delete if both closed OR if we closed and partner is stale
          if (bothClosed || partnerStale) {
            final messagesSnapshot = await roomDoc.reference.collection('messages').get();
            
            for (final doc in messagesSnapshot.docs) {
              await doc.reference.delete();
            }
            
            await roomDoc.reference.delete();
          }
        }
      } catch (e) {
        // Ignore errors if room is already deleted
      }
      
      _currentRoomId = null;
    }
    
    _stopChatHeartbeat();
    await cancelMatchmaking();
    await _roomListener?.cancel();
  }

  // Mark that we're leaving (but don't delete room yet)
  Future<void> markAsLeft() async {
    if (_currentRoomId != null) {
      try {
        await _firestore.collection('chat_rooms').doc(_currentRoomId).update({
          'leftBy': FieldValue.arrayUnion([userId]),
        });
        // Stop chat heartbeat when leaving
        _stopChatHeartbeat();
      } catch (e) {
        // Room might already be deleted
      }
    }
  }

  // Monitor room status for changes
  Stream<RoomStatus> getRoomStatus(String roomId) {
    // Start chat heartbeat when monitoring room
    _startChatHeartbeat(roomId);
    
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return RoomStatus.deleted;
      
      final data = snapshot.data();
      if (data == null) return RoomStatus.deleted;
      
      // Check if partner has left
      final leftBy = (data['leftBy'] as List?)?.cast<String>() ?? [];
      final participants = (data['participants'] as List?)?.cast<String>() ?? [];
      
      // Find partner's ID
      final partnerId = participants.firstWhere(
        (id) => id != userId,
        orElse: () => '',
      );
      
      // Check if partner has left explicitly
      if (partnerId.isNotEmpty && leftBy.contains(partnerId)) {
        return RoomStatus.partnerLeft;
      }
      
      // Check if partner's heartbeat is stale (force quit detection)
      final heartbeats = data['heartbeats'] as Map<String, dynamic>?;
      if (heartbeats != null && partnerId.isNotEmpty) {
        final partnerHeartbeat = heartbeats[partnerId] as Timestamp?;
        if (partnerHeartbeat != null) {
          final age = DateTime.now().difference(partnerHeartbeat.toDate());
          if (age.inSeconds > 15) {
            // Partner's heartbeat is stale, they likely force quit
            return RoomStatus.partnerLeft;
          }
        }
      }
      
      return RoomStatus.active;
    });
  }

  void dispose() {
    _stopHeartbeat();
    _stopChatHeartbeat();
    _roomListener?.cancel();
  }
}
