import 'models.dart';

const expertiseTags = [
  'Vedic',
  'Tarot',
  'Numerology',
  'Vastu',
  'Palmistry',
  'KP',
  'Love & Relationship',
  'Career',
  'Face Reading',
];

List<Astrologer> seedAstrologers() {
  final now = DateTime.now();
  Review r(String n, int s, String c, int daysAgo) => Review(
        userName: n,
        rating: s,
        comment: c,
        createdAt: now.subtract(Duration(days: daysAgo)),
      );

  Astrologer a(
    int i,
    String name,
    List<String> expertise,
    List<String> languages,
    int exp,
    double rating,
    int count,
    int chat,
    AstrologerStatus status,
    String bio,
    List<Review> reviews,
  ) =>
      Astrologer(
        id: 'a$i',
        phone: '91000000${i.toString().padLeft(2, '0')}',
        name: name,
        avatarUrl: 'https://i.pravatar.cc/300?img=${[12, 47, 33, 45, 59, 26, 68, 5, 53, 14, 32, 49][i - 1]}',
        expertise: expertise,
        languages: languages,
        experienceYears: exp,
        rating: rating,
        ratingCount: count,
        pricing: {'chat': chat, 'voice': chat + 5, 'video': chat + 15},
        status: status,
        bio: bio,
        totalConsultations: count * 7,
        reviews: reviews,
      );

  const on = AstrologerStatus.online;
  const busy = AstrologerStatus.busy;
  const off = AstrologerStatus.offline;

  return [
    a(1, 'Pt. Raghav Sharma', ['Vedic', 'KP', 'Career'], ['Hindi', 'English'], 15,
        4.8, 2140, 25, on,
        'Third-generation Vedic astrologer from Varanasi. Specialises in career timing using dasha analysis and KP sub-lords.',
        [
          r('Ankita', 5, 'Very accurate about my job change. Calm and patient.', 2),
          r('Rohit', 5, 'Explained my dasha period clearly.', 9),
          r('Meera', 4, 'Good guidance, a bit short on time.', 20),
        ]),
    a(2, 'Tara Mehta', ['Tarot', 'Love & Relationship'], ['English', 'Hindi', 'Gujarati'], 8,
        4.7, 1320, 20, on,
        'Certified tarot reader helping people find clarity in relationships and life decisions.',
        [
          r('Sneha', 5, 'The reading felt so personal. Loved it!', 1),
          r('Karan', 4, 'Helpful insights about my relationship.', 14),
        ]),
    a(3, 'Acharya Vikram Joshi', ['Vedic', 'Vastu', 'Palmistry'], ['Hindi', 'Marathi'], 22,
        4.9, 3890, 40, busy,
        'Renowned Vastu consultant and palmist with over two decades of practice across India.',
        [
          r('Pooja', 5, 'His Vastu remedies changed the energy of our home.', 5),
          r('Amit', 5, 'Extremely knowledgeable.', 30),
        ]),
    a(4, 'Neha Kapoor', ['Numerology', 'Career'], ['English', 'Hindi', 'Punjabi'], 6,
        4.5, 640, 15, on,
        'Numerologist focused on name corrections, lucky numbers and career alignment.',
        [r('Harsh', 4, 'Name correction suggestion was interesting.', 3)]),
    a(5, 'Swami Anand Giri', ['Vedic', 'Face Reading'], ['Hindi', 'Sanskrit'], 30,
        4.6, 5100, 35, off,
        'Spiritual guide and Vedic scholar. Consults on life purpose, spiritual growth and remedies.',
        [r('Lata', 5, 'Felt very peaceful after the consultation.', 40)]),
    a(6, 'Priya Iyer', ['Tarot', 'Numerology'], ['English', 'Tamil', 'Kannada'], 5,
        4.4, 410, 12, on,
        'Intuitive tarot and numerology reader who blends both systems for practical advice.',
        [r('Divya', 4, 'Practical and friendly.', 6)]),
    a(7, 'Dr. Suresh Rao', ['KP', 'Vedic', 'Career'], ['English', 'Telugu', 'Hindi'], 18,
        4.7, 2700, 30, on,
        'PhD in Jyotish. Precise event timing with the Krishnamurti Paddhati system.',
        [r('Ravi', 5, 'Predicted my promotion month correctly.', 60)]),
    a(8, 'Ritu Malhotra', ['Love & Relationship', 'Face Reading'], ['Hindi', 'English'], 9,
        4.3, 780, 18, on,
        'Relationship counsellor and face reader. Kind, direct and solution-oriented.',
        [r('Nikita', 4, 'Very empathetic listener.', 11)]),
    a(9, 'Pt. Hari Om Shastri', ['Vastu', 'Vedic'], ['Hindi'], 26,
        4.8, 4200, 32, off,
        'Vastu and muhurat expert. Guides on property, business and auspicious timings.',
        [r('Suresh', 5, 'Gave a perfect muhurat for our shop opening.', 25)]),
    a(10, 'Kavya Nair', ['Palmistry', 'Tarot'], ['English', 'Malayalam'], 4,
        4.2, 260, 10, on,
        'Young palmist and tarot reader with a modern, approachable style.',
        [r('Arjun', 4, 'Fun and insightful.', 4)]),
    a(11, 'Acharya Dev Prakash', ['Numerology', 'Vastu', 'KP'], ['Hindi', 'English', 'Bengali'], 12,
        4.6, 1510, 22, busy,
        'Combines numerology and Vastu to provide holistic remedies for home and business.',
        [r('Moumita', 5, 'Remedies were simple and effective.', 8)]),
    a(12, 'Sana Qureshi', ['Tarot', 'Career', 'Love & Relationship'], ['English', 'Hindi', 'Urdu'], 7,
        4.5, 920, 16, on,
        'Tarot coach helping professionals navigate career crossroads and relationships.',
        [r('Farhan', 5, 'Spot on about my career dilemma.', 7)]),
  ];
}

