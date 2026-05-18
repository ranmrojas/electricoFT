/// Tipo de corriente del componente o la fuente.
enum TipoCorriente { ac, dc }

extension TipoCorrienteLabel on TipoCorriente {
  String get label => this == TipoCorriente.ac ? 'AC' : 'DC';
}

/// Parámetros eléctricos configurables de una instancia de componente.
///
/// Cada [ComponenteEnCanvas] tiene su propio objeto [PropiedadesElectricas],
/// independiente del catálogo. El usuario puede modificarlos desde el canvas.
class PropiedadesElectricas {
  PropiedadesElectricas({
    this.tipoCorriente = TipoCorriente.ac,
    this.voltajeNominal = 120.0,
    this.potencia,
    this.corrienteMax,
    this.frecuencia = 60.0,
    this.cerrado = true,
    this.relacionTransf = 1.0,
    this.capacidadAh,
    this.factorPotencia = 1.0,
  });

  /// AC o DC.
  TipoCorriente tipoCorriente;

  /// Voltaje nominal (V). Para fuentes: lo que entrega. Para cargas: voltaje requerido.
  double voltajeNominal;

  /// Potencia nominal (W). Para cargas. null si no aplica.
  double? potencia;

  /// Corriente máxima (A). Para fuentes y protecciones.
  double? corrienteMax;

  /// Frecuencia (Hz). Solo relevante para AC.
  double? frecuencia;

  /// Estado del contacto: true = cerrado (conduce). Para interruptores y breakers.
  bool cerrado;

  /// Relación de transformación Vs/Vp. Para transformadores e inversores.
  double relacionTransf;

  /// Capacidad en amperios-hora. Para baterías y paneles solares.
  double? capacidadAh;

  /// Factor de potencia (cos φ). 1.0 para cargas resistivas puras.
  double factorPotencia;

  // ── Valores calculados ───────────────────────────────────────────────────

  /// Corriente nominal de la carga: I = P / (V × cos φ).
  double get corrienteNominal {
    final p = potencia;
    if (p == null || p == 0 || voltajeNominal == 0) return 0;
    return p / (voltajeNominal * factorPotencia);
  }

  /// Resistencia equivalente de la carga: R = V² / P.
  double get resistenciaEquivalente {
    final p = potencia;
    if (p == null || p == 0) return double.infinity;
    return (voltajeNominal * voltajeNominal) / p;
  }

  // ── Defaults por tipo de componente ─────────────────────────────────────

  static PropiedadesElectricas defaultsPara(String tipoId) {
    switch (tipoId) {
      case 'bateria':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.dc,
          voltajeNominal: 12.0,
          corrienteMax: 20.0,
          capacidadAh: 100.0,
        );
      case 'panel_solar':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.dc,
          voltajeNominal: 24.0,
          corrienteMax: 8.0,
        );
      case 'generador':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 30.0,
          frecuencia: 60.0,
        );
      case 'planta':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 60.0,
          frecuencia: 60.0,
        );
      case 'inversor':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 15.0,
          frecuencia: 60.0,
          relacionTransf: 1.0,
        );
      case 'transformador':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 10.0,
          relacionTransf: 1.0,
        );
      case 'bombilla':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          potencia: 60.0,
        );
      case 'resistencia':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          potencia: 100.0,
        );
      case 'toma':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          potencia: 500.0,
          corrienteMax: 15.0,
        );
      case 'condensador':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          potencia: 0.0,
          factorPotencia: 0.0,
        );
      case 'breaker':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 20.0,
          cerrado: true,
        );
      case 'fusible':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 15.0,
          cerrado: true,
        );
      case 'interruptor':
        return PropiedadesElectricas(
          cerrado: false,
        );
      case 'medidor':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 30.0,
          cerrado: true,
        );
      case 'tablero':
        return PropiedadesElectricas(
          tipoCorriente: TipoCorriente.ac,
          voltajeNominal: 120.0,
          corrienteMax: 100.0,
          cerrado: true,
        );
      case 'nodo':
      case 'caja_control':
      default:
        return PropiedadesElectricas();
    }
  }

  PropiedadesElectricas copyWith({
    TipoCorriente? tipoCorriente,
    double? voltajeNominal,
    double? potencia,
    double? corrienteMax,
    double? frecuencia,
    bool? cerrado,
    double? relacionTransf,
    double? capacidadAh,
    double? factorPotencia,
  }) =>
      PropiedadesElectricas(
        tipoCorriente: tipoCorriente ?? this.tipoCorriente,
        voltajeNominal: voltajeNominal ?? this.voltajeNominal,
        potencia: potencia ?? this.potencia,
        corrienteMax: corrienteMax ?? this.corrienteMax,
        frecuencia: frecuencia ?? this.frecuencia,
        cerrado: cerrado ?? this.cerrado,
        relacionTransf: relacionTransf ?? this.relacionTransf,
        capacidadAh: capacidadAh ?? this.capacidadAh,
        factorPotencia: factorPotencia ?? this.factorPotencia,
      );
}
