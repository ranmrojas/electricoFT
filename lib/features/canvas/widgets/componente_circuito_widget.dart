import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/componente_en_canvas.dart';
import '../models/terminal.dart';
import 'bombilla_widget.dart';
import 'terminal_widget.dart';

/// Renderiza la imagen del componente + sus terminales superpuestos.
///
/// Es [StatefulWidget] para mantener los [GlobalKey] de los terminales
/// estables entre rebuilds. Si fueran creados en [build], Flutter
/// destruiría y recreería el render-object en cada setState, causando
/// que [TerminalWidget._getGlobalPosition] devuelva posiciones incorrectas
/// y que el estado de animación de cada terminal se pierda.
class ComponenteCircuitoWidget extends StatefulWidget {
  const ComponenteCircuitoWidget({
    super.key,
    required this.componente,
    this.onTerminalTap,
  });

  final ComponenteEnCanvas componente;

  /// (componenteId, terminalId, globalPos)
  final void Function(String componenteId, String terminalId, Offset globalPos)?
      onTerminalTap;

  @override
  State<ComponenteCircuitoWidget> createState() =>
      _ComponenteCircuitoWidgetState();
}

class _ComponenteCircuitoWidgetState extends State<ComponenteCircuitoWidget> {
  /// Un GlobalKey por terminal, creado UNA SOLA VEZ en initState.
  /// La key persiste mientras el widget esté montado, garantizando que
  /// [TerminalWidget._getGlobalPosition()] siempre encuentre el RenderBox.
  late final Map<String, GlobalKey> _terminalKeys;

  @override
  void initState() {
    super.initState();
    final terminales = TerminalesDefinicion.get(widget.componente.tipo.id);
    _terminalKeys = {
      for (final t in terminales) t.id: GlobalKey(),
    };
  }

  @override
  Widget build(BuildContext context) {
    const double sz = ComponenteEnCanvas.tamano;
    final terminales = TerminalesDefinicion.get(widget.componente.tipo.id);

    // La bombilla tiene su propio widget animado con overlay SVG calibrado
    if (widget.componente.tipo.id == 'bombilla') {
      return BombillaWidget(
        encendida: widget.componente.activo,
        tamano: sz,
        componenteId: widget.componente.id,
        terminalesConectados: widget.componente.terminalesConectados,
        onTerminalTap: widget.onTerminalTap,
      );
    }

    // Widget genérico: SVG + terminales sólidos superpuestos
    return SizedBox(
      width: sz,
      height: sz,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              widget.componente.tipo.iconoCircuito,
              fit: BoxFit.contain,
            ),
          ),
          for (final terminal in terminales)
            Positioned(
              // Centro del TerminalWidget = relativeOffset × sz
              left: terminal.relativeOffset.dx * sz - 10,
              top:  terminal.relativeOffset.dy * sz - 10,
              child: TerminalWidget(
                terminal: terminal,
                globalKey: _terminalKeys[terminal.id] ?? GlobalKey(),
                conectado: widget.componente.terminalesConectados
                    .contains(terminal.id),
                onDragStart: (termId, globalPos) =>
                    widget.onTerminalTap?.call(
                      widget.componente.id,
                      termId,
                      globalPos,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
