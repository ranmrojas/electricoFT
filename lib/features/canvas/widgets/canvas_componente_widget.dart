import 'package:flutter/material.dart';
import '../models/componente_en_canvas.dart';
import 'componente_circuito_widget.dart';

class CanvasComponenteWidget extends StatelessWidget {
  const CanvasComponenteWidget({
    super.key,
    required this.componente,
    required this.seleccionado,
    required this.onTap,
    required this.onMoverStart,
    required this.onMover,
    required this.onRotar,
    required this.onEliminar,
    required this.onToggleActivo,
    required this.escala,
    this.onTerminalTap,
  });

  final ComponenteEnCanvas componente;
  final bool seleccionado;
  final VoidCallback onTap;
  final VoidCallback onMoverStart;
  final void Function(DragUpdateDetails) onMover;
  final VoidCallback onRotar;
  final VoidCallback onEliminar;

  /// Alterna el estado encendido/apagado del componente
  final VoidCallback onToggleActivo;

  final double escala;

  /// (componenteId, terminalId, globalPos)
  final void Function(String componenteId, String terminalId, Offset globalPos)?
      onTerminalTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const t = ComponenteEnCanvas.tamano;

    return Positioned(
      left: componente.posicion.dx - t / 2,
      top: componente.posicion.dy - t / 2,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onToggleActivo,
        onPanStart: (_) => onMoverStart(),
        onPanUpdate: onMover,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Contenedor visual del componente ──────────────────────────
            Transform.rotate(
              angle: componente.rotacion,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  // Solo dibujamos un borde si está seleccionado o activo (sin fondo)
                  borderRadius: BorderRadius.circular(14),
                  border: seleccionado
                      ? Border.all(color: colorScheme.primary, width: 2.5)
                      : componente.activo
                          ? Border.all(color: const Color(0xFFFFD600), width: 1.5)
                          : Border.all(color: Colors.transparent, width: 1),
                ),
                child: SizedBox(
                  width: t,
                  height: t,
                  child: ComponenteCircuitoWidget(
                    componente: componente,
                    onTerminalTap: onTerminalTap,
                  ),
                ),
              ),
            ),

            // ── Controles de selección ─────────────────────────────────────
            if (seleccionado) ...[
              Positioned(
                top: -16,
                right: -16,
                child: _ControlBtn(
                  icon: Icons.rotate_right,
                  color: colorScheme.secondary,
                  onTap: onRotar,
                ),
              ),
              Positioned(
                top: -16,
                left: -16,
                child: _ControlBtn(
                  icon: Icons.close,
                  color: colorScheme.error,
                  onTap: onEliminar,
                ),
              ),
              // Botón toggle encendido/apagado
              Positioned(
                bottom: -16,
                right: -16,
                child: _ControlBtn(
                  icon: componente.activo
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                  color: componente.activo
                      ? const Color(0xFFFFB300)
                      : colorScheme.outline,
                  onTap: onToggleActivo,
                  tooltip: componente.activo ? 'Apagar' : 'Encender',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
