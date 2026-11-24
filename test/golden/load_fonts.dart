import 'dart:io';

import 'package:flutter/services.dart';

/// Widget tests draw text as blocks unless fonts are loaded by hand.
Future<void> loadAppFonts() async {
  Future<void> load(String family, Future<ByteData> data) async {
    final loader = FontLoader(family)..addFont(data);
    await loader.load();
  }

  await load('DMSans', rootBundle.load('assets/fonts/DMSans.ttf'));
  await load('PlayfairDisplay', rootBundle.load('assets/fonts/PlayfairDisplay.ttf'));

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await load('MaterialIcons', Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    }
  }
}
