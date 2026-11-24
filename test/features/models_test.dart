import 'package:astro_connect/features/astrologers/domain/astrologer.dart';
import 'package:astro_connect/features/consultation/domain/consultation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('astrologer parses pricing and status', () {
    final a = sampleAstrologer();
    expect(a.chatPrice, 25);
    expect(a.pricing['video'], 40);
    expect(a.status, AstrologerStatus.online);
    expect(a.withStatus(AstrologerStatus.busy).status, AstrologerStatus.busy);
  });

  test('filter builds query parameters', () {
    const f = AstrologerFilter(
        query: ' tarot ', expertise: 'Tarot', onlineOnly: true, sort: AstrologerSort.priceLow);
    expect(f.toQuery(), {
      'q': 'tarot',
      'expertise': 'Tarot',
      'onlineOnly': 'true',
      'sort': 'price_low',
    });
    expect(f.activeCount, 3);
    expect(f.copyWith(expertise: () => null).expertise, isNull);
  });

  test('consultation parses states, rtc and end reasons', () {
    final voice = Consultation.fromJson(sessionJson(type: 'voice'));
    expect(voice.type, ConsultationType.voice);
    expect(voice.rtc?.channel, 'astro_s1');
    expect(voice.status.isActive, isTrue);

    final done = Consultation.fromJson(
        sessionJson(status: 'completed', endReason: 'astrologer_disconnected'));
    expect(done.elapsedSeconds, 300);
    expect(done.cost, 125);
    expect(done.endReasonText, contains('disconnected'));
  });
}
