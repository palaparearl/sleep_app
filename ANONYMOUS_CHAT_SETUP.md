# Anonymous Chat Feature - Deployment Guide

## Overview
The anonymous chat feature allows users who can't sleep to match with strangers for ephemeral conversations. Chats are completely anonymous and auto-delete after 30 minutes.

## Firestore Setup

### 1. Deploy Security Rules

Deploy the Firestore security rules to your Firebase project:

```bash
firebase deploy --only firestore:rules
```

Or manually copy the rules from `firestore.rules` to your Firebase Console:
- Go to Firebase Console → Firestore Database → Rules
- Paste the contents of `firestore.rules`
- Publish the rules

### 2. Create Indexes (Optional)

For better performance, create these indexes in Firestore:

**Index 1: Matchmaking Queue**
- Collection: `matchmaking`
- Fields: `status` (Ascending), `timestamp` (Ascending)

To create via Firebase Console:
1. Go to Firestore Database → Indexes
2. Click "Create Index"
3. Add the fields above

### 3. Set up Auto-Cleanup (Optional but Recommended)

To automatically clean up expired chat rooms and stale matchmaking entries, deploy this Cloud Function:

**functions/index.js:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Clean up expired chat rooms every 5 minutes
exports.cleanupExpiredChats = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = Date.now();
    
    // Delete expired chat rooms
    const expiredRooms = await db.collection('chat_rooms')
      .where('expiresAt', '<', now)
      .get();
    
    const batch = db.batch();
    for (const doc of expiredRooms.docs) {
      // Delete messages subcollection
      const messages = await doc.ref.collection('messages').get();
      messages.docs.forEach(msg => batch.delete(msg.ref));
      
      // Delete room
      batch.delete(doc.ref);
    }
    
    // Delete stale matchmaking entries (older than 2 minutes)
    const staleMatches = await db.collection('matchmaking')
      .where('timestamp', '<', admin.firestore.Timestamp.fromMillis(now - 120000))
      .get();
    
    staleMatches.docs.forEach(doc => batch.delete(doc.ref));
    
    await batch.commit();
    console.log(`Cleaned up ${expiredRooms.size} rooms and ${staleMatches.size} stale matches`);
  });
```

Deploy the function:
```bash
cd functions
npm install firebase-functions firebase-admin
cd ..
firebase deploy --only functions
```

## Testing

### Local Testing

1. Run the app on two devices/emulators:
```bash
flutter run --dart-define-from-file=.env
```

2. On both devices:
   - Navigate to "Can't Sleep" tab
   - Tap the "Chat" tab
   - Tap "Find Someone to Chat"
   - They should match with each other

### What to Test

- ✅ Matchmaking works (two users connect)
- ✅ Messages send and receive in real-time
- ✅ Disconnect button ends the chat
- ✅ Chat auto-expires after 30 minutes
- ✅ Timeout shows when no one is available
- ✅ Multiple concurrent chat rooms work

## Architecture

### Collections Structure

```
/matchmaking/{userId}
  - status: "waiting" | "matched"
  - timestamp: serverTimestamp
  - roomId: string (only when matched)

/chat_rooms/{roomId}
  - participants: [userId1, userId2]
  - createdAt: serverTimestamp
  - expiresAt: timestamp (30 min from creation)
  
  /messages/{messageId}
    - text: string
    - senderId: string
    - timestamp: number
```

### How Matchmaking Works

1. User A clicks "Find Someone to Chat"
2. Service checks for waiting users in `/matchmaking`
3. If found:
   - Creates a chat room with both users
   - Updates matchmaking docs
   - Both users enter chat
4. If not found:
   - User A adds themselves to `/matchmaking` with status "waiting"
   - Listens for status change to "matched"
   - When User B arrives, they create the room and update User A's doc

### Security

- No authentication required (anonymous)
- Messages limited to 500 characters
- Rooms auto-expire after 30 minutes
- Users can only access rooms they're participants in

## Cost Estimation

Based on Firebase pricing:

**Firestore Operations:**
- Matchmaking: 2 reads + 2 writes per match = ~$0.0000012 per match
- Messages: 1 write + N reads (where N = number of participants) = ~$0.0000006 per message
- Cleanup: Minimal (runs every 5 minutes)

**Estimated monthly cost for 1000 daily active users:**
- ~500 matches/day × 30 days = 15,000 matches = $0.018
- ~50 messages per chat × 15,000 = 750,000 messages = $0.45
- **Total: ~$0.50/month** (well within free tier)

## Monitoring

Monitor usage in Firebase Console:
- Firestore → Usage tab
- Functions → Logs (if using Cloud Functions)

## Troubleshooting

**Users can't match:**
- Check Firestore rules are deployed
- Verify internet connection
- Check Firebase Console for errors

**Messages not appearing:**
- Check Firestore indexes are created
- Verify security rules allow message creation
- Check console for errors

**Cleanup not working:**
- Verify Cloud Function is deployed
- Check function logs in Firebase Console
- Manually delete old rooms if needed

## Future Enhancements

- Add report/block functionality
- Implement typing indicators
- Add message reactions
- Show online user count
- Add interest-based matching
- Implement rate limiting
