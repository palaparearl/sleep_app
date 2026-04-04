# Anonymous Chat Flow Diagram

## User Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Can't Sleep Screen                          │
│  ┌──────────┬──────────┬──────────┬──────────────────────┐    │
│  │  Listen  │   Read   │ Breathe  │  Chat (NEW!)         │    │
│  └──────────┴──────────┴──────────┴──────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Chat Tab Opened     │
                    │                       │
                    │  [Find Someone to     │
                    │   Chat] Button        │
                    └───────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  Matchmaking Started  │
                    │  "Looking for         │
                    │   someone..."         │
                    └───────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
    ┌───────────────────────┐       ┌───────────────────────┐
    │  Someone Found!       │       │  Timeout (30s)        │
    │  Creating room...     │       │  "No one available"   │
    └───────────────────────┘       └───────────────────────┘
                │                               │
                ▼                               ▼
    ┌───────────────────────┐       ┌───────────────────────┐
    │   Chat Interface      │       │   [Go Back] Button    │
    │                       │       └───────────────────────┘
    │  Stranger             │
    │  ┌─────────────────┐  │
    │  │ Messages here   │  │
    │  │                 │  │
    │  └─────────────────┘  │
    │  [Type message...]    │
    │  [Disconnect]         │
    └───────────────────────┘
                │
    ┌───────────┴───────────┐
    ▼                       ▼
┌─────────────┐    ┌─────────────────┐
│ User clicks │    │ 30 min timeout  │
│ Disconnect  │    │ (auto-cleanup)  │
└─────────────┘    └─────────────────┘
    │                       │
    └───────────┬───────────┘
                ▼
    ┌───────────────────────┐
    │  Chat Ended           │
    │  Room & messages      │
    │  deleted              │
    └───────────────────────┘
```

## Technical Flow

```
User A                    Firestore                    User B
  │                          │                           │
  │ 1. Click "Find Match"    │                           │
  ├─────────────────────────>│                           │
  │ Check /matchmaking       │                           │
  │                          │                           │
  │ No one waiting           │                           │
  │ Add self to queue        │                           │
  │                          │                           │
  │ Listen for match...      │                           │
  │                          │                           │
  │                          │<──────────────────────────┤
  │                          │ 2. User B clicks "Find"   │
  │                          │                           │
  │                          │ Found User A waiting!     │
  │                          │                           │
  │                          │ 3. Create chat room       │
  │                          │    /chat_rooms/{roomId}   │
  │                          │                           │
  │<─────────────────────────┤                           │
  │ Match found! roomId      │                           │
  │                          │                           │
  │ 4. Both enter chat       │                           │
  │                          │                           │
  │ 5. Send message          │                           │
  ├─────────────────────────>│                           │
  │                          │──────────────────────────>│
  │                          │ Real-time message         │
  │                          │                           │
  │                          │<──────────────────────────┤
  │<─────────────────────────┤ 6. Reply                  │
  │ Real-time message        │                           │
  │                          │                           │
  │ 7. Disconnect            │                           │
  ├─────────────────────────>│                           │
  │ Delete room & messages   │                           │
  │                          │──────────────────────────>│
  │                          │ Partner disconnected      │
  │                          │                           │
```

## Firestore Structure

```
firestore
│
├── matchmaking/
│   ├── anon_1234567890_1234
│   │   ├── status: "waiting"
│   │   ├── timestamp: 2024-04-04T17:30:00Z
│   │   └── roomId: null
│   │
│   └── anon_1234567891_5678
│       ├── status: "matched"
│       ├── timestamp: 2024-04-04T17:30:05Z
│       └── roomId: "room_1234567892"
│
└── chat_rooms/
    └── room_1234567892/
        ├── participants: ["anon_1234567890_1234", "anon_1234567891_5678"]
        ├── createdAt: 2024-04-04T17:30:05Z
        ├── expiresAt: 2024-04-04T18:00:05Z (30 min later)
        │
        └── messages/
            ├── msg_001
            │   ├── text: "Hi! Can't sleep either?"
            │   ├── senderId: "anon_1234567890_1234"
            │   └── timestamp: 1712253005000
            │
            └── msg_002
                ├── text: "Yeah, been tossing and turning"
                ├── senderId: "anon_1234567891_5678"
                └── timestamp: 1712253010000
```

## Cloud Function Cleanup

```
Every 5 minutes:
  ┌─────────────────────────────────────┐
  │  Cloud Function: cleanupExpiredChats│
  └─────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
  ┌──────────────┐      ┌──────────────┐
  │ Find rooms   │      │ Find stale   │
  │ where        │      │ matchmaking  │
  │ expiresAt <  │      │ entries >    │
  │ now          │      │ 2 min old    │
  └──────────────┘      └──────────────┘
        │                       │
        ▼                       ▼
  ┌──────────────┐      ┌──────────────┐
  │ Delete all   │      │ Delete from  │
  │ messages     │      │ /matchmaking │
  └──────────────┘      └──────────────┘
        │
        ▼
  ┌──────────────┐
  │ Delete room  │
  └──────────────┘
```

## Security Rules Logic

```
/matchmaking/{userId}
  ✅ Anyone can read/write (needed for matchmaking)
  ✅ Anyone can delete (cleanup)

/chat_rooms/{roomId}
  ✅ Can read if you're a participant
  ✅ Anyone can create (during matchmaking)
  ✅ Anyone can delete (cleanup)
  
  /messages/{messageId}
    ✅ Anyone in room can read
    ✅ Can create if:
       - text is a string
       - text length > 0
       - text length <= 500 chars
    ✅ Anyone can delete (cleanup)
```
