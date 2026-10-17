import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reusable Qibla compass dial used by both the summary card and detail screen.
///
/// When [showRelativeQibla] is true, [heading] is the device's true heading and
/// the dial rotates with the device. Otherwise the dial remains fixed at north
/// and shows the calculated Qibla bearing.
class QiblaDialPainter extends CustomPainter {
  const QiblaDialPainter({
    required this.qiblaBearing,
    required this.heading,
    required this.showRelativeQibla,
    this.showCardinals = true,
    required this.surfaceColor,
    required this.outlineColor,
    required this.onSurfaceColor,
    required this.onSurfaceVariantColor,
    required this.primaryColor,
  });

  final double qiblaBearing;
  final double heading;
  final bool showRelativeQibla;
  final bool showCardinals;
  final Color surfaceColor;
  final Color outlineColor;
  final Color onSurfaceColor;
  final Color onSurfaceVariantColor;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    if (radius <= 0) return;

    final circlePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = surfaceColor;
    canvas.drawCircle(center, radius, circlePaint);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide >= 160 ? 2 : 1.5
      ..color = outlineColor;
    canvas.drawCircle(center, radius, outlinePaint);

    canvas.save();
    if (showRelativeQibla) {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-heading * math.pi / 180);
      canvas.translate(-center.dx, -center.dy);
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final inset = size.shortestSide >= 160 ? 34.0 : 18.0;
    if (showCardinals) {
      _drawCardinal(
        canvas,
        textPainter,
        'N',
        Offset(center.dx, center.dy - radius + inset),
        onSurfaceColor,
        size.shortestSide >= 160 ? 18 : 11,
      );
      _drawCardinal(
        canvas,
        textPainter,
        'E',
        Offset(center.dx + radius - inset, center.dy),
        onSurfaceVariantColor,
        size.shortestSide >= 160 ? 18 : 11,
      );
      _drawCardinal(
        canvas,
        textPainter,
        'S',
        Offset(center.dx, center.dy + radius - inset),
        onSurfaceVariantColor,
        size.shortestSide >= 160 ? 18 : 11,
      );
      _drawCardinal(
        canvas,
        textPainter,
        'W',
        Offset(center.dx - radius + inset, center.dy),
        onSurfaceVariantColor,
        size.shortestSide >= 160 ? 18 : 11,
      );
    }

    final qiblaAngle = qiblaBearing * math.pi / 180 - math.pi / 2;
    final direction = Offset(math.cos(qiblaAngle), math.sin(qiblaAngle));
    final perpendicular = Offset(-direction.dy, direction.dx);
    final largeDial = size.shortestSide >= 160;
    final pointerTipDistance = radius - (largeDial ? 30.0 : 18.0);
    final pointerTailDistance = largeDial ? 30.0 : 15.0;
    final pointerHalfWidth = largeDial ? 7.0 : 4.0;
    final tip = center + direction * pointerTipDistance;
    final tail = center - direction * pointerTailDistance;
    final left = center + perpendicular * pointerHalfWidth;
    final right = center - perpendicular * pointerHalfWidth;

    // A restrained two-tone compass needle replaces the custom arrow and
    // Kaaba drawing. Its primary tip always points along the Qibla bearing.
    final qiblaNeedle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(
      qiblaNeedle,
      Paint()..color = onSurfaceVariantColor.withValues(alpha: .24),
    );

    final qiblaTip = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(qiblaTip, Paint()..color = primaryColor);

    canvas.drawCircle(
      center,
      largeDial ? 5 : 3,
      Paint()..color = primaryColor,
    );

    canvas.restore();
  }


  void _drawCardinal(
    Canvas canvas,
    TextPainter painter,
    String label,
    Offset center,
    Color color,
    double fontSize,
  ) {
    painter.text = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant QiblaDialPainter oldDelegate) =>
      oldDelegate.qiblaBearing != qiblaBearing ||
      oldDelegate.heading != heading ||
      oldDelegate.showRelativeQibla != showRelativeQibla ||
      oldDelegate.showCardinals != showCardinals ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.onSurfaceColor != onSurfaceColor ||
      oldDelegate.onSurfaceVariantColor != onSurfaceVariantColor ||
      oldDelegate.primaryColor != primaryColor;
}
