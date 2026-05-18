import 'package:flutter/material.dart';
import '../models/terminal.dart';

/// Modo de renderizado del terminal.
///
/// [solido]  → círculo relleno con etiqueta (para componentes sin dot en su imagen).
/// [overlay] → solo anillo + glow; el interior queda transparente para no tapar
///             el punto que ya está dibujado en la imagen del componente.
enum TerminalMode { solido, overlay }

class TerminalWidget extends StatefulWidget {
  const TerminalWidget({
    super.key,
    required this.terminal,
    required this.globalKey,
    this.mode = TerminalMode.solido,
    this.size = 20,
    this.conectado = false,
    this.onDragStart,
    this.onHover,
  });

  final Terminal terminal;
  final GlobalKey globalKey;
  final TerminalMode mode;

  /// Diámetro del widget interactivo en lógical pixels
  final double size;

  final bool conectado;
  final void Function(String terminalId, Offset globalPos)? onDragStart;
  final void Function(bool hovering)? onHover;


  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    // En modo sólido siempre pulsa; en overlay solo cuando esté activo
    if (widget.mode == TerminalMode.solido) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Offset _getGlobalPosition() {
    final box =
        widget.globalKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    final bool activo = widget.conectado || _hovering;

    return GestureDetector(
      onTapDown: (_) =>
          widget.onDragStart?.call(widget.terminal.id, _getGlobalPosition()),
      onLongPressStart: (_) =>
          widget.onDragStart?.call(widget.terminal.id, _getGlobalPosition()),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _hovering = true);
          if (widget.mode == TerminalMode.overlay && !_pulseCtrl.isAnimating) {
            _pulseCtrl.repeat(reverse: true);
          }
          widget.onHover?.call(true);
        },
        onExit: (_) {
          setState(() => _hovering = false);
          if (widget.mode == TerminalMode.overlay && !widget.conectado) {
            _pulseCtrl.stop();
            _pulseCtrl.value = 0;
          }
          widget.onHover?.call(false);
        },
        child: widget.mode == TerminalMode.overlay
            ? _buildOverlay(activo)
            : AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) => _buildSolido(activo),
              ),
      ),
    );
  }

  /// Modo overlay: INVISIBLE por defecto (solo hit-area transparente).
  /// Solo muestra el glow cuando el usuario está interactuando activamente
  /// (hover / cable siendo conectado). Los dots del SVG siempre visibles.
  Widget _buildOverlay(bool activo) {
    final double sz = widget.size;
    final color = widget.terminal.color;

    // Sin interacción → completamente invisible, solo área táctil
    if (!activo) {
      return SizedBox(key: widget.globalKey, width: sz, height: sz);
    }

    // Con interacción → halo pulsante alrededor del dot existente del SVG
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          key: widget.globalKey,
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
              color: color.withValues(alpha: _pulseAnim.value * 0.9),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _pulseAnim.value * 0.85),
                blurRadius: 12 * _pulseAnim.value,
                spreadRadius: 4 * _pulseAnim.value,
              ),
              BoxShadow(
                color: color.withValues(alpha: _pulseAnim.value * 0.35),
                blurRadius: 22 * _pulseAnim.value,
                spreadRadius: 7 * _pulseAnim.value,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Modo sólido: círculo relleno con etiqueta (para componentes sin dot propio)
  Widget _buildSolido(bool activo) {
    final double sz = widget.size;
    final color = widget.terminal.color;

    return Container(
      key: widget.globalKey,
      width: sz,
      height: sz,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: activo ? color : color.withValues(alpha: 0.6),
        border: Border.all(
          color: activo ? Colors.white : Colors.white70,
          width: activo ? 2.5 : 1.5,
        ),
        boxShadow: activo
            ? [
                BoxShadow(
                  color: color.withValues(alpha: _pulseAnim.value * 0.8),
                  blurRadius: 8 * _pulseAnim.value,
                  spreadRadius: 2 * _pulseAnim.value,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          widget.terminal.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
