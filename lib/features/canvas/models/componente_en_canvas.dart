import 'package:flutter/material.dart';
import '../../library/models/componente_electrico.dart';

class ComponenteEnCanvas {
  ComponenteEnCanvas({
    required this.id,
    required this.tipo,
    required this.posicion,
    this.rotacion = 0,
    this.activo = false,
    Set<String>? terminalesConectados,
  }) : terminalesConectados = terminalesConectados ?? {};

  final String id;
  final ComponenteElectrico tipo;
  Offset posicion;
  double rotacion;

  /// true = componente energizado/encendido (ej: bombilla encendida)
  bool activo;

  /// IDs de los terminales de este componente que tienen un cable conectado
  final Set<String> terminalesConectados;

  static const double tamano = 90.0;

  ComponenteEnCanvas copyWith({
    Offset? posicion,
    double? rotacion,
    bool? activo,
    Set<String>? terminalesConectados,
  }) {
    return ComponenteEnCanvas(
      id: id,
      tipo: tipo,
      posicion: posicion ?? this.posicion,
      rotacion: rotacion ?? this.rotacion,
      activo: activo ?? this.activo,
      terminalesConectados: terminalesConectados ?? Set.from(this.terminalesConectados),
    );
  }
}
