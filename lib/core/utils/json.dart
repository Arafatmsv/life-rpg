/// Small helpers for hand-written JSON (de)serialization.
library;

typedef Json = Map<String, dynamic>;

DateTime? parseDate(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

DateTime parseDateOr(Object? v, DateTime fallback) => parseDate(v) ?? fallback;

String? isoOrNull(DateTime? d) => d?.toUtc().toIso8601String();

String iso(DateTime d) => d.toUtc().toIso8601String();

int asInt(Object? v, [int fallback = 0]) => switch (v) {
      int i => i,
      num n => n.round(),
      String s => int.tryParse(s) ?? fallback,
      _ => fallback,
    };

int? asIntOrNull(Object? v) => v == null ? null : asInt(v);

double asDouble(Object? v, [double fallback = 0]) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? fallback,
      _ => fallback,
    };

bool asBool(Object? v, [bool fallback = false]) => switch (v) {
      bool b => b,
      num n => n != 0,
      String s => s == 'true',
      _ => fallback,
    };

String asString(Object? v, [String fallback = '']) => v?.toString() ?? fallback;

List<String> asStringList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

Json asJson(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
