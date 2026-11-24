import 'package:intl/intl.dart';

class Fmt {
  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  static String money(num v) => _currency.format(v);

  static String perMinute(num v) => '${money(v)}/min';

  /// 75 -> "01:15", 3725 -> "1:02:05"
  static String clock(int seconds) {
    final d = Duration(seconds: seconds < 0 ? 0 : seconds);
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
  }

  /// 75 -> "1 min 15 sec"
  static String duration(int seconds) {
    final m = seconds ~/ 60, s = seconds % 60;
    if (m == 0) return '$s sec';
    return s == 0 ? '$m min' : '$m min $s sec';
  }

  static String time(DateTime d) => DateFormat.jm().format(d.toLocal());

  static String dateTime(DateTime d) =>
      DateFormat('d MMM yyyy, h:mm a').format(d.toLocal());

  /// 24 Nov, 3:30 PM
  static String shortDateTime(DateTime d) =>
      DateFormat('d MMM, h:mm a').format(d.toLocal());

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d.toLocal());

  /// "Today", "Yesterday" or "12 Mar 2026".
  static String day(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(local.year, local.month, local.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return date(local);
  }

  /// "06:30" -> "6:30 AM"
  static String birthTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final dt = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return DateFormat.jm().format(dt);
  }

  static String phone(String p) =>
      p.length == 10 ? '+91 ${p.substring(0, 5)} ${p.substring(5)}' : p;
}
