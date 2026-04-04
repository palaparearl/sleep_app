class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      text: map['text'] as String,
      senderId: map['senderId'] as String,
      timestamp: (map['timestamp'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
