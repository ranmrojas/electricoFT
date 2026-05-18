import 'package:flutter/material.dart';

class CanvasGridPainter extends CustomPainter {
  const CanvasGridPainter({
    this.gridSize = 40.0,
    this.color = const Color(0xFFDDE3EA),
    this.dotColor = const Color(0xFFB0BEC5),
  });

  final double gridSize;
  final Color color;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    final dotPaint = Paint()
      ..color = dotColor
      ..strokeWidth = 2;

    // líneas verticales
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // líneas horizontales
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // puntos en intersecciones cada 4 celdas
    for (double x = 0; x <= size.width; x += gridSize * 4) {
      for (double y = 0; y <= size.height; y += gridSize * 4) {
        canvas.drawCircle(Offset(x, y), 2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(CanvasGridPainter old) =>
      old.gridSize != gridSize || old.color != color;
}
