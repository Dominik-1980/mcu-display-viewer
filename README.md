# MCU Display Viewer

Native macOS-Anzeige und MIDI-Bridge für acht MCU-Scribble-Strips. Die App stellt den virtuellen CoreMIDI-Eingang `MCU Display Bridge` bereit, zeigt Logics Display- und Farbdaten an und leitet den gesamten MIDI-Strom an einen wählbaren Ausgang weiter. 

## Starten

Im Menü `MIDI → Ausgangsgerät` den physischen MIDI-Ausgang des Controllers wählen. Die Auswahl wird gespeichert und nach einem Gerätewechsel erneut gesucht. Die Bridge ist nur vorhanden, solange die App läuft; deshalb die App vor Logic öffnen.

In Logic Pro unter `Bedienoberflächen → Setup` bei der **vorhandenen** Mackie-Control-Instanz den Eingang des physischen Controllers beibehalten und als Ausgang `MCU Display Bridge` wählen. Keine zweite Mackie-Control-Instanz anlegen.

CoreMIDI liefert nur neue Nachrichten. Wird die App nach Logic geöffnet, kann sie zunächst leere Felder zeigen, bis Logic die Display-Daten erneut sendet. Ein Spurwechsel oder erneutes Öffnen des Logic-Projekts kann die Anzeige aktualisieren.

## Bedienung

- Das Fenster ist frei skalierbar. Die acht Felder ordnen sich je nach Breite in acht, vier, zwei oder einer Spalte an.
- Kanäle ohne Namen und Wert bleiben als dunkle, nummerierte Felder sichtbar. Sobald Daten eintreffen, zeigt das Feld wieder seine Logic-Farbe.
- `Ansicht → Immer im Vordergrund` schaltet die schwebende Fensterebene um. Der Zustand bleibt gespeichert.
- `MIDI → Ausgangsgerät` zeigt verfügbare MIDI-Ziele. Der Controller-Ausgang ist frei wählbar; die Einstellung gilt auch nach einem Neustart. `MIDI → Logic einrichten …` zeigt die nötige Logic-Zuordnung.
- Fenstergröße und Position werden beim Schließen gespeichert.
- Die Statuszeile zeigt, ob die Bridge bereit ist, welcher Ausgang gewählt wurde und ob MIDI-Daten empfangen wurden. Bei einem Portwechsel sucht die App den gespeicherten Ausgang erneut.


## Bauen

`MCUDisplayViewer.xcodeproj` in Xcode öffnen und das Schema `MCU Display Viewer` für `My Mac` bauen. Das Xcode-Projekt und Swift Package Manager verwenden dieselben Swift-Quelldateien.

Alternativ lokal:

```sh
./scripts/build-app.sh
```

Das Skript erstellt eine ad-hoc signierte App unter `build/`. Für Parser-Tests:

```sh
xcrun swift test --disable-sandbox --scratch-path /tmp/mcu-display-build --cache-path /tmp/mcu-display-spm-cache --manifest-cache local
```

## Release-DMG

Nach `./scripts/build-app.sh` erstellt `./scripts/package-dmg.sh` ein DMG und eine Prüfsummendatei unter `dist/`. Das DMG enthält die App, einen Link zum Programme-Ordner, diese Anleitung und die Lizenz. Die App ist für Apple Silicon ab macOS 13 gebaut.

Der Build ist ad-hoc signiert und nicht durch Apple notarisiert. macOS kann deshalb das erste Öffnen blockieren. Prüfe vor dem Öffnen die SHA-256-Prüfsumme und verwende bei Bedarf **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen**. [Apple erklärt diesen Schritt](https://support.apple.com/102445). Für eine reguläre Verteilung ohne diese Hürde wäre eine Developer-ID-Signatur mit Notarisierung nötig.

Der Quellcode steht unter **GPL-3.0-only**; der vollständige Lizenztext liegt in [LICENSE](LICENSE).

## Empfangene Nachrichten

- MCU-Display-Text: `F0 00 00 66 14 12 <Position> <Text> F7` — Teilupdates werden in einem 112-Zeichen-Puffer zusammengesetzt.
- X-Touch-Farben: `F0 00 00 66 14 72 <8 Farben> F7` — Codes 0 bis 7 für aus, Rot, Grün, Gelb, Blau, Violett, Cyan, Weiß.
