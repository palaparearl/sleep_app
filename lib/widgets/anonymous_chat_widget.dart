import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/anonymous_chat_service.dart';

class AnonymousChatWidget extends StatefulWidget {
  const AnonymousChatWidget({super.key});

  @override
  State<AnonymousChatWidget> createState() => _AnonymousChatWidgetState();
}

class _AnonymousChatWidgetState extends State<AnonymousChatWidget> {
  final _chatService = AnonymousChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  ChatState _state = ChatState.idle;
  String? _roomId;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _roomSubscription;
  List<ChatMessage> _messages = [];
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _roomSubscription?.cancel();
    _timeoutTimer?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _startMatching() async {
    setState(() => _state = ChatState.matching);

    try {
      final roomId = await _chatService.findMatch();
      
      if (!mounted) return;
      
      setState(() {
        _roomId = roomId;
        _state = ChatState.chatting;
      });

      // Listen to messages
      _messageSubscription = _chatService.getMessages(roomId).listen((messages) {
        setState(() => _messages = messages);
        _scrollToBottom();
      });

      // Listen for partner disconnect
      _roomSubscription = _chatService.getRoomStatus(roomId).listen((status) {
        if (!mounted) return;
        
        // Only handle partner left if we're still in chatting state
        if (status == RoomStatus.partnerLeft && _state == ChatState.chatting) {
          _handlePartnerDisconnect();
        }
      });

      // Auto-disconnect after 30 minutes
      _timeoutTimer = Timer(const Duration(minutes: 30), () {
        if (mounted) _disconnect();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = ChatState.error);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _roomId == null) return;

    _messageController.clear();
    await _chatService.sendMessage(_roomId!, text);
  }

  Future<void> _disconnect() async {
    if (_state != ChatState.chatting) return;
    
    // Mark that we're leaving
    await _chatService.markAsLeft();
    
    // Cancel room subscription but keep message subscription to preserve history
    await _roomSubscription?.cancel();
    _timeoutTimer?.cancel();
    
    if (!mounted) return;
    setState(() {
      _state = ChatState.youLeft;
      // Keep roomId and messages so they can still see the chat
    });
  }

  void _handlePartnerDisconnect() {
    // Cancel room subscription but keep message subscription to preserve history
    _roomSubscription?.cancel();
    _timeoutTimer?.cancel();
    
    if (!mounted) return;
    setState(() {
      _state = ChatState.partnerLeft;
      // Keep roomId and messages so they can still see the chat
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: _buildContent(isDark),
        ),
      ],
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_state) {
      case ChatState.idle:
        return _buildIdleState(isDark);
      case ChatState.matching:
        return _buildMatchingState(isDark);
      case ChatState.chatting:
        return _buildChatState(isDark);
      case ChatState.partnerLeft:
        return _buildChatEndedState(isDark, isPartnerLeft: true);
      case ChatState.youLeft:
        return _buildChatEndedState(isDark, isPartnerLeft: false);
      case ChatState.error:
        return _buildErrorState(isDark);
    }
  }

  Widget _buildIdleState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: isDark ? Colors.deepPurple[300] : Colors.deepPurple[200],
            ),
            const SizedBox(height: 24),
            Text(
              'Chat with a Stranger',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect anonymously with someone else who can\'t sleep',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _startMatching,
              icon: const Icon(Icons.search),
              label: const Text('Find Someone to Chat'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.deepPurple[300]),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoItem('• Completely anonymous — no accounts needed'),
                  _infoItem('• Chat disappears after 30 minutes'),
                  _infoItem('• Be kind and respectful'),
                  _infoItem('• You can disconnect anytime'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildMatchingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.deepPurple[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Looking for someone...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Searching for someone who can\'t sleep',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                _chatService.cancelMatchmaking();
                setState(() => _state = ChatState.idle);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatEndedState(bool isDark, {required bool isPartnerLeft}) {
    return Column(
      children: [
        // Header with status
        Container(
          padding: const EdgeInsets.all(12),
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[600],
                child: const Icon(Icons.person_off, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPartnerLeft ? 'Stranger left' : 'You left the chat',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Chat ended',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Messages (read-only)
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages were sent',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderId == _chatService.userId;
                    return _buildMessageBubble(message, isMe, isDark);
                  },
                ),
        ),
        // Banner with action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.deepPurple[900]?.withOpacity(0.3) : Colors.deepPurple[50],
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPartnerLeft
                          ? 'The stranger has disconnected'
                          : 'You ended this conversation',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        // Mark ourselves as left if we haven't already
                        if (_state == ChatState.partnerLeft) {
                          await _chatService.markAsLeft();
                        }
                        // Clean up current chat only if both have left
                        await _chatService.cleanupIfBothLeft();
                        
                        // Cancel all subscriptions before starting new match
                        await _messageSubscription?.cancel();
                        await _roomSubscription?.cancel();
                        _timeoutTimer?.cancel();
                        
                        setState(() {
                          _roomId = null;
                          _messages = [];
                        });
                        // Start new match
                        _startMatching();
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Find New Match'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      // Mark ourselves as left if we haven't already
                      if (_state == ChatState.partnerLeft) {
                        await _chatService.markAsLeft();
                      }
                      await _chatService.cleanupIfBothLeft();
                      
                      // Cancel all subscriptions
                      await _messageSubscription?.cancel();
                      await _roomSubscription?.cancel();
                      _timeoutTimer?.cancel();
                      
                      setState(() {
                        _state = ChatState.idle;
                        _roomId = null;
                        _messages = [];
                      });
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => setState(() => _state = ChatState.idle),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatState(bool isDark) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepPurple[300],
                child: const Icon(Icons.person, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stranger',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Anonymous chat',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 20),
                tooltip: 'End Chat',
                color: Colors.red[300],
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('End chat?'),
                      content: const Text('This will disconnect you from the stranger.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('End Chat'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) _disconnect();
                },
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'Say hello! 👋',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message.senderId == _chatService.userId;
                    return _buildMessageBubble(message, isMe, isDark);
                  },
                ),
        ),
        // Input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                color: Colors.deepPurple,
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.deepPurple
              : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

enum ChatState {
  idle,
  matching,
  chatting,
  partnerLeft,
  youLeft,
  error,
}
