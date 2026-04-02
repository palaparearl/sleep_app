import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatService {
  static const _dbUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue: 'https://pahingapp-sleep-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _dbUrl,
  );
  final String _userId = _generateUserId();

  String? _currentRoomId;
  StreamSubscription? _waitingSub;
  StreamSubscription? _roomSub;
  StreamSubscription? _presenceSub;

  String get userId => _userId;
  String? get currentRoomId => _currentRoomId;

  static String _generateUserId() {
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// Start looking for a match. Returns a Stream that emits the room ID once matched.
  Stream<String?> findMatch() {
    final controller = StreamController<String?>.broadcast();

    _startMatchmaking(controller);

    return controller.stream;
  }

  Future<void> _startMatchmaking(StreamController<String?> controller) async {
    // Look for someone already waiting
    final waitingSnapshot = await _db
        .collection('waiting')
        .orderBy('timestamp')
        .limit(1)
        .get();

    if (waitingSnapshot.docs.isNotEmpty) {
      final waitingDoc = waitingSnapshot.docs.first;
      final otherUserId = waitingDoc.id;

      // Don't match with ourselves
      if (otherUserId == _userId) {
        // We're already in the queue — just wait
        _listenForRoom(controller);
        return;
      }

      // Create a chat room
      final roomRef = await _db.collection('chatRooms').add({
        'users': [otherUserId, _userId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentRoomId = roomRef.id;

      // Update the waiting user's doc so they know the room
      await waitingDoc.reference.update({'roomId': roomRef.id});

      // Remove them from waiting
      // (they'll clean up their own listener)

      controller.add(roomRef.id);
    } else {
      // No one waiting — add ourselves to the queue
      await _db.collection('waiting').doc(_userId).set({
        'timestamp': FieldValue.serverTimestamp(),
        'roomId': null,
      });

      // Listen for a room assignment
      _listenForRoom(controller);
    }
  }

  void _listenForRoom(StreamController<String?> controller) {
    _waitingSub = _db
        .collection('waiting')
        .doc(_userId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['roomId'] != null) {
        _currentRoomId = data['roomId'] as String;
        controller.add(_currentRoomId);
        _waitingSub?.cancel();

        // Clean up our waiting doc
        _db.collection('waiting').doc(_userId).delete();
      }
    });
  }

  /// Send a message to the current room.
  Future<void> sendMessage(String text) async {
    if (_currentRoomId == null || text.trim().isEmpty) return;

    await _db
        .collection('chatRooms')
        .doc(_currentRoomId)
        .collection('messages')
        .add({
      'senderId': _userId,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of messages in the current room.
  Stream<List<ChatMessage>> getMessages() {
    if (_currentRoomId == null) return const Stream.empty();

    return _db
        .collection('chatRooms')
        .doc(_currentRoomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return ChatMessage(
                senderId: data['senderId'] ?? '',
                text: data['text'] ?? '',
                timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                isMe: data['senderId'] == _userId,
              );
            }).toList());
  }

  /// Listen for the other user disconnecting.
  /// Uses Firestore `ended` flag + Realtime Database presence.
  Stream<bool> roomActive() {
    if (_currentRoomId == null) return const Stream.empty();

    return _db
        .collection('chatRooms')
        .doc(_currentRoomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data();
      return data?['ended'] != true;
    });
  }

  /// Monitor partner presence via RTDB. Returns a stream that emits
  /// `false` when the partner goes offline.
  Stream<bool> partnerPresence() {
    if (_currentRoomId == null) return const Stream.empty();

    final controller = StreamController<bool>.broadcast();

    // We need to find the partner's userId first
    _db.collection('chatRooms').doc(_currentRoomId).get().then((doc) {
      final data = doc.data();
      if (data == null) return;
      final users = data['users'] as List<dynamic>?;
      if (users == null) return;
      final partnerId = users.cast<String>().firstWhere(
            (id) => id != _userId,
            orElse: () => '',
          );
      if (partnerId.isEmpty) return;

      // Listen to partner's presence node in RTDB
      final ref = _rtdb.ref('presence/$_currentRoomId/$partnerId');
      _presenceSub = ref.onValue.listen((event) {
        final value = event.snapshot.value;
        // null means the node doesn't exist yet (partner still joining) — treat as online
        // true means online, false means explicitly went offline
        if (value == null) return;
        controller.add(value == true);
      });
    });

    return controller.stream;
  }

  /// Set our presence as online and register an onDisconnect handler
  /// so Firebase server marks us offline the instant we lose connection.
  Future<void> goOnline() async {
    if (_currentRoomId == null) return;
    final ref = _rtdb.ref('presence/$_currentRoomId/$_userId');
    await ref.set(true);
    await ref.onDisconnect().set(false);
  }

  /// Explicitly go offline (called when user taps End or navigates away).
  Future<void> goOffline() async {
    if (_currentRoomId == null) return;
    final ref = _rtdb.ref('presence/$_currentRoomId/$_userId');
    await ref.set(false);
    await ref.onDisconnect().cancel();
  }

  /// End the chat — marks room as ended and cleans up.
  Future<void> endChat() async {
    await goOffline();
    _presenceSub?.cancel();
    _presenceSub = null;
    _waitingSub?.cancel();
    _roomSub?.cancel();

    // Remove from waiting queue if still there
    await _db.collection('waiting').doc(_userId).delete();

    if (_currentRoomId != null) {
      // Mark room as ended so the other user gets notified
      await _db.collection('chatRooms').doc(_currentRoomId).update({
        'ended': true,
      });
      _currentRoomId = null;
    }
  }

  /// Full cleanup — delete room and its messages.
  Future<void> cleanup() async {
    await goOffline();
    _presenceSub?.cancel();
    _presenceSub = null;
    _waitingSub?.cancel();
    _roomSub?.cancel();
    await _db.collection('waiting').doc(_userId).delete();
    _currentRoomId = null;
  }
}

class ChatMessage {
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}
