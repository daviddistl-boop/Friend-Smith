# Friendsmith veröffentlichen

## Vor dem ersten Upload (einmalig)
1. **Interface-Nummer prüfen:** Im Spiel `/dump select(4, GetBuildInfo())` eingeben und die Zahl in
   `Friendsmith.toc` bei `## Interface:` eintragen (aktuell steht dort 16001 – nicht verifiziert).
2. **Live-Test:** `python tools/build_zip.py`, das Zip in `Interface\AddOns\` entpacken, mit
   `/console scriptErrors 1` spielen: Fenster, Berufsfenster-Leiste, Minimap-Button, Sync mit einem Gildenmitglied.
3. **CurseForge-Projekt anlegen:** https://authors.curseforge.com → *Create Project* → World of Warcraft → Addon.
   - Name: Friendsmith, Kategorie: Professions (ggf. zusätzlich Guild)
   - Lizenz auswählen (z. B. MIT oder All Rights Reserved – deine Entscheidung)
   - Projektbild: `assets/logo-400.png`
   - Beschreibung: Text aus `CURSEFORGE.md`
   - Spielversion: die passende WoW-Forever/Classic-Variante
4. Die **Projekt-ID** (steht rechts auf der Projektseite) in `Friendsmith.toc` eintragen:
   `## X-Curse-Project-ID: 123456`

## Weg A: Automatisch über GitHub (empfohlen)
1. Leeres Repository auf GitHub anlegen und diesen Ordner hochladen (`git remote add origin …`, `git push`).
2. CurseForge → Profil → *API Tokens* → Token erzeugen. Auf GitHub unter
   *Settings → Secrets and variables → Actions* als `CF_API_KEY` speichern.
3. Für jede Version: Versionsnummer in `Friendsmith.toc` erhöhen, `CHANGELOG.md` ergänzen, committen, dann
   `git tag v0.3.0` und `git push --tags`.
   Der Workflow `.github/workflows/release.yml` baut das Paket mit den Bibliotheken aus `.pkgmeta`
   (LibStub, CallbackHandler, LibDataBroker, LibDBIcon) und lädt es hoch.

## Weg B: Manuell
1. `python tools/build_zip.py` → `dist/Friendsmith-<Version>.zip`.
2. Auf der Projektseite *Upload File* → Zip wählen, Spielversion und Changelog angeben.
   Ohne `Libs/`-Ordner erscheint der Broker-Eintrag nur, wenn ein anderes Addon die Bibliotheken
   mitbringt (jede Broker-Leiste tut das). Der Minimap-Button funktioniert immer.

## Bei jeder neuen Version
- `## Version:` in `Friendsmith.toc` (wird auch im Fenster angezeigt)
- Eintrag in `CHANGELOG.md`
