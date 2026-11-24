import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/zodiac.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/consultation.dart';

/// The customer's birth data, as the astrologer needs it for a reading.
class BirthDetails extends StatelessWidget {
  const BirthDetails({super.key, required this.session, this.compact = false});

  final Consultation session;

  /// One-line summary instead of a labelled list.
  final bool compact;

  DateTime? get _dob => DateTime.tryParse(session.userDob);

  String? get sunSign => _dob == null ? null : Zodiac.sunSign(_dob!);

  @override
  Widget build(BuildContext context) {
    final dob = _dob == null ? '–' : Fmt.date(_dob!);
    final time = session.userBirthTime.isEmpty ? '–' : Fmt.birthTime(session.userBirthTime);
    final place = session.userBirthPlace.isEmpty ? '–' : session.userBirthPlace;

    if (compact) {
      return Text('$dob · $time · $place',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall);
    }

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: AppColors.indigo),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row(Icons.cake_outlined, 'Date of birth', dob),
      row(Icons.schedule_rounded, 'Birth time', time),
      row(Icons.place_outlined, 'Birth place', place),
      if (sunSign != null) ...[
        const SizedBox(height: 6),
        Pill(icon: Icons.wb_sunny_outlined, label: 'Sun sign: $sunSign', color: AppColors.saffron),
      ],
    ]);
  }
}
