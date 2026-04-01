import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String roomId;
  final String userId;
  final bool isVideo;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.isVideo,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _connected = false;
  bool _ending = false;
  StreamSubscription? _remoteStreamSub;
  StreamSubscription? _callEndedSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _callService.initialize();

    _remoteStreamSub = _callService.onRemoteStream.listen((_) {
      if (mounted) setState(() => _connected = true);
    });

    _callEndedSub = _callService.onCallEnded.listen((_) {
      if (mounted) _onCallEnded();
    });

    if (widget.isCaller) {
      await _callService.startCall(
        roomId: widget.roomId,
        callerId: widget.userId,
        video: widget.isVideo,
      );
    } else {
      await _callService.answerCall(
        roomId: widget.roomId,
        video: widget.isVideo,
      );
    }

    if (mounted) setState(() {});
  }

  void _onCallEnded() {
    if (!mounted || _ending) return;
    _ending = true;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call ended')),
    );
  }

  Future<void> _hangUp() async {
    if (_ending) return;
    _ending = true;
    await _callService.hangUp(roomId: widget.roomId);
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleMute() {
    setState(() => _isMuted = _callService.toggleMute());
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = _callService.toggleCamera());
  }

  void _switchCamera() {
    _callService.switchCamera();
  }

  @override
  void dispose() {
    _remoteStreamSub?.cancel();
    _callEndedSub?.cancel();
    // Fire-and-forget: dispose is synchronous but CallService cleanup is async.
    // The _disposed guard in CallService prevents double cleanup.
    _callService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main view
            if (widget.isVideo) ...[
              // Remote video (full screen)
              Positioned.fill(
                child: _connected
                    ? RTCVideoView(
                        _callService.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepPurple,
                        ),
                      ),
              ),

              // Local video (small pip)
              Positioned(
                top: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 100,
                    height: 140,
                    child: _isCameraOff
                        ? Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.videocam_off,
                                color: Colors.white54, size: 32),
                          )
                        : RTCVideoView(
                            _callService.localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),
              ),
            ] else ...[
              // Voice call view
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Colors.deepPurple.withValues(alpha: 0.3),
                      child: const Icon(Icons.person,
                          size: 48, color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Anonymous Stranger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connected ? 'Connected' : 'Connecting...',
                      style: TextStyle(
                        color: _connected
                            ? Colors.green[400]
                            : Colors.white54,
                        fontSize: 15,
                      ),
                    ),
                    if (!_connected) ...[
                      const SizedBox(height: 16),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.deepPurple,
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _CallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    color: _isMuted ? Colors.red : Colors.white24,
                    onPressed: _toggleMute,
                  ),

                  // Hang up
                  _CallButton(
                    icon: Icons.call_end,
                    label: 'End',
                    color: Colors.red,
                    size: 64,
                    onPressed: _hangUp,
                  ),

                  // Camera toggle (video only) or speaker
                  if (widget.isVideo) ...[
                    _CallButton(
                      icon: _isCameraOff
                          ? Icons.videocam_off
                          : Icons.videocam,
                      label: _isCameraOff ? 'Camera On' : 'Camera Off',
                      color: _isCameraOff ? Colors.red : Colors.white24,
                      onPressed: _toggleCamera,
                    ),
                  ] else ...[
                    _CallButton(
                      icon: Icons.volume_up,
                      label: 'Speaker',
                      color: Colors.white24,
                      onPressed: () {},
                    ),
                  ],
                ],
              ),
            ),

            // Top bar with back + switch camera
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: _hangUp,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            if (widget.isVideo)
              Positioned(
                top: 8,
                right: widget.isVideo ? 130 : 8,
                child: IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    this.size = 52,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
