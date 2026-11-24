class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const profileSetup = '/profile-setup';
  static const astrologers = '/astrologers';
  static const history = '/history';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const wallet = '/wallet';

  // Astrologer app
  static const desk = '/desk';
  static const deskHistory = '/desk/history';
  static const deskProfile = '/desk/profile';

  static String astrologer(String id) => '/astrologers/$id';
  static String consultation(String id) => '/consultation/$id';
}
