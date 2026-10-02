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
    required this.surfaceColor,
    required this.outlineColor,
    required this.onSurfaceColor,
    required this.onSurfaceVariantColor,
    required this.primaryColor,
  });

  final double qiblaBearing;
  final double heading;
  final bool showRelativeQibla;
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

    final inset = size.shortestSide >= 160 ? 34.0 : 20.0;
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

    final qiblaAngle = qiblaBearing * math.pi / 180 - math.pi / 2;
    final markerDistance = radius - (size.shortestSide >= 160 ? 42 : 24);
    final markerCenter = Offset(
      center.dx + math.cos(qiblaAngle) * markerDistance,
      center.dy + math.sin(qiblaAngle) * markerDistance,
    );

    final direction = markerCenter - center;
    final length = direction.distance;
    if (length > 0) {
      final unit = direction / length;
      final arrowTip = markerCenter - unit * (size.shortestSide >= 160 ? 11 : 7);
      final perpendicular = Offset(-unit.dy, unit.dx);

      final arrowPaint = Paint()
        ..color = primaryColor
        ..strokeWidth = size.shortestSide >= 160 ? 6 : 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, arrowTip, arrowPaint);

      final headLength = size.shortestSide >= 160 ? 22.0 : 10.0;
      final headWidth = size.shortestSide >= 160 ? 11.0 : 6.0;
      final left = arrowTip - unit * headLength + perpendicular * headWidth;
      final right = arrowTip - unit * headLength - perpendicular * headWidth;
      final path = Path()
        ..moveTo(arrowTip.dx, arrowTip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = primaryColor);
    }

    canvas.drawCircle(
      center,
      size.shortestSide >= 160 ? 7 : 4,
      Paint()..color = primaryColor,
    );

    _drawKaaba(
      canvas,
      markerCenter,
      size.shortestSide >= 160 ? 18 : 11,
    );

    canvas.restore();
  }

  void _drawKaaba(
    Canvas canvas,
    Offset center,
    double size,
  ) {
    final bodyRect = Rect.fromCenter(
      center: center,
      width: size,
      height: size * .86,
    );
    final body = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(size * .12),
    );
    canvas.drawRRect(
      body,
      Paint()..color = onSurfaceColor,
    );

    final band = Rect.fromCenter(
      center: Offset(center.dx, center.dy - size * .08),
      width: size,
      height: size * .16,
    );
    canvas.drawRect(
      band,
      Paint()..color = primaryColor,
    );

    final door = Rect.fromCenter(
      center: Offset(center.dx, center.dy + size * .22),
      width: size * .22,
      height: size * .32,
    );
    canvas.drawRect(
      door,
      Paint()..color = primaryColor,
    );
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
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.onSurfaceColor != onSurfaceColor ||
      oldDelegate.onSurfaceVariantColor != onSurfaceVariantColor ||
      oldDelegate.primaryColor != primaryColor;
}
