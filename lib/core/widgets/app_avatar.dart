import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Network avatar with initials fallback, optional status ring and dot.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 56,
    this.statusColor,
    this.ring = false,
  });

  final String name;
  final String? url;
  final double size;

  /// Presence colour: draws the corner dot (and the ring when [ring]).
  final Color? statusColor;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && p[0].toUpperCase() != p[0].toLowerCase())
        .where((p) => !p.endsWith('.'))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B49C9), AppColors.indigo],
        ),
      ),
      alignment: Alignment.center,
      child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * .34,
              letterSpacing: .5)),
    );

    final inset = ring ? size * .06 : 0.0;
    final image = ClipOval(
      child: SizedBox.square(
        dimension: size - inset * 2 - (ring ? 3 : 0),
        child: url == null || url!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );

    final dot = size * .27;
    return SizedBox.square(
      dimension: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: ring
              ? Container(
                  padding: EdgeInsets.all(inset),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor ?? AppColors.hairline, width: 1.8),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: image,
                    ),
                  ),
                )
              : Center(child: image),
        ),
        if (statusColor != null)
          Positioned(
            right: ring ? size * .02 : 0,
            bottom: ring ? size * .02 : 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.2),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Presence badge: "Online" / "Busy" / "Offline".
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: AppColors.readableOnLight(color),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2)),
        ]),
      );
}

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              rating >= i
                  ? Icons.star_rounded
                  : rating >= i - .5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: size,
              color: AppColors.gold,
            ),
        ],
      );
}
