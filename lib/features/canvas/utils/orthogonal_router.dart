import 'dart:collection' show SplayTreeMap;
import 'dart:math' show min, max;
import 'package:flutter/painting.dart';

/// Enrutador ortogonal A* para cables en el canvas.
///
/// Calcula el camino más limpio entre dos puntos usando solo movimientos
/// horizontales y verticales (Manhattan), esquivando obstáculos rectangulares
/// (componentes, etc.).
///
/// Uso básico:
///   final path = OrthogonalRouter.findPath(
///     start: Offset(100, 200),
///     end:   Offset(450, 320),
///     obstacles: [Rect.fromCenter(center: comp.pos, width: 90, height: 90)],
///   );
///
/// Uso con waypoints (puntos fijos del usuario):
///   final path = OrthogonalRouter.throughWaypoints(
///     points: [inicio, wp1, wp2, fin],
///     obstacles: obstacles,
///   );
abstract final class OrthogonalRouter {
  /// Tamaño de celda en px de canvas. Coincide con la grid visual del canvas.
  static const int cellSize = 12;

  /// Margen en celdas alrededor de cada obstáculo.
  static const int _pad = 2;

  /// Límite de celdas para no bloquear el UI en áreas muy grandes.
  static const int _maxCells = 60000;

  /// Cuatro direcciones ortogonales.
  static const List<(int, int)> _dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

  // ── API pública ────────────────────────────────────────────────────────────

  /// Encuentra la ruta ortogonal más corta (y con menos giros) de [start] a [end]
  /// evitando [obstacles]. Devuelve una `List<Offset>` en coordenadas de canvas.
  ///
  /// Si A* no encuentra ruta (obstáculos totalmente bloqueantes o área demasiado
  /// grande), devuelve la ruta simple L/Z de [_fallback].
  static List<Offset> findPath({
    required Offset start,
    required Offset end,
    List<Rect> obstacles = const [],
    double searchPad = 96,
  }) {
    // Región de búsqueda acotada al bounding box inicio-fin + margen
    final x0 = (min(start.dx, end.dx) - searchPad).floorToDouble();
    final y0 = (min(start.dy, end.dy) - searchPad).floorToDouble();
    final x1 = (max(start.dx, end.dx) + searchPad).ceilToDouble();
    final y1 = (max(start.dy, end.dy) + searchPad).ceilToDouble();

    final cols = ((x1 - x0) / cellSize).ceil() + 1;
    final rows = ((y1 - y0) / cellSize).ceil() + 1;

    if (cols * rows > _maxCells) return _fallback(start, end);

    // ── Mapa de celdas bloqueadas ────────────────────────────────────────────
    final blocked = <int>{};
    final padPx = _pad * cellSize.toDouble();
    for (final rect in obstacles) {
      final r0 = _row(rect.top - padPx, y0).clamp(0, rows - 1);
      final r1 = _row(rect.bottom + padPx, y0).clamp(0, rows - 1);
      final c0 = _col(rect.left - padPx, x0).clamp(0, cols - 1);
      final c1 = _col(rect.right + padPx, x0).clamp(0, cols - 1);
      for (int r = r0; r <= r1; r++) {
        for (int c = c0; c <= c1; c++) {
          blocked.add(r * cols + c);
        }
      }
    }

    final sCol = _col(start.dx, x0).clamp(0, cols - 1);
    final sRow = _row(start.dy, y0).clamp(0, rows - 1);
    final eCol = _col(end.dx, x0).clamp(0, cols - 1);
    final eRow = _row(end.dy, y0).clamp(0, rows - 1);
    final startIdx = sRow * cols + sCol;
    final endIdx = eRow * cols + eCol;

    // Desbloquear celdas de inicio/fin (pueden solapar con un componente)
    blocked.remove(startIdx);
    blocked.remove(endIdx);

    if (startIdx == endIdx) return [start, end];

    // ── A* ────────────────────────────────────────────────────────────────────
    // Priority queue ligero: SplayTreeMap<fScore, List<nodeIdx>>
    final openQ = SplayTreeMap<double, List<int>>();
    final inOpen = <int>{};
    final gScore = <int, double>{startIdx: 0};
    final cameFrom = <int, int>{};

    void enqueue(int idx, double f) => (openQ[f] ??= []).add(idx);
    int dequeue() {
      final e = openQ.entries.first;
      final idx = e.value.removeLast();
      if (e.value.isEmpty) openQ.remove(e.key);
      return idx;
    }

    final h0 = _h(sRow, sCol, eRow, eCol);
    enqueue(startIdx, h0);
    inOpen.add(startIdx);

    while (openQ.isNotEmpty) {
      final cur = dequeue();
      inOpen.remove(cur);

      if (cur == endIdx) {
        return _reconstruct(cameFrom, cur, cols, x0, y0, start, end);
      }

      final cC = cur % cols;
      final cR = cur ~/ cols;
      final cG = gScore[cur] ?? double.infinity;

      for (final (dc, dr) in _dirs) {
        final nc = cC + dc;
        final nr = cR + dr;
        if (nc < 0 || nc >= cols || nr < 0 || nr >= rows) continue;
        final nIdx = nr * cols + nc;
        if (blocked.contains(nIdx)) continue;

        // Pequeña penalización por cambio de dirección → líneas más rectas
        double turn = 0;
        if (cameFrom.containsKey(cur)) {
          final pc = cameFrom[cur]! % cols;
          final pr = cameFrom[cur]! ~/ cols;
          if ((cC - pc) != dc || (cR - pr) != dr) turn = 2.0;
        }

        final tentG = cG + 1.0 + turn;
        if (tentG < (gScore[nIdx] ?? double.infinity)) {
          cameFrom[nIdx] = cur;
          gScore[nIdx] = tentG;
          final f = tentG + _h(nr, nc, eRow, eCol);
          if (!inOpen.contains(nIdx)) {
            inOpen.add(nIdx);
            enqueue(nIdx, f);
          }
        }
      }
    }

    return _fallback(start, end);
  }

  /// Concatena tramos individuales a través de [points] = [start, wp1, …, end].
  /// Cada tramo usa A* independiente, permitiendo que cada segmento esquive
  /// obstáculos por su cuenta.
  static List<Offset> throughWaypoints({
    required List<Offset> points,
    List<Rect> obstacles = const [],
  }) {
    if (points.length < 2) return points;
    final result = <Offset>[];
    for (int i = 0; i < points.length - 1; i++) {
      final seg = findPath(
        start: points[i],
        end: points[i + 1],
        obstacles: obstacles,
      );
      result.addAll(i == 0 ? seg : seg.skip(1));
    }
    return result;
  }

  // ── Utilidades internas ────────────────────────────────────────────────────

  static int _col(double x, double x0) => ((x - x0) / cellSize).round();
  static int _row(double y, double y0) => ((y - y0) / cellSize).round();

  static double _h(int r, int c, int er, int ec) =>
      ((r - er).abs() + (c - ec).abs()).toDouble();

  static List<Offset> _reconstruct(
    Map<int, int> cameFrom,
    int end,
    int cols,
    double x0,
    double y0,
    Offset startOff,
    Offset endOff,
  ) {
    final cells = <int>[];
    var node = end;
    while (cameFrom.containsKey(node)) {
      cells.add(node);
      node = cameFrom[node]!;
    }
    cells.add(node);

    final pts = cells.reversed
        .map((idx) => Offset(
              x0 + (idx % cols) * cellSize,
              y0 + (idx ~/ cols) * cellSize,
            ))
        .toList();

    if (pts.isNotEmpty) {
      pts[0] = startOff;
      pts[pts.length - 1] = endOff;
    }

    return _simplify(pts);
  }

  /// Elimina vértices colineales innecesarios para obtener una polilínea mínima.
  static List<Offset> _simplify(List<Offset> pts) {
    if (pts.length <= 2) return pts;
    final out = [pts[0]];
    for (int i = 1; i < pts.length - 1; i++) {
      final a = out.last;
      final b = pts[i];
      final c = pts[i + 1];
      final colX = (a.dx - b.dx).abs() < 0.5 && (b.dx - c.dx).abs() < 0.5;
      final colY = (a.dy - b.dy).abs() < 0.5 && (b.dy - c.dy).abs() < 0.5;
      if (!colX && !colY) out.add(b);
    }
    out.add(pts.last);
    return out;
  }

  /// Ruta L/Z ortogonal simple — se usa como fallback si A* falla.
  static List<Offset> _fallback(Offset a, Offset b) {
    final dx = (b.dx - a.dx).abs();
    final dy = (b.dy - a.dy).abs();
    if (dx < 0.5) return [a, b];
    if (dy < 2.0) {
      const vOff = 48.0;
      return [a, Offset(a.dx, a.dy + vOff), Offset(b.dx, a.dy + vOff), b];
    }
    if (dx >= dy) {
      final midY = (a.dy + b.dy) / 2;
      return [a, Offset(a.dx, midY), Offset(b.dx, midY), b];
    } else {
      final midX = (a.dx + b.dx) / 2;
      return [a, Offset(midX, a.dy), Offset(midX, b.dy), b];
    }
  }
}
