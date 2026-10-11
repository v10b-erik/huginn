#!/usr/bin/env bun
// Genererer apple/AppCore/Sources/AppCore/Theme.swift fra design/tokens.css (identitet.md → data → Swift).
//
//   bun Scripts/gen-theme.ts           # skriv Theme.swift
//   bun Scripts/gen-theme.ts --sjekk   # exit 1 hvis Theme.swift er utdatert, eller tokens.css er internt
//                                      # inkonsistent (CI kjører denne)
//
// Forventer formatet beskrevet øverst i tokens.css: tre blokker (mørk :root, lys [data-tema="lys"], og
// lys etter systemet i @media), én egenskap per linje. Lys-blokken og @media-blokken må være identiske,
// og mørk og lys må ha de samme --farge-*-nøklene — ellers feiler skriptet også uten --sjekk.
import { readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";

const rot = join(dirname(import.meta.path), "..");
const CSS = join(rot, "design/tokens.css");
const UT = join(rot, "apple/AppCore/Sources/AppCore/Theme.swift");

type Egenskaper = Map<string, string>;

/** Innholdet mellom `{` og matchende `}` som starter rett etter `start`. */
function blokk(tekst: string, start: number): string {
  const åpne = tekst.indexOf("{", start);
  let dybde = 0;
  for (let i = åpne; i < tekst.length; i++) {
    if (tekst[i] === "{") dybde++;
    else if (tekst[i] === "}" && --dybde === 0) return tekst.slice(åpne + 1, i);
  }
  throw new Error(`ubalansert blokk ved posisjon ${start}`);
}

function egenskaper(innhold: string): Egenskaper {
  const m: Egenskaper = new Map();
  for (const linje of innhold.split("\n")) {
    const t = linje.match(/^\s*(--[\w-]+)\s*:\s*(.+?)\s*;\s*$/);
    if (t) m.set(t[1], t[2]);
  }
  return m;
}

function les() {
  // Kommentarer fjernes først, så de ikke forveksles med blokker.
  const css = readFileSync(CSS, "utf8").replace(/\/\*[\s\S]*?\*\//g, "");
  const funn = (nål: string) => {
    const i = css.indexOf(nål);
    if (i < 0) throw new Error(`tokens.css mangler blokken «${nål}»`);
    return i;
  };
  const mork = egenskaper(blokk(css, funn(":root {")));
  const lys = egenskaper(blokk(css, funn(':root[data-tema="lys"] {')));
  const media = egenskaper(blokk(css, funn(':root:not([data-tema="mork"]) {')));
  return { mork, lys, media };
}

function sjekkKonsistens({ mork, lys, media }: ReturnType<typeof les>) {
  const feil: string[] = [];
  const likt = (a: Egenskaper, b: Egenskaper, navn: string) => {
    for (const k of new Set([...a.keys(), ...b.keys()])) if (a.get(k) !== b.get(k)) feil.push(`${navn}: ${k} er «${a.get(k)}» mot «${b.get(k)}»`);
  };
  likt(lys, media, "lys-blokken og @media(prefers-color-scheme: light) er ulike");
  const farger = (m: Egenskaper) => new Set([...m.keys()].filter((k) => k.startsWith("--farge-")));
  const fm = farger(mork), fl = farger(lys);
  for (const k of fm) if (!fl.has(k)) feil.push(`${k} finnes i mørk men ikke i lys`);
  for (const k of fl) if (!fm.has(k)) feil.push(`${k} finnes i lys men ikke i mørk`);
  if (feil.length) throw new Error(`tokens.css er inkonsistent:\n  ${feil.join("\n  ")}`);
}

const TRANSLIT: Record<string, string> = { ø: "o", å: "a", æ: "ae" };
function camel(nøkkel: string): string {
  const deler = nøkkel.toLowerCase().replace(/[øåæ]/g, (c) => TRANSLIT[c]).split("-");
  const navn = deler.map((d, i) => (i === 0 ? d : d[0].toUpperCase() + d.slice(1))).join("");
  return /^\d/.test(navn) ? `s${navn}` : navn;
}

function tall(n: number): string {
  const s = n.toFixed(4).replace(/0+$/, "").replace(/\.$/, "");
  return s.includes(".") ? s : `${s}.0`;
}

function rgba(verdi: string): string {
  let m = verdi.match(/^#([0-9a-fA-F]{6})$/);
  if (m) {
    const h = parseInt(m[1], 16);
    return `RGBA(${tall(((h >> 16) & 255) / 255)}, ${tall(((h >> 8) & 255) / 255)}, ${tall((h & 255) / 255)})`;
  }
  m = verdi.match(/^rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)$/);
  if (m) return `RGBA(${tall(+m[1] / 255)}, ${tall(+m[2] / 255)}, ${tall(+m[3] / 255)}, ${tall(+m[4])})`;
  throw new Error(`farge jeg ikke kan lese: «${verdi}»`);
}

function tallverdi(verdi: string): string {
  const m = verdi.match(/^(-?[\d.]+)(px|em|ms)?$/);
  if (!m) throw new Error(`tallverdi jeg ikke kan lese: «${verdi}»`);
  return tall(m[2] === "ms" ? +m[1] / 1000 : +m[1]);  // ms → sekunder
}

function bygg(): string {
  const d = les();
  sjekkKonsistens(d);
  const fargenøkler = [...d.mork.keys()].filter((k) => k.startsWith("--farge-"));
  const felt = fargenøkler.map((k) => camel(k.slice("--farge-".length)));
  const palett = (m: Egenskaper) =>
    fargenøkler.map((k, i) => `        ${felt[i]}: ${rgba(m.get(k)!)}`).join(",\n");
  const rader = (prefiks: string, inn: string) =>
    [...d.mork.keys()]
      .filter((k) => k.startsWith(`--${prefiks}-`))
      .map((k) => `${inn}public static let ${camel(k.slice(prefiks.length + 3))}: Double = ${tallverdi(d.mork.get(k)!)}`)
      .join("\n");
  const gruppe = (prefiks: string, enum_: string, dok: string) =>
    `    /// ${dok}\n    public enum ${enum_} {\n${rader(prefiks, "        ")}\n    }`;
  const undergruppe = (prefiks: string, enum_: string, dok: string) =>
    `        /// ${dok}\n        public enum ${enum_} {\n${rader(prefiks, "            ")}\n        }`;
  const typografi = `    /// Typografi: størrelser og linjehøyder i pt, sperring i em, vekt som CSS-tall (400…700).
    /// Skriftfamiliene er ikke tall og følger med appen (apple/Resources/Fonts/FONTER.md).
    public enum Typografi {
${undergruppe("vekt", "Vekt", "Skriftvekt (CSS-tall).")}

${undergruppe("str", "Str", "Skriftstørrelse (pt).")}

${undergruppe("lh", "Lh", "Linjehøyde (pt).")}

${undergruppe("sperring", "Sperring", "Bokstavsperring (em, multipliseres med skriftstørrelsen).")}
    }`;
  return `// GENERERT fra design/tokens.css av Scripts/gen-theme.ts — ikke rediger for hånd.
// Endre tokens.css og kjør: bun Scripts/gen-theme.ts   (CI kjører --sjekk).
//
// Ren logikk uten SwiftUI, så den testes på Linux (swift test på ygg-v1). Farger er sRGB 0…1; App-målet
// gjør dem til Color (apple/Sources/ThemeFarge.swift). Bevegelse speiles her når en flate trenger den.

public enum Theme {
    public struct RGBA: Sendable, Equatable {
        public let r: Double, g: Double, b: Double, a: Double
        public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
            self.r = r; self.g = g; self.b = b; self.a = a
        }
    }

    /// Fargerollene (tokens.css \`--farge-*\`). Samme roller i begge moduser.
    public struct Palette: Sendable, Equatable {
${felt.map((f) => `        public let ${f}: RGBA`).join("\n")}
    }

    /// Mørk modus (standard).
    public static let mork = Palette(
${palett(d.mork)}
    )

    /// Lys modus.
    public static let lys = Palette(
${palett(d.lys)}
    )

${gruppe("avstand", "Avstand", "Avstandsskala (pt), 4-basert.")}

${gruppe("radius", "Radius", "Radiusskala (pt). Blandes aldri utenfor skalaen.")}

${gruppe("maal", "Maal", "Mål (pt).")}

${gruppe("lcd", "Lcd", "LCD-avlesningen: punktmatrise 5×7.")}

${gruppe("varighet", "Varighet", "Varigheter (sekunder). Kurven (--easing-ut) er ikke et tall og velges i viewet.")}

${typografi}
}
`;
}

const tekst = bygg();
if (process.argv.includes("--sjekk")) {
  let nå = "";
  try { nå = readFileSync(UT, "utf8"); } catch { /* finnes ikke ennå */ }
  if (nå !== tekst) {
    console.error("Theme.swift er utdatert i forhold til design/tokens.css. Kjør: bun Scripts/gen-theme.ts");
    process.exit(1);
  }
  console.log("Theme.swift er i synk med design/tokens.css");
} else {
  writeFileSync(UT, tekst);
  console.log(`skrev ${UT}`);
}
