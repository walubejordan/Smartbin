import 'package:flutter/material.dart';

/// Gradient "SmartBin" icon driven by fill level.
///
/// Empty => green, Full => red.
class SmartBinFillIcon extends StatelessWidget {
  final double fillLevel; // expected 0..100
  final double size;
  final Color emptyColor;
  final Color fullColor;
  final IconData icon;

  const SmartBinFillIcon({
    super.key,
    required this.fillLevel,
    this.size = 26,
    this.emptyColor = Colors.green,
    this.fullColor = Colors.red,
    this.icon = Icons.sensors_rounded,
  });

  Color _lerp(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return Color.lerp(emptyColor, fullColor, clamped)!;
  }

  @override
  Widget build(BuildContext context) {
    final t = (fillLevel / 100).clamp(0.0, 1.0);

    final primary = _lerp(t);

    // Vertical gradient: top is "cleaner", bottom is "fuller".
    final topColor = Color.lerp(Colors.white, primary, 0.25 + 0.35 * t)!;
    final bottomColor = Color.lerp(Colors.black, primary, 0.25 + 0.55 * t)!;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, bottomColor],
          ).createShader(bounds),
          child: Icon(
            icon,
            size: size,
            color: Colors.white, // used as mask; actual colors come from ShaderMask
          ),
        ),
      ),
    );
  }
}

