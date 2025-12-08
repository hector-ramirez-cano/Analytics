import 'package:logger/web.dart';

enum OperandType {
  string,
  arithmeticInteger,
  arithmeticFloating,
  agnostic
}

class OperandModifierDefinition {
  final String label;
  final List<String> paramLabels;
  final List<Set<OperandType>> params;
  final OperandType result;

  const OperandModifierDefinition ({
    required this.label,
    required this.params,
    required this.paramLabels,
    required this.result,
  });
}

sealed class OperandModifier {
  const OperandModifier();

  factory OperandModifier.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return const OperandModifierNone();
    if (json.length != 1) return const OperandModifierNone();

    final key = json.keys.first.toLowerCase();
    final value = json[key];

    switch (key) {
      case 'add':
        return OperandModifierAdd((value as num).toDouble());
      case 'mul':
        return OperandModifierMul((value as num).toDouble());
      case 'mod':
        return OperandModifierMod((value as num).toInt());
      case 'rem':
        return OperandModifierRem((value as num).toDouble());
      case 'pow':
        return OperandModifierPow((value as num).toDouble());
      case 'floor':
        return OperandModifierFloor();
      case 'ceil':
        return OperandModifierCeil();
      case 'round':
        return OperandModifierRound();
      case 'truncate':
        return OperandModifierTruncate();
      case 'append':
        return OperandModifierAppend(value as String);
      case 'prepend':
        return OperandModifierPrepend(value as String);
      case 'bitwiseAnd':
        return OperandModifierBitwiseAnd((value as num).toInt());
      case 'bitwiseOr':
        return OperandModifierBitwiseOr((value as num).toInt());
      case 'bitwiseXor':
        return OperandModifierBitwiseXor((value as num).toInt());
      case 'bitwiseLshift':
        return OperandModifierBitwiseLShift((value as num).toInt());
      case 'bitwiseRshift':
        return OperandModifierBitwiseRShift((value as num).toInt());
      case 'bitwiseComplement':
        return OperandModifierBitwiseComplement();
      case 'toString':
        return OperandModifierToString();
      case 'trim':
        return const OperandModifierTrim();
      case 'replace':
        return OperandModifierReplace(
          pattern: value['pattern'] as String,
          withValue: value['with'] as String,
        );
      case 'replacen':
        return OperandModifierReplaceN(
          pattern: value['pattern'] as String,
          withValue: value['with'] as String,
          count: value['count'] as int,
        );
      case 'lower':
        return const OperandModifierLower();
      case 'upper':
        return const OperandModifierUpper();
      case 'multi':
        return OperandModifierMulti(
          operations: value['operations'].map((op) => (op is Map<String, dynamic> ? OperandModifier.fromJson(op) : OperandModifier.fromJson({op: null})))
            .cast<OperandModifier>().toList(),
        );
      default:
        return const OperandModifierNone();
    }
  }

  static Set<OperandModifierDefinition> get variants {
    return {
      OperandModifierAdd(0.0).definition,
      OperandModifierMul(0.0).definition,
      OperandModifierMod(0).definition,
      OperandModifierRem(0.0).definition,
      OperandModifierPow(0.0).definition,
      OperandModifierFloor().definition,
      OperandModifierCeil().definition,
      OperandModifierRound().definition,
      OperandModifierTruncate().definition,
      OperandModifierToString().definition,

      OperandModifierBitwiseAnd(0xFFFFFFFFFFFFFFFF).definition,
      OperandModifierBitwiseOr(0).definition,
      OperandModifierBitwiseXor(0).definition,
      OperandModifierBitwiseLShift(0).definition,
      OperandModifierBitwiseRShift(0).definition,
      OperandModifierBitwiseComplement().definition,

      OperandModifierAppend("").definition,
      OperandModifierPrepend("").definition,
      OperandModifierTrim().definition,
      OperandModifierReplace(pattern: "", withValue:"").definition,
      OperandModifierReplaceN(pattern: "", withValue: "", count: 0).definition,
      OperandModifierLower().definition,
      OperandModifierUpper().definition,
      OperandModifierNone().definition,
    };
  }

  static Map<OperandType, bool Function(String)> get validators => {
    OperandType.arithmeticFloating: (s) => double.tryParse(s) != null,
    OperandType.arithmeticInteger: (s) => int.tryParse(s) != null,
    OperandType.string: (_) => true,
    OperandType.agnostic: (_) => true
  };

  factory OperandModifier.fromLabel(String label) {
    switch (label) {
      case 'add':
        return OperandModifierAdd(.0);
      case 'mul':
        return OperandModifierMul(.0);
      case 'mod':
        return OperandModifierMod(1);
      case 'rem':
        return OperandModifierRem(1);
      case 'pow':
        return OperandModifierPow(1);
      case 'floor':
        return OperandModifierFloor();
      case 'ceil':
        return OperandModifierCeil();
      case 'round':
        return OperandModifierRound();
      case 'bitwiseAnd':
        return OperandModifierBitwiseAnd(0xFFFFFFFFFFFFFFFF);
      case 'bitwiseOr':
        return OperandModifierBitwiseOr(0x0);
      case 'bitwiseXor':
        return OperandModifierBitwiseXor(0x0);
      case 'bitwiseLshift':
        return OperandModifierBitwiseLShift(0x0);
      case 'bitwiseRshift':
        return OperandModifierBitwiseRShift(0x0);
      case 'bitwiseComplement':
        return OperandModifierBitwiseComplement();
      case 'toString': 
        return OperandModifierToString();
      case 'truncate':
        return OperandModifierTruncate();
      case 'append':
        return OperandModifierAppend('');
      case 'prepend':
        return OperandModifierPrepend('');
      case 'trim':
        return OperandModifierTrim();
      case 'replace':
        return OperandModifierReplace(pattern: '', withValue: '');
      case 'replacen':
        return OperandModifierReplaceN(pattern: '', withValue: '', count: 0);
      case 'lower':
        return OperandModifierLower();
      case 'upper':
        return OperandModifierUpper();
      case 'none':
        return OperandModifierNone();

      default:
        Logger().w("tried to parse OperandModifier from label '$label', for undefined label. Was it just added?");
        return OperandModifierNone();
    }
  }

  /// Converts the modifier into a map that can be represented as JSON and follows the JSON format
  Map<String, dynamic> toMap();

  /// Makes a clone
  OperandModifier copyWith();

  /// Sets the param at a given param index
  OperandModifier setParam(dynamic param, int index);

  /// Gets the value of a param at a given param index
  String getValue(int index);

  /// Collapses the modifier for optimization, such that unit operations get turned into none, and subsquently reduced
  OperandModifier collapse();

  /// Gets the definition of this modifier, regardless of variant
  OperandModifierDefinition get definition;

  @override String toString();
}

class OperandModifierAdd extends OperandModifier {
  final double value;
  const OperandModifierAdd(this.value);

  @override Map<String, dynamic> toMap() => {'add': value};

  @override OperandModifierAdd copyWith({double? value}) =>
      OperandModifierAdd(value ?? this.value);

  @override String toString() => '.add($value)';

  @override OperandModifier collapse() => value != 0 ? this : OperandModifierNone();

  @override OperandModifierAdd setParam(dynamic param, int index) {
    if (index == 1) return copyWith(value: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return value.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'add',
    paramLabels: ["input", "rhs"],
    params: [{OperandType.arithmeticFloating, OperandType.arithmeticInteger}, {OperandType.arithmeticFloating, OperandType.arithmeticInteger}],
    result: OperandType.arithmeticFloating
  );
}

class OperandModifierMul extends OperandModifier {
  final double value;
  const OperandModifierMul(this.value);

  @override Map<String, dynamic> toMap() => {'mul': value};

  @override OperandModifierMul copyWith({double? value}) =>
      OperandModifierMul(value ?? this.value);

  @override String toString() => '.mul($value)';

  @override OperandModifier collapse() => value != 1.0 ? this : OperandModifierNone();

  @override OperandModifierMul setParam(dynamic param, int index) {
    if (index == 1) return copyWith(value: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return value.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'mul',
    paramLabels: ["input", "rhs"],
    params: [{OperandType.arithmeticFloating, OperandType.arithmeticInteger}, {OperandType.arithmeticFloating, OperandType.arithmeticInteger}],
    result: OperandType.arithmeticFloating
  );
}

class OperandModifierMod extends OperandModifier {
  final int value;
  const OperandModifierMod(this.value);

  @override Map<String, dynamic> toMap() => {'mod': value};

  @override OperandModifierMod copyWith({int? value}) =>
      OperandModifierMod(value ?? this.value);

  @override String toString() => '.mod($value)';

  @override OperandModifier collapse() => this;

  @override OperandModifierMod setParam(dynamic param, int index) {
    if (index == 1) return copyWith(value: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return value.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'mod',
    paramLabels: ["input", "denominador"],
    params: [{OperandType.arithmeticFloating, OperandType.arithmeticInteger}, {OperandType.arithmeticInteger}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierRem extends OperandModifier {
  final double value;
  const OperandModifierRem(this.value);

  @override Map<String, dynamic> toMap() => {'rem': value};

  @override OperandModifierRem copyWith({double? value}) =>
      OperandModifierRem(value ?? this.value);

  @override String toString() => '.rem($value)';

  @override OperandModifier collapse() => this;

  @override OperandModifierRem setParam(dynamic param, int index) {
    if (index == 1) return copyWith(value: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return value.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'rem',
    paramLabels: ["input", "denominador"],
    params: [{OperandType.arithmeticFloating, OperandType.arithmeticInteger}, {OperandType.arithmeticFloating, OperandType.arithmeticInteger}],
    result: OperandType.arithmeticFloating
  );
}

class OperandModifierPow extends OperandModifier {
  final double value;
  const OperandModifierPow(this.value);

  @override Map<String, dynamic> toMap() => {'pow': value};

  @override OperandModifierPow copyWith({double? value}) =>
      OperandModifierPow(value ?? this.value);

  @override String toString() => '.pow($value)';

  @override OperandModifier collapse() => value != 1.0 ? this : OperandModifierNone();

  @override OperandModifierPow setParam(dynamic param, int index) {
    if (index == 1) return copyWith(value: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return value.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'pow',
    paramLabels: ["input", "potencia"],
    params: [{OperandType.arithmeticFloating}, {OperandType.arithmeticFloating, OperandType.arithmeticInteger}],
    result: OperandType.arithmeticFloating
  );
}

class OperandModifierFloor extends OperandModifier {
  const OperandModifierFloor();

  @override Map<String, dynamic> toMap() => {'floor': null};

  @override OperandModifierFloor copyWith() => const OperandModifierFloor();

  @override String toString() => '.floor()';

  @override OperandModifier collapse() => this;

  @override OperandModifierFloor setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'floor',
    paramLabels: ["input"],
    params: [{OperandType.arithmeticFloating}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierCeil extends OperandModifier {
  const OperandModifierCeil();

  @override Map<String, dynamic> toMap() => {'ceil': null};

  @override OperandModifierCeil copyWith() => const OperandModifierCeil();

  @override String toString() => '.ceil()';

  @override OperandModifier collapse() => this;

  @override OperandModifierCeil setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'ceil',
    paramLabels: ["input"],
    params: [{OperandType.arithmeticFloating}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierRound extends OperandModifier {
  const OperandModifierRound();

  @override Map<String, dynamic> toMap() => {'round': null};

  @override OperandModifierRound copyWith() => const OperandModifierRound();

  @override String toString() => '.round()';

  @override OperandModifier collapse() => this;

  @override OperandModifierRound setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'round',
    paramLabels: ["input"],
    params: [{OperandType.arithmeticFloating}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierTruncate extends OperandModifier {
  const OperandModifierTruncate();

  @override Map<String, dynamic> toMap() => {'truncate': null};

  @override OperandModifierTruncate copyWith() => const OperandModifierTruncate();

  @override String toString() => '.truncate()';

  @override OperandModifier collapse() => this;

  @override OperandModifierTruncate setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'truncate',
    paramLabels: ["input"],
    params: [{OperandType.arithmeticFloating}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierToString extends OperandModifier {
  const OperandModifierToString();

  @override Map<String, dynamic> toMap() => {'toString': null};

  @override OperandModifierToString copyWith() => const OperandModifierToString();

  @override String toString() => '.toString()';

  @override OperandModifier collapse() => this;

  @override OperandModifierToString setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'toString',
    paramLabels: ["input"],
    params: [{OperandType.string, OperandType.arithmeticFloating, OperandType.arithmeticInteger, OperandType.agnostic}],
    result: OperandType.string
  );
}

class OperandModifierAppend extends OperandModifier {
  final String value;
  const OperandModifierAppend(this.value);

  @override Map<String, dynamic> toMap() => {'append': value};

  @override OperandModifierAppend copyWith({String? value}) =>
      OperandModifierAppend(value ?? this.value);

  @override String toString() => '.append("$value")';

  @override OperandModifier collapse() => value.isNotEmpty ? this : OperandModifierNone();

  @override OperandModifierAppend setParam(dynamic param, int index) {
    if (index == 1) return copyWith(value: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return value.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'append',
    paramLabels: ["input", "texto"],
    params: [{OperandType.string}, {OperandType.string}],
    result: OperandType.string
  );
}

class OperandModifierPrepend extends OperandModifier {
  final String value;
  const OperandModifierPrepend(this.value);

  @override Map<String, dynamic> toMap() => {'prepend': value};

  @override OperandModifierPrepend copyWith({String? value}) =>
      OperandModifierPrepend(value ?? this.value);

  @override String toString() => '.prepend("$value")';

  @override OperandModifier collapse() => value.isNotEmpty ? this : OperandModifierNone();

  @override OperandModifierPrepend setParam(dynamic param, int index) {
    if (index == 1) return copyWith(value: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return value.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'prepend',
    paramLabels: ["input", "texto"],
    params: [{OperandType.string}, {OperandType.string}],
    result: OperandType.string
  );
}

class OperandModifierTrim extends OperandModifier {
  const OperandModifierTrim();

  @override Map<String, dynamic> toMap() => {'trim': null};

  @override OperandModifierTrim copyWith() => const OperandModifierTrim();

  @override String toString() => '.trim()';

  @override OperandModifier collapse() => this;

  @override OperandModifierTrim setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'trim',
    paramLabels: ["input"],
    params: [{OperandType.string}],
    result: OperandType.string
  );
}

class OperandModifierReplace extends OperandModifier {
  final String pattern;
  final String withValue;

  const OperandModifierReplace({required this.pattern, required this.withValue});

  @override Map<String, dynamic> toMap() =>
      {'replace': {'pattern': pattern, 'with': withValue}};

  @override OperandModifierReplace copyWith({String? pattern, String? withValue}) =>
      OperandModifierReplace(
        pattern: pattern ?? this.pattern,
        withValue: withValue ?? this.withValue,
      );

  @override String toString() => '.replaceN("$pattern", with="$withValue")';

  @override OperandModifier collapse() => pattern.isNotEmpty ? this : OperandModifierNone();

  @override OperandModifierReplace setParam(dynamic param, int index) {
    if (index == 1) return copyWith(pattern: param);
    if (index == 2) return copyWith(withValue: param);

    return this;
  }

  @override String getValue(int index) {
    switch (index) {
      case 1: 
        return pattern;

      case 2:
        return withValue;

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'replace',
    paramLabels: ["input", "text", "with"],
    params: [{OperandType.string}, {OperandType.string}, {OperandType.string}],
    result: OperandType.string
  );
}

class OperandModifierReplaceN extends OperandModifier {
  final String pattern;
  final String withValue;
  final int count;

  const OperandModifierReplaceN({
    required this.pattern,
    required this.withValue,
    required this.count,
  });

  @override Map<String, dynamic> toMap() => {
        'replacen': {
          'pattern': pattern,
          'with': withValue,
          'count': count,
        }
      };

  @override OperandModifierReplaceN copyWith({String? pattern, String? withValue, int? count}) =>
      OperandModifierReplaceN(
        pattern: pattern ?? this.pattern,
        withValue: withValue ?? this.withValue,
        count: count ?? this.count,
      );

  @override String toString() => '.replaceN("$pattern", with="$withValue", count=$count)';

  @override OperandModifier collapse() => pattern.isNotEmpty && count > 0 ? this : OperandModifierNone();

  @override OperandModifierReplaceN setParam(dynamic param, int index) {
    if (index == 1) return copyWith(pattern: param);
    if (index == 2) return copyWith(withValue: param);
    if (index == 3) return copyWith(count: param);

    return this;
  }

    @override String getValue(int index) {
    switch (index) {
      case 1: 
        return pattern;

      case 2:
        return withValue;

      case 3:
        return count.toString();

      default: 
        return "";
    }
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'replacen',
    paramLabels: ["input", "text", "with", "count"],
    params: [{OperandType.string}, {OperandType.string}, {OperandType.string}, {OperandType.arithmeticInteger}],
    result: OperandType.string
  );
}

class OperandModifierLower extends OperandModifier {
  const OperandModifierLower();

  @override Map<String, dynamic> toMap() => {'lower': null};

  @override OperandModifierLower copyWith() => const OperandModifierLower();

  @override String toString() => '.lower()';

  @override OperandModifierLower setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifier collapse() => this;

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'lower',
    paramLabels: ["input"],
    params: [{OperandType.string}],
    result: OperandType.string
  );
}

class OperandModifierUpper extends OperandModifier {
  const OperandModifierUpper();

  @override Map<String, dynamic> toMap() => {'upper': null};

  @override OperandModifierUpper copyWith() => const OperandModifierUpper();

  @override String toString() => '.upper()';

  @override OperandModifierUpper setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifier collapse() => this;


  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'upper',
    paramLabels: ["input"],
    params: [{OperandType.string}],
    result: OperandType.string
  );
}

class OperandModifierBitwiseAnd extends OperandModifier {
  final int value;
  const OperandModifierBitwiseAnd(this.value);

  @override Map<String, dynamic> toMap() => {'bitwiseAnd': value};

  @override OperandModifierBitwiseAnd copyWith({int? value}) => OperandModifierBitwiseAnd(value ?? this.value);

  @override String toString() => '.bitwiseAnd($value)';

  @override OperandModifier collapse() => value == 0xFFFFFFFFFFFFFFFF? OperandModifierNone() : this;

  @override OperandModifierBitwiseAnd setParam(dynamic param, int index) {
    if (index == 1) { return copyWith(value: param);}

    return this;
  }

  @override String getValue(int index) {
    if (index case 1) { return value.toString();}
    
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'bitwiseAnd',
    paramLabels: ["input", "mask"],
    params: [{OperandType.arithmeticInteger}, {OperandType.arithmeticInteger}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierBitwiseOr extends OperandModifier {
  final int value;
  const OperandModifierBitwiseOr(this.value);

  @override Map<String, dynamic> toMap() => {'bitwiseOr': value};

  @override OperandModifierBitwiseOr copyWith({int? value}) => OperandModifierBitwiseOr(value ?? this.value);

  @override String toString() => '.bitwiseOr($value)';

  @override OperandModifier collapse() => value != 0 ? this : OperandModifierNone();

  @override OperandModifierBitwiseOr setParam(dynamic param, int index) {
    if (index == 1) { return copyWith(value: param);}

    return this;
  }

  @override String getValue(int index) {
    if (index case 1) { return value.toString();}
    
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'bitwiseOr',
    paramLabels: ["input", "mask"],
    params: [{OperandType.arithmeticInteger}, {OperandType.arithmeticInteger}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierBitwiseXor extends OperandModifier {
  final int value;
  const OperandModifierBitwiseXor(this.value);

  @override Map<String, dynamic> toMap() => {'bitwiseXor': value};

  @override OperandModifierBitwiseXor copyWith({int? value}) => OperandModifierBitwiseXor(value ?? this.value);

  @override String toString() => '.bitwiseXor($value)';

  @override OperandModifier collapse() => value != 0 ? this : OperandModifierNone();

  @override OperandModifierBitwiseXor setParam(dynamic param, int index) {
    if (index == 1) { return copyWith(value: param);}

    return this;
  }

  @override String getValue(int index) {
    if (index case 1) { return value.toString();}
    
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'bitwiseXor',
    paramLabels: ["input", "mask"],
    params: [{OperandType.arithmeticInteger}, {OperandType.arithmeticInteger}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierBitwiseLShift extends OperandModifier {
  final int value;
  const OperandModifierBitwiseLShift(this.value);

  @override Map<String, dynamic> toMap() => {'bitwiseLshift': value};

  @override OperandModifierBitwiseLShift copyWith({int? value}) => OperandModifierBitwiseLShift(value ?? this.value);

  @override String toString() => '.bitwiseLshift($value)';

  @override OperandModifier collapse() => value != 0 ? this : OperandModifierNone();

  @override OperandModifierBitwiseLShift setParam(dynamic param, int index) {
    if (index == 1) { return copyWith(value: param);}

    return this;
  }

  @override String getValue(int index) {
    if (index case 1) { return value.toString();}
    
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'bitwiseLshift',
    paramLabels: ["input", "positions"],
    params: [{OperandType.arithmeticInteger}, {OperandType.arithmeticInteger}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierBitwiseRShift extends OperandModifier {
  final int value;
  const OperandModifierBitwiseRShift(this.value);

  @override Map<String, dynamic> toMap() => {'bitwiseRshift': value};

  @override OperandModifierBitwiseRShift copyWith({int? value}) => OperandModifierBitwiseRShift(value ?? this.value);

  @override String toString() => '.bitwiseRshift($value)';

  @override OperandModifier collapse() => value != 0 ? this : OperandModifierNone();

  @override OperandModifierBitwiseRShift setParam(dynamic param, int index) {
    if (index == 1) { return copyWith(value: param);}

    return this;
  }

  @override String getValue(int index) {
    if (index case 1) { return value.toString();}
    
    return "";
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'bitwiseRshift',
    paramLabels: ["input", "positions"],
    params: [{OperandType.arithmeticInteger}, {OperandType.arithmeticInteger}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierBitwiseComplement extends OperandModifier {
  const OperandModifierBitwiseComplement();

  @override Map<String, dynamic> toMap() => {'bitwiseComplement': null};

  @override OperandModifierBitwiseComplement copyWith() => OperandModifierBitwiseComplement();

  @override String toString() => '.bitwiseComplement()';

  @override OperandModifier collapse() => this;

  @override OperandModifierBitwiseComplement setParam(dynamic param, int index) {
    return this;
  }

  @override String getValue(int index) => "";

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'bitwiseComplement',
    paramLabels: ["input"],
    params: [{OperandType.arithmeticInteger}],
    result: OperandType.arithmeticInteger
  );
}

class OperandModifierMulti extends OperandModifier {
  final List<OperandModifier> operations;

  const OperandModifierMulti({required this.operations});

  @override Map<String, dynamic> toMap() => {
        'multi': {
          'operations': operations.map((op) => op.collapse())
                          .where((op) => op is! OperandModifierNone)
                          .map((op) => op.toMap()).toList(),
        }
      };

  @override OperandModifierMulti setParam(dynamic param, int index) {
    return this;
  }

  @override
  OperandModifierMulti copyWith({List<OperandModifier>? operations}) =>
      OperandModifierMulti(
        operations: operations ?? this.operations,
      );

  @override String toString() => operations.map((op) => op.toString()).join();

  @override String getValue(int index) {
    return "";
  }

  @override OperandModifier collapse() {
    final list = operations.map((op) => op.collapse()).where((op) => op is! OperandModifierNone).toList();

    if (list.isEmpty) { return OperandModifierNone(); }
    if (list.length == 1) { return list[0]; }
    
    final reduced = list.map((mod) => mod is OperandModifierMulti ? mod.operations : [mod]).expand((l) => l).toList();

    return OperandModifierMulti(operations: reduced);
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'multi',
    paramLabels: ["operations", "operations"],
    params: [{OperandType.arithmeticFloating, OperandType.string, OperandType.arithmeticInteger}, {OperandType.arithmeticFloating, OperandType.string, OperandType.arithmeticInteger}],
    result: OperandType.agnostic
  );
}

class OperandModifierNone extends OperandModifier {
  const OperandModifierNone();

  @override Map<String, dynamic> toMap() => {'none': null};

  @override OperandModifierNone copyWith() => const OperandModifierNone();

  @override OperandModifier collapse() => this;

  @override String toString() => '';

  @override String getValue(int index) {
    return "";
  }


  @override OperandModifierNone setParam(dynamic param, int index) {
    return this;
  }

  @override OperandModifierDefinition get definition => const OperandModifierDefinition(
    label: 'none',
    paramLabels: ["input"],
    params: [{OperandType.agnostic}],
    result: OperandType.agnostic
  );
}
