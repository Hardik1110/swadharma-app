
import 'package:flutter/material.dart';

import '../../../../core/brand/brand.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeroBackdrop(
        child: SizedBox.expand(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const BrandMark(size: 92),
            const SizedBox(height: 22),
            const Text(
              AppBrand.name,
              style: TextStyle(
                fontFamily: AppTheme.serif,
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: .6,
                fontFeatures: [FontFeature.liningFigures()],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Astrology, in conversation',
              style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 15, letterSpacing: .4),
            ),
            const SizedBox(height: 48),
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            ),
          ]),
        ),
      ),
    );
  }
}
