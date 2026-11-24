import 'user.dart';

/// [astrologer] signs in to the astrologer app with a registered number.
enum OtpPurpose { login, signup, astrologer }

class OtpTicket {
  const OtpTicket({required this.resendIn, this.devOtp});

  final Duration resendIn;

  /// Returned by the demo backend so the flow works without SMS. Null when a
  /// real SMS was sent.
  final String? devOtp;
}

abstract class AuthRepository {
  /// Cached user from the last session, without a network call.
  User? cachedUser();

  /// Fetches the current user from the backend.
  Future<User> fetchMe();

  Future<OtpTicket> sendOtp(String phone, OtpPurpose purpose);

  /// Verifies the code, stores the token and returns the user.
  Future<User> verifyOtp({
    required String phone,
    required String otp,
    required OtpPurpose purpose,
    String? name,
  });

  Future<User> updateProfile(ProfileInput input);

  Future<void> logout();
}
