// lib/widgets/primary_button.dart
import 'package:flutter/material.dart';

/// A polished, accessible primary button used across the app.
/// - Large tap target
/// - Optional icon
/// - Disabled state
/// - Consistent padding, border radius and shadow to match app's look-and-feel.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.compact = false,
  });

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onPrimary;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 40 : 52),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: _enabled ? 4 : 0,
          shadowColor: Colors.black.withOpacity(0.15),
          backgroundColor: _enabled ? primaryColor : theme.disabledColor.withOpacity(0.12),
          foregroundColor: _enabled ? textColor : theme.disabledColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: compact ? 18 : 20),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _enabled ? textColor : theme.disabledColor,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 14 : 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convenience constructor that shows an icon before the label.
  static Widget withIcon({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    double borderRadius = 16.0,
    bool compact = false,
  }) {
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      borderRadius: borderRadius,
      compact: compact,
    );
  }
}
