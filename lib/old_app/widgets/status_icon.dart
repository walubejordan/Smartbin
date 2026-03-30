import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Circular icon with a 10% opacity background bubble.
class StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const StatusIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: FaIcon(
          icon,
          size: size,
          color: color,
        ),
      ),
    );
  }
}

