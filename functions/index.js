const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Clean up expired chat rooms and stale matchmaking entries
exports.cleanupExpiredChats = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = Date.now();
    
    console.log('Starting cleanup...');
    
    try {
      // Delete expired chat rooms (older than 30 minutes)
      const expiredRooms = await db.collection('chat_rooms')
        .where('expiresAt', '<', now)
        .get();
      
      let roomsDeleted = 0;
      let messagesDeleted = 0;
      
      for (const roomDoc of expiredRooms.docs) {
        // Delete all messages in the room
        const messages = await roomDoc.ref.collection('messages').get();
        const messageBatch = db.batch();
        
        messages.docs.forEach(msg => {
          messageBatch.delete(msg.ref);
          messagesDeleted++;
        });
        
        await messageBatch.commit();
        
        // Delete the room itself
        await roomDoc.ref.delete();
        roomsDeleted++;
      }
      
      // Delete stale matchmaking entries (older than 2 minutes)
      const twoMinutesAgo = admin.firestore.Timestamp.fromMillis(now - 120000);
      const staleMatches = await db.collection('matchmaking')
        .where('timestamp', '<', twoMinutesAgo)
        .get();
      
      const matchBatch = db.batch();
      staleMatches.docs.forEach(doc => matchBatch.delete(doc.ref));
      await matchBatch.commit();
      
      console.log(`Cleanup complete: ${roomsDeleted} rooms, ${messagesDeleted} messages, ${staleMatches.size} stale matches`);
      
      return null;
    } catch (error) {
      console.error('Cleanup error:', error);
      return null;
    }
  });
