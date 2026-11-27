import 'api.dart';

bool reservedDay(DateTime day, List<Json> periods) {
  final start = DateTime.utc(day.year, day.month, day.day, 6),
      end = DateTime.utc(day.year, day.month, day.day + 1, 6);
  return periods.any(
    (p) =>
        DateTime.parse(p['inicio_utc'].toString()).isBefore(end) &&
        DateTime.parse(p['fin_utc'].toString()).isAfter(start),
  );
}

bool fullyReservedDay(DateTime day, List<Json> periods) {
  final start = DateTime.utc(day.year, day.month, day.day, 6);
  final end = start.add(const Duration(days: 1));
  var coveredUntil = start;
  final ranges =
      periods
          .map(
            (p) => (
              DateTime.tryParse('${p['inicio_utc']}'),
              DateTime.tryParse('${p['fin_utc']}'),
            ),
          )
          .where((p) => p.$1 != null && p.$2 != null)
          .toList()
        ..sort((a, b) => a.$1!.compareTo(b.$1!));
  for (final (from, to) in ranges) {
    if (from!.isAfter(coveredUntil)) break;
    if (to!.isAfter(coveredUntil)) coveredUntil = to;
    if (!coveredUntil.isBefore(end)) return true;
  }
  return false;
}

bool reservedRange(DateTime start, DateTime end, List<Json> periods) =>
    periods.any((period) {
      final from = DateTime.tryParse('${period['inicio_utc']}');
      final to = DateTime.tryParse('${period['fin_utc']}');
      return from != null &&
          to != null &&
          from.isBefore(end) &&
          to.isAfter(start);
    });

const _minute = Duration(minutes: 1);
const _day = Duration(days: 1);
const _offset = Duration(hours: 6);

DateTime _midnight(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).add(_offset);

DateTime _floorMinute(DateTime time) => DateTime.fromMillisecondsSinceEpoch(
  time.millisecondsSinceEpoch ~/ 60000 * 60000,
  isUtc: true,
);

DateTime? pickupSuggestion(
  DateTime day,
  List<Json> periods, {
  required DateTime now,
  required Duration preferred,
}) {
  final midnight = _midnight(day);
  final end = midnight.add(_day);
  final target = midnight.add(preferred);
  final nextMinute = _floorMinute(now).add(_minute);
  var cursor = nextMinute.isAfter(midnight) ? nextMinute : midnight;
  DateTime? first;
  final busy =
      periods
          .map(
            (p) => (
              DateTime.tryParse('${p['inicio_utc']}'),
              DateTime.tryParse('${p['fin_utc']}'),
            ),
          )
          .where((p) => p.$1 != null && p.$2 != null && p.$2!.isAfter(p.$1!))
          .map((p) => (p.$1!, p.$2!))
          .where((p) => p.$1.isBefore(end) && p.$2.isAfter(cursor))
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
  for (final (from, to) in [...busy, (end, end)]) {
    final last = _floorMinute(from);
    if (cursor.isBefore(last)) {
      first ??= cursor;
      if (target.isBefore(last)) {
        return (target.isBefore(cursor) ? cursor : target).subtract(_offset);
      }
    }
    var next = _floorMinute(to);
    if (next.isBefore(to)) next = next.add(_minute);
    if (next.isAfter(cursor)) cursor = next;
  }
  return first?.subtract(_offset);
}

DateTime? returnSuggestion(
  DateTime day,
  DateTime pickup,
  List<Json> periods, {
  required Duration preferred,
}) {
  final midnight = _midnight(day);
  final nextMinute = pickup.add(_minute);
  final earliest = midnight.isAfter(nextMinute) ? midnight : nextMinute;
  var latest = midnight.add(_day - _minute);
  for (final p in periods) {
    final from = DateTime.tryParse('${p['inicio_utc']}');
    final to = DateTime.tryParse('${p['fin_utc']}');
    if (from != null &&
        to != null &&
        to.isAfter(pickup) &&
        from.isBefore(latest)) {
      latest = _floorMinute(from);
    }
  }
  if (earliest.isAfter(latest)) return null;
  var target = midnight.add(preferred);
  if (target.isBefore(earliest)) {
    target = pickup.isBefore(midnight)
        ? earliest
        : pickup.add(const Duration(hours: 1));
  }
  return (target.isAfter(latest) ? latest : target).subtract(_offset);
}
