# Modelo de datos

El modelo se construyó en tres niveles. Todos los diagramas usan notación de «pata de gallo» (*crow's foot*): `||` exactamente uno, `|o` cero o uno, `|{` uno o muchos, `o{` cero o muchos.

| Nivel | Pregunta que responde | Archivo editable | Exportación |
|---|---|---|---|
| Conceptual | ¿Qué cosas del negocio hay que recordar y cómo se relacionan? | `diagramas/conceptual.mmd` | `.png`, `.svg`, `.pdf` |
| Lógico (relacional, 3FN) | ¿Qué relaciones, claves primarias y foráneas resultan, independientemente del motor? | `diagramas/logico_red_vuelos.mmd`, `logico_flota_tripulacion.mmd`, `logico_personas_tiquetes.mmd`, `logico_precios_pagos.mmd` | `.png`, `.svg`, `.pdf` |
| Físico (SQL Server) | ¿Qué tablas, tipos, nulabilidad y restricciones existen realmente en la base? | `diagramas/fisico_*.mmd` (**generados** desde el catálogo) | `.png`, `.svg`, `.pdf` |

Los `.mmd` son la fuente editable: texto Mermaid que GitHub muestra como diagrama y que draw.io puede importar (*Organizar → Insertar → Avanzado → Mermaid*). Las exportaciones PNG, SVG y PDF las genera `python -m aerolinea documentar` con **Graphviz** a partir del mismo `.mmd` (`src/aerolinea/diagramas.py`, que también guarda el `.dot`): Graphviz produce diagramas mucho más compactos que el renderizador de Mermaid, cuyo texto quedaba en 2-4 pt al imprimirlo. Si Graphviz no está instalado se recurre a `mermaid-cli`. Los diagramas físicos son amplios: en papel sirven de vista general y para el detalle conviene abrir el SVG o el PDF y ampliar.

## Nivel conceptual

Simplificaciones deliberadas respecto del modelo lógico, para que el diagrama se lea en una diapositiva:

- `AEROPUERTO`–`RUTA` muestra una sola relación; en el modelo lógico son dos (origen y destino).
- La tripulación aparece como relación muchos a muchos `EMPLEADO`–`VUELO`; en el modelo lógico es la entidad asociativa `ASIGNACION_TRIPULACION`, que guarda el rol.
- Los días de operación (atributo multivaluado de `PROGRAMACION`), el modelo de avión y el mapa de asientos (parte de `CONFIGURACION`) se omiten.
- `CUPO_CABINA` (la capacidad de una cabina en un vuelo concreto) se muestra porque es la clave para explicar cómo se evita la sobreventa.

## Nivel lógico

Cuatro áreas temáticas para que cada diagrama sea legible a tamaño de página (red y vuelos; flota y tripulación; personas, compras y tiquetes; precios, pagos y reembolsos). Las entidades de otra área aparecen solo con su clave. Se omiten los tipos genéricos y los nombres de las FK, que ya se marcan en los atributos. Las decisiones de normalización y las desnormalizaciones controladas están en [`normalizacion.md`](normalizacion.md).

## Nivel físico y diccionario de datos

Generados por `python -m aerolinea documentar` a partir del catálogo del motor (`sys.tables`, `sys.columns`, `sys.foreign_keys`, `sys.check_constraints`, `sys.indexes`, `sys.masked_columns`) y de las definiciones de negocio de `definiciones_atributos.csv`. Así el diccionario y los diagramas coinciden con el código por construcción.

| Archivo | Contenido |
|---|---|
| `diccionario_datos.md` | Por tabla: columna, tipo, nulabilidad, valor por defecto, claves, restricciones `CHECK`, notas (identidad, calculada, enmascarada), definición y dominio |
| `diccionario_datos.csv` / `.xlsx` | Lo mismo en formato tabular (separador `;`, UTF-8) |
| `../../sql/13_descripciones.sql` | Las definiciones como propiedades extendidas `MS_Description`, visibles en SSMS (*Propiedades* de tabla o columna) |
| `diagramas/fisico_red_operaciones.*` | Red, flota, vuelos y tripulación |
| `diagramas/fisico_ventas.*` | Personas, compras, tiquetes, tarifas, pagos y reembolsos |
| `diagramas/fisico_catalogos_control.*` | Estados, transiciones, parámetros y control |

El esquema `stg` (área de carga) se excluye del diccionario y de los diagramas porque no forma parte del modelo de negocio.
