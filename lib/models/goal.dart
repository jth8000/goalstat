class Goal {
  final int? id;
  final String name;
  final String category;
  final String type; // 'boolean' | 'number'
  final String? unit;
  final String evalPeriod; // 'daily' | 'weekly' | 'monthly'
  final double targetValue;
  final String targetDirection; // 'gte' | 'lte' | 'eq'
  final int sortOrder;

  const Goal({
    this.id,
    required this.name,
    required this.category,
    required this.type,
    this.unit,
    required this.evalPeriod,
    required this.targetValue,
    required this.targetDirection,
    this.sortOrder = 0,
  });

  Goal copyWith({
    int? id,
    String? name,
    String? category,
    String? type,
    Object? unit = _sentinel,
    String? evalPeriod,
    double? targetValue,
    String? targetDirection,
    int? sortOrder,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      type: type ?? this.type,
      unit: unit == _sentinel ? this.unit : unit as String?,
      evalPeriod: evalPeriod ?? this.evalPeriod,
      targetValue: targetValue ?? this.targetValue,
      targetDirection: targetDirection ?? this.targetDirection,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'type': type,
    'unit': unit,
    'eval_period': evalPeriod,
    'target_value': targetValue,
    'target_direction': targetDirection,
    'sort_order': sortOrder,
  };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
    id: m['id'] as int?,
    name: m['name'] as String,
    category: m['category'] as String,
    type: m['type'] as String,
    unit: m['unit'] as String?,
    evalPeriod: m['eval_period'] as String,
    targetValue: (m['target_value'] as num).toDouble(),
    targetDirection: m['target_direction'] as String,
    sortOrder: (m['sort_order'] as int?) ?? 0,
  );

  bool get isBoolean => type == 'boolean';
  bool get isDailyEval => evalPeriod == 'daily';
  bool get isWeeklyEval => evalPeriod == 'weekly';
  bool get isMonthlyEval => evalPeriod == 'monthly';

  /// 'day' | 'week' | 'month'
  String get periodNoun =>
      isWeeklyEval ? 'week' : isMonthlyEval ? 'month' : 'day';

  /// First day of the evaluation period containing [d].
  DateTime periodStart(DateTime d) {
    if (isWeeklyEval) return DateTime(d.year, d.month, d.day - (d.weekday - 1));
    if (isMonthlyEval) return DateTime(d.year, d.month, 1);
    return DateTime(d.year, d.month, d.day);
  }

  /// Last day of the evaluation period containing [d].
  DateTime periodEnd(DateTime d) {
    final start = periodStart(d);
    if (isWeeklyEval) return DateTime(start.year, start.month, start.day + 6);
    if (isMonthlyEval) return DateTime(start.year, start.month + 1, 0);
    return start;
  }

  /// First day of the period [n] periods before the one containing [d].
  DateTime periodsAgo(DateTime d, int n) {
    final start = periodStart(d);
    if (isWeeklyEval) return DateTime(start.year, start.month, start.day - 7 * n);
    if (isMonthlyEval) return DateTime(start.year, start.month - n, 1);
    return DateTime(start.year, start.month, start.day - n);
  }

  String get directionSymbol {
    switch (targetDirection) {
      case 'gte': return '≥';
      case 'lte': return '≤';
      default: return '=';
    }
  }

  bool isOnTarget(double value) {
    switch (targetDirection) {
      case 'gte': return value >= targetValue;
      case 'lte': return value <= targetValue;
      default: return value == targetValue;
    }
  }
}

const _sentinel = Object();
