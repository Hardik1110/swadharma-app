class Zodiac {
  static const _signs = [
    (1, 20, 'Capricorn'), (2, 19, 'Aquarius'), (3, 21, 'Pisces'),
    (4, 20, 'Aries'), (5, 21, 'Taurus'), (6, 21, 'Gemini'),
    (7, 23, 'Cancer'), (8, 23, 'Leo'), (9, 23, 'Virgo'),
    (10, 23, 'Libra'), (11, 22, 'Scorpio'), (12, 22, 'Sagittarius'),
  ];

  static const symbols = {
    'Aries': '♈\uFE0E', 'Taurus': '♉\uFE0E', 'Gemini': '♊\uFE0E', 'Cancer': '♋\uFE0E',
    'Leo': '♌\uFE0E', 'Virgo': '♍\uFE0E', 'Libra': '♎\uFE0E', 'Scorpio': '♏\uFE0E',
    'Sagittarius': '♐\uFE0E', 'Capricorn': '♑\uFE0E', 'Aquarius': '♒\uFE0E', 'Pisces': '♓\uFE0E',
  };

  static String sunSign(DateTime d) {
    final (_, cutoff, before) = _signs[d.month - 1];
    return d.day < cutoff ? before : _signs[d.month % 12].$3;
  }
}
