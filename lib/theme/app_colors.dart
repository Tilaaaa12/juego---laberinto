import 'package:flutter/material.dart';

class GameColors {
  const GameColors({
    required this.background,
    required this.surface,
    required this.ink,
    required this.forest,
    required this.mint,
    required this.coral,
    required this.muted,
    required this.floor,
    required this.floorAlternate,
    required this.wall,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color forest;
  final Color mint;
  final Color coral;
  final Color muted;
  final Color floor;
  final Color floorAlternate;
  final Color wall;

  static GameColors forBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const GameColors(
        background: Color(0xFF101A18),
        surface: Color(0xFF1D2B27),
        ink: Color(0xFFEAF1E9),
        forest: Color(0xFF24483E),
        mint: Color(0xFFC9F36A),
        coral: Color(0xFFFF9274),
        muted: Color(0xFFA8B7AE),
        floor: Color(0xFF35463D),
        floorAlternate: Color(0xFF2D3E36),
        wall: Color(0xFF15221E),
      );
    }
    return const GameColors(
      background: Color(0xFFF4F3E9),
      surface: Colors.white,
      ink: Color(0xFF183B35),
      forest: Color(0xFF214F45),
      mint: Color(0xFFC9F36A),
      coral: Color(0xFFF07B5B),
      muted: Color(0xFF73837B),
      floor: Color(0xFFE8EFD9),
      floorAlternate: Color(0xFFDFE8D0),
      wall: Color(0xFF183B35),
    );
  }
}
