import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cable_en_canvas.dart';

/// Dibuja todos los cables del canvas + el cable en progreso (preview).
///
/// Cada cable es una polilínea ortogonal dibujada con 4 capas de aspecto 3D.
/// [version] se incrementa externamente cada vez que los cables mutan, forzando
/// el repaint correcto incluso cuando la referencia de la lista no cambia.
class CablesPainter extends CustomPainter {
  const CablesPainter({
    required this.cables,
    required this.version,
    this.enProgreso,
    this.cableSeleccionadoId,
  });

  final List<CableEnCanvas> cables;

  /// Contador externo que cambia en cada mutación de cables.
  /// Necesario porque la lista se muta in-place y su referencia no cambia.
  final int version;

  final CableEnProgreso? enProgreso;
  final String? cableSeleccionadoId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final cable in cables) {
      _drawCable(
        canvas,
        puntos: cable.puntos,
        color: cable.colorCable.color,
        grosor: cable.grosorVisual,
        seleccionado: cable.id == cableSeleccionadoId,
      );
    }

    if (enProgreso != null) {
      _drawCableProgreso(
        canvas,
        puntos: enProgreso!.puntos,
        color: enProgreso!.colorCable.color,
      );
    }
  }

  // ── Cable completado ─────────────────────────────────────────────────────

  void _drawCable(
    Canvas canvas, {
    required List<Offset> puntos,
    required Color color,
    required double grosor,
    bool seleccionado = false,
  }) {
    if (puntos.length < 2) return;
    final path = _buildPath(puntos);

    // Indicador de selección — trazo exterior fino y discreto
    if (seleccionado) {
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2196F3).withValues(alpha: 0.18)
          ..strokeWidth = grosor + 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Capa 1: sombra (offset sólido, sin blur) ──────────────────────────
    canvas.drawPath(
      _buildPath(puntos.map((p) => p + const Offset(1.5, 2.0)).toList()),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..strokeWidth = grosor + 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // ── Capa 2: borde oscuro ──────────────────────────────────────────────
    canvas.drawPath(
      path,
      Paint()
        ..color = _darkVariant(color)
        ..strokeWidth = grosor + 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // ── Capa 3: color principal ───────────────────────────────────────────
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // ── Capa 4: reflejo/brillo ────────────────────────────────────────────
    canvas.drawPath(
      path,
      Paint()
        ..color = _highlightVariant(color)
        ..strokeWidth = (grosor * 0.28).clamp(1.0, 2.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // ── Puntos de conexión en extremos ────────────────────────────────────
    _drawEndpoint(canvas, puntos.first, color, grosor);
    _drawEndpoint(canvas, puntos.last, color, grosor);

    if (seleccionado) {
      _drawVertexDots(canvas, puntos, color);
    }
  }

  /// Dibuja un punto redondo en cada vértice intermedio.
  void _drawVertexDots(Canvas canvas, List<Offset> puntos, Color color) {
    for (int i = 1; i < puntos.length - 1; i++) {
      final p = puntos[i];
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..color = _darkVariant(color).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
  }

  /// Dibuja el punto de conexión en el extremo del cable (sin blur).
  void _drawEndpoint(Canvas canvas, Offset pos, Color color, double grosor) {
    final r = (grosor * 0.75).clamp(2.5, 5.5);

    // Sombra sólida offset (reemplaza el blur anterior)
    canvas.drawCircle(
      pos + const Offset(0.5, 1.0),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(pos, r,
        Paint()
          ..color = _darkVariant(color)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(pos, r * 0.75,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.drawCircle(
        pos - Offset(r * 0.2, r * 0.25),
        r * 0.22,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.fill);
  }

  // ── Cable en progreso (preview) ──────────────────────────────────────────

  void _drawCableProgreso(
    Canvas canvas, {
    required List<Offset> puntos,
    required Color color,
  }) {
    if (puntos.length < 2) return;

    // Sombra sólida offset (sin blur)
    canvas.drawPath(
      _buildPath(puntos.map((p) => p + const Offset(1, 1.5)).toList()),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Línea punteada ortogonal — segmento a segmento
    for (int i = 0; i < puntos.length - 1; i++) {
      _drawDashedLine(
        canvas,
        inicio: puntos[i],
        fin: puntos[i + 1],
        color: color.withValues(alpha: 0.80),
        strokeWidth: 3.0,
        dashLen: 10,
        gapLen: 6,
      );
    }

    _drawEndpoint(canvas, puntos.first, color, 3.5);

    canvas.drawCircle(
        puntos.last,
        6.0,
        Paint()
          ..color = color.withValues(alpha: 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    canvas.drawCircle(
        puntos.last,
        3.0,
        Paint()
          ..color = color.withValues(alpha: 0.50)
          ..style = PaintingStyle.fill);
  }

  // ── Utilidades ──────────────────────────────────────────────────────────

  Path _buildPath(List<Offset> puntos) {
    // Radio máximo de la curva en esquinas (unidades de canvas).
    // Sutil: nunca supera la mitad del segmento más corto adyacente.
    const double cornerRadius = 10.0;

    final path = Path()..moveTo(puntos[0].dx, puntos[0].dy);

    for (int i = 1; i < puntos.length; i++) {
      final prev = puntos[i - 1];
      final curr = puntos[i];

      // Último punto: llegar directo sin curva saliente
      if (i == puntos.length - 1) {
        path.lineTo(curr.dx, curr.dy);
        continue;
      }

      final next = puntos[i + 1];

      // Radio limitado por la longitud de los dos segmentos adyacentes
      final lenIn  = (curr - prev).distance;
      final lenOut = (next - curr).distance;
      final r = cornerRadius.clamp(0.0, (lenIn * 0.45).clamp(0.0, lenOut * 0.45));

      // Puntos de tangencia: r unidades antes y después del vértice
      final tIn  = curr + (prev - curr) / lenIn  * r;
      final tOut = curr + (next - curr) / lenOut * r;

      path.lineTo(tIn.dx, tIn.dy);
      // Curva cuadrática con el vértice como punto de control
      path.quadraticBezierTo(curr.dx, curr.dy, tOut.dx, tOut.dy);
    }

    return path;
  }

  void _drawDashedLine(
    Canvas canvas, {
    required Offset inicio,
    required Offset fin,
    required Color color,
    double strokeWidth = 2,
    double dashLen = 8,
    double gapLen = 5,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final total = (fin - inicio).distance;
    if (total == 0) return;

    final direction = (fin - inicio) / total;
    double drawn = 0;
    bool drawing = true;

    while (drawn < total) {
      final segLen = drawing ? dashLen : gapLen;
      final end = math.min(drawn + segLen, total);
      if (drawing) {
        canvas.drawLine(
          inicio + direction * drawn,
          inicio + direction * end,
          paint,
        );
      }
      drawn = end;
      drawing = !drawing;
    }
  }

  static Color _darkVariant(Color c) {
    final hsl = HSLColor.fromColor(c);
    final drop = hsl.lightness > 0.85 ? 0.40 : 0.22;
    return hsl
        .withLightness((hsl.lightness - drop).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _highlightVariant(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + 0.38).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation - 0.15).clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: 0.75);
  }

  @override
  bool shouldRepaint(CablesPainter old) =>
      old.version != version ||
      old.enProgreso != enProgreso ||
      old.cableSeleccionadoId != cableSeleccionadoId;
}
