# Anonymous Chat - Quick Start

## What Was Added

✅ **New "Chat" tab** in the Can't Sleep screen  
✅ **Anonymous matchmaking** - connects two strangers instantly  
✅ **Real-time messaging** via Firestore  
✅ **Auto-expiring chats** - rooms delete after 30 minutes  
✅ **Clean UI** - matching screen, chat bubbles, disconnect button  
✅ **Cloud Function** for automatic cleanup of expired chats  

## Files Created

```
lib/
├── models/chat_message.dart              # Message data model
├── services/anonymous_chat_service.dart  # Matchmaking & messaging logic
└── widgets/anonymous_chat_widget.dart    # Chat UI

functions/
├── index.js                              # Cloud Function for cleanup
├── package.json                          # Dependencies
└── .gitignore

firestore.rules                           # Security rules
ANONYMOUS_CHAT_SETUP.md                   # Full deployment guide
```

## Files Modified

- `lib/screens/cant_sleep_screen.dart` - Added 4th tab for Chat
- `lib/models/models.dart` - Exported ChatMessage
- `lib/widgets/widgets.dart` - Exported AnonymousChatWidget

## How to Deploy

### 1. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 2. Deploy Cloud Function (Optional but Recommended)

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### 3. Test It

```bash
flutter run --dart-define-from-file=.env
```

Open the app on two devices, go to Can't Sleep → Chat tab, and click "Find Someone to Chat" on both.

## How It Works

1. **User clicks "Find Someone to Chat"**
   - Service checks `/matchmaking` collection for waiting users
   
2. **If someone is waiting:**
   - Creates a chat room in `/chat_rooms/{roomId}`
   - Both users are connected instantly
   
3. **If no one is waiting:**
   - User is added to `/matchmaking` with status "waiting"
   - Listens for when another user creates a room with them
   
4. **During chat:**
   - Messages are stored in `/chat_rooms/{roomId}/messages`
   - Real-time sync via Firestore snapshots
   
5. **On disconnect:**
   - Room and all messages are deleted immediately
   - Or auto-deleted after 30 minutes by Cloud Function

## Features

- ✅ Completely anonymous (no accounts)
- ✅ Ephemeral (chats disappear)
- ✅ Real-time messaging
- ✅ 30-minute auto-timeout
- ✅ Manual disconnect button
- ✅ Matching timeout (30 seconds)
- ✅ Clean, simple UI
- ✅ Message character limit (500 chars)

## Cost

**Extremely cheap** - estimated $0.50/month for 1000 daily active users (well within Firebase free tier).

## Next Steps

See `ANONYMOUS_CHAT_SETUP.md` for:
- Detailed deployment instructions
- Security considerations
- Monitoring and troubleshooting
- Future enhancement ideas
