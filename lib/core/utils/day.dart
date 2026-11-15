/// Calendar-day arithmetic that is immune to DST shifts.
///
/// A "day key" is an ISO date string (`2026-11-13`). All game periods are
/// built on day keys in the player's game time zone, so the same moment
/// maps to the same day on every device.
library;

String two(int v) => v.toString().padLeft(2, '0');

String dayKeyOf(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

/// Parses a day key into a UTC midnight [DateTime] (used only for math).
DateTime parseDayKey(String key) {
  final p = key.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String addDays(String key, int days) =>
    dayKeyOf(parseDayKey(key).add(Duration(days: days)));

/// Whole days from [a] to [b] (positive when b is later).
int daysBetween(String a, String b) =>
    parseDayKey(b).difference(parseDayKey(a)).inDays;

/// ISO weekday 1 (Mon) … 7 (Sun) of a day key.
int weekdayOf(String key) => parseDayKey(key).weekday;

/// First day of the week containing [key]. [firstDayOfWeek] is 1 (Mon) … 7.
String weekStartOf(String key, int firstDayOfWeek) {
  final wd = weekdayOf(key);
  final back = (wd - firstDayOfWeek + 7) % 7;
  return addDays(key, -back);
}

/// Iterates day keys from [from] to [to] inclusive.
Iterable<String> dayRange(String from, String to) sync* {
  var cur = from;
  while (daysBetween(cur, to) >= 0) {
    yield cur;
    cur = addDays(cur, 1);
  }
}

int compareDayKeys(String a, String b) => a.compareTo(b);

String minDay(String a, String b) => a.compareTo(b) <= 0 ? a : b;
String maxDay(String a, String b) => a.compareTo(b) >= 0 ? a : b;

const weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const weekdayFull = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье'
];
const monthShort = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
];
const monthNominative = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
];

/// "13 ноя"
String humanDay(String key) {
  final d = parseDayKey(key);
  return '${d.day} ${monthShort[d.month - 1]}';
}

/// "13 ноя 2026"
String humanDayYear(String key) {
  final d = parseDayKey(key);
  return '${d.day} ${monthShort[d.month - 1]} ${d.year}';
}

/// Russian plural: plural(5, 'день', 'дня', 'дней').
String plural(int n, String one, String few, String many) {
  final m10 = n.abs() % 10, m100 = n.abs() % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}
