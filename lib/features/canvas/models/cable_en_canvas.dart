import 'package:flutter/material.dart';

/// Los 5 colores de cable disponibles en el simulador
enum ColorCable {
  negro( 'Negro  —  Fase / L',    Color(0xFF1A1A1A)),
  rojo(  'Rojo   —  Fase 2 / L2', Color(0xFFD32F2F)),
  azul(  'Azul   —  Neutro / N',  Color(0xFF1565C0)),
  verde( 'Verde  —  Tierra / PE', Color(0xFF2E7D32)),
  blanco('Blanco —  Neutro / N2', Color(0xFFF5F5F5));

  const ColorCable(this.label, this.color);
  final String label;
  final Color color;
}

/// Instancia de un cable colocado en el canvas.
///
/// El recorrido se almacena como [puntos]: una lista de [Offset] que forma
/// una polilínea **ortogonal** (sin diagonales). El mínimo es 2 puntos
/// (inicio + fin), con puntos intermedios que son las esquinas de la ruta.
class CableEnCanvas {
  CableEnCanvas({
    required this.id,
    required List<Offset> puntos,
    this.fromComponenteId,
    this.fromTerminalId,
    this.toComponenteId,
    this.toTerminalId,
    this.colorCable = ColorCable.negro,
    this.calibreAWG = 14,
  }) : puntos = List<Offset>.from(puntos);

  final String id;

  /// Polilínea ortogonal: [inicio, ...esquinas..., fin]
  List<Offset> puntos;

  // ── Acceso directo a extremos ─────────────────────────────────────────────
  Offset get inicio => puntos.first;
  Offset get fin    => puntos.last;

  set inicio(Offset v) {
    if (puntos.isNotEmpty) puntos[0] = v;
  }
  set fin(Offset v) {
    if (puntos.length >= 2) puntos[puntos.length - 1] = v;
  }

  String? fromComponenteId;
  String? fromTerminalId;
  String? toComponenteId;
  String? toTerminalId;

  ColorCable colorCable;
  int calibreAWG;

  /// Calibres AWG disponibles para selección
  static const List<int> calibresDisponibles = [14, 12, 10, 8, 6, 4, 2];

  /// Grosor visual proporcional al calibre AWG
  double get grosorVisual {
    const map = {14: 3.5, 12: 4.5, 10: 5.5, 8: 7.0, 6: 8.5, 4: 10.0, 2: 12.5};
    return map[calibreAWG] ?? 3.5;
  }

  // ── Ruteo ortogonal ───────────────────────────────────────────────────────

  /// Genera una ruta **ortogonal** (sin diagonales) entre [inicio] y [fin].
  ///
  /// Estrategia de routing:
  ///
  /// • Misma X exacta → línea vertical directa.
  ///
  /// • Mismo Y (±2 px) → forma en U: va [vOffset] px hacia abajo, luego
  ///   cruza horizontal y sube de vuelta. Evita pisar terminales vecinas cuando
  ///   los componentes están alineados en horizontal.
  ///
  /// • Dominantemente horizontal (|dx| ≥ |dy|) → forma en L-horizontal:
  ///   baja/sube al midY al salir, luego va a la X de destino y sube/baja.
  ///
  /// • Dominantemente vertical (|dy| > |dx|) → forma en Z:
  ///   va al midX, luego baja/sube, y sale hacia la X de destino.
  static const double _vOffset = 48.0;

  static List<Offset> rutaOrtogonal(Offset inicio, Offset fin) {
    final dx = (fin.dx - inicio.dx).abs();
    final dy = (fin.dy - inicio.dy).abs();

    // Misma posición o exactamente vertical
    if (dx < 0.5) return [inicio, fin];

    // Alineados horizontalmente (mismo Y ± tolerancia)
    if (dy < 2.0) {
      final midY = inicio.dy + _vOffset;
      return [
        inicio,
        Offset(inicio.dx, midY),
        Offset(fin.dx, midY),
        fin,
      ];
    }

    if (dx >= dy) {
      // Más separación horizontal → forma en L-horizontal
      // S ──┐              ┌── E
      //     └──────────────┘
      final midY = (inicio.dy + fin.dy) / 2;
      return [
        inicio,
        Offset(inicio.dx, midY),
        Offset(fin.dx, midY),
        fin,
      ];
    } else {
      // Más separación vertical → forma en Z
      // S ──────┐
      //         │
      //         └────── E
      final midX = (inicio.dx + fin.dx) / 2;
      return [
        inicio,
        Offset(midX, inicio.dy),
        Offset(midX, fin.dy),
        fin,
      ];
    }
  }

  /// Recalcula los puntos intermedios cuando se mueve un extremo,
  /// manteniendo la forma en Z de la ruta ortogonal.
  void recalcularRuta() {
    if (puntos.length < 2) return;
    final nueva = rutaOrtogonal(inicio, fin);
    // Conservar inicio y fin; reemplazar solo los intermedios
    puntos = nueva;
  }

  CableEnCanvas copyWith({
    List<Offset>? puntos,
    String? fromComponenteId,
    String? fromTerminalId,
    String? toComponenteId,
    String? toTerminalId,
    ColorCable? colorCable,
    int? calibreAWG,
  }) {
    return CableEnCanvas(
      id: id,
      puntos: puntos ?? List<Offset>.from(this.puntos),
      fromComponenteId: fromComponenteId ?? this.fromComponenteId,
      fromTerminalId: fromTerminalId ?? this.fromTerminalId,
      toComponenteId: toComponenteId ?? this.toComponenteId,
      toTerminalId: toTerminalId ?? this.toTerminalId,
      colorCable: colorCable ?? this.colorCable,
      calibreAWG: calibreAWG ?? this.calibreAWG,
    );
  }
}

/// Estado temporal mientras el usuario está dibujando un cable.
///
/// Dos modos de trazado:
///   • **Automático** (sin waypoints): terminal A → terminal B directo.
///     Preview con [rutaOrtogonal]; al cerrar se usa A* con obstáculos.
///   • **Manual** (≥1 waypoint): cada clic en el aire fija un vértice.
///     Solo líneas rectas entre puntos consecutivos, sin A* ni esquinas extra.
class CableEnProgreso {
  const CableEnProgreso({
    required this.fromComponenteId,
    required this.fromTerminalId,
    required this.inicio,
    required this.fin,
    this.waypoints = const [],
    this.colorCable = ColorCable.negro,
  });

  final String fromComponenteId;
  final String fromTerminalId;

  /// Primer punto fijo del cable (terminal de origen).
  final Offset inicio;

  /// Posición actual del cursor (se actualiza con cada movimiento del mouse).
  final Offset fin;

  /// Vértices fijos añadidos por el usuario al clicar en el aire.
  final List<Offset> waypoints;

  final ColorCable colorCable;

  /// `true` cuando el usuario ya fijó al menos un punto manual en el aire.
  bool get esManual => waypoints.isNotEmpty;

  /// Último punto fijo: el waypoint más reciente o el inicio.
  Offset get lastFixed => waypoints.isEmpty ? inicio : waypoints.last;

  /// Polilínea de preview.
  /// Manual: [inicio, …waypoints, cursor] — un segmento recto entre cada par.
  /// Automático: ruta ortogonal sugerida de inicio al cursor.
  List<Offset> get puntos =>
      esManual ? [inicio, ...waypoints, fin] : CableEnCanvas.rutaOrtogonal(inicio, fin);

  CableEnProgreso copyWith({
    Offset? fin,
    List<Offset>? waypoints,
  }) =>
      CableEnProgreso(
        fromComponenteId: fromComponenteId,
        fromTerminalId: fromTerminalId,
        inicio: inicio,
        fin: fin ?? this.fin,
        waypoints: waypoints ?? this.waypoints,
        colorCable: colorCable,
      );
}
