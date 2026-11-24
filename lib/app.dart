import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/brand/brand.dart';
import 'core/network/realtime_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class AstroApp extends ConsumerWidget {
  const AstroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the realtime connection alive for the whole app lifetime.
    ref.watch(socketClientProvider);
    return MaterialApp.router(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
