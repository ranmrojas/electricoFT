import 'package:flutter/material.dart';

/// Capa de handles de vértices para el cable seleccionado.
///
/// Se coloca DENTRO del Stack del InteractiveViewer, de modo que sus
/// coordenadas son directamente coordenadas de canvas (sin transformar).
///
/// Comportamiento:
///   • Vértices intermedios (naranja): arrastrables, doble-tap o long-press para eliminar.
///   • Extremos (azul): solo indicativos — fijos al terminal del componente.
///
/// Las callbacks devuelven deltas/índices ya en coordenadas de canvas.
class CableVertexLayer extends StatelessWidget {
  const CableVertexLayer({
    required this.puntos,
    required this.escala,
    required this.onMoverVertice,
    required this.onEliminarVertice,
    super.key,
  });

  /// Lista de vértices del cable en coordenadas de canvas.
  final List<Offset> puntos;

  /// Escala actual del InteractiveViewer (para convertir delta de pantalla → canvas).
  final double escala;

  /// Llamado en cada onPanUpdate. [delta] ya está en coordenadas de canvas.
  final void Function(int idx, Offset delta) onMoverVertice;

  /// Llamado al doble-tap o long-press sobre un vértice intermedio.
  final void Function(int idx) onEliminarVertice;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < puntos.length; i++)
            _VertexHandle(
              key: ValueKey(i),
              pos: puntos[i],
              isEndpoint: i == 0 || i == puntos.length - 1,
              escala: escala,
              onDragDelta: (delta) => onMoverVertice(i, delta),
              onDelete: (i > 0 && i < puntos.length - 1)
                  ? () => onEliminarVertice(i)
                  : null,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VertexHandle extends StatefulWidget {
  const _VertexHandle({
    required this.pos,
    required this.isEndpoint,
    required this.escala,
    required this.onDragDelta,
    this.onDelete,
    super.key,
  });

  final Offset pos;
  final bool isEndpoint;
  final double escala;
  final void Function(Offset delta) onDragDelta;
  final VoidCallback? onDelete;

  @override
  State<_VertexHandle> createState() => _VertexHandleState();
}

class _VertexHandleState extends State<_VertexHandle> {
  bool _hovered = false;
  bool _dragging = false;

  // Radio visual en unidades de canvas
  static const double _r = 4.5;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color ring;
    final MouseCursor cursor;

    if (widget.isEndpoint) {
      fill = const Color(0xFF1565C0);
      ring = Colors.white;
      cursor = SystemMouseCursors.basic;
    } else if (_dragging) {
      fill = const Color(0xFFE65100);
      ring = Colors.white;
      cursor = SystemMouseCursors.grabbing;
    } else if (_hovered) {
      fill = const Color(0xFFF57C00);
      ring = Colors.white;
      cursor = SystemMouseCursors.grab;
    } else {
      fill = const Color(0xFFFF9800);
      ring = const Color(0xFFFFFFFF);
      cursor = SystemMouseCursors.grab;
    }

    return Positioned(
      left: widget.pos.dx - _r,
      top: widget.pos.dy - _r,
      width: _r * 2,
      height: _r * 2,
      child: MouseRegion(
        cursor: cursor,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _dragging = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: widget.isEndpoint
              ? null
              : (_) => setState(() => _dragging = true),
          onPanUpdate: widget.isEndpoint
              ? null
              : (d) => widget.onDragDelta(d.delta / widget.escala),
          onPanEnd: widget.isEndpoint
              ? null
              : (_) => setState(() => _dragging = false),
          onPanCancel: widget.isEndpoint
              ? null
              : () => setState(() => _dragging = false),
          onDoubleTap: widget.onDelete,
          onLongPress: widget.onDelete,
          child: CustomPaint(
            painter: _VertexDotPainter(
              fill: fill,
              ring: ring,
              isEndpoint: widget.isEndpoint,
              hovered: _hovered,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _VertexDotPainter extends CustomPainter {
  const _VertexDotPainter({
    required this.fill,
    required this.ring,
    required this.isEndpoint,
    required this.hovered,
  });

  final Color fill;
  final Color ring;
  final bool isEndpoint;
  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Sombra sólida offset (sin blur, sin GPU cost)
    canvas.drawCircle(
      center + const Offset(0.5, 1.0),
      r,
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.fill,
    );

    // Relleno
    canvas.drawCircle(center, r, Paint()..color = fill..style = PaintingStyle.fill);

    // Aro exterior
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Para intermedios: pequeño punto central que indica que es editable
    if (!isEndpoint) {
      canvas.drawCircle(
        center,
        r * 0.28,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_VertexDotPainter old) =>
      old.fill != fill || old.ring != ring || old.hovered != hovered;
}
