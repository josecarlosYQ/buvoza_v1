# BuVoza

App Flutter local para registrar informes de ambulancia SAMU con dictado por voz y PDF.

## Roles

- **Conductor**: bitácora de servicio, acta de conformidad mecánica y registro de horas de la emergencia.
- **Médico**: SOAPIE, consumo de oxígeno, temperatura de almacén y acta mecánica (médico entrante).
- **Enfermería**: los cinco formatos SAMU.

## Formatos SAMU (plantillas .xlsx y formatos impresos del conductor)

| Formato | Se registra | Reporte PDF |
|---|---|---|
| Bitácora de servicio | Inicio/fin de turno, km y recorridos (importables del registro de horas) | Hoja por turno con firmas |
| Acta de conformidad mecánica | 120 ítems SI/NO/F · OPE/INOP/F, km y combustible | Hoja por relevo con firmas |
| Registro de horas de la emergencia | Salida, foco, hospital, base, motivo y servicio; empalmes | Hoja por turno (horizontal) |
| Registro SOAPIE | Por paciente (turno M/T/MT/N) | Una hoja por paciente con firma |
| Entrega de turno | Checklist de 7 áreas por turno M/T/N | Cuadrícula quincenal OK/F + detalle de faltas |
| Procedimientos | Contadores por turno D/N (44 procedimientos) | Cuadrícula quincenal con totales (3 hojas) |
| Consumo de oxígeno | Consumo/trasegado/stock en PSI por balón | Cuadrícula quincenal + conversión a litros |
| Temperatura de almacén | Ingreso/salida: hora, °C y confort | Tabla mensual con lecturas fuera de rango |

Los registros se guardan como JSON en `Documentos/BuVoza/registros/` y los PDF en
`Documentos/BuVoza/informes/` (visibles en «Informes guardados»). Los datos de cabecera
(SAMU, base, distrito, ambulancia, personal habitual y balones de oxígeno) se configuran en
**Ajustes de la base** (icono ⚙ en Médico/Enfermería).

## Desarrollo

```
flutter pub get
flutter analyze
flutter test
flutter run
```
