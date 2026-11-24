import 'dart:math';

import 'package:astro_connect/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + .05) / (min(la, lb) + .05);
}

void main() {
  // Text must reach 4.5:1 (WCAG AA) against what it sits on.
  final textPairs = <String, (Color, Color)>{
    'body text on ivory': (AppColors.ink, AppColors.ivory),
    'body text on white': (AppColors.ink, Colors.white),
    'muted text on ivory': (AppColors.muted, AppColors.ivory),
    'muted text on white': (AppColors.muted, Colors.white),
    'white on indigo (buttons)': (Colors.white, AppColors.indigo),
    'white on hero backdrop': (Colors.white, AppColors.indigoDeep),
    'indigo on lavender (chips)': (AppColors.indigo, AppColors.lavender),
    'dark text on saffron (buttons, pills)': (AppColors.onSaffron, AppColors.saffron),
    'saffron label text on white': (AppColors.saffronText, Colors.white),
    'saffron label text on soft saffron': (AppColors.saffronText, AppColors.saffronSoft),
    'amber label text on white': (AppColors.busyText, Colors.white),
    'success green on white': (AppColors.success, Colors.white),
    'success green on ivory': (AppColors.success, AppColors.ivory),
    'danger red on white': (AppColors.danger, Colors.white),
  };

  for (final entry in textPairs.entries) {
    test('${entry.key} is readable', () {
      final (fg, bg) = entry.value;
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5),
          reason: '${entry.key}: ${contrast(fg, bg).toStringAsFixed(2)}:1');
    });
  }

  test('readableOnLight darkens the bright accents and leaves the rest alone', () {
    expect(AppColors.readableOnLight(AppColors.saffron), AppColors.saffronText);
    expect(AppColors.readableOnLight(AppColors.busy), AppColors.busyText);
    expect(AppColors.readableOnLight(AppColors.indigo), AppColors.indigo);
    for (final c in [AppColors.saffron, AppColors.busy, AppColors.offline, AppColors.success]) {
      expect(contrast(AppColors.readableOnLight(c), Colors.white), greaterThanOrEqualTo(4.5));
    }
  });
}
