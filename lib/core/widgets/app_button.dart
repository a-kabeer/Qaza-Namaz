import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = secondary
        ? (icon == null
              ? OutlinedButton(onPressed: onPressed, child: Text(label))
              : OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                ))
        : (icon == null
              ? FilledButton(onPressed: onPressed, child: Text(label))
              : FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                ));
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: color,
    );
  }
}
