import 'package:flutter/material.dart';

/// Tipos de falla detectables por el motor de simulación.
enum TipoFalla {
  ninguna,

  /// Corriente que circula supera la capacidad del componente (>80 %) — advertencia.
  sobrecarga,

  /// Corriente que circula supera la capacidad del componente (>100 %) — crítico.
  sobrecargaCritica,

  /// Fase conectada directamente a neutro/negativo sin carga entre ellos.
  cortocircuito,

  /// Carga AC conectada a fuente DC o viceversa.
  tipoIncorrecto,

  /// No hay camino completo desde la fuente hasta la carga.
  circuitoAbierto,

  /// Breaker o fusible disparado por sobrecorriente.
  proteccionDisparada,
}

extension TipoFallaInfo on TipoFalla {
  bool get esCritica =>
      this == TipoFalla.cortocircuito ||
      this == TipoFalla.sobrecargaCritica ||
      this == TipoFalla.proteccionDisparada;

  bool get esAdvertencia =>
      this == TipoFalla.sobrecarga || this == TipoFalla.tipoIncorrecto;

  String get descripcion {
    switch (this) {
      case TipoFalla.ninguna:
        return 'Sin fallas';
      case TipoFalla.sobrecarga:
        return 'Sobrecarga — corriente al límite';
      case TipoFalla.sobrecargaCritica:
        return 'Sobrecarga crítica — corriente excedida';
      case TipoFalla.cortocircuito:
        return 'Cortocircuito detectado';
      case TipoFalla.tipoIncorrecto:
        return 'Incompatibilidad AC/DC';
      case TipoFalla.circuitoAbierto:
        return 'Circuito abierto — sin retorno';
      case TipoFalla.proteccionDisparada:
        return 'Protección disparada';
    }
  }

  Color get color {
    switch (this) {
      case TipoFalla.ninguna:
        return Colors.transparent;
      case TipoFalla.sobrecarga:
        return const Color(0xFFFF8F00); // ámbar
      case TipoFalla.sobrecargaCritica:
        return const Color(0xFFD32F2F); // rojo
      case TipoFalla.cortocircuito:
        return const Color(0xFFC62828); // rojo intenso
      case TipoFalla.tipoIncorrecto:
        return const Color(0xFFF57F17); // amarillo oscuro
      case TipoFalla.circuitoAbierto:
        return const Color(0xFF757575); // gris
      case TipoFalla.proteccionDisparada:
        return const Color(0xFFE65100); // naranja oscuro
    }
  }

  IconData get icono {
    switch (this) {
      case TipoFalla.ninguna:
        return Icons.check_circle_outline;
      case TipoFalla.sobrecarga:
        return Icons.warning_amber_rounded;
      case TipoFalla.sobrecargaCritica:
        return Icons.error_outline;
      case TipoFalla.cortocircuito:
        return Icons.bolt;
      case TipoFalla.tipoIncorrecto:
        return Icons.swap_horiz;
      case TipoFalla.circuitoAbierto:
        return Icons.link_off;
      case TipoFalla.proteccionDisparada:
        return Icons.shield_outlined;
    }
  }
}

/// Resultado de la simulación para un componente específico.
class EstadoSimulacion {
  const EstadoSimulacion({
    this.energizado = false,
    this.voltajeReal = 0.0,
    this.corrienteReal = 0.0,
    this.potenciaReal = 0.0,
    this.falla = TipoFalla.ninguna,
  });

  /// El componente tiene tensión correcta en sus terminales y está operativo.
  final bool energizado;

  /// Tensión real que llega a este componente (V).
  final double voltajeReal;

  /// Corriente que circula por este componente (A).
  final double corrienteReal;

  /// Potencia activa consumida o entregada (W).
  final double potenciaReal;

  /// Falla activa, si la hay.
  final TipoFalla falla;

  bool get tieneFalla => falla != TipoFalla.ninguna;

  static const EstadoSimulacion apagado = EstadoSimulacion();
}
