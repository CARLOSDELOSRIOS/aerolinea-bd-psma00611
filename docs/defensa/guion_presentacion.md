# Guion de la presentación (20 minutos, 14 diapositivas)

Archivo: `slides/presentacion_PSMA00611.pptx` (se regenera con `cd slides; npm ci; node construir_presentacion.js`; las cifras salen de `reports/resultados/` y `evidence/`). Cada diapositiva tiene sus notas del expositor en PowerPoint (*Vista → Notas*).

**Asignación de expositores:** según las guías del curso (F3 p. 23, F4 p. 22), *todos los miembros exponen de forma aleatoria*. Por eso este guion **no asigna diapositivas a personas**: cualquier integrante debe poder tomar la palabra en cualquier diapositiva. La preparación común está en `guia_estudio_comun.md`. [POR COMPLETAR por el equipo: si el docente indica otra modalidad, registrar aquí la asignación real].

## Distribución del tiempo

| # | Diapositiva | Mensaje central (una frase) | Tiempo | Acumulado |
|---|---|---|---|---|
| 1 | Portada | Una base de datos que garantiza sus reglas y se reconstruye con un comando; datos sintéticos; nube pendiente | 0:30 | 0:30 |
| 2 | Un error en estos datos lo nota el pasajero | Tres riesgos guían el diseño; cinco objetivos específicos | 1:30 | 2:00 |
| 3 | Seis decisiones que resolvieron la ambigüedad | Pasajero ≠ comprador, horario ≠ vuelo, precio histórico, un descuento, pagos parciales, zonas horarias | 1:30 | 3:30 |
| 4 | Arquitectura | Las reglas viven en el motor; Python automatiza; mismo T-SQL en local y Azure | 1:15 | 4:45 |
| 5 | Modelo conceptual | 19 entidades alrededor del tiquete; el cupo por cabina es la clave de la sobreventa | 1:30 | 6:15 |
| 6 | Normalización | 3FN con seis redundancias justificadas, cada una con su control | 1:30 | 7:45 |
| 7 | Integridad | 70 CHECK, 53 FK, 6 índices únicos filtrados, 12 triggers: 42 reglas en el motor | 1:15 | 9:00 |
| 8 | Concurrencia | 12 de 40, 1 de 20, 1 de 10, 30 de 30: sesiones simultáneas reales sin anomalías | 1:30 | 10:30 |
| 9 | Implementación reproducible | Scripts → datos → carga transaccional → consultas → gráficos, con un comando | 1:15 | 11:45 |
| 10 | Demostración en vivo | Atomicidad, pago en dos partes, cancelación, consulta parametrizada | 2:30 | 14:15 |
| 11 | Resultados | Ventas, cobros y reembolsos son distintas; la caja cuadra al centavo | 1:45 | 16:00 |
| 12 | Pruebas | 27 de 27 y 20 defectos reales corregidos | 1:15 | 17:15 |
| 13 | Nube y limitaciones | Azure preparado pero no desplegado; límites declarados | 1:15 | 18:30 |
| 14 | Conclusiones y próximos pasos | Una conclusión por objetivo; laptop, Azure y GitHub como siguientes pasos | 1:30 | **20:00** |

Margen: si la demostración se alarga, recortar de las diapositivas 6 y 11 (se pueden resumir en 45 s cada una). No recortar la 13: declarar lo pendiente es parte del criterio de honestidad del informe.

## Transiciones sugeridas

- 2 → 3: «Para evitar esos errores, primero hubo que decidir qué significa cada concepto».
- 4 → 5: «Con la arquitectura clara, veamos qué guardamos».
- 6 → 7: «El modelo es correcto en papel; ahora, ¿cómo obliga la base a respetarlo?».
- 8 → 9: «Todo esto se reconstruye desde cero con un comando, y lo mostramos en vivo».
- 10 → 11: «Con datos cargados, ¿qué nos dicen las consultas?».
- 12 → 13: «Y ahora, lo que falta».

## Reglas para quien expone

1. Decir siempre que los datos son sintéticos cuando se cite una cifra de negocio.
2. No afirmar que el requisito de nube está cumplido.
3. Citar cifras solo de las diapositivas o de `reports/resultados/`; si no se sabe un número, decir dónde está.
4. Ante una pregunta difícil: responder la parte que se conoce, señalar el archivo donde está el detalle y ofrecer completarlo por escrito.
