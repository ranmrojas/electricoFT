import 'package:flutter/material.dart';
import '../../library/models/componente_electrico.dart';
import '../../simulation/models/propiedades_electricas.dart';

class ComponenteEnCanvas {
  ComponenteEnCanvas({
    required this.id,
    required this.tipo,
    required this.posicion,
    this.rotacion = 0,
    this.activo = false,
    Set<String>? terminalesConectados,
    PropiedadesElectricas? propiedades,
  })  : terminalesConectados = terminalesConectados ?? {},
        propiedades = propiedades ?? PropiedadesElectricas.defaultsPara(tipo.id);

  final String id;
  final ComponenteElectrico tipo;
  Offset posicion;
  double rotacion;

  /// true = componente energizado/encendido (ej: bombilla encendida).
  /// Usado por widgets visuales para mostrar estado activo.
  bool activo;

  /// IDs de los terminales de este componente que tienen un cable conectado.
  final Set<String> terminalesConectados;

  /// Parámetros eléctricos configurables de esta instancia.
  PropiedadesElectricas propiedades;

  static const double tamano = 90.0;

  ComponenteEnCanvas copyWith({
    Offset? posicion,
    double? rotacion,
    bool? activo,
    Set<String>? terminalesConectados,
    PropiedadesElectricas? propiedades,
  }) {
    return ComponenteEnCanvas(
      id: id,
      tipo: tipo,
      posicion: posicion ?? this.posicion,
      rotacion: rotacion ?? this.rotacion,
      activo: activo ?? this.activo,
      terminalesConectados: terminalesConectados ?? Set.from(this.terminalesConectados),
      propiedades: propiedades ?? this.propiedades.copyWith(),
    );
  }
}
