import 'package:flutter/material.dart';

class AnimatedActionButton extends StatefulWidget {
  const AnimatedActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed
              ? 0.97
              : _hovered
              ? 1.015
              : 1,
          duration: const Duration(milliseconds: 140),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onPressed,
              icon: Icon(widget.icon ?? Icons.arrow_forward_rounded),
              label: Text(widget.label),
              style: FilledButton.styleFrom(
                elevation: _hovered ? 4 : 1,
                backgroundColor: widget.primary
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor: widget.primary
                    ? colors.onPrimary
                    : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
