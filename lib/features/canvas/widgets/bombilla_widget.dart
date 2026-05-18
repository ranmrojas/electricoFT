import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/terminal.dart';
import 'terminal_widget.dart' show TerminalWidget, TerminalMode;

class BombillaWidget extends StatefulWidget {
  const BombillaWidget({
    super.key,
    required this.encendida,
    required this.tamano,
    required this.componenteId,
    this.terminalesConectados = const {},
    this.onTerminalTap,
  });

  final bool encendida;
  final double tamano;

  /// IDs de terminales que ya tienen un cable conectado
  final Set<String> terminalesConectados;

  /// Callback cuando el usuario toca un terminal para iniciar un cable.
  /// Recibe (componenteId, terminalId, posición global del terminal).
  final void Function(String componenteId, String terminalId, Offset globalPos)? onTerminalTap;

  /// ID del componente padre (necesario para el callback)
  final String componenteId;

  @override
  State<BombillaWidget> createState() => _BombillaWidgetState();
}

class _BombillaWidgetState extends State<BombillaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  // Una GlobalKey por terminal para poder obtener su posición global
  final Map<String, GlobalKey> _terminalKeys = {
    'L': GlobalKey(),
    'N': GlobalKey(),
  };

  // Posiciones calibradas sobre los dots L y N dibujados en bombilla.svg.
  // El SVG tiene viewBox 240x280 y se muestra con BoxFit.contain dentro de 90x90,
  // por eso el contenido queda centrado horizontalmente.
  static const List<Terminal> _terminales = [
    Terminal(
      id: 'L',
      label: 'L',
      color: Terminal.colorFase,
      relativeOffset: Offset(0.357, 0.857),
    ),
    Terminal(
      id: 'N',
      label: 'N',
      color: Terminal.colorNeutro,
      relativeOffset: Offset(0.643, 0.857),
    ),
  ];

  // Tamaño del hit-area overlay (debe coincidir con el dot de la imagen ~14 px a 90 px)
  static const double _terminalSize = 14.0;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    if (widget.encendida) {
      _glowCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant BombillaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.encendida != oldWidget.encendida) {
      if (widget.encendida) {
        _glowCtrl.repeat(reverse: true);
      } else {
        _glowCtrl.stop();
        _glowCtrl.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double sz = widget.tamano;
    final double half = _terminalSize / 2;

    // El SizedBox es exactamente el tamaño visual del SVG; los terminales
    // se superponen como hit-area invisible sobre los dots del propio SVG.
    return SizedBox(
      width: sz,
      height: sz,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Imagen de la bombilla ──────────────────────────────────────────
          Positioned.fill(child: _buildImagen(sz)),

          // Capa de resplandor (solo encendida)
          if (widget.encendida) Positioned.fill(child: _buildGlow(sz)),

          // Halo exterior pulsante (solo encendida)
          if (widget.encendida) Positioned.fill(child: _buildHaloExterior(sz)),

          // ── Terminales invisibles centrados sobre los dots del SVG ─────────
          for (final terminal in _terminales)
            Positioned(
              left: terminal.relativeOffset.dx * sz - half,
              top: terminal.relativeOffset.dy * sz - half,
              child: TerminalWidget(
                terminal: terminal,
                globalKey: _terminalKeys[terminal.id]!,
                mode: TerminalMode.overlay,
                size: _terminalSize,
                conectado: widget.terminalesConectados.contains(terminal.id),
                onDragStart: (termId, globalPos) =>
                    widget.onTerminalTap?.call(
                      widget.componenteId,
                      termId,
                      globalPos,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagen(double sz) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) {
        if (!widget.encendida) {
          // Estado apagado: ligeramente desaturado
          return ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.7, 0.2, 0.1, 0, 0,
              0.2, 0.7, 0.1, 0, 0,
              0.2, 0.2, 0.6, 0, 0,
              0,   0,   0,   1, 0,
            ]),
            child: child!,
          );
        }
        // Estado encendido: tinte cálido dorado interpolado
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            return RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 0.7,
              colors: [
                Color.lerp(
                  Colors.transparent,
                  const Color(0xFFFFF176),
                  _glowAnim.value * 0.55,
                )!,
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: SvgPicture.asset(
        'assets/circuit_components/bombilla.svg',
        width: sz,
        height: sz,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildGlow(double sz) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(sz * 0.15),
              gradient: RadialGradient(
                center: const Alignment(0, -0.25),
                radius: 0.55,
                colors: [
                  const Color(0xFFFFF59D)
                      .withValues(alpha: _glowAnim.value * 0.65),
                  const Color(0xFFFFD600)
                      .withValues(alpha: _glowAnim.value * 0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHaloExterior(double sz) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return IgnorePointer(
          child: CustomPaint(
            painter: _HaloPainter(
              opacity: _glowAnim.value,
              radius: sz * 0.48,
              color: const Color(0xFFFFE57F),
            ),
          ),
        );
      },
    );
  }
}

// ── Painter para el halo de luz pulsante ────────────────────────────────────

class _HaloPainter extends CustomPainter {
  const _HaloPainter({
    required this.opacity,
    required this.radius,
    required this.color,
  });

  final double opacity;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity * 0.4),
          color.withValues(alpha: opacity * 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.4));

    canvas.drawCircle(center, radius * 1.4, paint);

    // Anillo de resplandor adicional
    final ringPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(
      center,
      radius * (1.1 + 0.15 * math.sin(opacity * math.pi)),
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.opacity != opacity || old.radius != radius;
}
