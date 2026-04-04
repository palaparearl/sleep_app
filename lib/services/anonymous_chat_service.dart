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

  String get userId => _currentUserId ??= _generateUserId();
  String? get roomId => _currentRoomId;

  String _generateUserId() {
    final random = Random();
    return 'anon_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(9999)}';
  }

  // Start looking for a match
  Future<String> findMatch() async {
    final uid = userId;
    
    // Try to find an existing waiting user
    final waitingQuery = await _firestore
        .collection('matchmaking')
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (waitingQuery.docs.isNotEmpty) {
      // Found someone waiting - create a room with them
      final partnerId = waitingQuery.docs.first.id;
      final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create chat room
      await _firestore.collection('chat_rooms').doc(roomId).set({
        'participants': [uid, partnerId],
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch,
        'leftBy': [], // Track who has left the chat
        'closedBy': [], // Track who has closed/moved on from viewing
      });

      // Delete both matchmaking docs (not update)
      await _firestore.collection('matchmaking').doc(partnerId).update({
        'status': 'matched',
        'roomId': roomId,
      });
      await _firestore.collection('matchmaking').doc(uid).delete();
      
      _currentRoomId = roomId;
      return roomId;
    } else {
      // No one waiting - add ourselves to the queue
      await _firestore.collection('matchmaking').doc(uid).set({
        'status': 'waiting',
        'timestamp': FieldValue.serverTimestamp(),
      });

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
  }

  // Cancel matchmaking
  Future<void> cancelMatchmaking() async {
    await _roomListener?.cancel();
    await _firestore.collection('matchmaking').doc(userId).delete();
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
          
          // Mark that we've closed/moved on from this chat
          await roomDoc.reference.update({
            'closedBy': FieldValue.arrayUnion([userId]),
          });
          
          // Only delete if both users have closed the chat
          if (closedBy.length + 1 >= participants.length) {
            // Both have closed, safe to delete
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
      } catch (e) {
        // Room might already be deleted
      }
    }
  }

  // Monitor room status for changes
  Stream<RoomStatus> getRoomStatus(String roomId) {
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
      
      // Check if partner has left
      if (partnerId.isNotEmpty && leftBy.contains(partnerId)) {
        return RoomStatus.partnerLeft;
      }
      
      return RoomStatus.active;
    });
  }

  void dispose() {
    _roomListener?.cancel();
  }
}
