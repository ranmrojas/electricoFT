enum CategoriaComponente {
  todos,
  basicos,
  proteccion,
  generacion,
  control,
  cajas,
}

extension CategoriaComponenteLabel on CategoriaComponente {
  String get label {
    switch (this) {
      case CategoriaComponente.todos:
        return 'Todos';
      case CategoriaComponente.basicos:
        return 'Básicos';
      case CategoriaComponente.proteccion:
        return 'Protección';
      case CategoriaComponente.generacion:
        return 'Generación';
      case CategoriaComponente.control:
        return 'Control';
      case CategoriaComponente.cajas:
        return 'Cajas';
    }
  }
}

class ComponenteElectrico {
  const ComponenteElectrico({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.iconoCircuito,
    required this.iconoDiagrama,
    this.descripcion,
  });

  final String id;
  final String nombre;
  final CategoriaComponente categoria;
  final String iconoCircuito;
  final String iconoDiagrama;
  final String? descripcion;

  static const List<ComponenteElectrico> catalogo = [
    ComponenteElectrico(
      id: 'toma',
      nombre: 'Toma de corriente',
      categoria: CategoriaComponente.basicos,
      iconoCircuito: 'assets/circuit_components/toma.svg',
      iconoDiagrama: 'assets/components/toma.svg',
      descripcion: 'Base de enchufe monofásica',
    ),
    ComponenteElectrico(
      id: 'interruptor',
      nombre: 'Interruptor',
      categoria: CategoriaComponente.basicos,
      iconoCircuito: 'assets/circuit_components/interruptor.svg',
      iconoDiagrama: 'assets/components/interruptor.svg',
      descripcion: 'Interruptor unipolar simple',
    ),
    ComponenteElectrico(
      id: 'bombilla',
      nombre: 'Bombilla',
      categoria: CategoriaComponente.basicos,
      iconoCircuito: 'assets/circuit_components/bombilla.svg',
      iconoDiagrama: 'assets/components/bombilla.svg',
      descripcion: 'Lámpara incandescente',
    ),
    ComponenteElectrico(
      id: 'nodo',
      nombre: 'Nodo',
      categoria: CategoriaComponente.basicos,
      iconoCircuito: 'assets/circuit_components/nodo.svg',
      iconoDiagrama: 'assets/components/nodo.svg',
      descripcion: 'Punto de unión de conductores',
    ),
    ComponenteElectrico(
      id: 'resistencia',
      nombre: 'Resistencia',
      categoria: CategoriaComponente.basicos,
      iconoCircuito: 'assets/circuit_components/resistencia.svg',
      iconoDiagrama: 'assets/components/resistencia.svg',
      descripcion: 'Resistencia eléctrica',
    ),
    ComponenteElectrico(
      id: 'condensador',
      nombre: 'Condensador',
      categoria: CategoriaComponente.basicos,
      iconoCircuito: 'assets/circuit_components/condensador.svg',
      iconoDiagrama: 'assets/components/condensador.svg',
      descripcion: 'Condensador electrolítico',
    ),
    ComponenteElectrico(
      id: 'breaker',
      nombre: 'Breaker',
      categoria: CategoriaComponente.proteccion,
      iconoCircuito: 'assets/circuit_components/breaker.svg',
      iconoDiagrama: 'assets/components/breaker.svg',
      descripcion: 'Interruptor automático DIN',
    ),
    ComponenteElectrico(
      id: 'fusible',
      nombre: 'Fusible',
      categoria: CategoriaComponente.proteccion,
      iconoCircuito: 'assets/circuit_components/fusible.svg',
      iconoDiagrama: 'assets/components/fusible.svg',
      descripcion: 'Fusible de cartucho',
    ),
    ComponenteElectrico(
      id: 'tablero',
      nombre: 'Tablero',
      categoria: CategoriaComponente.proteccion,
      iconoCircuito: 'assets/circuit_components/tablero.svg',
      iconoDiagrama: 'assets/components/tablero.svg',
      descripcion: 'Tablero de distribución eléctrica',
    ),
    ComponenteElectrico(
      id: 'medidor',
      nombre: 'Medidor',
      categoria: CategoriaComponente.control,
      iconoCircuito: 'assets/circuit_components/medidor.svg',
      iconoDiagrama: 'assets/components/medidor.svg',
      descripcion: 'Medidor monofásico de energía',
    ),
    ComponenteElectrico(
      id: 'transformador',
      nombre: 'Transformador',
      categoria: CategoriaComponente.control,
      iconoCircuito: 'assets/circuit_components/transformador.svg',
      iconoDiagrama: 'assets/components/transformador.svg',
      descripcion: 'Transformador de tensión',
    ),
    ComponenteElectrico(
      id: 'bateria',
      nombre: 'Batería',
      categoria: CategoriaComponente.generacion,
      iconoCircuito: 'assets/circuit_components/bateria.svg',
      iconoDiagrama: 'assets/components/bateria.svg',
      descripcion: 'Batería DC 12V',
    ),
    ComponenteElectrico(
      id: 'generador',
      nombre: 'Generador',
      categoria: CategoriaComponente.generacion,
      iconoCircuito: 'assets/circuit_components/generador.svg',
      iconoDiagrama: 'assets/components/generador.svg',
      descripcion: 'Generador eléctrico AC',
    ),
    ComponenteElectrico(
      id: 'planta',
      nombre: 'Planta eléctrica',
      categoria: CategoriaComponente.generacion,
      iconoCircuito: 'assets/circuit_components/planta.svg',
      iconoDiagrama: 'assets/components/planta.svg',
      descripcion: 'Planta diésel de emergencia',
    ),
    ComponenteElectrico(
      id: 'inversor',
      nombre: 'Inversor',
      categoria: CategoriaComponente.generacion,
      iconoCircuito: 'assets/circuit_components/inversor.svg',
      iconoDiagrama: 'assets/components/inversor.svg',
      descripcion: 'Inversor DC/AC',
    ),
    ComponenteElectrico(
      id: 'panel_solar',
      nombre: 'Panel solar',
      categoria: CategoriaComponente.generacion,
      iconoCircuito: 'assets/circuit_components/panel_solar.svg',
      iconoDiagrama: 'assets/components/panel_solar.svg',
      descripcion: 'Panel fotovoltaico',
    ),
    ComponenteElectrico(
      id: 'caja_control',
      nombre: 'Caja de Control',
      categoria: CategoriaComponente.cajas,
      iconoCircuito: 'assets/circuit_components/caja_control.svg',
      iconoDiagrama: 'assets/components/caja_control.svg',
      descripcion: 'Enclosure / caja para agrupar componentes de control',
    ),
  ];

  static List<ComponenteElectrico> porCategoria(CategoriaComponente cat) {
    if (cat == CategoriaComponente.todos) return catalogo;
    return catalogo.where((c) => c.categoria == cat).toList();
  }
}
