import 'package:flutter/material.dart';

class DiceFace extends StatelessWidget {
  const DiceFace({required this.value, required this.color, super.key});

  final int value;
  final Color color;

  static const _pipPositions = <int, Set<int>>{
    1: {4},
    2: {0, 8},
    3: {0, 4, 8},
    4: {0, 2, 6, 8},
    5: {0, 2, 4, 6, 8},
    6: {0, 2, 3, 5, 6, 8},
  };

  @override
  Widget build(BuildContext context) {
    final pips = _pipPositions[value] ?? _pipPositions[1]!;
    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) => Center(
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: pips.contains(index) ? color : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
