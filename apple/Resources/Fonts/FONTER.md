# Fonter

Statiske instanser av to OFL-lisensierte variable fonter (Google Fonts), laget med `fonttools varLib.instancer`
(wdth=100, vekt som i filnavnet). Lisensene ligger ved siden av. Identiteten: `design/identitet.md` regel 5.

| Fil | PostScript-navn (bruk dette i `Font.custom`) | Brukes til |
|---|---|---|
| `Archivo-Bold.ttf` | `ArchivoRoman-Bold` | hero, store tall, h2 (token `--vekt-stor` 700) |
| `Archivo-Medium.ttf` | `ArchivoRoman-Medium` | løpende tekst (`--vekt-tekst` 500) |
| `MartianMono-Regular.ttf` | `MartianMono-Regular` | etiketter, enheter, tider (`--vekt-etikett` 400) |
| `MartianMono-SemiBold.ttf` | `MartianMono-SemiBold` | aksent-etiketter og knapper (`--vekt-etikett-aksent` 600) |

Kilde: github.com/google/fonts, `ofl/archivo` og `ofl/martianmono`. Lag instansene på nytt ved behov:
`fonttools varLib.instancer <variabel.ttf> wght=<vekt> wdth=100 --update-name-table -o <ut>.ttf`.
