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
  test('deja reservar el horario libre al final del 30 de noviembre', () {
    final periods = [
      {'inicio_utc': '2026-11-12T04:13:00Z', 'fin_utc': '2026-12-01T04:13:00Z'},
      {'inicio_utc': '2026-12-01T15:00:00Z', 'fin_utc': '2026-12-23T15:00:00Z'},
    ];
    expect(fullyReservedDay(DateTime(2026, 11, 29), periods), true);
    expect(fullyReservedDay(DateTime(2026, 11, 30), periods), false);
    final end = DateTime.parse('2026-12-01T15:00:00Z');
    expect(
      reservedRange(DateTime.parse('2026-12-01T04:13:00Z'), end, periods),
      false,
    );
    expect(
      reservedRange(DateTime.parse('2026-12-01T04:12:00Z'), end, periods),
      true,
    );
  });
}
