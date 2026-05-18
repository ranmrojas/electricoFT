import 'package:flutter/painting.dart';

/// Utilidades puras para la edición interactiva de polilíneas.
///
/// Sin dependencias de Flutter UI — reutilizable en cualquier componente
/// que represente un camino definido por vértices (cables, alambres, tuberías…).
///
/// Los tres métodos fundamentales de manipulación de nodos:
///   • [insertVertex]  — inserta un vértice en un segmento al hacer tap en él.
///   • [deleteVertex]  — elimina un vértice intermedio al doble-tap o long-press.
///   • [moveVertex]    — mueve un vértice a una nueva posición en tiempo real.
abstract final class PolylineEditor {
  // ── Hit-testing ─────────────────────────────────────────────────────────────

  /// Devuelve el índice del vértice más cercano a [pos] dentro de [radius].
  /// Incluye extremos (índices 0 y pts.length-1).
  /// Null si ninguno está suficientemente cerca.
  static int? nearestVertex(
    List<Offset> pts,
    Offset pos, {
    double radius = 16.0,
  }) {
    double minDist = radius;
    int? best;
    for (int i = 0; i < pts.length; i++) {
      final d = (pts[i] - pos).distance;
      if (d < minDist) {
        minDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Devuelve el índice del segmento más cercano a [pos] dentro de [radius].
  /// El segmento i une pts[i] con pts[i+1].
  /// Null si ninguno está suficientemente cerca.
  static int? nearestSegment(
    List<Offset> pts,
    Offset pos, {
    double radius = 10.0,
  }) {
    double minDist = radius;
    int? best;
    for (int i = 0; i < pts.length - 1; i++) {
      final d = distToSegment(pos, pts[i], pts[i + 1]);
      if (d < minDist) {
        minDist = d;
        best = i;
      }
    }
    return best;
  }

  // ── Mutaciones (devuelven nuevas listas, no modifican in-place) ──────────────

  /// Inserta [pos] en el segmento [segIdx] y devuelve la nueva lista.
  ///
  /// El nuevo vértice queda en la proyección ortogonal de [pos] sobre el
  /// segmento para que el resultado sea preciso aunque el tap no sea exacto.
  static List<Offset> insertVertex(
    List<Offset> pts,
    int segIdx,
    Offset pos,
  ) {
    assert(segIdx >= 0 && segIdx < pts.length - 1);
    final snapped = projectOnSegment(pos, pts[segIdx], pts[segIdx + 1]);
    return [
      ...pts.sublist(0, segIdx + 1),
      snapped,
      ...pts.sublist(segIdx + 1),
    ];
  }

  /// Elimina el vértice en [idx] (solo intermedios, nunca extremos).
  /// Devuelve [pts] sin cambios si [idx] es un extremo o la lista tiene ≤ 2 pts.
  static List<Offset> deleteVertex(List<Offset> pts, int idx) {
    if (idx <= 0 || idx >= pts.length - 1 || pts.length <= 2) {
      return List<Offset>.from(pts);
    }
    return [
      ...pts.sublist(0, idx),
      ...pts.sublist(idx + 1),
    ];
  }

  /// Mueve el vértice [idx] a [newPos] y devuelve la nueva lista.
  /// Funciona para cualquier vértice, incluidos extremos.
  static List<Offset> moveVertex(List<Offset> pts, int idx, Offset newPos) {
    final result = List<Offset>.from(pts);
    result[idx] = newPos;
    return result;
  }

  // ── Geometría ────────────────────────────────────────────────────────────────

  /// Proyección ortogonal (clamped) de [p] sobre el segmento [a]-[b].
  static Offset projectOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final distSq = ab.distanceSquared;
    if (distSq == 0) return a;
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / distSq;
    return a + ab * t.clamp(0.0, 1.0);
  }

  /// Distancia mínima de [p] al segmento [a]-[b].
  static double distToSegment(Offset p, Offset a, Offset b) =>
      (p - projectOnSegment(p, a, b)).distance;
}
