# App-ikon: forslag

`forslag-a/b/c.png` er 1024x1024 uten alfa, generert av `Scripts/gen-ikon.py`
(`python3 -I Scripts/gen-ikon.py`; krever PIL). `index.html` er galleriet (256, 60 og 29 px).
Ingen er koblet til appen. Fjern katalogen når valget er tatt.

- A Ett lys: slukket 5x7-matrise, én tent prikk. B Godkjenn: hake i prikker. C Kø: søyler, to aksentprikker øverst.
- Ingen tekst. Mening ligger i form og plassering (hake, høyde, enkeltprikk), aldri farge alene.

## Slik kobles valgt ikon inn (ikke gjort)
1. Kopier valgt fil til `apple/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`.
2. Legg `Contents.json` i samme mappe (single-size):
   `{"images":[{"filename":"icon-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}`
   (macOS-målet kan få egen `idiom: mac`-serie senere.)
3. I `apple/project.yml`, under App-målets `settings.base`: `ASSETCATALOG_COMPILER_APPICON_NAME: "AppIcon"`.
   `Resources` autodiscoveres, så katalogen følger med (`.md` er ekskludert).
4. Bygg med `Scripts/remote-test.sh ios`; iOS runder hjørnene selv, så PNG-en skal være firkantet og uten alfa.
