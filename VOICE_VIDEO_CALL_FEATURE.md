# Voice & Video Call Feature - Anonymous Chat

## Implementation Summary

Added WebRTC-based voice and video calling to the anonymous chat feature.

## Files Modified/Created

### New Files
- **lib/services/webrtc_service.dart** - WebRTC service handling peer connections, media streams, and signaling

### Modified Files
- **lib/services/anonymous_chat_service.dart** - Added `call` field to chat room creation
- **lib/widgets/anonymous_chat_widget.dart** - Added call UI, controls, and incoming call handling
- **pubspec.yaml** - Added `flutter_webrtc: ^0.11.7` dependency
- **firestore.rules** - Added rules for `ice_candidates` subcollection

## Features

### Call Types
- **Voice Call** - Audio-only communication
- **Video Call** - Audio + video communication with camera feed

### Call Controls
- Toggle microphone on/off
- Toggle camera on/off (video calls only)
- End call button
- Local video preview (small overlay)
- Remote video (full screen)

### Call Flow
1. User clicks video/voice call button in chat header
2. WebRTC offer is created and stored in Firestore `chat_rooms/{roomId}/call/offer`
3. Partner receives incoming call dialog
4. If accepted, answer is created and stored in `chat_rooms/{roomId}/call/answer`
5. ICE candidates are exchanged via `chat_rooms/{roomId}/ice_candidates` subcollection
6. Peer connection established, media streams flow

### Signaling via Firestore
- **Offer/Answer** - Stored in `chat_rooms/{roomId}/call` field
- **ICE Candidates** - Stored in `chat_rooms/{roomId}/ice_candidates/{id}` subcollection
- Real-time listeners detect incoming calls and ICE candidates

## Setup Required

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Deploy Firestore rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Permissions** (already configured)
   - Android: CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS
   - iOS: Add to Info.plist if needed

## Usage

1. Start a chat with a stranger
2. Click the video camera icon for video call or phone icon for voice call
3. Partner receives incoming call dialog
4. Accept to start call
5. Use controls to mute/unmute or toggle camera
6. Click red phone icon to end call

## Technical Details

- **STUN Server**: `stun:stun.l.google.com:19302` (free Google STUN)
- **Video Codec**: Default WebRTC codecs (VP8/VP9)
- **Audio Codec**: Default WebRTC codecs (Opus)
- **Signaling**: Firestore real-time listeners
- **NAT Traversal**: ICE candidates via STUN

## Limitations

- No TURN server configured (calls may fail behind strict NATs/firewalls)
- No call recording
- No screen sharing
- Calls end when either user disconnects from chat

## Future Enhancements

- Add TURN server for better connectivity
- Add call quality indicators
- Add call duration timer
- Add speaker/earpiece toggle
- Add camera flip (front/back)
