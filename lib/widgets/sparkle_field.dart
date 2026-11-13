import 'dart:math';

import 'package:flutter/material.dart';

class SparkleField extends StatefulWidget {
  const SparkleField({required this.color, super.key});

  final Color color;

  @override
  State<SparkleField> createState() => _SparkleFieldState();
}

class _SparkleFieldState extends State<SparkleField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => CustomPaint(
      painter: _SparklePainter(phase: _controller.value, color: widget.color),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  static const _positions = [
    Offset(0.78, 0.18),
    Offset(0.92, 0.38),
    Offset(0.68, 0.77),
    Offset(0.86, 0.83),
    Offset(0.56, 0.14),
    Offset(0.95, 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < _positions.length; index++) {
      final cycle = (phase + index / _positions.length) % 1;
      final opacity = 0.18 + (sin(cycle * pi * 2) + 1) * 0.22;
      final radius = 1.3 + (sin(cycle * pi * 2) + 1) * 1.4;
      final center = Offset(
        size.width * _positions[index].dx,
        size.height * _positions[index].dy,
      );
      final paint = Paint()..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
      canvas.drawLine(
        center.translate(-radius * 1.6, 0),
        center.translate(radius * 1.6, 0),
        paint..strokeWidth = 0.8,
      );
      canvas.drawLine(
        center.translate(0, -radius * 1.6),
        center.translate(0, radius * 1.6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}
