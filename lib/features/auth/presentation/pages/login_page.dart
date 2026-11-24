import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/brand/brand.dart';
import '../../../../core/config/server_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/otp_boxes.dart';
import '../../../../core/widgets/ui.dart';
import '../../../astrologers/presentation/providers/astrologer_providers.dart';
import '../../domain/auth_repository.dart';
import '../providers/login_controller.dart';
import '../widgets/server_settings_sheet.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(loginControllerProvider.select((s) => s.step));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light clock/battery icons: the top of this screen is the dark hero.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, c) {
        final heroHeight = (c.maxHeight * .38).clamp(190.0, 340.0);
        return Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight + 48,
            child: HeroBackdrop(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const BrandLockup(markSize: 34),
                    const Spacer(),
                    Text(
                      AppBrand.tagline,
                      style: const TextStyle(
                        fontFamily: AppTheme.serif,
                        fontSize: 30,
                        height: 1.18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 76),
                  ]),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(top: heroHeight),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - heroHeight),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Color(0x26150E3A), blurRadius: 30, offset: Offset(0, -6)),
                  ],
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      child: step == LoginStep.details
                          ? const _DetailsForm(key: ValueKey('details'))
                          : const _OtpForm(key: ValueKey('otp')),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // The form scrolls up over the hero; keep it from sliding under the
          // status bar icons.
          Positioned(
            key: const Key('status_bar_cover'),
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: const ColoredBox(color: AppColors.indigoDeep),
          ),
        ]);
      }),
    ));
  }
}

/// Numbers of the seeded demo astrologers (server/lib/src/seed.dart).
const _demoAstrologers = [
  ('Raghav', '9100000001'),
  ('Tara', '9100000002'),
  ('Neha', '9100000004'),
  ('Priya', '9100000006'),
];

class _DetailsForm extends ConsumerStatefulWidget {
  const _DetailsForm({super.key});

  @override
  ConsumerState<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends ConsumerState<_DetailsForm> {
  late final TextEditingController _phone;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final s = ref.read(loginControllerProvider);
    _phone = TextEditingController(text: s.phone);
    _name = TextEditingController(text: s.name);
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(loginControllerProvider.notifier)
      .requestOtp(phone: _phone.text, name: _name.text);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final ctrl = ref.read(loginControllerProvider.notifier);
    final theme = Theme.of(context);
    final isSignup = state.purpose == OtpPurpose.signup;
    final error = state.error;

    final isAstrologer = state.purpose == OtpPurpose.astrologer;
    // Real-SMS servers hide the demo numbers. If the server can't be asked
    // they are shown: Riverpod retries a failed request with growing delays and
    // reports "loading" in between, so an error seen earlier counts as an error.
    final demo = ref.watch(appConfigProvider.select(
        (c) => c.hasValue ? c.requireValue.isDemoLogin : c.hasError));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAstrologer)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('back_to_customer'),
              onPressed: () => ctrl.setPurpose(OtpPurpose.login),
              style: TextButton.styleFrom(padding: const EdgeInsets.only(right: 12)),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: const Text('Customer login'),
            ),
          )
        else
          _AuthTabs(
            selected: state.purpose,
            onChanged: (p) {
              _phone.clear();
              ctrl.setPurpose(p);
            },
          ),
        SizedBox(height: isAstrologer ? 10 : 26),
        Text(
            isAstrologer
                ? 'Astrologer sign in'
                : isSignup
                    ? 'Create your account'
                    : 'Welcome back',
            style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          isAstrologer
              ? 'Sign in with the mobile number registered with ${AppBrand.name} to take consultations.'
              : isSignup
                  ? 'Tell us your name and number. We\'ll text you a code.'
                  : 'Log in with your mobile number to continue.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        if (isSignup) ...[
          TextField(
            key: const Key('name_field'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          key: const Key('phone_field'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: .6),
          decoration: InputDecoration(
            hintText: 'Mobile number',
            counterText: '',
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text('+91',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(width: 12),
                Container(width: 1, height: 22, color: AppColors.hairline),
              ]),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _Notice(error.message, info: error.code == 'switched'),
        ],
        if (isAstrologer && demo) ...[
          const SizedBox(height: 14),
          Text('Demo astrologers (tap to fill)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (name, phone) in _demoAstrologers)
              ActionChip(
                key: Key('demo_$phone'),
                label: Text('$name · $phone'),
                onPressed: () => _phone.text = phone,
              ),
          ]),
        ],
        const SizedBox(height: 22),
        PrimaryButton(
          key: const Key('send_otp'),
          label: 'Get OTP',
          icon: Icons.arrow_forward_rounded,
          loading: state.loading,
          onPressed: _submit,
        ),
        if (!isAstrologer) ...[
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              key: const Key('astrologer_login'),
              onPressed: () {
                _phone.clear();
                ref.invalidate(appConfigProvider); // retry if the first load failed
                ctrl.setPurpose(OtpPurpose.astrologer);
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('I\'m an astrologer'),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const _TrustRow(),
        const SizedBox(height: 18),
        Text(
          'By continuing you agree to our Terms of Service and Privacy Policy.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            key: const Key('server_settings'),
            onPressed: () => showServerSettings(context),
            icon: const Icon(Icons.dns_outlined, size: 16),
            label: Text('Server: ${Uri.parse(ref.watch(serverUrlProvider)).authority}'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.muted,
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpForm extends ConsumerStatefulWidget {
  const _OtpForm({super.key});

  @override
  ConsumerState<_OtpForm> createState() => _OtpFormState();
}

class _OtpFormState extends ConsumerState<_OtpForm> {
  final _otp = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _otp.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _verify() => ref.read(loginControllerProvider.notifier).verify(_otp.text);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final ctrl = ref.read(loginControllerProvider.notifier);
    final theme = Theme.of(context);
    // A wrong code clears the boxes so the user can simply retype.
    ref.listen(loginControllerProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        _otp.clear();
        _focus.requestFocus();
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: state.loading ? null : ctrl.editDetails,
            style: TextButton.styleFrom(padding: const EdgeInsets.only(right: 12)),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text('Back'),
          ),
        ),
        const SizedBox(height: 10),
        Text('Verify your number', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Enter the 6-digit code sent to '),
            TextSpan(
                text: Fmt.phone(state.phone),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          ]),
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 28),
        OtpBoxes(
          controller: _otp,
          focusNode: _focus,
          hasError: state.error != null,
          enabled: !state.loading,
          onCompleted: (_) => _verify(),
        ),
        if (state.devOtp != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _otp.text = state.devOtp!;
                  _verify();
                },
                child: Pill(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Demo code ${state.devOtp} · tap to fill',
                  color: AppColors.saffron,
                ),
              ),
            ),
          ),
        if (state.error != null) ...[
          const SizedBox(height: 14),
          _Notice(state.error!.message),
        ],
        const SizedBox(height: 26),
        PrimaryButton(
          key: const Key('verify_otp'),
          label: 'Verify & continue',
          loading: state.loading,
          onPressed: _verify,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: state.resendIn > 0 || state.loading ? null : ctrl.resendOtp,
            child: Text(state.resendIn > 0
                ? 'Resend code in 0:${state.resendIn.toString().padLeft(2, '0')}'
                : 'Resend code'),
          ),
        ),
      ],
    );
  }
}

/// Log in / Sign up switcher.
class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.selected, required this.onChanged});

  final OtpPurpose selected;
  final ValueChanged<OtpPurpose> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, OtpPurpose value) {
      final on = selected == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              boxShadow: on
                  ? [
                      BoxShadow(
                          color: AppColors.indigo.withValues(alpha: .12),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]
                  : null,
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: on ? AppColors.indigo : AppColors.muted,
                  )),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        tab('Log in', OtpPurpose.login),
        tab('Sign up', OtpPurpose.signup),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.info = false});

  final String message;
  final bool info;

  @override
  Widget build(BuildContext context) {
    final color = info ? AppColors.indigo : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(info ? Icons.info_outline_rounded : Icons.error_outline_rounded,
            size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: TextStyle(color: color, fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) => Expanded(
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: AppColors.indigo),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.25)),
          ]),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      item(Icons.verified_outlined, 'Verified\nastrologers'),
      item(Icons.lock_outline_rounded, 'Private &\nsecure'),
      item(Icons.bolt_rounded, 'Chat, call\nor video'),
    ]);
  }
}
