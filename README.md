# Friendsmith (WoW Forever)

Zeigt, wer in deiner Gilde – und unter deinen eigenen Twinks – wem ein Ausrüstungs-Upgrade craften kann.
Gedacht für Craftlocked-Gilden, funktioniert aber für jede Gilde.
Sprachen: Englisch und Deutsch – das Addon richtet sich nach der Sprache des Spiel-Clients.
Neue Sprachen kommen als Block in `Locales.lua` dazu.

## Was es macht
- Speichert von jedem deiner Charaktere die angelegte Ausrüstung und alle gelernten Rezepte für Ausrüstung.
- Tauscht diese Daten unsichtbar über den Gildenkanal mit allen aus, die das Addon ebenfalls haben.
- Rechnet aus, welche craftbaren Teile für welchen Charakter besser sind als das, was er gerade trägt.
- Zeigt das in einem Fenster (`/fsmith`) mit drei Ansichten:
  - **Für mich** – wer kann dir oder deinen Twinks etwas Besseres craften?
  - **Ich kann craften** – für wen kannst du mit deinen Berufen etwas Besseres craften (Twinks und Gilde)?
  - **Ganze Gilde** – alles auf einen Blick.
  Die Liste ist wie im Berufsfenster nach Charakter (oder Handwerker) gruppiert und einklappbar.
  Rechts stehen Details, ein Vergleich mit dem getragenen Teil und Knöpfe zum Anfragen/Anbieten per Flüstern.
- Hängt eine **Leiste ans Berufsfenster**: „Upgrades für dich“, „Upgrades für <Twink>“, „Upgrades für <Gildenmitglied>“
  aus dem gerade offenen Beruf. Klick öffnet das Rezept, Rechtsklick zeigt es im Friendsmith-Fenster.
  Die Leiste lässt sich am Kopf verschieben und in der Seitenleiste des Fensters abschalten.
- Im Tooltip jedes Gegenstands: „craftbar von …“ und „Upgrade für …“.
- **Addon-Button** mit eigenem Logo: als Broker-Eintrag in Leisten wie Titan Panel, ChocolateBar oder Bazooka
  (zeigt „X für mich · Y craftbar“), als Minimap-Button (über LibDBIcon, sonst ein eigener, am Rand verschiebbar)
  und im Addon-Menü an der Minimap. Linksklick öffnet das Fenster, Rechtsklick zeigt „Ich kann craften“.

## Installation
1. Den Ordner `Friendsmith` (mit den `.lua`- und `.toc`-Dateien darin) nach
   `...\World of Warcraft\<Forever-Ordner>\Interface\AddOns\` kopieren.
   Den richtigen Spielordner findest du im Battle.net-Launcher bei WoW Forever über
   das Zahnrad → „Im Explorer anzeigen“.
2. Im Charakterauswahl-Bildschirm unter „AddOns“ prüfen, dass Friendsmith aktiviert ist.
   Falls es als „veraltet“ markiert ist: „Veraltete AddOns laden“ anhaken.
3. Nach dem Kopieren das Spiel ganz neu starten (nicht nur `/reload`).

## Einrichtung
1. Mit **jedem** Charakter einmal einloggen (Ausrüstung wird automatisch gespeichert).
2. Bei jedem Handwerker einmal **jedes Berufsfenster öffnen**. Am besten alle Kategorien
   aufklappen und Filter (z. B. „nur herstellbare“) ausschalten, damit alle Rezepte erfasst werden.
3. Alle in der Gilde installieren das Addon. Beim Einloggen tauschen sich alle automatisch aus,
   manuell geht es mit dem Knopf „Gilde syncen“ oder `/fsmith sync`.

## Befehle
| Befehl | Wirkung |
|---|---|
| `/fsmith` | Fenster öffnen/schließen |
| `/fsmith sync` | Daten mit der Gilde austauschen |
| `/fsmith scan` | offenes Berufsfenster neu einlesen |
| `/fsmith diff 3` | erst ab +3 Itemlevel bzw. +3 % (Spec-Bewertung) als Upgrade zählen (Standard: 1) |
| `/fsmith ruestung` | auch niedrigere Rüstungsklassen vorschlagen (an/aus) |
| `/fsmith minimap` | Minimap-Button ein/aus |
| `/fsmith reset` | Daten anderer Gildenmitglieder löschen |
| `/fsmith hilfe` | Befehlsübersicht |

Im Fenster: Klick zeigt Details, Shift-Klick verlinkt im Chat, Strg-Klick probiert an, Mausrad scrollt, Suche oben rechts.

## Wie „Upgrade“ bewertet wird (Grenzen)
- **Nach Spezialisierung:** Sobald ein Charakter Talentpunkte verteilt hat, zählt der Talentbaum mit den
  meisten Punkten. Die Werte (Stärke, Beweglichkeit, Zaubermacht, Waffen-DPS, Rüstung …) werden je nach Spec
  gewichtet und mit dem getragenen Teil verglichen – inklusive Zufallswerten wie „… des Affen“.
  Angezeigt wird, um wie viel Prozent das neue Teil besser ist.
- Zauber-Ausrüstung für Krieger und Schurken bzw. Nahkampf-Ausrüstung für Zauberer wird dabei weggelassen.
- Ohne Talentpunkte (oder mit ausgeschaltetem „Nach Spec-Werten“) zählt nur das **Itemlevel**.
- Pro Charakter lässt sich die Bewertung im Detailbereich über „ändern“ festlegen
  (Automatisch → Talentbaum 1/2/3 → nur Itemlevel). Das gilt nur bei dir.
- Die Gewichtungen sind grobe Leveling-Werte. Rückmeldungen sind willkommen.
- Rüstung: Standardmäßig nur die beste Rüstungsklasse (Stoff/Leder/Kette/Platte) nach
  Classic-Regeln. Krieger und Paladine bekommen ab Level 40 Platte, Jäger und Schamanen ab 40 Kette.
- Waffen: nach den Classic-Waffenfähigkeiten der Klasse (Schurken zusätzlich 1H-Äxte, wie in Forever).
- Teile, die erst bis zu 2 Level über dem aktuellen Level tragbar sind, werden mit angezeigt.
- Pro Charakter und Platz werden höchstens die 3 besten Vorschläge gezeigt – plus bis zu 3, die du selbst craften kannst.
- Beim Aufheben gebundene Teile (BoP) werden nur dem Handwerker selbst vorgeschlagen, weil man sie nicht weitergeben kann.
- Nur Charaktere derselben Gilde (plus deine eigenen Charaktere) werden berücksichtigt.
  Daten, die älter als 30 Tage sind, werden ignoriert.

## Hinweise
- Das Addon wurde außerhalb des Spiels gegen eine nachgebaute Schnittstelle getestet, aber noch
  nicht live in WoW Forever. Forever schränkt Addons stellenweise ein. Falls ein Lua-Fehler
  auftaucht: mit `/console scriptErrors 1` Fehler anzeigen lassen und die Meldung kopieren.
- Im Kampf sendet und rechnet das Addon nichts.
