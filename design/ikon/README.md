# App-ikon

Valgt: **B «Godkjenn»** (hake i 5×7 LCD-prikker, periwinkle på mørk flate), valgt av Erik. Kobla til appen:
`apple/Resources/Assets.xcassets/AppIcon.appiconset` (single-size 1024) og `ASSETCATALOG_COMPILER_APPICON_NAME` i
`apple/project.yml` (bare iOS-målet; macOS får eget ikon senere).

`forslag-b.png` er kilden (1024×1024, uten alfa), generert av `Scripts/gen-ikon.py` (`python3 -I Scripts/gen-ikon.py`,
krever PIL; skriver også A og C). Ingen tekst; mening ligger i form (hake), aldri farge alene.
