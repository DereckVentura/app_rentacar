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
