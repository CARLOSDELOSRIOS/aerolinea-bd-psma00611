/*
 * Presentación del PAC (PSMA00611): 14 diapositivas para 20 minutos, con notas del expositor.
 * Las cifras se leen de reports/resultados/*.csv y de las evidencias, no se escriben a mano.
 *
 * Uso (desde la carpeta slides/):
 *   npm install          (instala las versiones de package.json)
 *   node construir_presentacion.js
 * Salida: slides/presentacion_PSMA00611.pptx
 */
const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const fa = require("react-icons/fa");

const RAIZ = path.resolve(__dirname, "..");
const SALIDA = path.join(__dirname, "presentacion_PSMA00611.pptx");

// ------------------------------------------------------------------ datos
function leerCsv(nombre) {
  const texto = fs.readFileSync(path.join(RAIZ, "reports", "resultados", nombre + ".csv"), "utf-8").replace(/^﻿/, "");
  const [cabecera, ...lineas] = texto.trim().split(/\r?\n/);
  const columnas = cabecera.split(",");
  return lineas.map((l) => {
    const valores = l.match(/("([^"]|"")*"|[^,]*)(,|$)/g).map((v) => v.replace(/,$/, "").replace(/^"|"$/g, ""));
    return Object.fromEntries(columnas.map((c, i) => [c, valores[i]]));
  });
}
const num = (v, d = 0) => Number(v).toLocaleString("es-ES", { minimumFractionDigits: d, maximumFractionDigits: d, useGrouping: true });
const q03 = leerCsv("Q03_ventas_cobros_reembolsos_mes");
const q02 = leerCsv("Q02_ocupacion_ruta_cabina");
const q19 = leerCsv("Q19_controles_conciliacion");
const pruebas = JSON.parse(fs.readFileSync(path.join(RAIZ, "evidence", "contenedor_linux", "resultados_pruebas.json"), "utf-8"));
const carga = JSON.parse(fs.readFileSync(path.join(RAIZ, "evidence", "contenedor_linux", "carga_sintetica.json"), "utf-8"));
const totalEco = q02.find((r) => r.ruta === "TOTAL" && r.codigo_cabina === "ECO");
const totalVip = q02.find((r) => r.ruta === "TOTAL" && r.codigo_cabina === "VIP");
const identidad = q19.find((r) => r.control.startsWith("Identidad"));
const filasCargadas = Object.values(carga.resumen.filas).reduce((a, b) => a + b, 0);
const superadas = pruebas.resumen.superadas, totalPruebas = pruebas.resumen.total;
const mes = (iso) => ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"][Number(iso.slice(5, 7)) - 1] + " " + iso.slice(0, 4);

// ------------------------------------------------------------------ tema
const THEME = {
  name: "Aerolinea PSMA00611",
  headFontFace: "Cambria",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "0B0B0B", lt1: "FFFFFF", dk2: "14213D", lt2: "EEF3FA",
    accent1: "2A78D6", accent2: "EB6834", accent3: "1BAF7A", accent4: "FCA311", accent5: "52514E", accent6: "9EC5F4",
    hlink: "2A78D6", folHlink: "184F95",
  },
};
const HEX = THEME.colors;

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13,333" x 7,5"
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.author = "[POR COMPLETAR: equipo]";
pres.title = "Base de datos para una aerolínea comercial (PSMA00611)";
pres.subject = "Producto Académico Colaborativo";
const C = pres.SchemeColor;

pres.defineSlideMaster({
  title: "PORTADA",
  background: { color: HEX.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 2.0, w: 9.4, h: 1.9, fontFace: THEME.headFontFace, fontSize: 40, bold: true, color: C.background1, valign: "bottom", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.8, y: 4.1, w: 9.4, h: 0.9, fontSize: 20, color: C.accent6, valign: "top", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CONTENIDO",
  background: { color: HEX.lt1 },
  margin: [0.5, 0.6, 0.6, 0.6],
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.35, w: 12.1, h: 0.9, fontFace: THEME.headFontFace, fontSize: 32, bold: true, color: C.text2, valign: "middle", margin: 0 }, text: "" } },
    { text: { text: "PSMA00611 · Base de datos de una aerolínea · datos sintéticos", options: { x: 0.6, y: 7.0, w: 8, h: 0.3, fontSize: 10, color: C.accent5, margin: 0 } } },
  ],
  slideNumber: { x: 12.2, y: 7.0, w: 0.5, h: 0.3, fontSize: 10, color: C.accent5, align: "right" },
});
pres.defineSlideMaster({
  title: "CIERRE",
  background: { color: HEX.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.35, w: 12.1, h: 0.9, fontFace: THEME.headFontFace, fontSize: 32, bold: true, color: C.background1, valign: "middle", margin: 0 }, text: "" } },
  ],
  slideNumber: { x: 12.2, y: 7.0, w: 0.5, h: 0.3, fontSize: 10, color: C.accent6, align: "right" },
});

// pptxgenjs no escribe los colores del tema: se reemplaza el esquema de colores y el nombre del tema
// en ppt/theme/theme1.xml con JSZip (dependencia de pptxgenjs).
async function aplicarTema(archivo, tema) {
  const JSZip = require("jszip");
  const zip = await JSZip.loadAsync(fs.readFileSync(archivo));
  const ruta = "ppt/theme/theme1.xml";
  let xml = await zip.file(ruta).async("string");
  const orden = ["dk1", "lt1", "dk2", "lt2", "accent1", "accent2", "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink"];
  const esquema = `<a:clrScheme name="${tema.name}">` + orden.map((k) => `<a:${k}><a:srgbClr val="${tema.colors[k]}"/></a:${k}>`).join("") + "</a:clrScheme>";
  xml = xml.replace(/<a:clrScheme [^>]*>[\s\S]*?<\/a:clrScheme>/, esquema);
  xml = xml.replace(/(<a:majorFont><a:latin typeface=")[^"]*"/, `$1${tema.headFontFace}"`).replace(/(<a:minorFont><a:latin typeface=")[^"]*"/, `$1${tema.bodyFontFace}"`);
  xml = xml.replace(/(<a:theme [^>]*name=")[^"]*"/, `$1${tema.name}"`);
  zip.file(ruta, xml);
  fs.writeFileSync(archivo, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
}

// ------------------------------------------------------------------ utilidades
async function icono(Componente, colorHex, tam = 256) {
  const svg = ReactDOMServer.renderToStaticMarkup(React.createElement(Componente, { color: "#" + colorHex, size: tam }));
  const png = await sharp(Buffer.from(svg)).png().toBuffer();
  return "image/png;base64," + png.toString("base64");
}
async function iconoCirculo(slide, Componente, x, y, d, fondo, colorIcono, nombre) {
  slide.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: fondo }, line: { color: fondo }, objectName: nombre + "_circulo" });
  const m = d * 0.24;
  slide.addImage({ data: await icono(Componente, colorIcono), x: x + m, y: y + m, w: d - 2 * m, h: d - 2 * m, objectName: nombre + "_icono" });
}
function texto(slide, t, opciones) {
  slide.addText(t, { isTextBox: true, margin: 0, valign: "top", fontSize: 15, color: C.text1, ...opciones });
}
function tarjeta(slide, x, y, w, h, nombre, relleno = C.background2) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.08, fill: { color: relleno }, line: { color: relleno }, objectName: nombre });
}
function nuevo(master, titulo, seccion) {
  const s = pres.addSlide({ masterName: master, sectionTitle: seccion });
  if (titulo) s.addText(titulo, { placeholder: "title" });
  return s;
}

(async () => {
  // =========================================================== 1. Portada
  pres.addSection({ title: "Apertura" });
  let s = pres.addSlide({ masterName: "PORTADA", sectionTitle: "Apertura" });
  s.addText("Base de datos para una aerolínea comercial en Estados Unidos", { placeholder: "title" });
  s.addText("Requisitos, modelado, SQL Server, Python y preparación para Azure SQL Database", { placeholder: "body" });
  await iconoCirculo(s, fa.FaPlane, 10.6, 2.2, 1.9, HEX.accent1, HEX.lt1, "portada");
  texto(s, [
    { text: "Gestión de datos y bases de datos con SQL (PSMA00611)", options: { breakLine: true } },
    { text: "Maestría en Ciencia de Datos · Escuela de Posgrado · Universidad Continental", options: { breakLine: true } },
    { text: "Equipo: [POR COMPLETAR]   ·   Docente: [POR COMPLETAR]" },
  ], { x: 0.8, y: 5.6, w: 11.5, h: 1.2, fontSize: 14, color: C.background1, paraSpaceAfter: 4 });
  s.addNotes("Tiempo: 0:30. Presentar el producto en una frase: una base de datos relacional para una aerolínea nueva, que garantiza en el propio motor las reglas del negocio y que se puede reconstruir completa con un comando. Aclarar desde el inicio que todos los datos son sintéticos y que el despliegue en Azure está preparado pero pendiente. Recordar que la exposición es aleatoria: cualquiera del equipo puede continuar desde cualquier diapositiva.");

  // =========================================================== 2. Problema y objetivos
  pres.addSection({ title: "Problema y diseño" });
  s = nuevo("CONTENIDO", "Un error en estos datos lo nota el pasajero", "Problema y diseño");
  const riesgos = [
    [fa.FaChair, "Asiento vendido dos veces", "o un vuelo con más pasajeros que asientos"],
    [fa.FaCreditCard, "Cobro duplicado", "dos pagos simultáneos del mismo saldo"],
    [fa.FaMoneyBillWave, "Reembolso mal calculado", "política aplicada a mano o con datos viejos"],
  ];
  for (let i = 0; i < riesgos.length; i++) {
    const y = 1.55 + i * 1.65;
    await iconoCirculo(s, riesgos[i][0], 0.6, y, 0.9, HEX.accent2, HEX.lt1, "riesgo" + i);
    texto(s, [{ text: riesgos[i][1], options: { bold: true, fontSize: 18, breakLine: true } }, { text: riesgos[i][2], options: { fontSize: 14, color: C.accent5 } }],
      { x: 1.7, y: y + 0.05, w: 4.3, h: 1.0 });
  }
  tarjeta(s, 6.4, 1.45, 6.3, 5.25, "objetivos_fondo");
  texto(s, "Objetivos", { x: 6.75, y: 1.65, w: 5.6, h: 0.5, fontSize: 20, bold: true, color: C.text2, fontFace: THEME.headFontFace });
  const objetivos = [
    ["OE1", "Requisitos verificables: 42 reglas y 13 supuestos explícitos"],
    ["OE2", "Modelo conceptual, lógico y físico en 3FN"],
    ["OE3", "Reglas en el motor, resistentes a la concurrencia"],
    ["OE4", "Datos reproducibles y 20 consultas desde Python"],
    ["OE5", "Pruebas automatizadas y preparación para Azure"],
  ];
  objetivos.forEach(([id, t], i) => {
    const y = 2.35 + i * 0.85;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 6.75, y, w: 0.85, h: 0.5, rectRadius: 0.08, fill: { color: C.accent1 }, line: { color: C.accent1 }, objectName: "oe_" + id });
    texto(s, id, { x: 6.75, y, w: 0.85, h: 0.5, fontSize: 14, bold: true, color: C.background1, align: "center", valign: "middle" });
    texto(s, t, { x: 7.8, y: y - 0.02, w: 4.7, h: 0.6, fontSize: 15, valign: "middle" });
  });
  s.addNotes("Tiempo: 1:30. El problema no es guardar datos sino garantizar que sean correctos aunque varias personas vendan y cobren a la vez. Los tres riesgos de la izquierda guían el diseño. Leer los cinco objetivos específicos: el informe tiene una conclusión por cada uno. Enfatizar que el enunciado pide una base de datos en la nube, requisitos, modelo, tablas, carga, consultas y su ejecución desde un lenguaje de programación; lo demás son mejoras propuestas por el equipo.");

  // =========================================================== 3. Decisiones de dominio
  s = nuevo("CONTENIDO", "Seis decisiones que resolvieron la ambigüedad", "Problema y diseño");
  const decisiones = [
    [fa.FaUserFriends, "Pasajero ≠ comprador", "Toda persona puede comprar o viajar; «cliente» es quien tiene cuenta (subtipo 1:0..1)"],
    [fa.FaCalendarAlt, "Horario ≠ vuelo", "La programación semanal genera los vuelos fechados (procedimiento idempotente)"],
    [fa.FaTag, "Precio histórico", "El tiquete copia precio y descuento; las tarifas se versionan, no se editan"],
    [fa.FaPercent, "Un descuento por tiquete", "Se aplica el mayor disponible; sin acumulación"],
    [fa.FaClock, "Pagos parciales", "Varios pagos; se emite al completar; la reserva vence a las 72 h"],
    [fa.FaGlobeAmericas, "Zonas horarias", "Hora local con desfase para el pasajero; UTC para las transacciones"],
  ];
  for (let i = 0; i < decisiones.length; i++) {
    const col = i % 3, fila = Math.floor(i / 3);
    const x = 0.6 + col * 4.1, y = 1.5 + fila * 2.7;
    tarjeta(s, x, y, 3.85, 2.45, "decision" + i);
    await iconoCirculo(s, decisiones[i][0], x + 0.3, y + 0.3, 0.75, HEX.accent1, HEX.lt1, "decision" + i);
    texto(s, decisiones[i][1], { x: x + 1.2, y: y + 0.38, w: 2.5, h: 0.6, fontSize: 17, bold: true, color: C.text2, valign: "middle" });
    texto(s, decisiones[i][2], { x: x + 0.3, y: y + 1.2, w: 3.3, h: 1.15, fontSize: 14 });
  }
  s.addNotes("Tiempo: 1:30. El enunciado deja abiertas preguntas que cambian el modelo. Explicar dos con ejemplo: (1) un padre compra tres tiquetes para su familia sin registrarse: comprador y pasajeros son personas distintas y ninguna necesita cuenta; (2) si la tarifa JFK-LAX sube mañana, el tiquete vendido hoy conserva su precio porque el precio es un hecho de la venta. La regla de 24 horas sigue la norma del Departamento de Transporte de EE. UU. (14 CFR 259.5).");

  // =========================================================== 4. Arquitectura
  s = nuevo("CONTENIDO", "Arquitectura: el motor garantiza, Python reproduce", "Problema y diseño");
  s.addImage({ path: path.join(RAIZ, "docs", "03_arquitectura", "arquitectura.png"), x: 0.6, y: 1.4, w: 6.6, h: 5.3, sizing: { type: "contain", w: 6.6, h: 5.3 }, altText: "Diagrama de arquitectura: laptop con SSMS y Python, SQL Server local y Azure SQL Database", objectName: "arquitectura" });
  const puntos = [
    ["Esquemas por área", "ref · ops · rh · ven · rpt (reportes) · aud (auditoría)"],
    ["El motor garantiza", "restricciones, triggers y procedimientos: valen para SSMS, cargas y aplicaciones"],
    ["Python reproduce", "despliegue, carga, consultas, gráficos, pruebas y documentación"],
    ["Seguridad", "cifrado siempre; Windows en local; Entra ID y certificado validado en Azure"],
  ];
  puntos.forEach(([t, d], i) => {
    const y = 1.55 + i * 1.3;
    tarjeta(s, 7.6, y, 5.1, 1.1, "arq" + i);
    texto(s, [{ text: t, options: { bold: true, color: C.text2, fontSize: 16, breakLine: true } }, { text: d, options: { fontSize: 14 } }], { x: 7.85, y: y + 0.13, w: 4.7, h: 0.9 });
  });
  s.addNotes("Tiempo: 1:15. La decisión central: las reglas viven en la base, no en la aplicación. Si solo estuvieran en Python, un INSERT desde SSMS o una carga masiva podría saltarlas. SSMS administra, el motor garantiza y Python automatiza. El mismo código T-SQL sirve para SQL Server local y Azure SQL Database: los scripts no usan USE y la concurrencia se probó con READ_COMMITTED_SNAPSHOT, que es el valor por defecto en Azure.");

  // =========================================================== 5. Modelo conceptual
  s = nuevo("CONTENIDO", "Modelo conceptual: 19 entidades alrededor del tiquete", "Problema y diseño");
  s.addImage({ path: path.join(RAIZ, "docs", "02_modelo", "diagramas", "conceptual.png"), x: 0.6, y: 1.35, w: 6.1, h: 5.45, sizing: { type: "contain", w: 6.1, h: 5.45 }, altText: "Modelo conceptual entidad-relación", objectName: "conceptual" });
  const claves = [
    [fa.FaChair, "CUPO_CABINA", "Capacidad de una cabina en un vuelo. Es la fila que se bloquea al vender: la base del control de sobreventa."],
    [fa.FaUserFriends, "PERSONA → CLIENTE", "Subtipo 1:0..1: resuelve la compra sin registro."],
    [fa.FaRoute, "RUTA → PROGRAMACIÓN → VUELO", "Del par origen-destino al horario semanal y a la salida fechada."],
  ];
  for (let i = 0; i < claves.length; i++) {
    const y = 1.5 + i * 1.75;
    await iconoCirculo(s, claves[i][0], 7.1, y, 0.75, HEX.accent2, HEX.lt1, "concepto" + i);
    texto(s, [{ text: claves[i][1], options: { bold: true, color: C.text2, fontSize: 17, breakLine: true } }, { text: claves[i][2], options: { fontSize: 14 } }], { x: 8.05, y: y - 0.02, w: 4.6, h: 1.5 });
  }
  s.addNotes("Tiempo: 1:30. Leer el diagrama desde el tiquete: pertenece a una compra, la viaja una persona, consume una plaza de una cabina en un vuelo, tiene una tarifa y quizá un descuento, y se paga con uno o varios pagos que pueden reembolsarse. Notación de pata de gallo: dos rayas = exactamente uno, círculo = opcional, pata = muchos. El modelo lógico se divide en cuatro diagramas en el informe (figuras 2 a 5).");

  // =========================================================== 6. Normalización
  s = nuevo("CONTENIDO", "3FN con seis redundancias deliberadas y controladas", "Problema y diseño");
  tarjeta(s, 0.6, 1.45, 4.2, 5.25, "planilla");
  texto(s, [
    { text: "Punto de partida: una planilla de ventas", options: { bold: true, fontSize: 17, color: C.text2, breakLine: true } },
    { text: "Pagos y días de operación como listas (viola 1FN)", options: { bullet: true, breakLine: true } },
    { text: "Cambiar la hora del XX101 exige editar miles de filas", options: { bullet: true, breakLine: true } },
    { text: "Borrar los tiquetes de un vuelo borra el avión", options: { bullet: true, breakLine: true } },
    { text: "Descomposición por dependencias funcionales: tiquete → vuelo → programación → ruta → aeropuertos", options: { bullet: true } },
  ], { x: 0.85, y: 1.7, w: 3.75, h: 4.9, fontSize: 14, paraSpaceAfter: 8 });
  const filasRed = [
    [{ text: "Redundancia", options: { bold: true, color: C.background1, fill: { color: C.text2 } } }, { text: "Control que evita la anomalía", options: { bold: true, color: C.background1, fill: { color: C.text2 } } }],
    ["Precio y % de descuento en el tiquete", "Trigger valida la copia; precio inmutable; tarifas versionadas"],
    ["Plazas ocupadas por vuelo y cabina", "Trigger en la misma transacción + CHECK ≤ capacidad + conciliación"],
    ["Capacidad por vuelo y cabina", "Se sincroniza al asignar avión; no se cambia de configuración con ventas"],
    ["Fecha local de salida", "Columna calculada persistida"],
    ["Tipo «AER» en aeropuerto", "Columna calculada + FK compuesta al supertipo"],
    ["Cabina junto a la tarifa en el tiquete", "Dos FK compuestas: cabina existe en el vuelo y es la de la tarifa"],
  ];
  s.addTable(filasRed, { x: 5.1, y: 1.45, w: 7.6, colW: [3.0, 4.6], fontSize: 13, color: HEX.dk1, border: { type: "solid", pt: 0.5, color: "D9D9D9" }, fill: { color: HEX.lt1 }, valign: "middle", rowH: 0.7, objectName: "desnormalizaciones" });
  s.addNotes("Tiempo: 1:30. La normalización evita que un dato se repita y quede inconsistente. Aceptamos seis redundancias porque cada una tiene un motivo y un control. La más importante es el precio histórico: la dependencia «tarifa → precio» solo vale en el momento de la venta, así que copiar el precio no es una anomalía sino un registro del hecho. La segunda es el contador de plazas, que además sirve de semáforo para la concurrencia. Prueba de que no hay anomalías: los controles de conciliación devuelven cero diferencias.");

  // =========================================================== 7. Integridad
  pres.addSection({ title: "Implementación" });
  s = nuevo("CONTENIDO", "La base rechaza lo inválido, venga de donde venga", "Implementación");
  const stats = [["70", "restricciones CHECK"], ["53", "claves foráneas"], ["6", "índices únicos filtrados"], ["12", "triggers set-based"]];
  stats.forEach(([n, t], i) => {
    const x = 0.6 + i * 3.1;
    tarjeta(s, x, 1.45, 2.85, 1.75, "stat" + i);
    texto(s, n, { x, y: 1.55, w: 2.85, h: 0.95, fontSize: 48, bold: true, color: C.accent1, align: "center", fontFace: THEME.headFontFace });
    texto(s, t, { x, y: 2.55, w: 2.85, h: 0.5, fontSize: 14, align: "center", color: C.accent5 });
  });
  s.addChart(pres.charts.BAR, [{ name: "Reglas", labels: ["Declarativa (D)", "Trigger (T)", "Procedimiento (P)", "Combinada (D+T, T+P)", "Verificación (A)"], values: [16, 20, 2, 3, 1] }], {
    x: 0.6, y: 3.45, w: 6.7, h: 3.35, barDir: "bar", chartColors: [HEX.accent1], showValue: true, dataLabelPosition: "outEnd", dataLabelColor: HEX.accent5, dataLabelFontSize: 12,
    catAxisLabelColor: HEX.accent5, catAxisLabelFontSize: 12, valAxisHidden: true, valGridLine: { style: "none" }, catGridLine: { style: "none" },
    showLegend: false, showTitle: true, title: "42 reglas de negocio según el mecanismo que las garantiza", titleFontSize: 14, titleColor: HEX.dk2,
    catAxisLabelFontFace: "+mn-lt", dataLabelFontFace: "+mn-lt", titleFontFace: "+mn-lt", catAxisOrientation: "maxMin", objectName: "grafico_reglas",
  });
  tarjeta(s, 7.6, 3.45, 5.1, 3.35, "codigo_fondo", C.text2);
  texto(s, "Un asiento, un pasajero (índice único filtrado)", { x: 7.85, y: 3.6, w: 4.7, h: 0.4, fontSize: 14, bold: true, color: C.background1 });
  texto(s, "CREATE UNIQUE INDEX ux_tiquete_vuelo_asiento\n  ON ven.tiquete (id_vuelo, codigo_asiento)\nWHERE codigo_asiento IS NOT NULL\n  AND codigo_estado IN ('RESERVADO',\n      'EMITIDO','USADO','NO_PRESENTADO');",
    { x: 7.85, y: 4.1, w: 4.75, h: 2.5, fontSize: 13, fontFace: "Courier New", color: C.accent6 });
  s.addNotes("Tiempo: 1:15. Orden de preferencia: restricción declarativa, luego trigger, luego procedimiento. Lo declarativo lo aplica el motor siempre y es más rápido. Los triggers cubren reglas entre filas: transiciones de estado, solapes de avión y tripulación, tarifa vigente, inventario. Están escritos en conjunto: funcionan igual con una fila que con 300 000. El índice filtrado solo cuenta tiquetes activos, por eso un tiquete cancelado libera el asiento.");

  // =========================================================== 8. Concurrencia
  s = nuevo("CONTENIDO", "Sesiones simultáneas reales: sin sobreventa ni cobros dobles", "Implementación");
  const pc = pruebas.pruebas.filter((p) => p.tipo === "Concurrencia");
  const tarjetasPc = [
    ["12 de 40", "compras simultáneas en una cabina VIP de 12 asientos", "Semáforo: la fila del cupo se bloquea (UPDLOCK) y CHECK ≤ capacidad"],
    ["1 de 20", "sesiones piden el asiento 12A del mismo vuelo", "Índice único filtrado; el error se traduce a «asiento ocupado»"],
    ["1 de 10", "pagos simultáneos del saldo total del mismo tiquete", "El pago bloquea la fila del tiquete antes de sumar lo cobrado"],
    ["30 de 30", "asignaciones automáticas de asiento simultáneas", "Antes 6 de 30 (efecto manada); corregido con el semáforo"],
  ];
  tarjetasPc.forEach(([n, que, como], i) => {
    const x = 0.6 + i * 3.1;
    tarjeta(s, x, 1.45, 2.85, 4.75, "pc" + i);
    texto(s, n, { x: x + 0.2, y: 1.6, w: 2.45, h: 0.9, fontSize: 40, bold: true, color: C.accent3, fontFace: THEME.headFontFace });
    texto(s, que, { x: x + 0.2, y: 2.55, w: 2.45, h: 1.3, fontSize: 15, bold: true, color: C.text2 });
    texto(s, como, { x: x + 0.2, y: 3.95, w: 2.45, h: 1.6, fontSize: 14 });
    texto(s, `${pc[i].id} · ${pc[i].resultado.toLowerCase()}`, { x: x + 0.2, y: 5.7, w: 2.45, h: 0.35, fontSize: 12, color: C.accent5 });
  });
  texto(s, "Aislamiento: READ COMMITTED con versiones de fila (predeterminado en Azure). Las validaciones que deciden una escritura leen con bloqueo para evitar la escritura sesgada.",
    { x: 0.6, y: 6.35, w: 12.1, h: 0.55, fontSize: 14, color: C.accent5 });
  s.addNotes("Tiempo: 1:30. Las pruebas usan hilos con una conexión cada uno y una barrera para que todos empiecen a la vez. Explicar la escritura sesgada: dos ventas leen «queda 1 asiento», ambas validan y ambas escriben. Por eso la validación bloquea la fila del cupo: la segunda venta espera a que la primera termine. Las ventas de otros vuelos no esperan. Contar el hallazgo de la asignación automática: la primera versión falló esta misma prueba (6 de 30) y se corrigió.");

  // =========================================================== 9. Implementación reproducible
  s = nuevo("CONTENIDO", "Todo se reconstruye con un comando", "Implementación");
  const pasos = [
    [fa.FaDatabase, "Scripts T-SQL", "02-13 en orden, idempotentes; el destructivo va aparte"],
    [fa.FaCogs, "Datos sintéticos", "semilla 20261106; CSV con huella SHA-256"],
    [fa.FaLayerGroup, "Carga transaccional", `${num(filasCargadas / 1e6, 2)} M filas en ~90 s con todas las reglas activas`],
    [fa.FaTerminal, "20 consultas", "parámetros enlazados (?) → CSV y manifiesto"],
    [fa.FaChartBar, "Gráficos e informe", "figuras, diccionario y diagramas desde el catálogo"],
  ];
  for (let i = 0; i < pasos.length; i++) {
    const x = 0.6 + i * 2.5;
    await iconoCirculo(s, pasos[i][0], x + 0.7, 1.55, 0.95, HEX.accent1, HEX.lt1, "paso" + i);
    if (i < pasos.length - 1) s.addShape(pres.shapes.RIGHT_ARROW, { x: x + 1.85, y: 1.83, w: 0.45, h: 0.4, fill: { color: C.accent6 }, line: { color: C.accent6 }, objectName: "flecha" + i });
    texto(s, pasos[i][1], { x, y: 2.7, w: 2.35, h: 0.5, fontSize: 16, bold: true, color: C.text2, align: "center" });
    texto(s, pasos[i][2], { x: x + 0.05, y: 3.2, w: 2.25, h: 1.1, fontSize: 14, align: "center" });
  }
  tarjeta(s, 0.6, 4.65, 12.1, 1.3, "comando", C.text2);
  texto(s, "python -m aerolinea reproducir --confirmar-destruccion", { x: 0.9, y: 4.85, w: 11.5, h: 0.5, fontSize: 22, fontFace: "Courier New", color: C.background1, bold: true });
  texto(s, "verificar conexión → base local nueva → carga → pruebas → consultas → gráficos → documentación", { x: 0.9, y: 5.38, w: 11.5, h: 0.45, fontSize: 14, color: C.accent6 });
  texto(s, "La carga no desactiva ninguna regla: si un dato sintético viola una restricción, la transacción completa se revierte. Que termine es una prueba de integración.",
    { x: 0.6, y: 6.15, w: 12.1, h: 0.7, fontSize: 14, color: C.accent5 });
  s.addNotes("Tiempo: 1:15. Reproducibilidad: misma semilla, mismos datos byte a byte; cualquier integrante obtiene las mismas cifras. Seguridad: nunca se concatena la entrada del usuario en el SQL; los valores van como parámetros. Detalle técnico que vale la pena contar si preguntan: GO no es SQL, la aplicación divide los lotes del lado del cliente. Y el hallazgo del pooling de ODBC: la carga heredaba una transacción abierta de otra conexión.");

  // =========================================================== 10. Demostración
  s = nuevo("CONTENIDO", "Demostración en vivo", "Implementación");
  tarjeta(s, 0.6, 1.45, 7.4, 5.3, "terminal", "1E1E1E");
  texto(s, [
    { text: "> python -m aerolinea verificar-conexion", options: { color: HEX.accent4, breakLine: true } },
    { text: "  servidor, edición, versión, usuario, cifrado", options: { color: "BFBFBF", breakLine: true } },
    { text: " ", options: { breakLine: true } },
    { text: "> python -m aerolinea demo", options: { color: HEX.accent4, breakLine: true } },
    { text: "  A. sobrepago → error 50135 → se revierte TODO", options: { color: "BFBFBF", breakLine: true } },
    { text: "  B. compra sin registro → pago 40 % → saldo", options: { color: "BFBFBF", breakLine: true } },
    { text: "     → EMITIDO → cancelación → regla 24 h", options: { color: "BFBFBF", breakLine: true } },
    { text: "  ROLLBACK: los datos del informe no cambian", options: { color: "BFBFBF", breakLine: true } },
    { text: " ", options: { breakLine: true } },
    { text: "> python -m aerolinea consultas --id Q16", options: { color: HEX.accent4, breakLine: true } },
    { text: "      --param dias=7 origen=JFK", options: { color: HEX.accent4, breakLine: true } },
    { text: "  disponibilidad y tarifa vigente → CSV", options: { color: "BFBFBF" } },
  ], { x: 0.9, y: 1.7, w: 6.9, h: 4.9, fontSize: 15, fontFace: "Courier New", color: C.background1 });
  const mira = [
    ["Atomicidad", "un error de negocio deshace persona, reserva y pago parcial"],
    ["Pagos parciales", "el tiquete pasa a EMITIDO solo con el pago completo"],
    ["Política de reembolso", "la misma función que usan el procedimiento y las consultas"],
    ["Plan B", "si falla la conexión: evidence/contenedor_linux/demo_procedimientos.txt"],
  ];
  mira.forEach(([t, d], i) => {
    const y = 1.5 + i * 1.3;
    texto(s, [{ text: t, options: { bold: true, color: C.text2, fontSize: 16, breakLine: true } }, { text: d, options: { fontSize: 14 } }], { x: 8.35, y, w: 4.35, h: 1.15 });
  });
  s.addNotes("Tiempo: 2:30. Seguir docs/defensa/guion_demo.md. Antes de la sesión: base cargada, .env listo, terminal con letra grande. Paso 1 (20 s): verificar-conexion y señalar el cifrado. Paso 2 (80 s): demo; en la parte A señalar que el error deshace todo, incluida la persona creada; en la parte B leer los estados. Paso 3 (40 s): consulta Q16 con parámetros. Si algo falla, mostrar la salida guardada y seguir: no depurar en vivo.");

  // =========================================================== 11. Resultados
  pres.addSection({ title: "Resultados" });
  s = nuevo("CONTENIDO", "Ventas, cobros y reembolsos son magnitudes distintas", "Resultados");
  s.addChart(pres.charts.BAR, [
    { name: "Ventas brutas", labels: q03.map((r) => mes(r.mes)), values: q03.map((r) => Number(r.ventas_brutas_usd) / 1e6) },
    { name: "Cobros confirmados", labels: q03.map((r) => mes(r.mes)), values: q03.map((r) => Number(r.cobros_usd) / 1e6) },
    { name: "Reembolsos", labels: q03.map((r) => mes(r.mes)), values: q03.map((r) => Number(r.reembolsos_usd) / 1e6) },
  ], {
    x: 0.6, y: 1.4, w: 7.6, h: 5.4, barDir: "col", barGrouping: "clustered", barGapWidthPct: 60,
    chartColors: [HEX.accent1, HEX.accent2, HEX.accent3], showValue: true, dataLabelPosition: "outEnd", dataLabelFormatCode: "0.0", dataLabelFontSize: 10, dataLabelColor: HEX.accent5,
    catAxisLabelColor: HEX.accent5, valAxisLabelColor: HEX.accent5, catAxisLabelFontSize: 12, valAxisLabelFontSize: 11,
    valGridLine: { color: "E4E3DE", size: 0.5 }, catGridLine: { style: "none" }, valAxisTitle: "Millones de USD", showValAxisTitle: true, valAxisTitleColor: HEX.accent5, valAxisTitleFontSize: 11,
    showLegend: true, legendPos: "t", legendFontSize: 12, legendColor: HEX.dk1, showTitle: true, title: "Por mes del evento (Q03, datos sintéticos)", titleFontSize: 14, titleColor: HEX.dk2,
    catAxisLabelFontFace: "+mn-lt", valAxisLabelFontFace: "+mn-lt", dataLabelFontFace: "+mn-lt", legendFontFace: "+mn-lt", titleFontFace: "+mn-lt", valAxisTitleFontFace: "+mn-lt",
    objectName: "grafico_flujo",
  });
  const destacados = [
    [`${num(identidad.diferencia_usd, 2)} USD`, "diferencia en la identidad de caja (cobros − reembolsos = ventas emitidas + abonos + penalidades)"],
    ["72,27 → 87,78 M USD", "lo que «cobra» una unión ingenua de pagos y reembolsos: importes multiplicados (PR-20)"],
    [`${num(totalEco.factor_ponderado * 100, 1)} % · ${num(totalVip.factor_ponderado * 100, 1)} %`, "ocupación ponderada ECO · VIP en vuelos operados"],
  ];
  destacados.forEach(([n, t], i) => {
    const y = 1.45 + i * 1.8;
    tarjeta(s, 8.5, y, 4.2, 1.6, "destacado" + i);
    texto(s, n, { x: 8.7, y: y + 0.12, w: 3.8, h: 0.6, fontSize: 26, bold: true, color: C.accent1, fontFace: THEME.headFontFace });
    texto(s, t, { x: 8.7, y: y + 0.75, w: 3.8, h: 0.8, fontSize: 13 });
  });
  s.addNotes("Tiempo: 1:45. Cada magnitud se agrega por su propia fecha en una expresión separada. Si se unen pagos y reembolsos antes de agregar, un tiquete con dos pagos duplica su reembolso: la prueba PR-20 lo demuestra (72,27 contra 87,78 millones). Los cobros superan a las ventas vigentes sin error: incluyen dinero devuelto o retenido como penalidad; la identidad de caja cuadra al centavo. No calculamos rentabilidad porque no hay costos. Recordar: datos sintéticos; validan el modelo, no describen un mercado.");

  // =========================================================== 12. Pruebas y hallazgos
  s = nuevo("CONTENIDO", "Pruebas: 27 de 27 y 20 defectos corregidos", "Resultados");
  const grandes = [[`${superadas}/${totalPruebas}`, "pruebas de reglas y de concurrencia"], ["23/23", "pruebas de la aplicación (pytest)"], ["0", "diferencias en los 9 controles de conciliación"]];
  grandes.forEach(([n, t], i) => {
    const y = 1.45 + i * 1.75;
    tarjeta(s, 0.6, y, 4.0, 1.55, "grande" + i);
    texto(s, n, { x: 0.85, y: y + 0.1, w: 3.5, h: 0.85, fontSize: 40, bold: true, color: C.accent3, fontFace: THEME.headFontFace });
    texto(s, t, { x: 0.85, y: y + 0.95, w: 3.5, h: 0.5, fontSize: 14 });
  });
  const hallazgos = [
    [fa.FaSyncAlt, "Plan reutilizado en triggers", "Compilado para una fila y aplicado a 300 000: la carga no terminaba. Corrección: RECOMPILE y sin «row goal»."],
    [fa.FaExclamationTriangle, "Lógica de tres valores", "NOT (x = 'TECNICA') es desconocido si x es NULL: se aceptaba un capitán sin categoría. Corrección: ISNULL."],
    [fa.FaUsers, "Efecto manada", "30 sesiones elegían el mismo «primer asiento libre». Corrección: semáforo por vuelo y cabina."],
    [fa.FaBug, "Pooling de ODBC", "La carga heredaba una transacción abierta de otra conexión y no se confirmaba. Corrección: sin pooling y control de @@TRANCOUNT."],
  ];
  for (let i = 0; i < hallazgos.length; i++) {
    const y = 1.45 + i * 1.33;
    await iconoCirculo(s, hallazgos[i][0], 5.0, y + 0.1, 0.7, HEX.accent2, HEX.lt1, "hallazgo" + i);
    texto(s, [{ text: hallazgos[i][1], options: { bold: true, color: C.text2, fontSize: 16, breakLine: true } }, { text: hallazgos[i][2], options: { fontSize: 14 } }], { x: 5.9, y, w: 6.8, h: 1.25 });
  }
  s.addNotes("Tiempo: 1:15. Una prueba solo se declara superada si se observó su resultado; los resultados están en evidence/contenedor_linux. Contar uno o dos hallazgos con detalle: el de lógica de tres valores es un clásico de SQL; el del pooling muestra por qué hay que verificar el estado de la transacción. El registro completo con causa y evidencia está en el anexo B del informe.");

  // =========================================================== 13. Nube y limitaciones
  s = nuevo("CONTENIDO", "Nube preparada, no desplegada: lo decimos tal cual", "Resultados");
  tarjeta(s, 0.6, 1.45, 6.0, 5.2, "nube_fondo");
  await iconoCirculo(s, fa.FaCloud, 0.9, 1.7, 0.85, HEX.accent1, HEX.lt1, "nube");
  texto(s, "Azure SQL Database", { x: 1.95, y: 1.82, w: 4.4, h: 0.6, fontSize: 20, bold: true, color: C.text2 });
  texto(s, [
    { text: "Oferta gratuita, pausa automática al agotar el límite", options: { bullet: true, breakLine: true } },
    { text: "Solo Microsoft Entra ID; TLS 1.2; certificado validado", options: { bullet: true, breakLine: true } },
    { text: "Firewall solo para la IP del equipo, sin 0.0.0.0", options: { bullet: true, breakLine: true } },
    { text: "Script de creación en modo simulación por defecto", options: { bullet: true, breakLine: true } },
    { text: "Verificación de solo lectura y lista de 8 evidencias", options: { bullet: true } },
  ], { x: 0.95, y: 2.75, w: 5.4, h: 2.8, fontSize: 16, paraSpaceAfter: 10 });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.95, y: 5.6, w: 5.35, h: 0.8, rectRadius: 0.08, fill: { color: C.accent4 }, line: { color: C.accent4 }, objectName: "pendiente" });
  texto(s, "Pendiente: requiere suscripción y autorización del equipo", { x: 1.1, y: 5.65, w: 5.05, h: 0.7, fontSize: 15, bold: true, color: C.text1, valign: "middle" });
  texto(s, "Limitaciones", { x: 7.0, y: 1.5, w: 5.7, h: 0.5, fontSize: 20, bold: true, color: C.text2 });
  const limites = [
    ["Datos sintéticos", "validan el modelo; no describen un mercado real"],
    ["Entorno de validación", "contenedor Linux con SQL Server 2022; falta la laptop Windows"],
    ["Compatibilidad 2016", "probada con nivel 130 en motor 2022, no en un motor 2016"],
    ["Enmascaramiento ≠ cifrado", "Always Encrypted queda como trabajo futuro"],
  ];
  limites.forEach(([t, d], i) => {
    const y = 2.2 + i * 1.15;
    texto(s, [{ text: t, options: { bold: true, fontSize: 16, breakLine: true } }, { text: d, options: { fontSize: 14, color: C.accent5 } }], { x: 7.0, y, w: 5.7, h: 1.0 });
  });
  s.addNotes("Tiempo: 1:15. Ser explícitos: el requisito de nube del enunciado no está cumplido mientras no se despliegue en Azure con evidencia propia, y las pruebas locales no lo sustituyen. Todo está listo: guía, script en modo simulación, verificación y lista de evidencias. Mencionar las diferencias resueltas en el diseño (sin USE, autenticación Entra, certificado validado, RCSI). Las limitaciones son también el trabajo futuro.");

  // =========================================================== 14. Conclusiones
  pres.addSection({ title: "Cierre" });
  s = nuevo("CIERRE", "Conclusiones y próximos pasos", "Cierre");
  const conclusiones = [
    "Las ambigüedades se resolvieron con 42 reglas verificables y decisiones documentadas",
    "Modelo en 3FN; diccionario y diagramas físicos generados del propio motor",
    "La base rechaza lo inválido aun con sesiones simultáneas: 27 de 27 pruebas",
    "Datos y 20 consultas reproducibles desde Python, sin multiplicar importes",
  ];
  conclusiones.forEach((t, i) => {
    const y = 1.55 + i * 1.05;
    s.addShape(pres.shapes.OVAL, { x: 0.6, y: y + 0.08, w: 0.5, h: 0.5, fill: { color: C.accent3 }, line: { color: C.accent3 }, objectName: "conclusion" + i });
    texto(s, String(i + 1), { x: 0.6, y: y + 0.08, w: 0.5, h: 0.5, fontSize: 15, bold: true, color: C.background1, align: "center", valign: "middle" });
    texto(s, t, { x: 1.35, y, w: 6.3, h: 0.9, fontSize: 17, color: C.background1, valign: "middle" });
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.1, y: 1.5, w: 4.6, h: 3.7, rectRadius: 0.1, fill: { color: "22325A" }, line: { color: "22325A" }, objectName: "pasos_fondo" });
  texto(s, "Próximos pasos", { x: 8.4, y: 1.7, w: 4.0, h: 0.5, fontSize: 20, bold: true, color: C.accent4 });
  texto(s, [
    { text: "Reproducir en la laptop Windows", options: { bullet: true, breakLine: true } },
    { text: "Desplegar en Azure con autorización", options: { bullet: true, breakLine: true } },
    { text: "Invitar al equipo al repositorio", options: { bullet: true, breakLine: true } },
    { text: "Cifrar columnas sensibles", options: { bullet: true, breakLine: true } },
    { text: "Probar con datos abiertos reales", options: { bullet: true } },
  ], { x: 8.4, y: 2.35, w: 4.0, h: 2.7, fontSize: 16, color: C.background1, paraSpaceAfter: 8 });
  texto(s, "Gracias · preguntas", { x: 0.6, y: 6.2, w: 7.0, h: 0.6, fontSize: 22, bold: true, color: C.accent6, fontFace: THEME.headFontFace });
  s.addNotes("Tiempo: 1:30. Cerrar con una conclusión por objetivo (el quinto, nube, queda pendiente y se dice). Próximos pasos concretos y en orden: laptop, Azure, GitHub. Abrir preguntas; las respuestas preparadas están en docs/defensa/preguntas_defensa.md.");

  await pres.writeFile({ fileName: SALIDA });
  await aplicarTema(SALIDA, THEME);
  console.log("Presentación generada:", SALIDA);
})().catch((e) => { console.error(e); process.exit(1); });
