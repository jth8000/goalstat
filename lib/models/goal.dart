class Goal {
  final int? id;
  final String name;
  final String category;
  final String type; // 'boolean' | 'number'
  final String? unit;
  final String frequency; // 'daily' | 'weekly'
  final String evalPeriod; // 'daily' | 'weekly'
  final double targetValue;
  final String targetDirection; // 'gte' | 'lte' | 'eq'
  final int sortOrder;
  final bool active;

  const Goal({
    this.id,
    required this.name,
    required this.category,
    required this.type,
    this.unit,
    required this.frequency,
    required this.evalPeriod,
    required this.targetValue,
    required this.targetDirection,
    this.sortOrder = 0,
    this.active = true,
  });

  Goal copyWith({
    int? id,
    String? name,
    String? category,
    String? type,
    Object? unit = _sentinel,
    String? frequency,
    String? evalPeriod,
    double? targetValue,
    String? targetDirection,
    int? sortOrder,
    bool? active,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      type: type ?? this.type,
      unit: unit == _sentinel ? this.unit : unit as String?,
      frequency: frequency ?? this.frequency,
      evalPeriod: evalPeriod ?? this.evalPeriod,
      targetValue: targetValue ?? this.targetValue,
      targetDirection: targetDirection ?? this.targetDirection,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'type': type,
    'unit': unit,
    'frequency': frequency,
    'eval_period': evalPeriod,
    'target_value': targetValue,
    'target_direction': targetDirection,
    'sort_order': sortOrder,
    'active': active ? 1 : 0,
  };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
    id: m['id'] as int?,
    name: m['name'] as String,
    category: m['category'] as String,
    type: m['type'] as String,
    unit: m['unit'] as String?,
    frequency: m['frequency'] as String,
    evalPeriod: m['eval_period'] as String,
    targetValue: (m['target_value'] as num).toDouble(),
    targetDirection: m['target_direction'] as String,
    sortOrder: (m['sort_order'] as int?) ?? 0,
    active: (m['active'] as int?) == 1,
  );

  bool get isBoolean => type == 'boolean';
  bool get isWeeklyFreq => frequency == 'weekly';
  bool get isWeeklyEval => evalPeriod == 'weekly';

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
