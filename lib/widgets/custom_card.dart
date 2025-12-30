// lib/widgets/custom_card.dart
import 'package:flutter/material.dart';

/// Lightweight custom card wrapper used for consistent rounded cards across the app.
/// - Provides padding, border radius, elevation and optional color.
/// - Keeps markup small in screens while maintaining consistent style.
class CustomCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double elevation;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.borderRadius = 14.0,
    this.elevation = 2.5,
    this.color,
    this.padding = const EdgeInsets.all(12.0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = color ?? theme.cardColor;

    final card = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (elevation > 0)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: elevation * 2,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}
