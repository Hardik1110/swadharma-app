import 'package:astro_connect/core/utils/formatters.dart';
import 'package:astro_connect/core/utils/zodiac.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clock formats minutes and hours', () {
    expect(Fmt.clock(0), '00:00');
    expect(Fmt.clock(75), '01:15');
    expect(Fmt.clock(3725), '1:02:05');
    expect(Fmt.clock(-5), '00:00');
  });

  test('duration is human readable', () {
    expect(Fmt.duration(45), '45 sec');
    expect(Fmt.duration(120), '2 min');
    expect(Fmt.duration(135), '2 min 15 sec');
  });

  test('money uses rupees without decimals', () {
    expect(Fmt.money(1250), '₹1,250');
    expect(Fmt.perMinute(25), '₹25/min');
  });

  test('phone and birth time formatting', () {
    expect(Fmt.phone('9876543210'), '+91 98765 43210');
    // intl separates the period with a narrow no-break space.
    expect(Fmt.birthTime('18:05').replaceAll('\u202f', ' '), '6:05 PM');
  });

  test('sun sign boundaries', () {
    expect(Zodiac.sunSign(DateTime(1995, 8, 15)), 'Leo');
    expect(Zodiac.sunSign(DateTime(2000, 3, 20)), 'Pisces');
    expect(Zodiac.sunSign(DateTime(2000, 3, 21)), 'Aries');
    expect(Zodiac.sunSign(DateTime(2000, 12, 22)), 'Capricorn');
    expect(Zodiac.sunSign(DateTime(2000, 1, 19)), 'Capricorn');
    expect(Zodiac.sunSign(DateTime(2000, 1, 20)), 'Aquarius');
  });
}
