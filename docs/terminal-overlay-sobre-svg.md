# Cómo superponer terminales Flutter exactamente sobre círculos de un SVG

## Objetivo

Cuando un componente eléctrico tiene sus puntos de conexión dibujados **dentro del propio SVG** (como la bombilla con sus círculos L y N), necesitamos colocar el widget de terminal Flutter (`TerminalWidget`) **exactamente encima** de esos círculos, de modo que:

- El usuario vea solo los puntos del SVG (no puntos extra de Flutter).
- El hit-area del widget coincida visualmente con el círculo.
- El extremo del cable quede en el centro exacto del círculo.

---

## Conceptos clave

### El sistema de coordenadas `relativeOffset`

Cada terminal se define con un `relativeOffset: Offset(dx, dy)` donde:

- `0.0` = borde izquierdo / borde superior del widget (90×90 px)
- `1.0` = borde derecho / borde inferior
- `0.5` = centro exacto en ese eje

El widget del componente siempre tiene tamaño **`ComponenteEnCanvas.tamano = 90 px`**.

El `Positioned` que coloca el terminal se calcula así:

```dart
Positioned(
  left: terminal.relativeOffset.dx * sz - (terminalSize / 2),
  top:  terminal.relativeOffset.dy * sz - (terminalSize / 2),
  child: TerminalWidget(size: terminalSize, ...),
)
```

El resultado es que el **centro** del `TerminalWidget` queda en:
- `x = relativeOffset.dx * sz`
- `y = relativeOffset.dy * sz`

---

## Paso a paso para calcular el `relativeOffset`

### Paso 1 — Obtener el `viewBox` del SVG

Abrir el archivo `.svg` y buscar el atributo `viewBox` en la etiqueta raíz:

```xml
<svg viewBox="0 0 240 280">
```

Aquí: `svgW = 240`, `svgH = 280`.

---

### Paso 2 — Obtener las coordenadas reales del círculo

Buscar el elemento `<circle>` en el SVG y anotar su `cx` y `cy`.

> **Importante:** si el círculo está dentro de un grupo `<g transform="translate(tx, ty)">`,
> hay que sumar todos los `translate` anidados para obtener la posición absoluta.

**Ejemplo con la bombilla:**

```xml
<!-- Grupo externo: translate(0, -5) -->
<g transform="translate(0, -5)">

  <!-- Grupo de terminales: translate(0, 10) -->
  <g transform="translate(0, 10)">

    <!-- circle37 — Terminal L -->
    <circle cx="80" cy="235" r="10" fill="#d32f2f"/>

    <!-- circle38 — Terminal N -->
    <circle cx="160" cy="235" r="10" fill="#1565c0"/>

  </g>
</g>
```

Posición efectiva de cada círculo en el espacio del `viewBox`:

| Terminal | cx en SVG | Suma de tx | cx efectivo | cy en SVG | Suma de ty | cy efectivo |
|----------|-----------|------------|-------------|-----------|------------|-------------|
| L        | 80        | 0 + 0      | **80**      | 235       | -5 + 10    | **240**     |
| N        | 160       | 0 + 0      | **160**     | 235       | -5 + 10    | **240**     |

---

### Paso 3 — Calcular la escala de `BoxFit.contain`

El SVG se renderiza con `BoxFit.contain` dentro de una caja cuadrada de `sz × sz` (por defecto 90×90).

`BoxFit.contain` escala el SVG para **caber completamente** en la caja manteniendo la proporción, centrando el contenido que sobra.

```
scale = min(sz / svgW,  sz / svgH)
```

Para el ejemplo:
```
scale = min(90/240, 90/280) = min(0.375, 0.321) = 0.321
```

La imagen se escala por el **lado mayor** (altura), por lo que:
- `renderedW = svgW × scale = 240 × 0.321 = 77.14 px`
- `renderedH = svgH × scale = 280 × 0.321 = 90.00 px`

---

### Paso 4 — Calcular el offset de centrado (letterboxing)

Cuando el SVG no llena completamente un eje, `BoxFit.contain` con `Alignment.center` (valor por defecto) lo centra, añadiendo espacio en los bordes.

```
offsetX = (sz - renderedW) / 2 = (90 - 77.14) / 2 = 6.43 px
offsetY = (sz - renderedH) / 2 = (90 - 90.00) / 2 = 0.00 px
```

> Si `renderedH == sz` (la altura rellena exactamente), `offsetY = 0`.  
> Si `renderedW == sz` (el ancho rellena exactamente), `offsetX = 0`.

---

### Paso 5 — Calcular la posición del círculo en la caja de 90×90 px

```
pixelX = offsetX + (cx_efectivo × scale)
pixelY = offsetY + (cy_efectivo × scale)
```

Para L:
```
pixelX = 6.43 + (80  × 0.321) = 6.43 + 25.71 = 32.14 px
pixelY = 0.00 + (240 × 0.321) = 0.00 + 77.14 = 77.14 px
```

Para N:
```
pixelX = 6.43 + (160 × 0.321) = 6.43 + 51.43 = 57.86 px
pixelY = 77.14 px  (mismo cy)
```

---

### Paso 6 — Convertir a `relativeOffset`

```
relativeOffset.dx = pixelX / sz
relativeOffset.dy = pixelY / sz
```

| Terminal | pixelX | pixelY | relativeOffset.dx | relativeOffset.dy |
|----------|--------|--------|-------------------|-------------------|
| L        | 32.14  | 77.14  | **0.357**         | **0.857**         |
| N        | 57.86  | 77.14  | **0.643**         | **0.857**         |

---

### Paso 7 — Fórmula general (resumen)

```
scale    = min(sz / svgW, sz / svgH)
offsetX  = (sz - svgW × scale) / 2
offsetY  = (sz - svgH × scale) / 2

relativeOffset.dx = (offsetX + cx_efectivo × scale) / sz
relativeOffset.dy = (offsetY + cy_efectivo × scale) / sz
```

---

## Implementación en Flutter

### En el widget del componente (ej: `BombillaWidget`)

```dart
// 1. Definir los terminales con el relativeOffset calculado
static const List<Terminal> _terminales = [
  Terminal(
    id: 'L',
    label: 'L',
    color: Terminal.colorFase,
    relativeOffset: Offset(0.357, 0.857),  // ← calculado con la fórmula
  ),
  Terminal(
    id: 'N',
    label: 'N',
    color: Terminal.colorNeutro,
    relativeOffset: Offset(0.643, 0.857),  // ← calculado con la fórmula
  ),
];

// 2. El tamaño del hit-area debe ser similar al radio del círculo SVG renderizado
//    Radio SVG = r × scale = 10 × 0.321 ≈ 3.2 px → usar al menos 12-16 px para usabilidad
static const double _terminalSize = 14.0;

// 3. Colocar el widget invisible (overlay) centrado exactamente sobre el círculo SVG
@override
Widget build(BuildContext context) {
  final double sz = widget.tamano;     // 90
  final double half = _terminalSize / 2;  // 7

  return SizedBox(
    width: sz,
    height: sz,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Imagen SVG — ocupa todo el SizedBox
        Positioned.fill(
          child: SvgPicture.asset(
            'assets/circuit_components/mi_componente.svg',
            width: sz,
            height: sz,
            fit: BoxFit.contain,   // ← DEBE coincidir con lo usado en la fórmula
          ),
        ),

        // Terminales superpuestos sobre los círculos SVG
        for (final terminal in _terminales)
          Positioned(
            left: terminal.relativeOffset.dx * sz - half,
            top:  terminal.relativeOffset.dy * sz - half,
            child: TerminalWidget(
              terminal: terminal,
              globalKey: _terminalKeys[terminal.id]!,
              mode: TerminalMode.overlay,   // ← invisible por defecto
              size: _terminalSize,
              onDragStart: (termId, globalPos) =>
                  widget.onTerminalTap?.call(widget.componenteId, termId, globalPos),
            ),
          ),
      ],
    ),
  );
}
```

---

## Reglas importantes

| Regla | Detalle |
|-------|---------|
| **`fit: BoxFit.contain`** | El SVG SIEMPRE debe renderizarse con este modo. Si cambias a `fill` o `cover`, las fórmulas no aplican. |
| **`Alignment.center`** | `SvgPicture.asset` usa `Alignment.center` por defecto. No cambiar. |
| **Sin Padding extra** | El `SizedBox(sz, sz)` que envuelve el componente no debe tener `Padding`. Un padding de 4 px desplazaría todos los terminales 4 px. |
| **Transforms anidados** | Acumular **todos** los `translate(tx, ty)` de los grupos padre antes de calcular la posición efectiva. |
| **`sz` consistente** | El `sz` en el widget (`tamano = 90`) debe ser el mismo que se usa en la fórmula. Si cambias el tamaño del widget, los `relativeOffset` siguen siendo válidos (son relativos). |
| **Tamaño del hit-area** | El `_terminalSize` (tamaño del `TerminalWidget`) solo afecta la zona táctil, no la posición. Se recomienda 12–20 px para buena usabilidad. |

---

## Cómo encontrar los círculos en Inkscape

Si tienes el SVG abierto en **Inkscape**:

1. Hacer clic en el círculo del terminal deseado en el canvas.
2. En el panel de **XML** (`Ctrl+Shift+X`) ver los atributos `cx`, `cy`, `r`.
3. En el panel lateral de capas ver la jerarquía de grupos `<g>` padre y sus `transform`.
4. Acumular todos los `translate(tx, ty)` desde la raíz hasta el círculo para obtener la posición efectiva.

Alternativamente, editar el SVG en un editor de texto y buscar `<circle` — los valores de `cx` y `cy` son los que se necesitan (más los transforms padre).

---

## Checklist rápido para un nuevo SVG

```
[ ] Obtener viewBox del SVG  (svgW, svgH)
[ ] Localizar el <circle> de cada terminal
[ ] Sumar todos los translate() de los grupos padre  → (cx_efectivo, cy_efectivo)
[ ] scale = min(sz/svgW, sz/svgH)
[ ] offsetX = (sz - svgW*scale)/2
[ ] offsetY = (sz - svgH*scale)/2
[ ] relDx = (offsetX + cx_efectivo*scale) / sz
[ ] relDy = (offsetY + cy_efectivo*scale) / sz
[ ] Definir Terminal(relativeOffset: Offset(relDx, relDy)) en el widget
[ ] Usar TerminalMode.overlay en el TerminalWidget
[ ] Verificar que el SizedBox del componente NO tiene Padding
[ ] Hot reload y confirmar visualmente el alineamiento
```

---

## Cómo hacer que el cable llegue exactamente al círculo SVG

Para que el extremo del cable se conecte al círculo de un nuevo SVG se necesitan
**tres elementos sincronizados**. Si cualquiera de los tres no coincide, el cable
termina en un punto diferente al círculo.

```
┌─────────────────────────────────────────────────────────────────┐
│  CÍRCULO EN EL SVG  ──►  relativeOffset  ──►  EXTREMO DEL CABLE │
│                                                                  │
│  El mismo relativeOffset debe estar en:                          │
│    1. El widget visual del componente  (TerminalWidget overlay)  │
│    2. TerminalesDefinicion             (cálculo del cable)       │
│    3. _globalToCanvas                 (conversión de pantalla)   │
└─────────────────────────────────────────────────────────────────┘
```

---

### Elemento 1 — Widget visual: `relativeOffset` en el componente

El widget del componente posiciona el `TerminalWidget` overlay encima del círculo SVG.
Calculado con la fórmula del paso a paso anterior:

```dart
// En el StatefulWidget del componente (ej: BombillaWidget)
static const List<Terminal> _terminales = [
  Terminal(
    id: 'L',
    label: 'L',
    color: Terminal.colorFase,
    relativeOffset: Offset(0.357, 0.857),  // ← fórmula SVG
  ),
];

// En build():
Positioned(
  left: terminal.relativeOffset.dx * sz - (terminalSize / 2),
  top:  terminal.relativeOffset.dy * sz - (terminalSize / 2),
  child: TerminalWidget(
    terminal: terminal,
    globalKey: _terminalKeys[terminal.id]!,
    mode: TerminalMode.overlay,  // invisible; solo hit-area sobre el círculo SVG
    size: terminalSize,
    onDragStart: (termId, globalPos) =>
        widget.onTerminalTap?.call(widget.componenteId, termId, globalPos),
  ),
),
```

---

### Elemento 2 — `TerminalesDefinicion`: el mismo `relativeOffset`

`_terminalCanvasPos` (que calcula dónde termina el cable en coordenadas del canvas)
usa **`TerminalesDefinicion`**, no los terminales del widget visual.
Si los valores no coinciden, el cable termina en otro lugar aunque el overlay esté bien.

```dart
// En terminal.dart → TerminalesDefinicion.porTipo
'mi_componente': [
  // MISMO relativeOffset que en el widget visual
  Terminal(id: 'L', label: 'L', color: Terminal.colorFase,
      relativeOffset: Offset(0.357, 0.857)),
  Terminal(id: 'N', label: 'N', color: Terminal.colorNeutro,
      relativeOffset: Offset(0.643, 0.857)),
],
```

> **Regla:** si tienes un componente con widget propio (como `BombillaWidget`) y uno genérico
> (`ComponenteCircuitoWidget`), ambos deben tener el **mismo** `relativeOffset` para el mismo
> terminal. La fuente de la verdad es la posición del círculo en el SVG.

---

### Elemento 3 — `_globalToCanvas`: usar el RenderBox del body

Cuando el usuario toca un terminal, se obtiene su posición real en pantalla (`globalPos`
vía `GlobalKey`). Esa posición se convierte a coordenadas del canvas con `_globalToCanvas`.

Para que esa conversión sea precisa, `_globalToCanvas` debe usar el `RenderBox` del
widget que contiene el `InteractiveViewer` (el body del Scaffold), **no** el del Scaffold
completo. El `TransformationController` usa el sistema de coordenadas del body; si se
usa el Scaffold, hay un offset igual al alto del AppBar que desplaza el cable hacia abajo.

#### Declarar la key en el State

```dart
class _CanvasPageState extends State<CanvasPage> {
  final TransformationController _transformCtrl = TransformationController();

  // Key del widget padre del InteractiveViewer (GestureDetector del body).
  // Necesaria para que _globalToCanvas use el mismo origen de coordenadas
  // que el TransformationController.
  final GlobalKey _bodyKey = GlobalKey();
}
```

#### Asignar la key al GestureDetector del body

```dart
body: GestureDetector(
  key: _bodyKey,   // ← aquí
  onTapUp: _onCanvasTapUp,
  onPanUpdate: dibujando ? _onCanvasPanUpdate : null,
  child: InteractiveViewer(
    transformationController: _transformCtrl,
    // ...
  ),
),
```

#### Implementar `_globalToCanvas` con `_bodyKey`

```dart
Offset _globalToCanvas(Offset global) {
  final box = (_bodyKey.currentContext?.findRenderObject() ??
      context.findRenderObject()) as RenderBox?;
  if (box == null) return global;
  final local = box.globalToLocal(global);
  return MatrixUtils.transformPoint(
    Matrix4.inverted(_transformCtrl.value),
    local,
  );
}
```

#### Usar la misma key al agregar componentes

Para que los componentes aparezcan centrados en el área visible:

```dart
void _agregarComponente(ComponenteElectrico tipo) {
  final inv = Matrix4.inverted(_transformCtrl.value);
  final bodyBox = (_bodyKey.currentContext?.findRenderObject() ??
      context.findRenderObject()) as RenderBox?;
  final size = bodyBox?.size ?? const Size(400, 700);
  final centro = MatrixUtils.transformPoint(
    inv,
    Offset(size.width / 2, size.height / 2),
  );
  // ...
}
```

---

## Ejemplo completo: nuevo componente con círculos SVG

**SVG:** `viewBox="0 0 120 80"`, bornas laterales sin grupos transform:
- L1: `cx="5"`, `cy="40"`
- L2: `cx="115"`, `cy="40"`

**Cálculo:**
```
scale    = min(90/120, 90/80) = 0.75
renderedW = 90 px  →  offsetX = 0
renderedH = 60 px  →  offsetY = 15

L1: relDx = (0 + 5×0.75) / 90 = 0.042    relDy = (15 + 40×0.75) / 90 = 0.500
L2: relDx = (0 + 115×0.75) / 90 = 0.958  relDy = 0.500
```

**Widget visual** (`mi_componente_widget.dart`):
```dart
static const _terminales = [
  Terminal(id: 'L1', label: 'L1', color: Terminal.colorFase,
      relativeOffset: Offset(0.042, 0.500)),
  Terminal(id: 'L2', label: 'L2', color: Terminal.colorFase,
      relativeOffset: Offset(0.958, 0.500)),
];
```

**`TerminalesDefinicion`** (`terminal.dart`) — mismos valores:
```dart
'mi_componente': [
  Terminal(id: 'L1', label: 'L1', color: Terminal.colorFase,
      relativeOffset: Offset(0.042, 0.500)),
  Terminal(id: 'L2', label: 'L2', color: Terminal.colorFase,
      relativeOffset: Offset(0.958, 0.500)),
],
```

---

## Checklist para un nuevo SVG con terminales

```
── SVG ──────────────────────────────────────────────────────────────
[ ] Dibujar los <circle> de los terminales en posiciones conocidas
[ ] Anotar viewBox (svgW, svgH) y cx/cy de cada círculo
[ ] Sumar todos los translate() de grupos padre → (cx_efectivo, cy_efectivo)

── Fórmula ──────────────────────────────────────────────────────────
[ ] scale    = min(sz/svgW, sz/svgH)
[ ] offsetX  = (sz - svgW×scale) / 2
[ ] offsetY  = (sz - svgH×scale) / 2
[ ] relDx    = (offsetX + cx_efectivo×scale) / sz
[ ] relDy    = (offsetY + cy_efectivo×scale) / sz

── Widget visual (ComponenteWidget) ─────────────────────────────────
[ ] Definir Terminal(relativeOffset: Offset(relDx, relDy))
[ ] Posicionar con Positioned(left: relDx*sz - half, top: relDy*sz - half)
[ ] Usar TerminalMode.overlay (invisible; el círculo SVG es el visual)
[ ] GlobalKeys estables en initState() (NO en build())
[ ] SizedBox(sz, sz) sin Padding extra alrededor

── TerminalesDefinicion (terminal.dart) ─────────────────────────────
[ ] Agregar entrada con el MISMO relativeOffset que en el widget visual
[ ] Verificar que el id del terminal coincide ('L', 'N', 'L1', etc.)

── canvas_page.dart ─────────────────────────────────────────────────
[ ] _bodyKey asignado al GestureDetector que envuelve el InteractiveViewer
[ ] _globalToCanvas usa _bodyKey.currentContext?.findRenderObject()
[ ] _agregarComponente usa _bodyKey para calcular el centro del viewport

── Verificación ─────────────────────────────────────────────────────
[ ] Hot reload
[ ] Al pasar el mouse sobre el círculo SVG aparece el glow del overlay
[ ] Al conectar un cable, el extremo llega exactamente al centro del círculo
[ ] Al mover el componente, el cable sigue el círculo sin desplazarse
```
