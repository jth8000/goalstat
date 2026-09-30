class Entry {
  final int? id;
  final int goalId;
  final String date; // ISO 8601 YYYY-MM-DD
  final double value;

  const Entry({
    this.id,
    required this.goalId,
    required this.date,
    required this.value,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'goal_id': goalId,
    'date': date,
    'value': value,
  };

  factory Entry.fromMap(Map<String, dynamic> m) => Entry(
    id: m['id'] as int?,
    goalId: m['goal_id'] as int,
    date: m['date'] as String,
    value: (m['value'] as num).toDouble(),
  );
}
