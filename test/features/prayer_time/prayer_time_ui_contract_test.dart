import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Prayer Time focus countdown cannot wrap', () {
    final source =
        File('lib/features/prayer_time/presentation/prayer_time_page.dart')
            .readAsStringSync();
    final start = source.indexOf('class _PrayerTimeFocusCard extends StatelessWidget {');
    final end = source.indexOf('class _PrayerSchedule extends StatelessWidget {', start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final card = source.substring(start, end);
    expect(card, contains('FittedBox('));
    expect(card, contains('fit: BoxFit.scaleDown'));
    expect(card, contains('maxLines: 1'));
    expect(card, contains('softWrap: false'));
    expect(card, isNot(contains('SizedBox(height: ')));
  });

  test('Qibla summary replaces the large bearing value with the shared compass visualization', () {
    final source =
        File('lib/features/prayer_time/presentation/qibla_summary_card.dart')
            .readAsStringSync();

    expect(source, contains('class QiblaSummaryCard extends ConsumerWidget {'));
    expect(source, contains('compassSensorAvailableProvider'));
    expect(source, contains('compassReadingProvider'));
    expect(source, contains('magneticDeclinationProvider'));
    expect(source, contains('QiblaDialPainter('));
    expect(source, contains("Key('qibla_summary_compass')"));
    expect(source, contains('showRelativeQibla: live'));
  });

  test('Qibla dial contains a Kaaba marker and supports static and live modes', () {
    final source =
        File('lib/features/prayer_time/presentation/qibla_visuals.dart')
            .readAsStringSync();

    expect(source, contains('class QiblaDialPainter extends CustomPainter {'));
    expect(source, contains('_drawKaaba('));
    expect(source, contains('showRelativeQibla'));
    expect(source, contains('canvas.rotate(-heading * math.pi / 180)'));
    expect(source, contains('markerCenter'));
  });
}
