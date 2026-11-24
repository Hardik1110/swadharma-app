import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/zodiac.dart';
import '../../../../core/widgets/async_views.dart';
import '../../../../core/widgets/ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_form_controller.dart';

const _cities = [
  'Ahmedabad, Gujarat', 'Bengaluru, Karnataka', 'Bhopal, Madhya Pradesh',
  'Bhubaneswar, Odisha', 'Chandigarh', 'Chennai, Tamil Nadu',
  'Coimbatore, Tamil Nadu', 'Dehradun, Uttarakhand', 'Delhi',
  'Guwahati, Assam', 'Hyderabad, Telangana', 'Indore, Madhya Pradesh',
  'Jaipur, Rajasthan', 'Kanpur, Uttar Pradesh', 'Kochi, Kerala',
  'Kolkata, West Bengal', 'Lucknow, Uttar Pradesh', 'Ludhiana, Punjab',
  'Mumbai, Maharashtra', 'Mysuru, Karnataka', 'Nagpur, Maharashtra',
  'Nashik, Maharashtra', 'Patna, Bihar', 'Pune, Maharashtra',
  'Raipur, Chhattisgarh', 'Rajkot, Gujarat', 'Ranchi, Jharkhand',
  'Surat, Gujarat', 'Thiruvananthapuram, Kerala', 'Vadodara, Gujarat',
  'Varanasi, Uttar Pradesh', 'Visakhapatnam, Andhra Pradesh',
];

/// Collects birth details. Used for onboarding ([isEdit] false) and editing.
class ProfileFormPage extends ConsumerWidget {
  const ProfileFormPage({super.key, this.isEdit = false});

  final bool isEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(profileFormProvider);
    final c = ref.read(profileFormProvider.notifier);
    final theme = Theme.of(context);

    Future<void> save() async {
      final ok = await c.save();
      if (!context.mounted) return;
      if (ok && isEdit) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated')));
        context.pop();
      }
      // Onboarding: router redirect moves on once the profile is complete.
    }

    final sign = s.dob == null ? null : Zodiac.sunSign(s.dob!);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: isEdit,
        title: isEdit ? const Text('Edit profile') : null,
        actions: [
          if (!isEdit)
            TextButton(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              child: const Text('Log out'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            MaxWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!isEdit) ...[
                  Text('Your birth details', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Astrologers use your exact birth date, time and place to prepare '
                    'your kundli, so the more accurate, the better the reading.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(children: [
                      Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.indigo),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Private by default. Only the astrologer you consult can see this.',
                          style: TextStyle(fontSize: 13, color: AppColors.indigo, height: 1.35),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 22),
                ],
                _Label('Full name'),
                TextFormField(
                  key: const Key('profile_name'),
                  initialValue: s.name,
                  onChanged: c.setName,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'As you would like to be addressed',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    errorText: s.showErrors ? s.nameError : null,
                  ),
                ),
                const SizedBox(height: 18),
                _Label('Gender (optional)'),
                Wrap(spacing: 10, children: [
                  for (final g in const ['Male', 'Female', 'Other'])
                    ChoiceChip(
                      label: Text(g),
                      selected: s.gender == g,
                      onSelected: (sel) => c.setGender(sel ? g : ''),
                    ),
                ]),
                const SizedBox(height: 18),
                _Label('Date of birth'),
                _PickerField(
                  key: const Key('profile_dob'),
                  icon: Icons.cake_outlined,
                  hint: 'Select date',
                  value: s.dob == null ? null : Fmt.date(s.dob!),
                  error: s.showErrors ? s.dobError : null,
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: s.dob ?? DateTime(now.year - 25),
                      firstDate: DateTime(1900),
                      lastDate: now,
                      helpText: 'Date of birth',
                    );
                    if (d != null) c.setDob(d);
                  },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: sign == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Pill(
                              icon: Icons.wb_sunny_outlined,
                              label: 'Sun sign: $sign',
                              color: AppColors.saffron,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                _Label('Birth time'),
                _PickerField(
                  key: const Key('profile_time'),
                  icon: Icons.schedule_rounded,
                  hint: 'Select time',
                  value: s.birthTime?.format(context),
                  error: s.showErrors ? s.timeError : null,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: s.birthTime ?? const TimeOfDay(hour: 6, minute: 0),
                      helpText: 'Birth time (as on birth certificate)',
                    );
                    if (t != null) c.setBirthTime(t);
                  },
                ),
                const SizedBox(height: 18),
                _Label('Birth place'),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: s.birthPlace),
                  optionsBuilder: (v) {
                    final q = v.text.trim().toLowerCase();
                    if (q.isEmpty) return const [];
                    return _cities.where((c) => c.toLowerCase().contains(q));
                  },
                  onSelected: c.setBirthPlace,
                  fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                    key: const Key('profile_place'),
                    controller: controller,
                    focusNode: focus,
                    onChanged: c.setBirthPlace,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'City, State',
                      prefixIcon: const Icon(Icons.place_outlined),
                      errorText: s.showErrors ? s.placeError : null,
                    ),
                  ),
                ),
                if (s.error != null) ...[
                  const SizedBox(height: 16),
                  Text(s.error!.message, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 30),
                PrimaryButton(
                  key: const Key('profile_save'),
                  label: isEdit ? 'Save changes' : 'Continue',
                  icon: isEdit ? null : Icons.arrow_forward_rounded,
                  loading: s.saving,
                  onPressed: save,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.icon,
    required this.hint,
    required this.value,
    required this.onTap,
    this.error,
  });

  final IconData icon;
  final String hint;
  final String? value;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.expand_more_rounded),
            errorText: error,
          ),
          child: Text(value ?? '', style: const TextStyle(fontSize: 16)),
        ),
      );
}
