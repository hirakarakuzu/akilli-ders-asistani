class Question {
  final String question;
  final String topic;
  final List<String> options;
  final String correct;
  final String explanation;
  String? selected;

  Question({
    required this.question,
    required this.topic,
    required this.options,
    required this.correct,
    required this.explanation,
    this.selected,
  });

  /// Yapay zekâdan gelen soruyu doğrular. Geçersizse null döner.
  static Question? tryParse(dynamic j) {
    if (j is! Map) return null;
    final q = j['question'];
    final opts = j['options'];
    final c = j['correct_answer'];
    final e = j['explanation'];
    final t = j['topic'];
    if (q is! String || opts is! List || c is! String || e is! String) {
      return null;
    }
    final options = opts.map((o) => o.toString()).toList();
    if (options.length != 4 ||
        options.toSet().length != 4 ||
        !options.contains(c)) {
      return null;
    }
    return Question(
      question: q,
      topic: (t is String && t.trim().isNotEmpty) ? t : 'Genel',
      options: options,
      correct: c,
      explanation: e,
    );
  }

  Map<String, dynamic> toApiJson() => {
        'question': question,
        'topic': topic,
        'options': options,
        'correct_answer': correct,
        'user_answer': selected,
      };
}
