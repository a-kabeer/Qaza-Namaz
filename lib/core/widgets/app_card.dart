import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: margin,
      color: color,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
    return onTap == null
        ? card
        : InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: card,
          );
  }
}
