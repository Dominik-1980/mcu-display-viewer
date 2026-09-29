# MCU Display Viewer

**Acht MCU-Displayfelder für Logic Pro**

[![Auf Ko-fi unterstützen](https://img.shields.io/badge/Ko--fi-Unterst%C3%BCtzen-FF5E5B?style=for-the-badge&logo=kofi&logoColor=white)](https://ko-fi.com/dominik_w)
[![Mit PayPal unterstützen](https://img.shields.io/badge/PayPal-Unterst%C3%BCtzen-003087?style=for-the-badge&logo=paypal&logoColor=white)](https://paypal.me/DominikWeiland)

MCU Display Viewer ist eine native macOS-App für acht MCU-Displayfelder.
Sie zeigt Namen, Werte und Logic-Farben an.
Die integrierte CoreMIDI-Bridge empfängt Logics MCU-Daten und leitet sie an
einen wählbaren physischen MIDI-Ausgang weiter.

## Schnellstart

1. Lade die [DMG-Datei von GitHub Releases](https://github.com/Dominik-1980/mcu-display-viewer/releases/latest)
   herunter und öffne sie. Ziehe `MCU Display Viewer.app` auf die
   Verknüpfung **Programme**.
2. Verbinde deinen Controller und öffne die App **vor Logic Pro**. Wähle
   unter **MIDI → Ausgangsgerät** den physischen MIDI-Ausgang des Controllers.
3. Öffne in Logic Pro **Bedienoberflächen → Setup**. Behalte bei der
   **vorhandenen** Mackie-Control-Instanz den physischen Controller als Eingang
   bei und wähle `MCU Display Bridge` als Ausgang. Lege keine zweite
   Mackie-Control-Instanz an.
4. Wechsle in Logic eine Spur und prüfe die acht Felder sowie die Statuszeile
   der App. Der Controller sollte weiterhin auf Logic reagieren.

Die Bridge ist nur verfügbar, solange die App läuft. CoreMIDI liefert
Display-Daten erst bei neuen Nachrichten. Wenn die Felder nach dem Start leer
bleiben, wechsle in Logic eine Spur oder öffne das Projekt erneut.

## Was die App kann

| Bereich | Funktionen |
| --- | --- |
| Display | Namen, Werte und Logic-Farben für acht MCU-Kanäle anzeigen |
| MIDI-Bridge | Logics MCU-Daten an einen wählbaren Controller-Ausgang weiterleiten |
| Fenster | Acht Felder je nach Breite in 8, 4, 2 oder 1 Spalte anordnen |
| Ansicht | Leere Kanäle dezent anzeigen und das Fenster optional im Vordergrund halten |
| Einstellungen | MIDI-Ausgang sowie Fenstergröße und -position speichern |
| Status | Bridge, gewählten Ausgang und empfangene MIDI-Daten anzeigen |

Unter **MIDI → Logic einrichten …** zeigt die App die nötige Zuordnung
noch einmal an. Nach einem MIDI-Gerätewechsel sucht sie den gespeicherten
Ausgang erneut.

## Voraussetzungen und erster Start

Der Download enthält eine App für **Apple Silicon ab macOS 13**. Für den
beschriebenen Signalweg benötigst du Logic Pro und einen physischen
MCU-kompatiblen Controller.

Version 1.0.0 ist lokal signiert, aber noch nicht mit einer Apple Developer ID
signiert oder von Apple notarisiert. macOS kann den ersten Start deshalb
blockieren. Wenn du den Download aus dem offiziellen Repository geprüft hast,
versuche die App einmal zu öffnen und wähle dann unter **Systemeinstellungen →
Datenschutz & Sicherheit → Dennoch öffnen**. Siehe dazu
[Apples Anleitung zum sicheren Öffnen von Apps](https://support.apple.com/de-de/102445).
Die [SHA-256-Prüfsumme](https://github.com/Dominik-1980/mcu-display-viewer/releases/latest)
liegt beim Download als `SHA256SUMS` bei.

## Versionierung

`1.0.x` steht für Fehlerkorrekturen, `1.x.0` für neue Funktionen und
`x.0.0` für größere Versionssprünge mit Änderungen an Bedienung oder
Zuordnungen.

## Lizenz

Copyright © 2026 Dominik Weiland. MCU Display Viewer wird unter der
**GNU General Public License Version 3 (GPL-3.0-only)** veröffentlicht.
Den vollständigen Lizenztext findest du in [LICENSE](LICENSE).
Der Quellcode ist in diesem GitHub-Repository verfügbar.

## Entwicklung unterstützen

Wenn dir MCU Display Viewer hilft, kannst du die Entwicklung freiwillig über
[Ko-fi](https://ko-fi.com/dominik_w) oder
[PayPal](https://paypal.me/DominikWeiland) unterstützen.
Im App-Menü findest du außerdem **Über MCU Display Viewer** sowie direkte
Links zu beiden Seiten.

## Für Entwickler

Das native Xcode-Projekt ist `MCUDisplayViewer.xcodeproj` mit dem Scheme
`MCU Display Viewer` und Ziel **My Mac**. Das Swift-Package verwendet dieselben
Quellen und enthält Parser-Tests:

```sh
xcrun swift test --disable-sandbox --scratch-path /tmp/mcu-display-build --cache-path /tmp/mcu-display-spm-cache --manifest-cache local
./scripts/build-app.sh
./scripts/package-dmg.sh
```

Der Skript-Build legt `build/MCU Display Viewer.app` ab. Das Paket-Skript
erstellt unter `dist/` eine DMG mit App, Programme-Verknüpfung, README und
Lizenz sowie die Datei `SHA256SUMS`.

Die App setzt MCU-Display-Teilupdates
(`F0 00 00 66 14 12 <Position> <Text> F7`) in einem
112-Zeichen-Puffer zusammen. Die acht Farbcodes kommen als
`F0 00 00 66 14 72 <8 Farben> F7`; Werte von 0 bis 7 stehen für
aus, Rot, Grün, Gelb, Blau, Violett, Cyan und Weiß.
