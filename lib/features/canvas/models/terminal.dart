import 'package:flutter/material.dart';

class Terminal {
  const Terminal({
    required this.id,
    required this.label,
    required this.color,
    required this.relativeOffset,
  });

  /// Identificador único dentro del componente (ej: 'L', 'N', 'PE', '+', '-')
  final String id;

  /// Etiqueta visible
  final String label;

  /// Color del terminal (rojo=fase, azul=neutro, verde=tierra, etc.)
  final Color color;

  /// Posición relativa dentro del componente: (0,0)=top-left, (1,1)=bottom-right
  final Offset relativeOffset;

  static const Color colorFase = Color(0xFFE74C3C);
  static const Color colorNeutro = Color(0xFF3498DB);
  static const Color colorTierra = Color(0xFF27AE60);
  static const Color colorPositivo = Color(0xFFE74C3C);
  static const Color colorNegativo = Color(0xFF555555);
  static const Color colorGenerico = Color(0xFF777777);
}

/// Define los terminales estándar de cada tipo de componente
class TerminalesDefinicion {
  static const Map<String, List<Terminal>> porTipo = {
    // Posiciones calculadas con la técnica de overlay SVG:
    // viewBox 240x280, scale=90/280=0.3214, offsetX=(90-77.14)/2=6.43
    // L → cx=80, cy=240 efectivo → pixel (32.14, 77.14) → relOffset (0.357, 0.857)
    // N → cx=160, cy=240 efectivo → pixel (57.86, 77.14) → relOffset (0.643, 0.857)
    'bombilla': [
      Terminal(id: 'L', label: 'L', color: Terminal.colorFase,   relativeOffset: Offset(0.357, 0.857)),
      Terminal(id: 'N', label: 'N', color: Terminal.colorNeutro, relativeOffset: Offset(0.643, 0.857)),
    ],
    'interruptor': [
      Terminal(id: 'L1', label: 'L1', color: Terminal.colorFase, relativeOffset: Offset(0.0, 0.5)),
      Terminal(id: 'L2', label: 'L2', color: Terminal.colorFase, relativeOffset: Offset(1.0, 0.5)),
    ],
    'toma': [
      Terminal(id: 'L',  label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.25, 0.0)),
      Terminal(id: 'N',  label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.50, 0.0)),
      Terminal(id: 'PE', label: 'PE', color: Terminal.colorTierra, relativeOffset: Offset(0.75, 0.0)),
    ],
    'breaker': [
      Terminal(id: '1', label: '1', color: Terminal.colorFase,   relativeOffset: Offset(0.5, 0.0)),
      Terminal(id: '2', label: '2', color: Terminal.colorTierra, relativeOffset: Offset(0.5, 1.0)),
    ],
    'fusible': [
      Terminal(id: 'L1', label: 'L1', color: Terminal.colorFase, relativeOffset: Offset(0.0, 0.5)),
      Terminal(id: 'L2', label: 'L2', color: Terminal.colorFase, relativeOffset: Offset(1.0, 0.5)),
    ],
    'resistencia': [
      Terminal(id: 'A', label: 'A', color: Terminal.colorGenerico, relativeOffset: Offset(0.0, 0.5)),
      Terminal(id: 'B', label: 'B', color: Terminal.colorGenerico, relativeOffset: Offset(1.0, 0.5)),
    ],
    'condensador': [
      Terminal(id: '-', label: '−', color: Terminal.colorNegativo, relativeOffset: Offset(0.0, 0.5)),
      Terminal(id: '+', label: '+', color: Terminal.colorPositivo, relativeOffset: Offset(1.0, 0.5)),
    ],
    'bateria': [
      Terminal(id: '+', label: '+', color: Terminal.colorPositivo, relativeOffset: Offset(0.0, 0.5)),
      Terminal(id: '-', label: '−', color: Terminal.colorNegativo, relativeOffset: Offset(1.0, 0.5)),
    ],
    'generador': [
      Terminal(id: 'L',  label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.0, 0.4)),
      Terminal(id: 'N',  label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.0, 0.6)),
      Terminal(id: 'PE', label: 'PE', color: Terminal.colorTierra, relativeOffset: Offset(1.0, 0.5)),
    ],
    'planta': [
      Terminal(id: 'L',  label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.0, 0.4)),
      Terminal(id: 'N',  label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.0, 0.6)),
      Terminal(id: 'PE', label: 'PE', color: Terminal.colorTierra, relativeOffset: Offset(1.0, 0.5)),
    ],
    'panel_solar': [
      Terminal(id: '+', label: '+', color: Terminal.colorPositivo, relativeOffset: Offset(0.0, 0.5)),
      Terminal(id: '-', label: '−', color: Terminal.colorNegativo, relativeOffset: Offset(1.0, 0.5)),
    ],
    'inversor': [
      Terminal(id: 'DC+', label: 'DC+', color: Terminal.colorPositivo, relativeOffset: Offset(0.0, 0.4)),
      Terminal(id: 'DC-', label: 'DC−', color: Terminal.colorNegativo, relativeOffset: Offset(0.0, 0.6)),
      Terminal(id: 'ACL', label: 'AC L', color: Terminal.colorFase,   relativeOffset: Offset(1.0, 0.4)),
      Terminal(id: 'ACN', label: 'AC N', color: Terminal.colorNeutro, relativeOffset: Offset(1.0, 0.6)),
    ],
    'transformador': [
      Terminal(id: 'L',  label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.0, 0.4)),
      Terminal(id: 'N',  label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.0, 0.6)),
      Terminal(id: '+',  label: '+',  color: Terminal.colorPositivo, relativeOffset: Offset(1.0, 0.4)),
      Terminal(id: '-',  label: '−',  color: Terminal.colorNegativo, relativeOffset: Offset(1.0, 0.6)),
    ],
    'medidor': [
      Terminal(id: 'L',  label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.3, 0.0)),
      Terminal(id: 'N',  label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.7, 0.0)),
      Terminal(id: "L'", label: "L'", color: Terminal.colorFase,   relativeOffset: Offset(0.3, 1.0)),
      Terminal(id: "N'", label: "N'", color: Terminal.colorNeutro, relativeOffset: Offset(0.7, 1.0)),
    ],
    'tablero': [
      Terminal(id: 'L_in',  label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.25, 0.0)),
      Terminal(id: 'N_in',  label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.50, 0.0)),
      Terminal(id: 'PE_in', label: 'PE', color: Terminal.colorTierra, relativeOffset: Offset(0.75, 0.0)),
      Terminal(id: 'L_out', label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.25, 1.0)),
      Terminal(id: 'N_out', label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.50, 1.0)),
      Terminal(id: 'PE_out',label: 'PE', color: Terminal.colorTierra, relativeOffset: Offset(0.75, 1.0)),
    ],
    'nodo': [
      Terminal(id: 'up',    label: '', color: Terminal.colorGenerico, relativeOffset: Offset(0.5, 0.0)),
      Terminal(id: 'down',  label: '', color: Terminal.colorGenerico, relativeOffset: Offset(0.5, 1.0)),
      Terminal(id: 'left',  label: '', color: Terminal.colorGenerico, relativeOffset: Offset(0.0, 0.5)),
      Terminal(id: 'right', label: '', color: Terminal.colorGenerico, relativeOffset: Offset(1.0, 0.5)),
    ],
    'caja_control': [
      Terminal(id: 'L_in',  label: 'L',  color: Terminal.colorFase,   relativeOffset: Offset(0.0, 0.35)),
      Terminal(id: 'N_in',  label: 'N',  color: Terminal.colorNeutro, relativeOffset: Offset(0.0, 0.50)),
      Terminal(id: 'PE_in', label: 'PE', color: Terminal.colorTierra, relativeOffset: Offset(0.0, 0.65)),
      Terminal(id: 'L_out', label: "L'", color: Terminal.colorFase,   relativeOffset: Offset(1.0, 0.35)),
      Terminal(id: 'N_out', label: "N'", color: Terminal.colorNeutro, relativeOffset: Offset(1.0, 0.50)),
      Terminal(id: 'PE_out',label: "PE'",color: Terminal.colorTierra, relativeOffset: Offset(1.0, 0.65)),
    ],
  };

  static List<Terminal> get(String componenteId) =>
      porTipo[componenteId] ?? [];
}
