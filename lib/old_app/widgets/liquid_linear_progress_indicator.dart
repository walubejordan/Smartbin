import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A "liquid" horizontal progress indicator with a wavy edge.
class LiquidLinearProgressIndicator extends StatefulWidget {
  final double value; // 0..1
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration animationDuration;

  const LiquidLinearProgressIndicator({
    super.key,
    required this.value,
    required this.color,
    this.backgroundColor = const Color(0xFFE0E3E7),
    this.height = 12,
    this.animationDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<LiquidLinearProgressIndicator> createState() =>
      _LiquidLinearProgressIndicatorState();
}

class _LiquidLinearProgressIndicatorState
    extends State<LiquidLinearProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(LiquidLinearProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _controller.duration = widget.animationDuration;
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final filledWidth = width * v;

        if (filledWidth <= 0) {
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: Stack(
            children: [
              // Background track
              Positioned.fill(
                child: Container(
                  color: widget.backgroundColor,
                ),
              ),
              // Filled liquid area (wavy right edge)
              Positioned(
                left: 0,
                width: filledWidth,
                top: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final phase = _controller.value * 2 * math.pi;
                    final amp = widget.height * 0.28; // wave amplitude
                    const freq = 1.6; // wave frequency
                    return ClipPath(
                      clipper: _RightWavyClipper(
                        phase: phase,
                        amplitude: amp,
                        frequency: freq,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withOpacity(0.35),
                              widget.color,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RightWavyClipper extends CustomClipper<Path> {
  final double phase;
  final double amplitude;
  final double frequency;

  _RightWavyClipper({
    required this.phase,
    required this.amplitude,
    required this.frequency,
  });

  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;

    // Points along the right edge create the wavy "liquid" surface.
    const steps = 14;
    final step = h / steps;

    final path = Path();
    path.moveTo(0, 0);

    // Start at the top-left, then go along the wavy right edge downwards.
    for (int i = 0; i <= steps; i++) {
      final y = i * step;
      final t = y / h;
      final xEdge = w - amplitude * math.sin(phase + t * 2 * math.pi * frequency);
      path.lineTo(xEdge.clamp(0, w), y);
    }

    // Close back to bottom-left.
    path.lineTo(0, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _RightWavyClipper oldClipper) {
    return oldClipper.phase != phase ||
        oldClipper.amplitude != amplitude ||
        oldClipper.frequency != frequency;
  }
}

