import '../../canvas/models/cable_en_canvas.dart';
import '../../canvas/models/componente_en_canvas.dart';
import '../../canvas/models/terminal.dart';
import '../models/estado_simulacion.dart';

// ── Roles eléctricos internos ─────────────────────────────────────────────────

enum _Rol {
  fuente,       // batería, generador, planta, panel_solar
  carga,        // bombilla, resistencia, toma, condensador
  interruptor,  // interruptor (abre/cierra sin límite de corriente)
  proteccion,   // breaker, fusible (abre/cierra + límite de corriente)
  conductor,    // nodo, medidor, tablero, caja_control (R≈0)
  conversor,    // inversor, transformador (aísla y convierte voltaje)
  desconocido,
}

_Rol _rolDe(String tipoId) {
  const fuentes = {'bateria', 'generador', 'planta', 'panel_solar'};
  const cargas = {'bombilla', 'resistencia', 'toma', 'condensador'};
  const interruptores = {'interruptor'};
  const protecciones = {'breaker', 'fusible'};
  const conductores = {'nodo', 'medidor', 'tablero', 'caja_control'};
  const conversores = {'inversor', 'transformador'};

  if (fuentes.contains(tipoId)) return _Rol.fuente;
  if (cargas.contains(tipoId)) return _Rol.carga;
  if (interruptores.contains(tipoId)) return _Rol.interruptor;
  if (protecciones.contains(tipoId)) return _Rol.proteccion;
  if (conductores.contains(tipoId)) return _Rol.conductor;
  if (conversores.contains(tipoId)) return _Rol.conversor;
  return _Rol.desconocido;
}

// ── Union-Find ────────────────────────────────────────────────────────────────

class _UF {
  final Map<String, String> _p = {};

  String find(String x) {
    if (!_p.containsKey(x)) _p[x] = x;
    if (_p[x] != x) _p[x] = find(_p[x]!);
    return _p[x]!;
  }

  void union(String a, String b) {
    final ra = find(a), rb = find(b);
    if (ra != rb) _p[ra] = rb;
  }

  bool same(String a, String b) => find(a) == find(b);
}

// ── Motor principal ──────────────────────────────────────────────────────────

/// Calcula el estado eléctrico de todos los componentes del canvas.
///
/// Algoritmo:
///   1. Union-Find agrupa terminales conectados por cables o conductores (nodo…).
///   2. Por cada fuente, BFS de alcanzabilidad desde su terminal + (sin atravesar cargas).
///   3. BFS de alcanzabilidad desde su terminal − (sin atravesar cargas).
///   4. Un componente está energizado si un terminal está en el conjunto + y otro en −.
///   5. Se calculan potencias/corrientes y se evalúan protecciones y faltas.
abstract final class CircuitSolver {
  static Map<String, EstadoSimulacion> solve({
    required List<ComponenteEnCanvas> componentes,
    required List<CableEnCanvas> cables,
  }) {
    if (componentes.isEmpty) return {};

    // ── Paso 1: Construir Union-Find con cables ───────────────────────────────
    final uf = _UF();
    for (final cable in cables) {
      if (cable.fromComponenteId == null || cable.fromTerminalId == null) continue;
      if (cable.toComponenteId == null || cable.toTerminalId == null) continue;
      final a = '${cable.fromComponenteId}:${cable.fromTerminalId}';
      final b = '${cable.toComponenteId}:${cable.toTerminalId}';
      uf.union(a, b);
    }

    // Conductores (nodo, medidor…) fusionan todos sus terminales en un mismo nodo
    final compMap = {for (final c in componentes) c.id: c};
    for (final comp in componentes) {
      if (_rolDe(comp.tipo.id) != _Rol.conductor) continue;
      final terms = TerminalesDefinicion.get(comp.tipo.id);
      if (terms.length < 2) continue;
      final base = '${comp.id}:${terms[0].id}';
      for (int i = 1; i < terms.length; i++) {
        uf.union(base, '${comp.id}:${terms[i].id}');
      }
    }

    // ── Paso 2: Mapa de adyacencia por nodo eléctrico ────────────────────────
    // Para cada nodo (repr. canónica): qué (compId, termId) lo componen
    final Map<String, List<(String, String)>> nodoTerminales = {};
    for (final comp in componentes) {
      for (final t in TerminalesDefinicion.get(comp.tipo.id)) {
        final key = '${comp.id}:${t.id}';
        final node = uf.find(key);
        (nodoTerminales[node] ??= []).add((comp.id, t.id));
      }
    }

    // ── Paso 3: Para cada fuente, calcular alcanzabilidad y energización ─────
    final Map<String, EstadoSimulacion> resultados = {};
    for (final comp in componentes) {
      resultados[comp.id] = EstadoSimulacion.apagado;
    }

    final fuentes = componentes.where((c) => _rolDe(c.tipo.id) == _Rol.fuente);

    for (final fuente in fuentes) {
      final props = fuente.propiedades;
      final tipoId = fuente.tipo.id;
      final terms = TerminalesDefinicion.get(tipoId);
      if (terms.length < 2) continue;

      // Identificar terminal positivo (+/L) y negativo (−/N) de la fuente
      final termPos = _terminalPositivo(tipoId, terms);
      final termNeg = _terminalNegativo(tipoId, terms);
      if (termPos == null || termNeg == null) continue;

      final keyPos = '${fuente.id}:${termPos.id}';
      final keyNeg = '${fuente.id}:${termNeg.id}';
      final nodoPos = uf.find(keyPos);
      final nodoNeg = uf.find(keyNeg);

      // Cortocircuito: + y − en el mismo nodo eléctrico
      if (nodoPos == nodoNeg) {
        resultados[fuente.id] = const EstadoSimulacion(
          falla: TipoFalla.cortocircuito,
          energizado: false,
        );
        // Marcar también los conductores directamente conectados
        for (final t in nodoTerminales[nodoPos] ?? []) {
          final cId = t.$1;
          if (cId == fuente.id) continue;
          final c = compMap[cId];
          if (c == null) continue;
          if (_rolDe(c.tipo.id) == _Rol.conductor) {
            resultados[cId] = const EstadoSimulacion(
              falla: TipoFalla.cortocircuito,
            );
          }
        }
        continue;
      }

      // BFS de alcanzabilidad desde nodoPos (sin atravesar cargas)
      final alcanzablesPos = _bfsAlcanzabilidad(
        startNode: nodoPos,
        nodoTerminales: nodoTerminales,
        compMap: compMap,
        uf: uf,
        excluirNodo: nodoNeg,
      );

      // BFS de alcanzabilidad desde nodoNeg (sin atravesar cargas)
      final alcanzablesNeg = _bfsAlcanzabilidad(
        startNode: nodoNeg,
        nodoTerminales: nodoTerminales,
        compMap: compMap,
        uf: uf,
        excluirNodo: nodoPos,
      );

      // ── Paso 4: Calcular potencia total de cargas energizadas ───────────────
      double potenciaTotal = 0;
      final cargasEnergizadas = <String>[];

      for (final comp in componentes) {
        if (comp.id == fuente.id) continue;
        final rol = _rolDe(comp.tipo.id);
        if (rol != _Rol.carga) continue;

        final terms2 = TerminalesDefinicion.get(comp.tipo.id);
        if (terms2.length < 2) continue;

        final nodeA = uf.find('${comp.id}:${terms2[0].id}');
        final nodeB = uf.find('${comp.id}:${terms2[1].id}');

        final aEnPos = alcanzablesPos.contains(nodeA);
        final bEnPos = alcanzablesPos.contains(nodeB);
        final aEnNeg = alcanzablesNeg.contains(nodeA);
        final bEnNeg = alcanzablesNeg.contains(nodeB);

        final energizado = (aEnPos && bEnNeg) || (bEnPos && aEnNeg);
        if (!energizado) continue;

        // Verificar compatibilidad AC/DC
        if (comp.propiedades.tipoCorriente != props.tipoCorriente) {
          resultados[comp.id] = EstadoSimulacion(
            falla: TipoFalla.tipoIncorrecto,
            voltajeReal: props.voltajeNominal,
          );
          continue;
        }

        final p = comp.propiedades.potencia ?? 0;
        potenciaTotal += p;
        cargasEnergizadas.add(comp.id);
      }

      // ── Paso 5: Evaluar protecciones y fuente ──────────────────────────────
      final corrienteTotal =
          props.voltajeNominal > 0 ? potenciaTotal / props.voltajeNominal : 0;
      final iMax = props.corrienteMax;

      TipoFalla fallaFuente = TipoFalla.ninguna;
      if (iMax != null && corrienteTotal > iMax) {
        fallaFuente = TipoFalla.sobrecargaCritica;
      } else if (iMax != null && corrienteTotal > iMax * 0.8) {
        fallaFuente = TipoFalla.sobrecarga;
      }

      resultados[fuente.id] = EstadoSimulacion(
        energizado: true,
        voltajeReal: props.voltajeNominal,
        corrienteReal: corrienteTotal.toDouble(),
        potenciaReal: potenciaTotal,
        falla: fallaFuente,
      );

      // Evaluar protecciones en serie
      for (final comp in componentes) {
        if (comp.id == fuente.id) continue;
        final rol = _rolDe(comp.tipo.id);
        if (rol != _Rol.proteccion && rol != _Rol.interruptor) continue;

        final terms2 = TerminalesDefinicion.get(comp.tipo.id);
        if (terms2.length < 2) continue;
        final nodeA = uf.find('${comp.id}:${terms2[0].id}');
        final nodeB = uf.find('${comp.id}:${terms2[1].id}');

        final conectadoEnCircuito =
            (alcanzablesPos.contains(nodeA) || alcanzablesPos.contains(nodeB)) &&
            (alcanzablesNeg.contains(nodeA) || alcanzablesNeg.contains(nodeB));
        if (!conectadoEnCircuito) continue;

        if (!comp.propiedades.cerrado) {
          resultados[comp.id] = const EstadoSimulacion(
            energizado: false,
            falla: TipoFalla.circuitoAbierto,
          );
          continue;
        }

        // Corriente aguas abajo de la protección (simplificado: corriente total)
        final iNom = comp.propiedades.corrienteMax;
        TipoFalla fallaProteccion = TipoFalla.ninguna;
        if (iNom != null && corrienteTotal > iNom) {
          fallaProteccion = TipoFalla.proteccionDisparada;
        } else if (iNom != null && corrienteTotal > iNom * 0.8) {
          fallaProteccion = TipoFalla.sobrecarga;
        }

        resultados[comp.id] = EstadoSimulacion(
          energizado: true,
          voltajeReal: props.voltajeNominal,
          corrienteReal: corrienteTotal.toDouble(),
          falla: fallaProteccion,
        );
      }

      // ── Paso 6: Asignar estado a cada carga energizada ─────────────────────
      for (final compId in cargasEnergizadas) {
        final comp = compMap[compId]!;
        final p = comp.propiedades.potencia ?? 0;
        final i = props.voltajeNominal > 0 ? p / props.voltajeNominal : 0;
        resultados[compId] = EstadoSimulacion(
          energizado: true,
          voltajeReal: props.voltajeNominal,
          corrienteReal: i.toDouble(),
          potenciaReal: p,
        );
      }

      // Conductores alcanzados
      for (final node in alcanzablesPos.intersection(alcanzablesNeg)) {
        for (final t in nodoTerminales[node] ?? []) {
          final comp = compMap[t.$1];
          if (comp == null) continue;
          if (_rolDe(comp.tipo.id) == _Rol.conductor) {
            resultados[comp.id] = EstadoSimulacion(
              energizado: true,
              voltajeReal: props.voltajeNominal,
              corrienteReal: corrienteTotal.toDouble(),
            );
          }
        }
      }
    }

    return resultados;
  }

  // ── BFS sin atravesar cargas ───────────────────────────────────────────────

  /// Retorna el conjunto de nodos eléctricos alcanzables desde [startNode],
  /// siguiendo únicamente conductores y switches cerrados (no cargas).
  static Set<String> _bfsAlcanzabilidad({
    required String startNode,
    required Map<String, List<(String, String)>> nodoTerminales,
    required Map<String, ComponenteEnCanvas> compMap,
    required _UF uf,
    required String excluirNodo,
  }) {
    final visited = <String>{startNode};
    final queue = [startNode];

    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      final terminales = nodoTerminales[node] ?? [];

      for (final (compId, termId) in terminales) {
        final comp = compMap[compId];
        if (comp == null) continue;
        final rol = _rolDe(comp.tipo.id);

        // No atravesamos cargas — son los componentes que evaluamos
        if (rol == _Rol.carga) continue;

        // Switches e interruptores: solo si están cerrados
        if (rol == _Rol.interruptor || rol == _Rol.proteccion) {
          if (!comp.propiedades.cerrado) continue;
        }

        // Conversores aíslan sus lados — no se atraviesan en el BFS de este lado
        if (rol == _Rol.conversor) continue;

        // Fuentes: no se atraviesan (son el inicio, no un conductor)
        if (rol == _Rol.fuente) continue;

        // Pasar al otro terminal del componente
        final otrosTerms = TerminalesDefinicion.get(comp.tipo.id)
            .where((t) => t.id != termId);

        for (final otroTerm in otrosTerms) {
          final otroKey = '$compId:${otroTerm.id}';
          final otroNode = uf.find(otroKey);
          if (otroNode == excluirNodo) continue;
          if (visited.contains(otroNode)) continue;
          visited.add(otroNode);
          queue.add(otroNode);
        }
      }
    }

    return visited;
  }

  // ── Helpers de terminales de fuente ───────────────────────────────────────

  static Terminal? _terminalPositivo(String tipoId, List<Terminal> terms) {
    const posIds = {'+', 'DC+', 'L', 'L1'};
    return terms.firstWhere(
      (t) => posIds.contains(t.id),
      orElse: () => terms.first,
    );
  }

  static Terminal? _terminalNegativo(String tipoId, List<Terminal> terms) {
    const negIds = {'-', 'DC-', 'N', 'N1', 'L2'};
    return terms.firstWhere(
      (t) => negIds.contains(t.id),
      orElse: () => terms.last,
    );
  }
}
