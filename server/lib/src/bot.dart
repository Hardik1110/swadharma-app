import 'dart:math';

import 'models.dart';

/// Canned replies used when no human astrologer is connected via the console.
class AstroBot {
  AstroBot([Random? random]) : _rand = random ?? Random();

  final Random _rand;

  String greeting(Astrologer a, User u) {
    final sign = sunSign(u.dob);
    final name = u.name.isEmpty ? 'there' : u.name.split(' ').first;
    return 'Namaste $name 🙏 I am ${a.name}. '
        '${sign == null ? '' : 'I see you are a $sign. '}'
        'I have your birth details (${u.dob}, ${u.birthTime}, ${u.birthPlace}). '
        'What would you like to ask today?';
  }

  String reply(String text, User u) {
    final t = text.toLowerCase();
    final sign = sunSign(u.dob) ?? 'your sign';
    final pool = switch (t) {
      _ when _has(t, ['job', 'career', 'work', 'promotion', 'business']) => [
          'For $sign, Saturn is currently strengthening your 10th house. The next 3–4 months favour a job change; avoid signing anything in the last week of the month.',
          'Your chart shows growth through communication and networking. A senior person will play a key role in your next career move.',
          'Business partnerships look supportive, but read every contract carefully. Thursdays are auspicious for new starts.',
        ],
      _ when _has(t, ['love', 'marriage', 'relationship', 'partner', 'boyfriend', 'girlfriend', 'wife', 'husband']) => [
          'Venus is well placed for $sign right now. Honest conversations will bring you closer — avoid reacting in anger this week.',
          'Marriage yoga is visible in your chart within the next 12–18 months. Family will be supportive of your choice.',
          'There is some friction from Mars, but it is temporary. Offer water to the Sun in the morning for harmony.',
        ],
      _ when _has(t, ['money', 'finance', 'wealth', 'loan', 'invest']) => [
          'Jupiter supports steady gains for $sign. Prefer long-term investments over speculation this quarter.',
          'Avoid lending money for the next six weeks. A pending payment should come back to you soon.',
        ],
      _ when _has(t, ['health', 'stress', 'sleep', 'anxiety']) => [
          'Moon placement suggests stress affects your sleep. Meditation in the evening and a light dinner will help a lot.',
          'Take care of your digestion. Ketu’s transit can make you restless; spend some time near water.',
        ],
      _ when _has(t, ['thank', 'thanks', 'dhanyavad']) => [
          'You are most welcome! May the planets bless you. 🌟',
        ],
      _ => [
          'Let me check your chart… The coming period looks positive for $sign, especially for new beginnings. Could you tell me a bit more about your concern?',
          'I understand. Based on your birth details, patience will bring the best outcome here. Would you like a remedy as well?',
          'Interesting question. Your rising sign indicates strong intuition — trust your instincts on this one.',
        ],
    };
    return pool[_rand.nextInt(pool.length)];
  }

  bool _has(String t, List<String> words) => words.any(t.contains);

  /// Western sun sign from a yyyy-MM-dd date, or null if unparseable.
  static String? sunSign(String dob) {
    final d = DateTime.tryParse(dob);
    if (d == null) return null;
    const signs = [
      (1, 20, 'Capricorn'), (2, 19, 'Aquarius'), (3, 21, 'Pisces'),
      (4, 20, 'Aries'), (5, 21, 'Taurus'), (6, 21, 'Gemini'),
      (7, 23, 'Cancer'), (8, 23, 'Leo'), (9, 23, 'Virgo'),
      (10, 23, 'Libra'), (11, 22, 'Scorpio'), (12, 22, 'Sagittarius'),
    ];
    final (_, cutoff, before) = signs[d.month - 1];
    if (d.day < cutoff) return before;
    return signs[d.month % 12].$3;
  }
}
