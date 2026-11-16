import 'package:flutter_test/flutter_test.dart';
import 'package:autorent/core/availability.dart';

void main() {
  test(
    'el calendario bloquea días en El Salvador y respeta el fin exclusivo',
    () {
      final periods = [
        {
          'inicio_utc': '2027-01-10T06:00:00Z',
          'fin_utc': '2027-01-12T06:00:00Z',
        },
      ];
      expect(reservedDay(DateTime(2027, 1, 9), periods), false);
      expect(reservedDay(DateTime(2027, 1, 10), periods), true);
      expect(reservedDay(DateTime(2027, 1, 11), periods), true);
      expect(reservedDay(DateTime(2027, 1, 12), periods), false);
      expect(reservedDay(DateTime(2027, 1, 10), []), false);
    },
  );
}
