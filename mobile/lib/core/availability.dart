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
