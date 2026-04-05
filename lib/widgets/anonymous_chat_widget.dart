import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/chat_message.dart';
import '../services/anonymous_chat_service.dart';
import '../services/webrtc_service.dart';

class AnonymousChatWidget extends StatefulWidget {
  const AnonymousChatWidget({super.key});

  @override
  State<AnonymousChatWidget> createState() => _AnonymousChatWidgetState();
}

class _AnonymousChatWidgetState extends State<AnonymousChatWidget>
    with AutomaticKeepAliveClientMixin {
  final _chatService = AnonymousChatService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  ChatState _state = ChatState.idle;
  String? _roomId;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _callSubscription;
  List<ChatMessage> _messages = [];
  Timer? _timeoutTimer;
  Timer? _typingTimer;
  bool _isPartnerTyping = false;
  WebRTCService? _webrtcService;
  bool _inCall = false;
  bool _isVideoCall = false;
  MediaStream? _remoteStream;
  bool _showingCallDialog = false;
  String? _pendingCallId;

  final _remoteRenderer = RTCVideoRenderer();
  final _localRenderer = RTCVideoRenderer();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _roomSubscription?.cancel();
    _typingSubscription?.cancel();
    _callSubscription?.cancel();
    _timeoutTimer?.cancel();
    _typingTimer?.cancel();
    _webrtcService?.dispose();
    _remoteRenderer.dispose();
    _localRenderer.dispose();
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

      // Listen for typing indicator
      _typingSubscription = _chatService.isPartnerTyping(roomId).listen((isTyping) {
        if (mounted) {
          setState(() => _isPartnerTyping = isTyping);
        }
      });

      // Listen for incoming calls
      _callSubscription = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(roomId)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        final data = snapshot.data();
        final callData = data?['call'];
        
        // Handle incoming call
        if (callData != null && 
            callData['status'] == 'ringing' && 
            callData['caller'] != _chatService.userId && 
            !_inCall && 
            !_showingCallDialog &&
            _pendingCallId != callData['caller']) {
          _pendingCallId = callData['caller'];
          _handleIncomingCall(callData);
        }
        
        // Handle call ended by partner
        if (callData == null && _inCall) {
          _endCall();
        }
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
    _stopTypingIndicator();
  }

  void _onTextChanged(String text) {
    if (_roomId == null) return;
    
    // Cancel existing timer
    _typingTimer?.cancel();
    
    if (text.trim().isNotEmpty) {
      // User is typing, set indicator
      _chatService.setTyping(_roomId!, true);
      
      // Auto-clear after 3 seconds of no typing
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _stopTypingIndicator();
      });
    } else {
      // Text is empty, clear indicator
      _stopTypingIndicator();
    }
  }

  void _stopTypingIndicator() {
    _typingTimer?.cancel();
    if (_roomId != null) {
      _chatService.setTyping(_roomId!, false);
    }
  }

  Future<void> _startCall({required bool video}) async {
    if (_roomId == null) return;

    try {
      // Get permissions FIRST before setting any state
      _webrtcService = WebRTCService();
      await _webrtcService!.initialize(video: video);

      if (!mounted) {
        await _webrtcService?.dispose();
        return;
      }

      setState(() {
        _inCall = true;
        _isVideoCall = video;
      });

      _localRenderer.srcObject = _webrtcService!.localStream;

      _webrtcService!.remoteStream.listen((stream) {
        if (mounted && stream != null) {
          _remoteRenderer.srcObject = stream;
          setState(() => _remoteStream = stream);
        }
      });

      // Create initial call document without offer
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(_roomId)
          .update({
        'call': {
          'status': 'ringing',
          'caller': _chatService.userId,
          'video': video,
          'calleeReady': false,
        },
      });

      // Wait for callee to be ready (permissions granted) with longer timeout
      final calleeReadyCompleter = Completer<bool>();
      StreamSubscription? readySubscription;
      
      readySubscription = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(_roomId)
          .snapshots()
          .listen((snapshot) {
        final data = snapshot.data();
        final callData = data?['call'];
        
        if (callData == null) {
          // Call was declined or cancelled
          if (!calleeReadyCompleter.isCompleted) {
            calleeReadyCompleter.complete(false);
          }
        } else if (callData['calleeReady'] == true) {
          if (!calleeReadyCompleter.isCompleted) {
            calleeReadyCompleter.complete(true);
          }
        }
      });

      // Increased timeout to 2 minutes for permission granting
      final isReady = await calleeReadyCompleter.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () => false,
      );

      await readySubscription?.cancel();

      if (!isReady || !mounted) {
        await _endCall();
        return;
      }

      // Now create and send the offer
      await _webrtcService!.createOffer(_roomId!, _chatService.userId, video);
    } catch (e) {
      print('Error starting call: $e');
      await _endCall();
    }
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> callData) async {
    _showingCallDialog = true;
    final isVideo = callData['video'] ?? false;
    
    // Show permission request dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isVideo ? Icons.videocam : Icons.call, color: Colors.green),
            const SizedBox(width: 8),
            Text('Incoming ${isVideo ? 'Video' : 'Voice'} Call'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Requesting permissions...'),
          ],
        ),
      ),
    );

    MediaStream? permissionStream;
    bool permissionGranted = false;
    
    try {
      // Request permissions
      permissionStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo ? {'facingMode': 'user'} : false,
      });
      permissionGranted = true;
      
      // Release the stream
      permissionStream.getTracks().forEach((track) => track.stop());
    } catch (e) {
      print('Permission denied: $e');
      permissionGranted = false;
    }

    // Close permission dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (!permissionGranted) {
      _showingCallDialog = false;
      _pendingCallId = null;
      // Auto-decline
      if (_roomId != null) {
        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(_roomId)
            .update({'call': FieldValue.delete()});
      }
      return;
    }

    // Now show accept/decline dialog
    if (!mounted) return;
    _showIncomingCallDialog(callData);
  }

  Future<void> _showIncomingCallDialog(Map<String, dynamic> callData) async {
    if (_inCall) {
      _showingCallDialog = false;
      _pendingCallId = null;
      return;
    }
    
    final isVideo = callData['video'] ?? false;
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isVideo ? Icons.videocam : Icons.call, color: Colors.green),
            const SizedBox(width: 8),
            Text('Incoming ${isVideo ? 'Video' : 'Voice'} Call'),
          ],
        ),
        content: const Text('Stranger is calling you'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.call),
            label: const Text('Accept'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );

    _showingCallDialog = false;
    _pendingCallId = null;

    if (accept == true) {
      setState(() {
        _inCall = true;
        _isVideoCall = isVideo;
      });

      try {
        _webrtcService = WebRTCService();
        await _webrtcService!.initialize(video: isVideo);

        _localRenderer.srcObject = _webrtcService!.localStream;

        _webrtcService!.remoteStream.listen((stream) {
          if (mounted && stream != null) {
            _remoteRenderer.srcObject = stream;
            setState(() => _remoteStream = stream);
          }
        });

        // Send ready signal to caller
        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(_roomId)
            .update({
          'call.calleeReady': true,
        });

        // Wait for offer from caller
        final offerCompleter = Completer<Map<String, dynamic>?>();
        StreamSubscription? offerSubscription;
        
        offerSubscription = FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(_roomId)
            .snapshots()
            .listen((snapshot) {
          final data = snapshot.data();
          final offer = data?['call']?['offer'];
          
          if (offer != null && !offerCompleter.isCompleted) {
            offerCompleter.complete(offer);
          } else if (data?['call'] == null && !offerCompleter.isCompleted) {
            offerCompleter.complete(null);
          }
        });

        final offer = await offerCompleter.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () => null,
        );

        await offerSubscription?.cancel();

        if (offer == null || !mounted) {
          await _endCall();
          return;
        }

        await _webrtcService!.handleOffer(_roomId!, _chatService.userId, offer);
      } catch (e) {
        print('Error accepting call: $e');
        await _endCall();
      }
    } else {
      // Declined - clear the call offer
      if (_roomId != null) {
        await FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(_roomId)
            .update({'call': FieldValue.delete()});
      }
    }
  }

  Future<void> _endCall() async {
    // Immediately update UI state
    if (mounted) {
      setState(() {
        _inCall = false;
        _remoteStream = null;
      });
    }
    
    // Clean up renderers
    _remoteRenderer.srcObject = null;
    _localRenderer.srcObject = null;
    
    // Clean up WebRTC and Firestore in background
    final roomId = _roomId;
    final webrtc = _webrtcService;
    _webrtcService = null;
    
    // Don't await these - let them run in background
    if (roomId != null) {
      webrtc?.endCall(roomId).catchError((e) => print('Error ending call: $e'));
    }
    webrtc?.dispose().catchError((e) => print('Error disposing WebRTC: $e'));
  }

  Future<void> _disconnect() async {
    if (_state != ChatState.chatting) return;

    if (_inCall) {
      await _endCall();
    }
    
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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
    if (_inCall) {
      return _buildCallView(isDark);
    }

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
                icon: const Icon(Icons.videocam, size: 20),
                tooltip: 'Video Call',
                color: Colors.green[300],
                onPressed: () => _startCall(video: true),
              ),
              IconButton(
                icon: const Icon(Icons.call, size: 20),
                tooltip: 'Voice Call',
                color: Colors.blue[300],
                onPressed: () => _startCall(video: false),
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
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
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
                    // Typing indicator
                    if (_isPartnerTyping)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TypingDot(delay: 0),
                                const SizedBox(width: 4),
                                _TypingDot(delay: 200),
                                const SizedBox(width: 4),
                                _TypingDot(delay: 400),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
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
                  onChanged: _onTextChanged,
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

  Widget _buildCallView(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Remote video (full screen)
              if (_remoteStream != null)
                RTCVideoView(_remoteRenderer, mirror: false)
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              // Local video (small overlay)
              if (_isVideoCall && _webrtcService?.localStream != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: RTCVideoView(_localRenderer, mirror: true),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Call controls
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_isVideoCall)
                _CallButton(
                  icon: _webrtcService?.isVideoEnabled ?? false
                      ? Icons.videocam
                      : Icons.videocam_off,
                  color: Colors.white,
                  onPressed: () async {
                    await _webrtcService?.toggleVideo();
                    setState(() {});
                  },
                ),
              _CallButton(
                icon: _webrtcService?.isAudioEnabled ?? false
                    ? Icons.mic
                    : Icons.mic_off,
                color: Colors.white,
                onPressed: () async {
                  await _webrtcService?.toggleAudio();
                  setState(() {});
                },
              ),
              _CallButton(
                icon: Icons.call_end,
                color: Colors.red,
                onPressed: _endCall,
              ),
            ],
          ),
        ),
      ],
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

// Animated typing indicator dot
class _TypingDot extends StatefulWidget {
  final int delay;
  
  const _TypingDot({required this.delay});
  
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[600],
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        iconSize: 32,
        onPressed: onPressed,
      ),
    );
  }
}
