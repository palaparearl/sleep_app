class NoteRecord {
  final DateTime date;
  final String text;

  NoteRecord({required this.date, required this.text});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'text': text,
  };

  factory NoteRecord.fromJson(Map<String, dynamic> json) {
    return NoteRecord(
      date: DateTime.parse(json['date']),
      text: json['text'] as String,
    );
  }

  NoteRecord copyWith({DateTime? date, String? text}) {
    return NoteRecord(date: date ?? this.date, text: text ?? this.text);
  }
}
