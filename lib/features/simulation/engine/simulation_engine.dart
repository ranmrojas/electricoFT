import '../../canvas/models/cable_en_canvas.dart';
import '../../canvas/models/componente_en_canvas.dart';
import '../models/estado_simulacion.dart';
import 'circuit_solver.dart';

/// Fachada pública del motor de simulación eléctrica.
///
/// Uso desde el canvas:
///   final estados = SimulationEngine.run(
///     componentes: _componentes,
///     cables: _cables,
///   );
///
/// Los estados resultantes se pasan a los widgets de componentes para
/// que muestren su feedback visual (energizado, falla, apagado).
abstract final class SimulationEngine {
  /// Ejecuta el solver y devuelve un mapa [componenteId → EstadoSimulacion].
  ///
  /// Si la lista de componentes está vacía, devuelve un mapa vacío de
  /// forma instantánea. El solver es puro (sin side-effects) y corre en Dart,
  /// sin bloquear el UI thread en circuitos típicos (< 500 componentes).
  static Map<String, EstadoSimulacion> run({
    required List<ComponenteEnCanvas> componentes,
    required List<CableEnCanvas> cables,
  }) {
    if (componentes.isEmpty) return const {};
    return CircuitSolver.solve(componentes: componentes, cables: cables);
  }

  /// Resumen textual del estado global del circuito para mostrarlo en un banner.
  static SimulacionResumen resumen(Map<String, EstadoSimulacion> estados) {
    if (estados.isEmpty) {
      return const SimulacionResumen(
        tipo: TipoResumen.sinFuente,
        mensaje: 'Sin componentes en el canvas',
      );
    }

    int energizados = 0;
    int conFalla = 0;
    TipoFalla peorFalla = TipoFalla.ninguna;

    for (final estado in estados.values) {
      if (estado.energizado) energizados++;
      if (estado.tieneFalla) {
        conFalla++;
        if (estado.falla.index > peorFalla.index) {
          peorFalla = estado.falla;
        }
      }
    }

    final hayFuente = estados.values.any((e) => e.energizado || e.voltajeReal > 0);
    if (!hayFuente) {
      return const SimulacionResumen(
        tipo: TipoResumen.sinFuente,
        mensaje: 'Sin fuente de alimentación conectada',
      );
    }

    if (peorFalla == TipoFalla.cortocircuito) {
      return const SimulacionResumen(
        tipo: TipoResumen.critico,
        mensaje: '⚡ CORTOCIRCUITO DETECTADO',
      );
    }
    if (peorFalla == TipoFalla.sobrecargaCritica ||
        peorFalla == TipoFalla.proteccionDisparada) {
      return SimulacionResumen(
        tipo: TipoResumen.critico,
        mensaje: peorFalla.descripcion,
      );
    }
    if (conFalla > 0) {
      return SimulacionResumen(
        tipo: TipoResumen.advertencia,
        mensaje: '$conFalla componente${conFalla > 1 ? "s" : ""} con advertencia',
      );
    }
    return SimulacionResumen(
      tipo: TipoResumen.ok,
      mensaje: '$energizados componente${energizados != 1 ? "s" : ""} energizado${energizados != 1 ? "s" : ""}',
    );
  }
}

enum TipoResumen { ok, advertencia, critico, sinFuente }

class SimulacionResumen {
  const SimulacionResumen({required this.tipo, required this.mensaje});
  final TipoResumen tipo;
  final String mensaje;
}
