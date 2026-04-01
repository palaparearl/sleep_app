import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  _ChatState _state = _ChatState.idle;
  StreamSubscription? _matchSub;
  StreamSubscription? _roomActiveSub;
  StreamSubscription? _incomingCallSub;

  @override
  void dispose() {
    _matchSub?.cancel();
    _roomActiveSub?.cancel();
    _incomingCallSub?.cancel();
    _chatService.cleanup();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _findMatch() {
    setState(() => _state = _ChatState.searching);

    _matchSub = _chatService.findMatch().listen((roomId) {
      if (roomId != null && mounted) {
        setState(() => _state = _ChatState.chatting);

        // Listen for partner disconnect
        _roomActiveSub = _chatService.roomActive().listen((active) {
          if (!active && mounted) {
            setState(() => _state = _ChatState.partnerLeft);
          }
        });

        // Listen for incoming calls
        _listenForIncomingCalls();
      }
    });
  }

  void _listenForIncomingCalls() {
    final roomId = _chatService.currentRoomId;
    if (roomId == null) return;

    final callService = CallService();
    _incomingCallSub = callService.listenForIncomingCall(roomId).listen((callData) {
      if (callData != null &&
          callData['callerId'] != _chatService.userId &&
          mounted) {
        _showIncomingCallDialog(callData['type'] == 'video');
      }
    });
  }

  void _showIncomingCallDialog(bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.phone,
              size: 48,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 16),
            Text(
              'Incoming ${isVideo ? "Video" : "Voice"} Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Anonymous Stranger',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _declineCall();
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _answerCall(isVideo);
            },
            icon: Icon(isVideo ? Icons.videocam : Icons.phone),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _startCall(bool isVideo) {
    final roomId = _chatService.currentRoomId;
    if (roomId == null) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(
        roomId: roomId,
        userId: _chatService.userId,
        isVideo: isVideo,
        isCaller: true,
      ),
    ));
  }

  void _answerCall(bool isVideo) {
    final roomId = _chatService.currentRoomId;
    if (roomId == null) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(
        roomId: roomId,
        userId: _chatService.userId,
        isVideo: isVideo,
        isCaller: false,
      ),
    ));
  }

  void _declineCall() {
    final roomId = _chatService.currentRoomId;
    if (roomId == null) return;

    CallService().declineCall(roomId: roomId);
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _chatService.sendMessage(text);
    _msgController.clear();
  }

  void _endChat() async {
    _matchSub?.cancel();
    _roomActiveSub?.cancel();
    _incomingCallSub?.cancel();
    await _chatService.endChat();
    if (mounted) setState(() => _state = _ChatState.idle);
  }

  void _newChat() {
    _matchSub?.cancel();
    _roomActiveSub?.cancel();
    _incomingCallSub?.cancel();
    _chatService.cleanup();
    setState(() => _state = _ChatState.idle);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (_state) {
      case _ChatState.idle:
        return _buildIdleView(isDark);
      case _ChatState.searching:
        return _buildSearchingView(isDark);
      case _ChatState.chatting:
        return _buildChattingView(isDark);
      case _ChatState.partnerLeft:
        return _buildPartnerLeftView(isDark);
    }
  }

  Widget _buildIdleView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: Colors.deepPurple.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              "Can't sleep?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chat anonymously with someone else who is awake right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _findMatch,
              icon: const Icon(Icons.search),
              label: const Text('Find Someone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chats are anonymous and not saved.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Colors.deepPurple,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Looking for someone...',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _endChat,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildChattingView(bool isDark) {
    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepPurple.withValues(alpha: 0.2),
                child: const Icon(Icons.person, size: 18, color: Colors.deepPurple),
              ),
              const SizedBox(width: 10),
              Text(
                'Anonymous Stranger',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _startCall(false),
                icon: const Icon(Icons.phone, size: 20),
                color: Colors.deepPurple,
                tooltip: 'Voice Call',
              ),
              IconButton(
                onPressed: () => _startCall(true),
                icon: const Icon(Icons.videocam, size: 22),
                color: Colors.deepPurple,
                tooltip: 'Video Call',
              ),
              TextButton(
                onPressed: _endChat,
                style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
                child: const Text('End'),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _chatService.getMessages(),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'Say hi! 👋',
                    style: TextStyle(
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                );
              }

              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return _buildMessageBubble(msg, isDark);
                },
              );
            },
          ),
        ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      filled: true,
                      fillColor:
                          isDark ? Colors.grey[850] : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded),
                  color: Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isMe
              ? Colors.deepPurple
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
            bottomRight: Radius.circular(msg.isMe ? 4 : 16),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isMe
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerLeftView(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 56,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 16),
          Text(
            'Stranger has left the chat',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _newChat();
              _findMatch();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Find Someone New'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _newChat,
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

enum _ChatState { idle, searching, chatting, partnerLeft }
