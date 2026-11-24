import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/auth_repository.dart';
import 'auth_providers.dart';

enum LoginStep { details, otp }

class LoginState extends Equatable {
  const LoginState({
    this.purpose = OtpPurpose.login,
    this.step = LoginStep.details,
    this.phone = '',
    this.name = '',
    this.loading = false,
    this.error,
    this.devOtp,
    this.resendIn = 0,
  });

  final OtpPurpose purpose;
  final LoginStep step;
  final String phone;
  final String name;
  final bool loading;
  final AppException? error;
  final String? devOtp;

  /// Seconds until "Resend OTP" is enabled.
  final int resendIn;

  LoginState copyWith({
    OtpPurpose? purpose,
    LoginStep? step,
    String? phone,
    String? name,
    bool? loading,
    AppException? error,
    String? devOtp,
    int? resendIn,
  }) =>
      LoginState(
        purpose: purpose ?? this.purpose,
        step: step ?? this.step,
        phone: phone ?? this.phone,
        name: name ?? this.name,
        loading: loading ?? this.loading,
        error: error,
        devOtp: devOtp ?? this.devOtp,
        resendIn: resendIn ?? this.resendIn,
      );

  @override
  List<Object?> get props =>
      [purpose, step, phone, name, loading, error, devOtp, resendIn];
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(LoginController.new);

class LoginController extends Notifier<LoginState> {
  Timer? _countdown;

  @override
  LoginState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const LoginState();
  }

  static String? validatePhone(String phone) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(phone)
          ? null
          : 'Enter a valid 10-digit mobile number';

  static String? validateName(String name) =>
      name.trim().length < 2 ? 'Please enter your full name' : null;

  void setPurpose(OtpPurpose purpose) {
    if (state.loading) return;
    state = LoginState(purpose: purpose, phone: state.phone);
  }

  Future<void> requestOtp({required String phone, String name = ''}) async {
    final invalid = validatePhone(phone) ??
        (state.purpose == OtpPurpose.signup ? validateName(name) : null);
    if (invalid != null) {
      state = state.copyWith(error: AppException(invalid, code: 'validation'));
      return;
    }
    state = state.copyWith(loading: true, phone: phone, name: name.trim());
    await _send();
  }

  Future<void> resendOtp() async {
    if (state.resendIn > 0 || state.loading) return;
    state = state.copyWith(loading: true);
    await _send();
  }

  Future<void> _send() async {
    try {
      final ticket =
          await ref.read(authRepositoryProvider).sendOtp(state.phone, state.purpose);
      if (!ref.mounted) return;
      state = state.copyWith(
        step: LoginStep.otp,
        loading: false,
        devOtp: ticket.devOtp,
        resendIn: ticket.resendIn.inSeconds,
      );
      _startCountdown();
    } on AppException catch (e) {
      if (!ref.mounted) return;
      // Wrong tab for this number: switch to the right flow instead of
      // leaving the user at a dead end.
      final switchTo = switch (e.code) {
        'account_not_found' => OtpPurpose.signup,
        'account_exists' => OtpPurpose.login,
        _ => null,
      };
      if (switchTo != null) {
        state = LoginState(
          purpose: switchTo,
          phone: state.phone,
          name: state.name,
          error: AppException(
            switchTo == OtpPurpose.signup
                ? 'No account found for this number. Enter your name and continue to sign up.'
                : 'This number already has an account. Tap Get OTP to log in.',
            code: 'switched',
          ),
        );
        return;
      }
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> verify(String otp) async {
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      state = state.copyWith(
          error: const AppException('Enter the 6-digit OTP', code: 'validation'));
      return;
    }
    state = state.copyWith(loading: true);
    try {
      final user = await ref.read(authRepositoryProvider).verifyOtp(
            phone: state.phone,
            otp: otp,
            purpose: state.purpose,
            name: state.purpose == OtpPurpose.signup ? state.name : null,
          );
      // Router redirect takes over from here.
      ref.read(authProvider.notifier).setUser(user);
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  void editDetails() {
    _countdown?.cancel();
    state = LoginState(purpose: state.purpose, phone: state.phone, name: state.name);
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state.resendIn <= 1) {
        t.cancel();
        state = state.copyWith(resendIn: 0, error: state.error);
      } else {
        state = state.copyWith(resendIn: state.resendIn - 1, error: state.error);
      }
    });
  }
}
