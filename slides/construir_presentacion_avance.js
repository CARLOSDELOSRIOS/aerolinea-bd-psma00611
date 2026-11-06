/*
 * Presentación alineada con el documento de avance (reports/avance/): 15 diapositivas para 20 minutos.
 * Parte de la versión preparada por el equipo (23 diapositivas) y la condensa al máximo de 15 que fijan
 * las guías del curso. Cada diapositiva lleva un título, una idea clave (subtítulo) y frases cortas que
 * sirven de guía al expositor; el desarrollo oral está en las notas, con su tiempo.
 * Las figuras son las del avance (reports/avance/figuras/) y del modelo; las cifras, las del avance.
 *
 * Uso (desde la carpeta slides/):
 *   npm ci
 *   node construir_presentacion_avance.js
 * Salida: slides/presentacion_avance_PSMA00611.pptx
 */
const fs = require("fs");
const path = require("path");
const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const fa = require("react-icons/fa");

const RAIZ = path.resolve(__dirname, "..");
const SALIDA = path.join(__dirname, "presentacion_avance_PSMA00611.pptx");
const FIG = (...partes) => path.join(RAIZ, ...partes);
const AVANCE = (nombre) => FIG("reports", "avance", "figuras", nombre);

// ------------------------------------------------------------------ tema (el mismo de presentacion_PSMA00611.pptx)
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
pres.author = "Carlos Veliz de Villa Aguirre, Elias Sifuentes Valles y Carlos De los Ríos De la Roca";
pres.title = "Avance del PAC: base de datos para una aerolínea comercial (PSMA00611)";
pres.subject = "Producto Académico Colaborativo";
const C = pres.SchemeColor;

pres.defineSlideMaster({
  title: "PORTADA",
  background: { color: HEX.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 1.7, w: 9.4, h: 1.9, fontFace: THEME.headFontFace, fontSize: 40, bold: true, color: C.background1, valign: "bottom", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.8, y: 3.8, w: 9.4, h: 0.8, fontSize: 22, color: C.accent6, valign: "top", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CONTENIDO",
  background: { color: HEX.lt1 },
  margin: [0.5, 0.6, 0.6, 0.6],
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.25, w: 12.1, h: 0.75, fontFace: THEME.headFontFace, fontSize: 30, bold: true, color: C.text2, align: "center", valign: "middle", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.6, y: 1.0, w: 12.1, h: 0.42, fontSize: 17, italic: true, color: C.accent1, align: "center", valign: "top", margin: 0 }, text: "" } },
    { text: { text: "PSMA00611 · Avance · Base de datos de una aerolínea · datos sintéticos", options: { x: 0.6, y: 7.05, w: 8, h: 0.3, fontSize: 10, color: C.accent5, margin: 0 } } },
  ],
  slideNumber: { x: 12.2, y: 7.05, w: 0.5, h: 0.3, fontSize: 10, color: C.accent5, align: "right" },
});
pres.defineSlideMaster({
  title: "CIERRE",
  background: { color: HEX.dk2 },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.3, w: 12.1, h: 0.8, fontFace: THEME.headFontFace, fontSize: 32, bold: true, color: C.background1, align: "center", valign: "middle", margin: 0 }, text: "" } },
  ],
  slideNumber: { x: 12.2, y: 7.05, w: 0.5, h: 0.3, fontSize: 10, color: C.accent6, align: "right" },
});

// pptxgenjs no escribe los colores del tema: se reemplazan en ppt/theme/theme1.xml con JSZip.
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
  // pptxgenjs repite <a:pPr> en cada fragmento de un párrafo con varios fragmentos (negrita + texto normal);
  // solo el primero es válido: los demás anulan la viñeta y PowerPoint puede pedir reparar el archivo.
  const pPr = /<a:pPr(?:\s[^>]*)?\/>|<a:pPr(?:\s[^>]*)?>[\s\S]*?<\/a:pPr>/g;
  for (const nombre of Object.keys(zip.files).filter((n) => /^ppt\/slides\/slide\d+\.xml$/.test(n))) {
    const original = await zip.file(nombre).async("string");
    const corregido = original.replace(/<a:p>[\s\S]*?<\/a:p>/g, (parrafo) => {
      let primero = true;
      return parrafo.replace(pPr, (m, pos) => {
        const valido = primero && !parrafo.slice(0, pos).includes("<a:r>");
        primero = false;
        return valido ? m : "";
      });
    });
    zip.file(nombre, corregido);
  }
  // Sin entradas de carpeta en el ZIP: algunos servicios en la nube no abren paquetes que las tengan.
  const limpio = new JSZip();
  for (const [nombre, entrada] of Object.entries(zip.files)) if (!entrada.dir) limpio.file(nombre, await entrada.async("nodebuffer"), { createFolders: false });
  fs.writeFileSync(archivo, await limpio.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
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
// Figura ajustada a una caja sin deformarla (se lee el tamaño real del PNG) y centrada en ella.
async function figura(slide, ruta, caja, alt, nombre, alinear = "center") {
  const { width, height } = await sharp(ruta).metadata();
  const escala = Math.min(caja.w / width, caja.h / height);
  const w = width * escala, h = height * escala;
  const x = alinear === "left" ? caja.x : caja.x + (caja.w - w) / 2;
  slide.addImage({ path: ruta, x, y: caja.y, w, h, altText: alt, objectName: nombre });
  return { x, y: caja.y, w, h };
}
// Guía para el expositor: frases cortas con la palabra clave en negrita.
function guion(slide, x, y, w, h, items, nombre, { titulo = null, fontSize = 15, fondo = true } = {}) {
  if (fondo) tarjeta(slide, x, y, w, h, nombre + "_fondo");
  const m = fondo ? 0.22 : 0;
  const runs = [];
  if (titulo) runs.push({ text: titulo, options: { bold: true, color: C.accent1, fontSize: fontSize + 1, breakLine: true, paraSpaceAfter: 6 } });
  items.forEach(([clave, resto], i) => {
    const ultimo = i === items.length - 1;
    runs.push({ text: clave + " ", options: { bold: true, color: C.text2, bullet: { indent: 16 } } });
    runs.push({ text: resto, options: { color: C.text1, breakLine: !ultimo } });
  });
  texto(slide, runs, { x: x + m, y: y + m, w: w - 2 * m, h: h - 2 * m, fontSize, paraSpaceAfter: 9, valign: fondo ? "middle" : "top", objectName: nombre });
}
function nuevo(master, titulo, idea, seccion) {
  const s = pres.addSlide({ masterName: master, sectionTitle: seccion });
  s.addText(titulo, { placeholder: "title" });
  if (idea) s.addText(idea, { placeholder: "body" });
  return s;
}
const tabla = { fontSize: 13, color: HEX.dk1, border: { type: "solid", pt: 0.5, color: "D9D9D9" }, fill: { color: HEX.lt1 }, valign: "middle", margin: [2, 5, 2, 5] };
const cabecera = (t) => ({ text: t, options: { bold: true, color: HEX.lt1, fill: { color: HEX.accent1 } } });

(async () => {
  // =========================================================== 1. Portada
  pres.addSection({ title: "Apertura" });
  let s = pres.addSlide({ masterName: "PORTADA", sectionTitle: "Apertura" });
  s.addText("Base de datos para una aerolínea comercial en Estados Unidos", { placeholder: "title" });
  s.addText("Avance del Producto Académico Colaborativo", { placeholder: "body" });
  await iconoCirculo(s, fa.FaPlane, 10.6, 1.9, 1.9, HEX.accent1, HEX.lt1, "portada");
  texto(s, [
    { text: "Gestión de datos y bases de datos con SQL (PSMA00611)", options: { breakLine: true } },
    { text: "Maestría en Ciencia de Datos · Escuela de Posgrado · Universidad Continental", options: { breakLine: true } },
    { text: "Equipo: Carlos Veliz de Villa Aguirre · Elias Sifuentes Valles · Carlos De los Ríos De la Roca (líder)", options: { breakLine: true } },
    { text: "Docentes: Walter Alejandro Silva Sotillo y Max Leoncio Mucha Morales" },
  ], { x: 0.8, y: 5.25, w: 11.8, h: 1.65, fontSize: 14, color: C.background1, paraSpaceAfter: 4 });
  s.addNotes("Tiempo: 0:30.\nQué decir: saludar y presentar al equipo: Carlos Veliz, Elias Sifuentes y Carlos De los Ríos, que es el líder. En una frase: diseñamos la base de datos de una aerolínea nueva que hace cumplir sus propias reglas y que se reconstruye completa con un solo comando.\nAclarar desde el inicio: los datos son sintéticos y el despliegue en Azure está preparado, pero todavía pendiente. Cualquiera del equipo puede continuar desde cualquier diapositiva.");

  // =========================================================== 2. Problema y objetivos
  pres.addSection({ title: "Encargo y equipo" });
  s = nuevo("CONTENIDO", "El problema y lo que queremos lograr", "Que los datos sean correctos aunque muchos vendan y cobren a la vez", "Encargo y equipo");
  guion(s, 0.6, 1.65, 4.6, 5.15, [
    ["Qué registramos:", "vuelos, compras, pasajeros, cobros, reembolsos, aviones y tripulación."],
    ["Qué puede fallar:", "un asiento vendido dos veces, un vuelo sobrevendido o un reembolso mal calculado."],
    ["Para decidir:", "ocupación por ruta y ventas por canal, calculadas siempre de la misma manera."],
    ["Dónde estamos:", "cuatro objetivos completos; el quinto (nube) sigue en curso."],
  ], "problema", { titulo: "El problema" });
  await figura(s, AVANCE("A03_objetivos.png"), { x: 5.5, y: 1.65, w: 7.25, h: 5.15 }, "Objetivo general y cinco objetivos específicos con su estado", "objetivos");
  s.addNotes("Tiempo: 1:30.\nQué decir: el problema no es guardar datos, sino que sean correctos aunque varias personas vendan y cobren al mismo tiempo. Ejemplo: si dos agentes venden el último asiento a la vez, solo uno debe lograrlo.\nLuego recorrer los objetivos de la figura: requisitos, modelo, integridad, y datos y consultas están completos; el quinto, validación y nube, sigue en curso porque falta desplegar en Azure.\nSi preguntan: el objetivo general sale del enunciado del curso; los específicos son nuestra forma de dividirlo en partes verificables.");

  // =========================================================== 3. Qué pide el curso y dónde estamos
  s = nuevo("CONTENIDO", "Qué pide el curso y dónde estamos", "Los seis componentes ya tienen una versión probada; faltan las laptops y Azure", "Encargo y equipo");
  await figura(s, AVANCE("A02_estado.png"), { x: 0.6, y: 1.65, w: 7.6, h: 5.2 }, "Estado de cada componente del encargo", "estado");
  guion(s, 8.5, 1.65, 4.25, 5.15, [
    ["Avance:", "registrarse en GitHub, crear el equipo y el proyecto, y subir los scripts."],
    ["Pesos:", "avance 20 % · presentación 40 % · producto final 40 %."],
    ["Entrega final:", "16 de noviembre de 2026, 23:59."],
    ["Fecha del avance:", "semana 2, 3 o 4 según el documento; se lo consultamos al docente."],
  ], "encargo", { titulo: "El encargo" });
  s.addNotes("Tiempo: 1:15.\nQué decir: el curso evalúa tres momentos: el avance, la presentación oral y el producto final, con 20, 40 y 40 %. Para el avance, las guías piden GitHub con el equipo, el proyecto y los scripts.\nLeer la tabla de arriba abajo: verde es lo que ya está hecho y probado, ámbar lo que avanza y rojo lo que aún no empieza. Lo rojo son las laptops y Azure.\nSi preguntan por la fecha: los documentos del curso dicen semana 2, 3 o 4; por eso preparamos el avance con anticipación y lo consultamos al docente.");

  // =========================================================== 4. Cómo trabajamos los tres
  s = nuevo("CONTENIDO", "Cómo trabajamos los tres", "Los tres participamos en todas las etapas, del prompt al repositorio", "Encargo y equipo");
  await figura(s, AVANCE("A15_equipo.png"), { x: 0.6, y: 1.65, w: 7.3, h: 5.2 }, "Ciclo de trabajo del equipo: prompt, Claude Code, revisión y GitHub", "equipo");
  guion(s, 8.2, 1.65, 4.55, 5.15, [
    ["Juntos:", "decidimos qué pedir, y redactamos y revisamos cada prompt."],
    ["Claude Code:", "genera los archivos y ejecuta las pruebas."],
    ["Reglas fijas:", "no inventar datos ni dar por probado lo que no se probó."],
    ["Evidencia:", "prompts literales en el anexo B; historial en GitHub."],
    ["Desde ahora:", "cada integrante sube sus cambios con su propia cuenta."],
  ], "trabajo", { fontSize: 14 });
  s.addNotes("Tiempo: 1:15.\nQué decir: no nos repartimos el trabajo por áreas; los tres participamos en todas las etapas. Explicar el ciclo de la figura: redactamos juntos el prompt, Claude Code genera los archivos y ejecuta las pruebas, revisamos juntos el resultado y lo guardamos en GitHub. Si algo no convence, ajustamos el prompt y repetimos.\nMencionar las reglas que pusimos en los prompts: no inventar integrantes, cifras, referencias ni pruebas, y marcar como pendiente lo que no se pudo comprobar.\nSi preguntan por los commits a nombre de «Claude»: se subieron desde la sesión de la herramienta y representan el trabajo conjunto; desde ahora cada uno sube con su cuenta.");

  // =========================================================== 5. Las diez relaciones
  pres.addSection({ title: "Requisitos y modelo" });
  s = nuevo("CONTENIDO", "Las diez relaciones del enunciado", "Cada relación tiene sus tablas y sus atributos documentados", "Requisitos y modelo");
  const relaciones = [
    ["Clientes", "ven.persona (toda persona que compra o viaja) y ven.cliente (persona con cuenta)", "12 + 8"],
    ["Empleados", "rh.empleado, rh.cargo, rh.departamento", "14"],
    ["Rutas (origen, destino, día y hora)", "ops.ruta, ops.programacion, ops.programacion_dia", "7 + 9 + 2"],
    ["Vuelos (generados de una ruta programada)", "ops.vuelo, creado por ops.usp_generar_vuelos", "14"],
    ["Localizaciones (físicas y web)", "ref.localizacion (aeropuerto, oficina o canal web) y ref.aeropuerto", "14 + 7"],
    ["Tiquetes (clientes registrados o no)", "ven.compra, ven.tiquete", "7 + 20"],
    ["Aviones (asignados a viajes)", "ops.avion, ops.configuracion_asientos", "9"],
    ["Cabina (VIP o económica; precio por ruta y cabina)", "ref.cabina, ops.vuelo_cabina, ven.tarifa", "7 + 4 + 7"],
    ["Pagos (uno o más por tiquete)", "ven.pago, ven.reembolso", "12 + 8"],
    ["Descuentos (porcentaje sobre el precio original)", "ven.descuento", "11"],
  ];
  s.addTable([[cabecera("Relación del enunciado"), cabecera("Tablas que la implementan"), cabecera("Atributos")],
    ...relaciones.map(([r, t, a], i) => [
      { text: r, options: { bold: true, fill: { color: i % 2 ? HEX.lt1 : HEX.lt2 } } },
      { text: t, options: { fill: { color: i % 2 ? HEX.lt1 : HEX.lt2 } } },
      { text: a, options: { align: "center", fill: { color: i % 2 ? HEX.lt1 : HEX.lt2 } } }])],
    { ...tabla, x: 0.6, y: 1.65, w: 12.15, colW: [4.0, 6.75, 1.4], rowH: 0.43, objectName: "relaciones" });
  texto(s, "Ser exhaustivos con los atributos: el diccionario de datos documenta 269 columnas con su tipo, dominio y definición.",
    { x: 0.6, y: 6.5, w: 12.15, h: 0.35, fontSize: 13, italic: true, color: C.accent5, align: "center" });
  s.addNotes("Tiempo: 1:15.\nQué decir: el enunciado pide como mínimo estas diez relaciones; aquí se ve con qué tablas implementamos cada una y cuántos atributos tiene su tabla principal. No leer la tabla entera: elegir dos filas.\nPrimera: «Clientes» se separa en persona y cliente, porque también compran personas sin registro. Segunda: «Rutas» se reparte en tres tablas, porque el horario cambia con el tiempo.\nSi preguntan por «ser exhaustivo con los atributos»: el diccionario de datos del repositorio documenta las 269 columnas.");

  // =========================================================== 6. Persona/comprador/cliente y ruta→vuelo
  s = nuevo("CONTENIDO", "Dos dudas del enunciado que cambiaron el modelo", "Quien compra no siempre viaja, y la ruta no es el vuelo", "Requisitos y modelo");
  await figura(s, AVANCE("A04_personas.png"), { x: 0.6, y: 1.65, w: 5.95, h: 3.45 }, "Persona, comprador, pasajero y cliente registrado", "personas");
  await figura(s, AVANCE("A05_ruta_vuelo.png"), { x: 6.8, y: 1.65, w: 5.95, h: 3.45 }, "De la ruta al vuelo con fecha", "ruta_vuelo");
  guion(s, 0.6, 5.3, 5.95, 1.55, [
    ["Persona:", "toda persona que compra o viaja; cliente es la que tiene cuenta."],
    ["Resultado:", "la compra sin registro no deja campos vacíos ni duplica a nadie."],
  ], "dudas_1", { fontSize: 14 });
  guion(s, 6.8, 5.3, 5.95, 1.55, [
    ["Tres niveles:", "ruta (origen-destino) → programación (número, hora, días) → vuelo con fecha."],
    ["Lo genera:", "ops.usp_generar_vuelos, como pide el enunciado."],
  ], "dudas_2", { fontSize: 14 });
  s.addNotes("Tiempo: 1:30.\nQué decir: dos dudas del enunciado cambiaron el modelo. Primera: quien compra no siempre viaja. Usar el ejemplo de la figura: Ana compra sin registrarse dos tiquetes, uno para ella y otro para su hijo. Toda persona puede comprar o viajar y solo algunas tienen cuenta.\nSegunda: la ruta no es el vuelo. La ruta es JFK-LAX; la programación es el XX101 que sale todos los días a las 07:00; y cada día genera un vuelo con fecha, que es el que tiene avión, tripulación y estado.\nSi preguntan: el procedimiento ops.usp_generar_vuelos crea los vuelos y, si se ejecuta otra vez, no los duplica (prueba PR-18).");

  // =========================================================== 7. Precio histórico y otras decisiones
  s = nuevo("CONTENIDO", "El precio vendido no cambia, y otras reglas del negocio", "El tiquete guarda el precio y el descuento del momento de la venta", "Requisitos y modelo");
  await figura(s, AVANCE("A06_precio_historico.png"), { x: 0.6, y: 1.65, w: 7.0, h: 3.3 }, "Versiones de la tarifa JFK-LAX en económica y precio que conserva un tiquete", "precio");
  guion(s, 0.6, 5.15, 7.0, 1.7, [
    ["Tarifa JFK-LAX económica:", "308,99 → 333,99 → 354,99 USD; el tiquete comprado el 10-sep sigue en 308,99."],
    ["Control:", "la tarifa usada no se edita: se cierra y se crea otra versión."],
  ], "precio_guion", { fontSize: 14 });
  guion(s, 7.85, 1.65, 4.9, 5.2, [
    ["Descuentos:", "uno por tiquete, el mayor que corresponda."],
    ["Pagos:", "en partes; se emite al completar el precio; la reserva vence a las 72 h."],
    ["Horarios:", "hora local con su desfase en los vuelos; UTC en las transacciones."],
    ["Reembolsos:", "sin penalidad en 24 h si se compró con 7 días o más (norma del DOT); luego, según la cabina."],
  ], "decisiones", { titulo: "Otras decisiones", fontSize: 14 });
  s.addNotes("Tiempo: 1:30.\nQué decir: las tarifas cambian, pero un tiquete vendido debe conservar su precio. En el gráfico, la tarifa JFK-LAX en económica sube de 308,99 a 354,99 USD, y el tiquete comprado el 10 de septiembre sigue en 308,99. Por eso el tiquete guarda una copia del precio y del descuento, y la tarifa usada no se edita: se cierra y se crea otra versión.\nDespués, nombrar rápido las cuatro decisiones del recuadro: un solo descuento, pagos en partes, horas con su desfase y la política de reembolsos.\nSi preguntan por la regla de 24 horas: sigue la norma del Departamento de Transporte de Estados Unidos (14 CFR 259.5).");

  // =========================================================== 8. Modelo conceptual y normalización
  s = nuevo("CONTENIDO", "Un modelo de 19 entidades en tercera forma normal", "Todo gira alrededor del tiquete; el cupo por cabina impide la sobreventa", "Requisitos y modelo");
  await figura(s, FIG("docs", "02_modelo", "diagramas", "conceptual.png"), { x: 0.6, y: 1.6, w: 5.3, h: 5.3 }, "Modelo conceptual: 19 entidades y sus relaciones", "conceptual");
  await figura(s, AVANCE("A07_normalizacion.png"), { x: 6.2, y: 1.65, w: 6.55, h: 3.05 }, "Normalización paso a paso hasta la tercera forma normal", "normalizacion");
  guion(s, 6.2, 4.85, 6.55, 2.0, [
    ["Normalizar:", "cada dato se guarda una sola vez y en su lugar."],
    ["6 redundancias controladas:", "la principal es el precio en el tiquete, protegido por un trigger."],
    ["Coherencia:", "los diagramas físicos y el diccionario se generan desde la base."],
  ], "modelo", { fontSize: 14 });
  s.addNotes("Tiempo: 1:30.\nQué decir: el modelo tiene 19 entidades y todo gira alrededor del tiquete: pertenece a una compra, lo usa un pasajero, ocupa una plaza de un vuelo y cabina, y se paga con uno o varios pagos. La pieza clave contra la sobreventa es el cupo por vuelo y cabina: cada venta ocupa una plaza y la base no deja vender si no queda ninguna.\nA la derecha, la normalización: partimos de una planilla con todo junto y llegamos a la tercera forma normal.\nSi preguntan por las redundancias: son seis y están controladas; la principal es el precio en el tiquete, que es un hecho de la venta, y un trigger impide modificarlo.");

  // =========================================================== 9. Scripts y reglas en la base
  pres.addSection({ title: "Implementación" });
  s = nuevo("CONTENIDO", "Scripts ordenados y reglas dentro de la base", "La base rechaza un dato inválido, venga de la aplicación, de SSMS o de una carga", "Implementación");
  await figura(s, AVANCE("A09_scripts.png"), { x: 0.6, y: 1.65, w: 6.4, h: 3.55 }, "Orden de ejecución de los scripts T-SQL", "scripts");
  await figura(s, AVANCE("A08_integridad.png"), { x: 7.3, y: 1.65, w: 5.45, h: 4.3 }, "Capas de integridad", "integridad");
  guion(s, 0.6, 5.35, 6.4, 1.5, [
    ["Reejecutables:", "ningún script duplica datos si se vuelve a correr."],
    ["Lo destructivo, aparte:", "el script 99 pide confirmación y no funciona en Azure."],
  ], "scripts_guion", { fontSize: 14 });
  texto(s, "70 CHECK · 53 claves foráneas · 29 UNIQUE · 6 índices filtrados · 12 triggers · 16 procedimientos",
    { x: 7.3, y: 6.1, w: 5.45, h: 0.7, fontSize: 13, bold: true, color: C.accent1, align: "center", valign: "middle" });
  s.addNotes("Tiempo: 1:30.\nQué decir: los scripts se ejecutan en este orden y se pueden volver a correr sin duplicar nada; lo único que borra la base es el script 99, que pide confirmación y se niega a funcionar en Azure.\nA la derecha, la idea central: las reglas viven dentro de la base y no solo en la aplicación, para que un dato inválido se rechace aunque llegue desde SSMS o desde una carga masiva. El orden de preferencia es: primero restricciones declarativas, después triggers y luego procedimientos.\nSi preguntan por las cifras: 70 CHECK, 53 claves foráneas, 29 UNIQUE, 6 índices únicos filtrados, 12 triggers y 16 procedimientos; en total, 42 reglas de negocio.");

  // =========================================================== 10. Python y arquitectura
  s = nuevo("CONTENIDO", "Python automatiza; el mismo T-SQL sirve en la laptop y en Azure", "Un comando reconstruye todo; Azure está preparado, pero aún no desplegado", "Implementación");
  await figura(s, AVANCE("A10_aplicacion.png"), { x: 0.6, y: 1.65, w: 6.3, h: 3.55 }, "Comandos de la aplicación en Python", "aplicacion");
  await figura(s, FIG("docs", "03_arquitectura", "arquitectura.png"), { x: 7.15, y: 1.65, w: 5.6, h: 4.45 }, "Arquitectura: laptop con SQL Server local y Azure SQL Database", "arquitectura");
  guion(s, 0.6, 5.35, 6.3, 1.5, [
    ["Seguro:", "parámetros enlazados (sin inyección SQL); .env fuera de GitHub; sin contraseñas."],
    ["Reproducible:", "python -m aerolinea reproducir."],
  ], "python_guion", { fontSize: 14 });
  texto(s, "Azure: Microsoft Entra ID, conexión cifrada y certificado validado; oferta gratuita con pausa automática",
    { x: 7.15, y: 6.2, w: 5.6, h: 0.65, fontSize: 13, color: C.accent5, align: "center", valign: "middle", italic: true });
  s.addNotes("Tiempo: 1:15.\nQué decir: la aplicación de Python automatiza todo, desde verificar la conexión hasta generar los documentos, y un solo comando reconstruye el proyecto desde cero. Las consultas reciben sus valores como parámetros, así que no hay inyección SQL, y no guardamos contraseñas: en las laptops usamos autenticación de Windows.\nA la derecha, la arquitectura: el mismo código T-SQL va a la laptop y a Azure SQL Database. Decirlo claro: Azure está preparado, pero todavía no está desplegado; falta la suscripción y la autorización.\nSi preguntan: en Azure la autenticación es con Microsoft Entra ID y el certificado del servidor se valida siempre.");

  // =========================================================== 11. Pruebas y concurrencia
  pres.addSection({ title: "Pruebas y resultados" });
  s = nuevo("CONTENIDO", "Pruebas: todo superado en el entorno de desarrollo", "40 sesiones a la vez por 12 asientos: exactamente 12 ventas", "Pruebas y resultados");
  await figura(s, AVANCE("A12_pruebas.png"), { x: 0.6, y: 1.65, w: 5.6, h: 5.2 }, "Pruebas superadas y entornos pendientes", "pruebas");
  await figura(s, AVANCE("A11_concurrencia.png"), { x: 6.55, y: 1.65, w: 6.2, h: 3.4 }, "Prueba de concurrencia: 40 sesiones y 12 asientos", "concurrencia");
  guion(s, 6.55, 5.2, 6.2, 1.65, [
    ["Entorno:", "SQL Server 2022 Developer; repetido con el nivel de SQL Server 2016."],
    ["Concurrencia:", "solo se bloquea la fila del cupo, no toda la base."],
    ["Falta:", "repetir todo en las laptops y en Azure."],
  ], "pruebas_guion", { fontSize: 14 });
  s.addNotes("Tiempo: 1:30.\nQué decir: todas las pruebas se superaron en el entorno de desarrollo: 23 de reglas de negocio, 4 de concurrencia y 23 de la aplicación; además se repitieron con el nivel de compatibilidad de SQL Server 2016.\nExplicar la prueba de la derecha: 40 sesiones intentan comprar a la vez en una cabina VIP de 12 asientos; exactamente 12 lo logran y las otras 28 reciben un mensaje claro de que no hay plazas. Lo logramos bloqueando solo la fila del cupo, sin frenar al resto del sistema.\nRemarcar: esto no reemplaza la prueba en nuestras laptops ni en Azure.\nSi preguntan cómo se simula: con hilos de Python, una conexión por sesión y una barrera para que todas arranquen a la vez.");

  // =========================================================== 12. Resultados preliminares
  s = nuevo("CONTENIDO", "Primeros resultados con datos sintéticos", "Sirven para validar el modelo y las consultas, no para describir un mercado", "Pruebas y resultados");
  const indicadores = [
    ["Ocupación ponderada (económica · VIP)", "68,9 % · 53,0 %", "Q02"],
    ["Ventas brutas · cobros · reembolsos (jul-oct 2026)", "73,52 · 72,27 · 3,03 M USD", "Q03"],
    ["Compras hechas por compradores registrados", "41,9 % (generador: 42 %)", "Q08"],
    ["Vuelos que llegan con menos de 15 min de demora", "78,4 %", "Q15"],
    ["Máximo de horas de vuelo de un piloto en 28 días", "94,5 h (referencia: 100)", "Q18"],
  ];
  s.addTable([[cabecera("Indicador"), cabecera("Valor"), cabecera("Consulta")],
    ...indicadores.map(([a, b, c], i) => [
      { text: a, options: { fill: { color: i % 2 ? HEX.lt1 : HEX.lt2 } } },
      { text: b, options: { bold: true, fill: { color: i % 2 ? HEX.lt1 : HEX.lt2 } } },
      { text: c, options: { align: "center", fill: { color: i % 2 ? HEX.lt1 : HEX.lt2 } } }])],
    { ...tabla, x: 0.6, y: 1.65, w: 6.6, colW: [3.5, 2.3, 0.8], rowH: 0.5, objectName: "indicadores" });
  guion(s, 0.6, 4.95, 6.6, 1.9, [
    ["Semilla 20261106:", "los mismos datos cada vez."],
    ["Q08:", "41,9 % frente al 42 % del generador: la consulta calcula bien."],
    ["Q19:", "ventas, cobros y reembolsos se calculan por separado; la caja cuadra al centavo."],
  ], "resultados_guion", { fontSize: 14 });
  const f02 = await figura(s, FIG("reports", "figuras", "F02_flujo_mensual.png"), { x: 7.45, y: 1.65, w: 5.3, h: 4.4 }, "Ventas, cobros y reembolsos por mes (Q03)", "flujo");
  texto(s, "Ventas, cobros y reembolsos por mes (Q03)", { x: 7.45, y: f02.y + f02.h + 0.1, w: 5.3, h: 0.35, fontSize: 12, italic: true, color: C.accent5, align: "center" });
  s.addNotes("Tiempo: 1:30.\nQué decir: los datos son sintéticos, generados con reglas conocidas y una semilla fija, así que sirven para comprobar que el modelo y las consultas funcionan, no para hablar de un mercado real.\nDar dos cifras: la ocupación ponderada es de 68,9 % en económica y 53,0 % en VIP, y el 78,4 % de los vuelos llega con menos de 15 minutos de demora.\nExplicar cómo validamos: Q08 devuelve 41,9 % y el generador usa 42 %, así que la consulta calcula lo que dice calcular. En el gráfico, ventas, cobros y reembolsos no coinciden mes a mes por los pagos en partes y las devoluciones, y aun así la caja cuadra al centavo (Q19).\nSi preguntan por la rentabilidad: no la calculamos porque el modelo no registra costos.");

  // =========================================================== 13. Hallazgos
  s = nuevo("CONTENIDO", "Lo que aprendimos: 20 errores reales corregidos", "Las pruebas encontraron lo que una revisión a ojo no veía", "Pruebas y resultados");
  const hallazgos = [
    [fa.FaUsers, "Todos piden a la vez", "La asignación automática de asientos atendió solo 6 de 30 pedidos simultáneos.", "Ahora se atienden de uno en uno por vuelo y cabina: 30 de 30."],
    [fa.FaQuestionCircle, "El valor desconocido (NULL)", "Comparar con NULL no da verdadero ni falso: un empleado sin categoría pasaba como capitán.", "Se trata el NULL de forma explícita; la prueba PR-15 lo verifica."],
    [fa.FaUserClock, "Datos inventados, pero creíbles", "En la primera versión, algunos pilotos superaban las 100 h de vuelo en 28 días.", "Se ajustó el generador: el máximo quedó en 94,5 h."],
  ];
  for (const [i, [Icono, titulo, problema, solucion]] of hallazgos.entries()) {
    const x = 0.6 + i * 4.15;
    tarjeta(s, x, 1.7, 3.9, 5.15, "hallazgo" + i);
    await iconoCirculo(s, Icono, x + 1.5, 1.95, 0.9, HEX.accent1, HEX.lt1, "hallazgo" + i);
    texto(s, titulo, { x: x + 0.25, y: 3.0, w: 3.4, h: 0.75, fontSize: 19, bold: true, color: C.text2, align: "center", valign: "middle", fontFace: THEME.headFontFace });
    texto(s, [
      { text: "Qué pasó: ", options: { bold: true, color: C.accent2 } }, { text: problema, options: { breakLine: true } },
      { text: "Qué hicimos: ", options: { bold: true, color: C.accent3 } }, { text: solucion },
    ], { x: x + 0.3, y: 3.95, w: 3.3, h: 2.7, fontSize: 16, paraSpaceAfter: 16 });
  }
  s.addNotes("Tiempo: 1:15.\nQué decir: las pruebas encontraron 20 errores reales y todos están documentados con su causa y su corrección. Elegir uno y contarlo con calma, según el tiempo:\n· el de los asientos muestra por qué hay que probar con sesiones simultáneas de verdad;\n· el del NULL es un clásico de SQL: una comparación con un valor vacío no es verdadera ni falsa;\n· el de las horas de vuelo muestra que hasta los datos inventados deben ser creíbles.\nSi preguntan: el registro completo está en docs/06_pruebas/hallazgos_y_correcciones.md.");

  // =========================================================== 14. Plan y riesgos
  pres.addSection({ title: "Cierre" });
  s = nuevo("CONTENIDO", "Lo que sigue hasta el 16 de noviembre", "Laptops, Azure y cierre del informe", "Cierre");
  await figura(s, AVANCE("A13_cronograma_presentacion.png"), { x: 0.6, y: 1.65, w: 6.9, h: 3.2 }, "Plan de trabajo propuesto hasta la entrega final", "cronograma");
  await figura(s, AVANCE("A14_riesgos.png"), { x: 7.75, y: 1.65, w: 5.0, h: 3.2 }, "Riesgos identificados y medidas previstas", "riesgos");
  guion(s, 0.6, 5.2, 6.9, 1.6, [
    ["Primero:", "sumar a los tres al repositorio y reproducir el proyecto en cada laptop."],
    ["Después:", "desplegar en Azure con la oferta gratuita y cerrar el informe."],
  ], "plan_guion", { fontSize: 14 });
  guion(s, 7.75, 5.2, 5.0, 1.6, [
    ["Riesgo principal:", "no tener la suscripción de Azure a tiempo."],
    ["Medida:", "pedirla ya; la guía y los scripts están listos."],
  ], "riesgo_guion", { fontSize: 14 });
  s.addNotes("Tiempo: 1:15.\nQué decir: este es el plan que propusimos en el avance. Primero, sumar a los tres al repositorio y reproducir el proyecto en cada laptop; después, desplegar en Azure y cerrar el informe para el 16 de noviembre.\nA la derecha, los riesgos y su medida; el principal es no conseguir a tiempo una suscripción de Azure, porque sin ella no se cumple el requisito de nube.\nSi preguntan por las fechas que dependen del docente: la retroalimentación del avance y el ensayo de la exposición están por confirmar.");

  // =========================================================== 15. Conclusiones
  s = nuevo("CIERRE", "Conclusiones del avance", null, "Cierre");
  const conclusiones = [
    "Definir bien los conceptos fue el mayor reto: pasajero ≠ comprador, horario ≠ vuelo, precio vendido ≠ tarifa vigente.",
    "Las reglas viven dentro de la base: la carga de más de un millón de filas funcionó como una prueba más.",
    "Todo está probado en el entorno de desarrollo; falta probar en las laptops y desplegar en Azure.",
    "El repositorio está listo; ahora cada integrante sube sus cambios con su propia cuenta.",
  ];
  conclusiones.forEach((t, i) => {
    const y = 1.45 + i * 1.15;
    s.addShape(pres.shapes.OVAL, { x: 0.6, y: y + 0.12, w: 0.55, h: 0.55, fill: { color: C.accent3 }, line: { color: C.accent3 }, objectName: "conclusion" + i });
    texto(s, String(i + 1), { x: 0.6, y: y + 0.12, w: 0.55, h: 0.55, fontSize: 16, bold: true, color: C.background1, align: "center", valign: "middle" });
    texto(s, t, { x: 1.4, y, w: 6.5, h: 0.95, fontSize: 17, color: C.background1, valign: "middle" });
  });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 8.3, y: 1.5, w: 4.45, h: 3.9, rectRadius: 0.1, fill: { color: "22325A" }, line: { color: "22325A" }, objectName: "pasos_fondo" });
  texto(s, "Próximos pasos", { x: 8.6, y: 1.7, w: 3.9, h: 0.5, fontSize: 20, bold: true, color: C.accent4 });
  texto(s, [
    { text: "Sumar a los tres en GitHub", options: { bullet: true, breakLine: true } },
    { text: "Reproducir en las tres laptops", options: { bullet: true, breakLine: true } },
    { text: "Desplegar en Azure", options: { bullet: true, breakLine: true } },
    { text: "Cerrar el informe final", options: { bullet: true } },
  ], { x: 8.6, y: 2.4, w: 3.9, h: 2.8, fontSize: 17, color: C.background1, paraSpaceAfter: 10 });
  texto(s, "Gracias · preguntas", { x: 0.6, y: 6.25, w: 7.0, h: 0.6, fontSize: 24, bold: true, color: C.accent6, fontFace: THEME.headFontFace });
  s.addNotes("Tiempo: 1:30.\nQué decir: una idea por conclusión. Lo más difícil fue ponernos de acuerdo sobre qué significa cada palabra del enunciado. Tener las reglas dentro de la base nos permitió encontrar errores que de otro modo no habríamos visto. Decir sin rodeos qué falta: las laptops y Azure. Y cerrar con GitHub: el repositorio está listo y ahora cada uno sube sus cambios con su cuenta.\nAgradecer y abrir preguntas. Las respuestas preparadas están en docs/defensa/preguntas_defensa.md.");

  await pres.writeFile({ fileName: SALIDA });
  await aplicarTema(SALIDA, THEME);
  console.log("Presentación generada:", SALIDA);
})().catch((e) => { console.error(e); process.exit(1); });
