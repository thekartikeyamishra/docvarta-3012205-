// lib/widgets/verified_badge.dart
import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final bool verified;
  const VerifiedBadge({super.key, required this.verified});
  @override
  Widget build(BuildContext context) {
    if (!verified) return SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.verified, color: Colors.blue, size: 18),
        SizedBox(width: 4),
        Text('Verified', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
