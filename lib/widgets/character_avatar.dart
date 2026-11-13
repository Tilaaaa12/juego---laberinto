import 'dart:math';

import 'package:flutter/material.dart';

import '../models/player_character.dart';

class CharacterAvatar extends StatefulWidget {
  const CharacterAvatar({
    required this.character,
    required this.size,
    this.backgroundColor = Colors.transparent,
    super.key,
  });

  final PlayerCharacter character;
  final double size;
  final Color backgroundColor;

  @override
  State<CharacterAvatar> createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => CustomPaint(
          painter: _CharacterPainter(
            character: widget.character,
            phase: _animationController.value,
            background: widget.backgroundColor,
          ),
        ),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  const _CharacterPainter({
    required this.character,
    required this.phase,
    required this.background,
  });

  final PlayerCharacter character;
  final double phase;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 100);
    final bob = sin(phase * pi) * 2.2;
    canvas.translate(0, -bob);
    switch (character) {
      case PlayerCharacter.chomper:
        _paintChomper(canvas);
        break;
      case PlayerCharacter.ghost:
        _paintGhost(canvas);
        break;
      case PlayerCharacter.ball:
        _paintBall(canvas);
        break;
      case PlayerCharacter.penguin:
        _paintPenguin(canvas);
        break;
    }
    canvas.restore();
  }

  void _paintChomper(Canvas canvas) {
    const radius = 39.0;
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xFFFFD83D),
    );
    final mouthAngle = 0.08 + sin(phase * pi) * 0.48;
    final mouth = Path()
      ..moveTo(0, 0)
      ..lineTo(radius * cos(-mouthAngle), radius * sin(-mouthAngle))
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        -mouthAngle,
        mouthAngle * 2,
        false,
      )
      ..close();
    canvas.drawPath(mouth, Paint()..color = background);
    canvas.drawCircle(
      const Offset(-8, -16),
      4,
      Paint()..color = const Color(0xFF3B321B),
    );
  }

  void _paintGhost(Canvas canvas) {
    final body = Path()
      ..moveTo(-34, 34)
      ..lineTo(-34, -2)
      ..arcToPoint(
        const Offset(34, -2),
        radius: const Radius.circular(34),
        clockwise: false,
      )
      ..lineTo(34, 33)
      ..quadraticBezierTo(26, 22, 17, 34)
      ..quadraticBezierTo(8, 22, 0, 34)
      ..quadraticBezierTo(-9, 22, -17, 34)
      ..quadraticBezierTo(-26, 22, -34, 34)
      ..close();
    canvas.drawShadow(body, const Color(0x33000000), 3, true);
    canvas.drawPath(body, Paint()..color = const Color(0xFF8A78F5));
    for (final x in [-12.0, 12.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, -5), width: 15, height: 19),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(x + 2, -3),
        4.5,
        Paint()..color = const Color(0xFF28254D),
      );
    }
  }

  void _paintBall(Canvas canvas) {
    final ballRect = Rect.fromCircle(center: Offset.zero, radius: 39);
    canvas.drawCircle(
      Offset.zero,
      39,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Color(0xFFFF8C42), Color(0xFFE8425D), Color(0xFF7C3AED)],
          stops: [0, 0.58, 1],
        ).createShader(ballRect),
    );
    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      ballRect.deflate(9),
      phase * pi,
      pi * 1.15,
      false,
      seamPaint,
    );
    canvas.drawLine(
      Offset(-30 * cos(phase * pi), -24),
      Offset(30 * cos(phase * pi), 24),
      seamPaint,
    );
    canvas.drawCircle(
      const Offset(-13, -17),
      6,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  void _paintPenguin(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 4), width: 62, height: 78),
      Paint()..color = const Color(0xFF202C34),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 13), width: 39, height: 49),
      Paint()..color = const Color(0xFFF9F7EE),
    );
    for (final x in [-10.0, 10.0]) {
      canvas.drawCircle(Offset(x, -13), 7.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x + 1, -12),
        3.5,
        Paint()..color = const Color(0xFF172127),
      );
    }
    final beak = Path()
      ..moveTo(-7, -3)
      ..lineTo(7, -3)
      ..lineTo(0, 5)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFF9E3D));
    final feet = Paint()..color = const Color(0xFFFF9E3D);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-15, 42), width: 21, height: 9),
      feet,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(15, 42), width: 21, height: 9),
      feet,
    );
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter oldDelegate) =>
      oldDelegate.character != character ||
      oldDelegate.phase != phase ||
      oldDelegate.background != background;
}
