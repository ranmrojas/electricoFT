import 'dart:math';
import 'package:flutter/material.dart';
import '../library/models/componente_electrico.dart';
import '../library/widgets/componente_card.dart';
import 'models/cable_en_canvas.dart';
import 'models/componente_en_canvas.dart';
import 'models/terminal.dart';
import 'utils/polyline_editor.dart';
import 'widgets/cable_vertex_layer.dart';
import 'widgets/cables_painter.dart';
import 'widgets/canvas_componente_widget.dart';
import 'widgets/canvas_grid_painter.dart';

class CanvasPage extends StatefulWidget {
  const CanvasPage({super.key, this.nombreProyecto = 'Nuevo proyecto'});

  final String nombreProyecto;

  @override
  State<CanvasPage> createState() => _CanvasPageState();
}

class _CanvasPageState extends State<CanvasPage> {
  final TransformationController _transformCtrl = TransformationController();

  /// Key del GestureDetector que envuelve el InteractiveViewer (body del Scaffold).
  /// Su RenderBox empieza justo debajo del AppBar, que es el espacio de coordenadas
  /// que el TransformationController usa internamente.  Sin esta key, _globalToCanvas
  /// usa el Scaffold completo y queda desplazado por la altura del AppBar.
  final GlobalKey _bodyKey = GlobalKey();

  // ── Componentes ──────────────────────────────────────────────────────────
  final List<ComponenteEnCanvas> _componentes = [];
  String? _idSeleccionado;

  // ── Cables ───────────────────────────────────────────────────────────────
  final List<CableEnCanvas> _cables = [];
  String? _cableSeleccionado;
  CableEnProgreso? _enProgreso;

  /// Incrementa cada vez que se mutan cables in-place para forzar shouldRepaint.
  int _cableVersion = 0;

  // ── Historial (Deshacer/Rehacer) ─────────────────────────────────────────
  final List<(List<ComponenteEnCanvas>, List<CableEnCanvas>)> _history = [];
  final List<(List<ComponenteEnCanvas>, List<CableEnCanvas>)> _redoStack = [];
  bool _modoBorrador = false;

  // Color activo para nuevos cables (mutable, se elige desde el panel)
  ColorCable _colorActivoCable = ColorCable.negro;

  static const double _canvasW = 4000;
  static const double _canvasH = 3000;
  static const double _snapRadius = 30.0;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _saveState() {
    _history.add((
      _componentes.map((c) => c.copyWith()).toList(),
      _cables.map((c) => c.copyWith()).toList(),
    ));
    _redoStack.clear();
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _redoStack.add((
        _componentes.map((c) => c.copyWith()).toList(),
        _cables.map((c) => c.copyWith()).toList(),
      ));
      final prev = _history.removeLast();
      _componentes.clear();
      _componentes.addAll(prev.$1.map((c) => c.copyWith()));
      _cables.clear();
      _cables.addAll(prev.$2.map((c) => c.copyWith()));
      _idSeleccionado = null;
      _cableSeleccionado = null;
      _enProgreso = null;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _history.add((
        _componentes.map((c) => c.copyWith()).toList(),
        _cables.map((c) => c.copyWith()).toList(),
      ));
      final next = _redoStack.removeLast();
      _componentes.clear();
      _componentes.addAll(next.$1.map((c) => c.copyWith()));
      _cables.clear();
      _cables.addAll(next.$2.map((c) => c.copyWith()));
      _idSeleccionado = null;
      _cableSeleccionado = null;
      _enProgreso = null;
    });
  }

  // ── Utilidades de coordenadas ─────────────────────────────────────────────

  double get _escala => _transformCtrl.value.getMaxScaleOnAxis();

  /// El body (fuera del InteractiveViewer) captura el pan solo durante el
  /// dibujo del cable en progreso. El arrastre de segmentos se maneja
  /// dentro del InteractiveViewer para no bloquear el paneo en zona vacía.
  bool get _captureCanvasPan => _enProgreso != null;

  Offset _globalToCanvas(Offset global) {
    // Usar el RenderBox del body (debajo del AppBar) para que la conversión
    // de coordenadas globales a viewport sea correcta.
    final box = (_bodyKey.currentContext?.findRenderObject() ??
        context.findRenderObject()) as RenderBox?;
    if (box == null) return global;
    final local = box.globalToLocal(global);
    return MatrixUtils.transformPoint(
      Matrix4.inverted(_transformCtrl.value),
      local,
    );
  }

  Offset _terminalCanvasPos(ComponenteEnCanvas comp, Terminal terminal) {
    const t = ComponenteEnCanvas.tamano;

    // Posición del terminal relativa al centro del componente (sin rotar)
    // El centro local del componente es (0.5, 0.5)
    final dx = (terminal.relativeOffset.dx - 0.5) * t;
    final dy = (terminal.relativeOffset.dy - 0.5) * t;

    // Aplicar la matriz de rotación 2D sobre ese offset relativo
    final cosA = cos(comp.rotacion);
    final sinA = sin(comp.rotacion);

    final rotDx = dx * cosA - dy * sinA;
    final rotDy = dx * sinA + dy * cosA;

    // Sumar el centro absoluto del componente en el canvas
    return Offset(
      comp.posicion.dx + rotDx,
      comp.posicion.dy + rotDy,
    );
  }

  // ── Componentes ───────────────────────────────────────────────────────────

  void _agregarComponente(ComponenteElectrico tipo) {
    _saveState();
    final matrix = _transformCtrl.value;
    final inv = Matrix4.inverted(matrix);
    // Usar el body (viewport del InteractiveViewer) para centrar correctamente
    final bodyBox = (_bodyKey.currentContext?.findRenderObject() ??
        context.findRenderObject()) as RenderBox?;
    final size = bodyBox?.size ?? const Size(400, 700);
    final centro = MatrixUtils.transformPoint(
      inv,
      Offset(size.width / 2, size.height / 2),
    );
    setState(() {
      _componentes.add(
        ComponenteEnCanvas(id: _uid(), tipo: tipo, posicion: centro),
      );
      _idSeleccionado = _componentes.last.id;
    });
    Navigator.pop(context);
  }

  void _moverComponente(String id, DragUpdateDetails d) {
    if (_enProgreso != null) return; // no mover durante dibujo de cable
    setState(() {
      final i = _componentes.indexWhere((c) => c.id == id);
      if (i != -1) {
        _componentes[i].posicion += d.delta / _escala;
        _idSeleccionado = id;
        // Actualizar posiciones de cables conectados a este componente
        _actualizarCablesDeComponente(id);
      }
    });
  }

  void _actualizarCablesDeComponente(String compId) {
    bool anyUpdated = false;
    for (final cable in _cables) {
      bool updated = false;
      if (cable.fromComponenteId == compId && cable.fromTerminalId != null) {
        final comp = _componentes.firstWhere((c) => c.id == compId);
        final term = TerminalesDefinicion.get(comp.tipo.id)
            .firstWhere((t) => t.id == cable.fromTerminalId);
        cable.inicio = _terminalCanvasPos(comp, term);
        updated = true;
      }
      if (cable.toComponenteId == compId && cable.toTerminalId != null) {
        final comp = _componentes.firstWhere((c) => c.id == compId);
        final term = TerminalesDefinicion.get(comp.tipo.id)
            .firstWhere((t) => t.id == cable.toTerminalId);
        cable.fin = _terminalCanvasPos(comp, term);
        updated = true;
      }
      if (updated) {
        cable.recalcularRuta();
        anyUpdated = true;
      }
    }
    if (anyUpdated) _cableVersion++;
  }

  void _rotarComponente(String id) {
    setState(() {
      final i = _componentes.indexWhere((c) => c.id == id);
      if (i != -1) {
        _componentes[i].rotacion += pi / 2;
        _actualizarCablesDeComponente(id);
      }
    });
  }

  void _eliminarComponente(String id) {
    setState(() {
      _componentes.removeWhere((c) => c.id == id);
      _cables.removeWhere(
        (c) => c.fromComponenteId == id || c.toComponenteId == id,
      );
      _idSeleccionado = null;
    });
  }

  void _toggleActivo(String id) {
    setState(() {
      final i = _componentes.indexWhere((c) => c.id == id);
      if (i != -1) _componentes[i].activo = !_componentes[i].activo;
    });
  }

  // ── Cables: inicio ────────────────────────────────────────────────────────

  void _onTerminalTap(String componenteId, String terminalId, Offset globalPos) {
    // Convertir la posición real en pantalla del widget-terminal a coordenadas del canvas.
    // Usamos la posición del widget (GlobalKey) en lugar del cálculo matemático para evitar
    // cualquier desfase entre la posición calculada y la posición visual real del círculo SVG.
    final canvasPos = _globalToCanvas(globalPos);

    if (_enProgreso == null) {
      // Iniciar dibujo
      setState(() {
        _idSeleccionado = null;
        _cableSeleccionado = null;
        _enProgreso = CableEnProgreso(
          fromComponenteId: componenteId,
          fromTerminalId: terminalId,
          inicio: canvasPos,
          fin: canvasPos,
          colorCable: _colorActivoCable,
        );
      });
    } else {
      // Completar con terminal destino
      if (componenteId == _enProgreso!.fromComponenteId &&
          terminalId == _enProgreso!.fromTerminalId) {
        _cancelarCable(); // mismo terminal → cancelar
        return;
      }
      _completarCable(componenteId, terminalId, canvasPos);
    }
  }

  void _completarCable(String toCompId, String toTermId, Offset finCanvasPos) {
    if (_enProgreso == null) return;

    final puntos = CableEnCanvas.rutaOrtogonal(_enProgreso!.inicio, finCanvasPos);

    _saveState();
    setState(() {
      _cableVersion++;
      _cables.add(CableEnCanvas(
        id: _uid(),
        puntos: puntos,
        fromComponenteId: _enProgreso!.fromComponenteId,
        fromTerminalId: _enProgreso!.fromTerminalId,
        toComponenteId: toCompId,
        toTerminalId: toTermId,
        colorCable: _enProgreso!.colorCable,
      ));
      _enProgreso = null;
    });
  }

  void _cancelarCable() {
    if (_enProgreso != null) setState(() => _enProgreso = null);
  }

  // ── Cables: movimiento del preview y arrastre de segmentos ───────────────

  void _onBodyPanStart(DragStartDetails d) {
    // Solo se usa durante el dibujo del cable en progreso (preview)
  }

  void _onBodyPanUpdate(DragUpdateDetails d) {
    if (_enProgreso == null) return;
    // Modo dibujo: mover la punta del cable en progreso
    setState(() {
      _enProgreso = _enProgreso!.copyWith(
        fin: _enProgreso!.fin + d.delta / _escala,
      );
    });
  }

  void _onBodyPanEnd(DragEndDetails d) {}

  void _onCanvasTapUp(TapUpDetails d) {
    // Solo se activa durante el dibujo de cable (el cable layer maneja el resto).
    if (_enProgreso == null) return;
    final canvasPos = _globalToCanvas(d.globalPosition);
    final snap = _terminalMasCercano(canvasPos,
        excluirCompId: _enProgreso!.fromComponenteId,
        excluirTermId: _enProgreso!.fromTerminalId);
    if (snap != null) {
      _completarCable(snap.$1, snap.$2, snap.$3);
    } else {
      _cancelarCable();
    }
  }

  // ── Cables: hit-test y snap ────────────────────────────────────────────────

  /// Devuelve el id del cable cuyo recorrido (multi-segmento) toca la posición [pos].
  String? _cableTocado(Offset pos) {
    for (final cable in _cables.reversed) {
      if (PolylineEditor.nearestSegment(cable.puntos, pos, radius: 10) != null) {
        return cable.id;
      }
    }
    return null;
  }

  /// Devuelve (componenteId, terminalId, canvasPos) del terminal más cercano
  (String, String, Offset)? _terminalMasCercano(Offset pos,
      {String? excluirCompId, String? excluirTermId}) {
    double minDist = _snapRadius;
    (String, String, Offset)? result;

    for (final comp in _componentes) {
      for (final term in TerminalesDefinicion.get(comp.tipo.id)) {
        if (comp.id == excluirCompId && term.id == excluirTermId) continue;
        final tPos = _terminalCanvasPos(comp, term);
        final dist = (tPos - pos).distance;
        if (dist < minDist) {
          minDist = dist;
          result = (comp.id, term.id, tPos);
        }
      }
    }
    return result;
  }

  // ── Cables: edición ───────────────────────────────────────────────────────

  void _eliminarCable(String id) {
    _saveState();
    setState(() {
      _cableVersion++;
      _cables.removeWhere((c) => c.id == id);
      _cableSeleccionado = null;
    });
  }

  void _duplicarCable(String cableId) {
    final idx = _cables.indexWhere((c) => c.id == cableId);
    if (idx == -1) return;
    final original = _cables[idx];
    _saveState();
    setState(() {
      _cableVersion++;
      _cables.add(CableEnCanvas(
        id: _uid(),
        puntos: original.puntos.map((p) => p + const Offset(20, 20)).toList(),
        colorCable: original.colorCable,
        calibreAWG: original.calibreAWG,
      ));
      _cableSeleccionado = _cables.last.id;
      _idSeleccionado = null;
    });
  }

  // ── Edición de polilínea (callbacks desde CableVertexLayer) ───────────────

  /// Mueve el vértice [idx] del cable [cableId] aplicando [delta] canvas.
  void _onVerticeMovido(String cableId, int idx, Offset delta) {
    final cIdx = _cables.indexWhere((c) => c.id == cableId);
    if (cIdx == -1) return;
    setState(() {
      _cableVersion++;
      _cables[cIdx].puntos = PolylineEditor.moveVertex(
        _cables[cIdx].puntos,
        idx,
        _cables[cIdx].puntos[idx] + delta,
      );
    });
  }

  /// Elimina el vértice intermedio [idx] del cable [cableId].
  void _onVerticeEliminado(String cableId, int idx) {
    final cIdx = _cables.indexWhere((c) => c.id == cableId);
    if (cIdx == -1) return;
    _saveState();
    setState(() {
      _cableVersion++;
      _cables[cIdx].puntos = PolylineEditor.deleteVertex(_cables[cIdx].puntos, idx);
    });
  }

  /// Inserta un vértice en el segmento [segIdx] del cable [cableId] en la posición [pos].
  void _onVerticeInsertado(String cableId, int segIdx, Offset pos) {
    final cIdx = _cables.indexWhere((c) => c.id == cableId);
    if (cIdx == -1) return;
    _saveState();
    setState(() {
      _cableVersion++;
      _cables[cIdx].puntos = PolylineEditor.insertVertex(
        _cables[cIdx].puntos,
        segIdx,
        pos,
      );
    });
  }

  void _abrirPickerCable(String cableId) {
    final idx = _cables.indexWhere((c) => c.id == cableId);
    if (idx == -1) return;
    final cable = _cables[idx];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CablePickerSheet(
        cable: cable,
        onColorChanged: (c) {
          _saveState();
          setState(() => _cables[idx].colorCable = c);
          Navigator.pop(context);
        },
        onCalibreChanged: (awg) {
          _saveState();
          setState(() => _cables[idx].calibreAWG = awg);
          Navigator.pop(context);
        },
        onEliminar: () {
          Navigator.pop(context);
          _eliminarCable(cableId);
        },
        onDuplicar: () {
          Navigator.pop(context);
          _duplicarCable(cableId);
        },
      ),
    );
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  void _deseleccionar() {
    if (_idSeleccionado != null || _cableSeleccionado != null) {
      setState(() {
        _idSeleccionado = null;
        _cableSeleccionado = null;
      });
    }
    if (_enProgreso != null) _cancelarCable();
  }

  void _abrirPanelComponentes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PanelComponentes(
        onSeleccionar: _agregarComponente,
        onIniciarCable: (color) {
          setState(() => _colorActivoCable = color);
          // El usuario ahora debe tocar un terminal para empezar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Cable ${color.label.split('—').first.trim()} listo · toca un terminal',
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  String _uid() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      Random().nextInt(9999).toRadixString(36);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dibujando = _enProgreso != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombreProyecto,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${_componentes.length} componente${_componentes.length == 1 ? '' : 's'}'
              '  ·  ${_cables.length} cable${_cables.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          // Indicador de modo cable activo
          if (dibujando)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancelar cable'),
                style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error),
                onPressed: _cancelarCable,
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Deshacer',
              onPressed: _history.isEmpty ? null : _undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Rehacer',
              onPressed: _redoStack.isEmpty ? null : _redo,
            ),
            IconButton(
              icon: Icon(
                _modoBorrador ? Icons.backspace : Icons.backspace_outlined,
              ),
              color: _modoBorrador ? colorScheme.error : null,
              tooltip: 'Borrador',
              onPressed: () {
                setState(() {
                  _modoBorrador = !_modoBorrador;
                  if (_modoBorrador) _deseleccionar();
                });
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.center_focus_strong_outlined),
              tooltip: 'Centrar vista',
              onPressed: () => _transformCtrl.value = Matrix4.identity(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpiar canvas',
              onPressed: (_componentes.isEmpty && _cables.isEmpty)
                  ? null
                  : () => _confirmarLimpiar(),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),

      // ── Canvas ──────────────────────────────────────────────────────────
      body: Stack(
        children: [
          GestureDetector(
        key: _bodyKey,
        onTap: _deseleccionar,
        onPanStart: _onBodyPanStart,
        onPanUpdate: _captureCanvasPan ? _onBodyPanUpdate : null,
        onPanEnd: _captureCanvasPan ? _onBodyPanEnd : null,
        onTapUp: _onCanvasTapUp,
        child: InteractiveViewer(
          transformationController: _transformCtrl,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.3,
          maxScale: 4.0,
          constrained: false,
          // Desactiva el pan nativo del visor mientras se dibuja un cable o se arrastra un segmento
          panEnabled: !_captureCanvasPan,
          scaleEnabled: !_captureCanvasPan,
          child: SizedBox(
            width: _canvasW,
            height: _canvasH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Fondo cuadrícula
                Positioned.fill(
                  child: CustomPaint(painter: const CanvasGridPainter()),
                ),

                // ── Capa de cables ────────────────────────────────────────
                // Coordenadas ya en espacio de canvas (dentro del viewer).
                // onTapUp:
                //   • Tap en segmento de cable seleccionado → inserta vértice
                //   • Tap en otro cable → selecciona ese cable
                //   • Tap en vacío → deselecciona
                // onDoubleTapDown: abre propiedades del cable
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapUp: (d) {
                      if (_enProgreso != null || _modoBorrador) return;
                      final pos = d.localPosition;

                      if (_cableSeleccionado != null) {
                        final cIdx = _cables.indexWhere(
                            (c) => c.id == _cableSeleccionado);
                        if (cIdx != -1) {
                          final cable = _cables[cIdx];
                          // Tap sobre segmento (no sobre vértice) → insertar
                          final vNear = PolylineEditor.nearestVertex(
                              cable.puntos, pos,
                              radius: 14);
                          if (vNear == null) {
                            final sIdx = PolylineEditor.nearestSegment(
                                cable.puntos, pos,
                                radius: 12);
                            if (sIdx != null) {
                              _onVerticeInsertado(cable.id, sIdx, pos);
                              return;
                            }
                          }
                        }
                      }

                      final cableId = _cableTocado(pos);
                      setState(() {
                        _cableSeleccionado = cableId;
                        if (cableId != null) _idSeleccionado = null;
                      });
                    },
                    onDoubleTapDown: (d) {
                      if (_enProgreso != null || _modoBorrador) return;
                      final cableId = _cableTocado(d.localPosition);
                      if (cableId == null) return;
                      setState(() {
                        _cableSeleccionado = cableId;
                        _idSeleccionado = null;
                      });
                      _abrirPickerCable(cableId);
                    },
                    child: CustomPaint(
                      painter: CablesPainter(
                        cables: _cables,
                        version: _cableVersion,
                        enProgreso: _enProgreso,
                        cableSeleccionadoId: _cableSeleccionado,
                      ),
                    ),
                  ),
                ),

                // ── Handles de vértices del cable seleccionado ────────────
                // Se coloca DENTRO del viewer → coordenadas de canvas directas.
                if (_cableSeleccionado != null && !dibujando && !_modoBorrador)
                  Builder(builder: (_) {
                    final cIdx = _cables.indexWhere(
                        (c) => c.id == _cableSeleccionado);
                    if (cIdx == -1) return const SizedBox.shrink();
                    return CableVertexLayer(
                      key: ValueKey('vl_$_cableSeleccionado'),
                      puntos: _cables[cIdx].puntos,
                      escala: _escala,
                      onMoverVertice: (idx, delta) =>
                          _onVerticeMovido(_cableSeleccionado!, idx, delta),
                      onEliminarVertice: (idx) =>
                          _onVerticeEliminado(_cableSeleccionado!, idx),
                    );
                  }),

                // Componentes
                ..._componentes.map(
                  (c) => CanvasComponenteWidget(
                    key: ValueKey(c.id),
                    componente: c,
                    seleccionado: _idSeleccionado == c.id,
                    escala: _escala,
                    onTap: () {
                      if (_modoBorrador) {
                        _saveState();
                        _eliminarComponente(c.id);
                      } else {
                        setState(() {
                          _idSeleccionado = c.id;
                          _cableSeleccionado = null;
                        });
                      }
                    },
                    onMoverStart: () {
                      if (!_modoBorrador && _enProgreso == null) _saveState();
                    },
                    onMover: (d) {
                      if (!_modoBorrador) _moverComponente(c.id, d);
                    },
                    onRotar: () {
                      _saveState();
                      _rotarComponente(c.id);
                    },
                    onEliminar: () {
                      _saveState();
                      _eliminarComponente(c.id);
                    },
                    onToggleActivo: () {
                      _saveState();
                      _toggleActivo(c.id);
                    },
                    onTerminalTap: _modoBorrador ? null : _onTerminalTap,
                  ),
                ),

                // Hint vacío
                if (_componentes.isEmpty)
                  Positioned(
                    left: _canvasW / 2 - 140,
                    top: _canvasH / 2 - 60,
                    child: const _HintVacio(),
                  ),
              ],
            ),
          ),
        ),
      ),

        ],
      ),

      floatingActionButton: dibujando
          ? null
          : FloatingActionButton.extended(
              onPressed: _abrirPanelComponentes,
              icon: const Icon(Icons.add),
              label: const Text('Agregar componente'),
            ),
    );
  }

  void _confirmarLimpiar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Limpiar canvas?'),
        content: const Text(
            'Se eliminarán todos los componentes y cables del proyecto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              _saveState();
              setState(() {
                _componentes.clear();
                _cables.clear();
                _idSeleccionado = null;
                _cableSeleccionado = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet para editar propiedades del cable
// ─────────────────────────────────────────────────────────────────────────────

class _CablePickerSheet extends StatelessWidget {
  const _CablePickerSheet({
    required this.cable,
    required this.onColorChanged,
    required this.onCalibreChanged,
    required this.onEliminar,
    required this.onDuplicar,
  });

  final CableEnCanvas cable;
  final void Function(ColorCable) onColorChanged;
  final void Function(int) onCalibreChanged;
  final VoidCallback onEliminar;
  final VoidCallback onDuplicar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Propiedades del cable',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),

          // ── Colores ──────────────────────────────────────────────────────
          Text('Color', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Row(
            children: ColorCable.values.map((c) {
              final selected = c == cable.colorCable;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => onColorChanged(c),
                  child: Tooltip(
                    message: c.label,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c.color.withValues(alpha: 0.4),
                            blurRadius: selected ? 8 : 2,
                          ),
                        ],
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Calibre AWG ───────────────────────────────────────────────────
          Text('Calibre AWG', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CableEnCanvas.calibresDisponibles.map((awg) {
              final selected = awg == cable.calibreAWG;
              return ChoiceChip(
                label: Text('$awg AWG'),
                selected: selected,
                onSelected: (_) => onCalibreChanged(awg),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Acciones ─────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicar'),
                  onPressed: onDuplicar,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  onPressed: onEliminar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel deslizante de componentes
// ─────────────────────────────────────────────────────────────────────────────

class _PanelComponentes extends StatefulWidget {
  const _PanelComponentes({
    required this.onSeleccionar,
    required this.onIniciarCable,
  });

  final void Function(ComponenteElectrico) onSeleccionar;
  final void Function(ColorCable) onIniciarCable;

  @override
  State<_PanelComponentes> createState() => _PanelComponentesState();
}

class _PanelComponentesState extends State<_PanelComponentes> {
  CategoriaComponente _catActiva = CategoriaComponente.todos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lista = ComponenteElectrico.porCategoria(_catActiva);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
            child: Row(
              children: [
                Text(
                  'Agregar al circuito',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Sección cables ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Cables',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: ColorCable.values.map((cable) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CableChip(
                      cable: cable,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onIniciarCable(cable);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Divider(height: 1),
          ),

          // ── Sección componentes ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Componentes',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: CategoriaComponente.values.map((cat) {
                final activo = cat == _catActiva;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat.label),
                    selected: activo,
                    onSelected: (_) => setState(() => _catActiva = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: lista.length,
              itemBuilder: (context, i) => ComponenteCard(
                componente: lista[i],
                onTap: () => widget.onSeleccionar(lista[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip visual para seleccionar un tipo/color de cable
class _CableChip extends StatelessWidget {
  const _CableChip({required this.cable, required this.onTap});

  final ColorCable cable;
  final VoidCallback onTap;

  bool get _esBlanco => cable == ColorCable.blanco;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Etiqueta corta: solo la primera parte antes del "—"
    final partes = cable.label.split('—');
    final colorNombre = partes[0].trim();
    final uso = partes.length > 1 ? partes[1].trim() : '';

    // Para el cable blanco, el texto y borde usan el color del esquema
    final displayColor =
        _esBlanco ? colorScheme.onSurfaceVariant : cable.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: _esBlanco
              ? colorScheme.surfaceContainerHighest
              : cable.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _esBlanco
                ? colorScheme.outline
                : cable.color.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              child: CustomPaint(
                painter: _CableIconPainter(
                  color: cable.color,
                  // Para el blanco, dibujamos la línea con borde oscuro
                  borderColor: _esBlanco ? colorScheme.outline : null,
                ),
                size: const Size(double.infinity, 28),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              colorNombre,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: displayColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (uso.isNotEmpty)
              Text(
                uso,
                style: TextStyle(
                  fontSize: 9,
                  color: displayColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

class _CableIconPainter extends CustomPainter {
  const _CableIconPainter({required this.color, this.borderColor});
  final Color color;
  final Color? borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final border = borderColor;

    // Si hay borderColor (cable blanco), dibujamos primero un trazo de borde
    if (border != null) {
      canvas.drawLine(
        Offset(8, cy),
        Offset(size.width - 8, cy),
        Paint()
          ..color = border.withValues(alpha: 0.5)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawLine(
      Offset(8, cy),
      Offset(size.width - 8, cy),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(8, cy), 5, dotPaint);
    canvas.drawCircle(Offset(size.width - 8, cy), 5, dotPaint);

    final rimPaint = Paint()
      ..color = (border ?? Colors.white).withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(8, cy), 5, rimPaint);
    canvas.drawCircle(Offset(size.width - 8, cy), 5, rimPaint);
  }

  @override
  bool shouldRepaint(_CableIconPainter old) =>
      old.color != color || old.borderColor != borderColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Hint canvas vacío
// ─────────────────────────────────────────────────────────────────────────────

class _HintVacio extends StatelessWidget {
  const _HintVacio();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.touch_app_outlined, size: 52, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          'Toca "Agregar componente"\npara empezar el circuito',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
        ),
      ],
    );
  }
}

