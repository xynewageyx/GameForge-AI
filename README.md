# GameForge AI — Android Game Studio

GameForge AI ist ein Godot-4.7.2-Projekt für Android. Der Quellcode wird über GitHub gepflegt. GitHub Actions erstellt Debug-APKs.

## Auf Android installieren

1. [Android debug APK](https://github.com/xynewageyx/GameForge-AI/actions/workflows/android.yml) öffnen.
2. Einen **erfolgreichen** Workflow-Lauf auswählen.
3. Unter **Artifacts** `GameForgeAI-debug-APK` herunterladen.
4. ZIP entpacken, `GameForgeAI.apk` installieren.

**Achtung:** Die CI erzeugt aktuell pro Build einen neuen Debug-Keystore. Android kann deshalb Updates mit abweichender Signatur ablehnen. Eine Deinstallation der vorherigen Version kann erforderlich sein und löscht lokale App-Daten. Vorher lokale Dateien sichern. Dauerhafte Signierung ist noch nicht eingerichtet.

## Projektverwaltung und Editor

- Projekt im Bereich **Projekte** auswählen (GameForge AI oder Titan Legends).
- Im Bereich **Code** lokale Dateien bearbeiten und speichern.
- Über **GitHub-Ordner anzeigen** öffentliche Repository-Dateien durchsuchen.
- Datei antippen: Inhalt wird im Editor geladen.
- Über **GitHub-Datei als lokale Kopie sichern** wird eine **neue Datei im privaten Android-App-Speicher** angelegt. Bestehende Kopien werden nicht überschrieben.

Aktuelle Projektzuordnung:
- GameForge AI: `xynewageyx/GameForge-AI`
- Titan Legends: `xynewageyx/TitanLegend`
- MangaForge AI: bislang nur lokaler Arbeitsbereich (noch kein Repository zugeordnet).

## GitHub-Änderungen veröffentlichen (experimentell)

Der Upload ist **nicht** für unbeaufsichtigte Veröffentlichung vorgesehen; GitHub schreibt bei Bestätigung direkt in den Standardbranch des Repositories.

1. Auf https://github.com/settings/personal-access-tokens/new einen **fine-grained Personal Access Token** für das konkrete Repository erstellen. Nur **Contents: Read and write** gewähren, Ablaufdatum kurz halten. Nicht hier im Chat, in Screenshots oder im Repository veröffentlichen.
2. In GameForge AI eine vorhandene GitHub-Textdatei laden und im Editor ändern.
3. Nach unten zum Bereich **Änderungen auf GitHub veröffentlichen** scrollen.
4. Token im geschützten Eingabefeld einfügen. Optional eine Commit-Nachricht eingeben.
5. **Änderung prüfen** wählen. Die App holt den aktuellen GitHub-Datei-SHA erneut ab und bricht bei einer abweichenden Version ab.
6. Repository und Dateipfad in der Vorschau kontrollieren und **Hochladen verbindlich bestätigen** wählen.
7. Nur bei Erfolgsmeldung gilt der Commit als bestätigt; sonst im GitHub-Browser prüfen.

GitHub verlangt beim Aktualisieren einer Datei ihren bisherigen Blob-SHA. Der Upload sendet den SHA mit und behandelt Versionskonflikte (HTTP 409/422) als Fehler. Das schützt vor vielen, aber nicht allen denkbaren Konfliktsituationen. Für kritische Arbeiten sollten Änderungen erst in einem gesonderten Branch geprüft werden; Branch- und Pull-Request-Funktionen fehlen derzeit noch.

**Token-Sicherheit:** Der Token wird nicht in einer lokalen Datei gespeichert oder in GitHub-Commits eingebettet. Er wird ausschließlich zur Anfrage an `https://api.github.com` verwendet und nach einem erfolgreichen Upload aus dem Eingabefeld gelöscht. Bei jedem erneuten Öffnen der Code-Ansicht muss er neu eingegeben werden. Verwende nur den kleinsten benötigten Berechtigungsumfang.

## APK-Builds direkt aus der App

Im Reiter **Builds** zeigt **Letzte Build-Ergebnisse abrufen** die letzten GitHub-Actions-Läufe für `xynewageyx/GameForge-AI`. Tippe auf einen Eintrag, um den entsprechenden Build im Browser zu öffnen. Dieser Lesezugriff benötigt bei einem öffentlichen Repository keinen Token.

Ein neuer APK-Build kann über **Build-Auftrag prüfen** und die zweite Schaltfläche **Android-Build verbindlich starten** ausgelöst werden. Voraussetzungen:

1. Erstelle einen **fine-grained GitHub-Token**, der ausschließlich `xynewageyx/GameForge-AI` umfasst, mit **Actions: Read and write**. Ein Token nur mit Contents-Rechten ist dafür nicht ausreichend.
2. Gib den Token ausschließlich in GameForge AI unter **Builds** ein.
3. Prüfe, dass Repository `xynewageyx/GameForge-AI`, Workflow `android.yml` und Branch `main` angezeigt werden.
4. Bestätige den Start. GitHub antwortet bei erfolgreicher Annahme mit HTTP 204. Dies bestätigt **nur die Annahme des Auftrags**, nicht den erfolgreichen APK-Build.
5. Lade anschließend die Build-Liste erneut. Die fertige APK findest du weiterhin auf der jeweiligen GitHub-Actions-Webseite unter **Artifacts**.

Der Token wird weder in eine Datei geschrieben noch im Repository hinterlegt; die Eingabe wird beim Auslösen des Build-Auftrags geleert. Niemals Screenshots mit sichtbaren Zugangsdaten teilen.

Der Builds-Reiter startet derzeit **nur** den GameForge-AI-Android-Workflow, nicht die Build-Workflows von Titan Legends. Die Funktion muss noch auf einem Android-Gerät mit gültigen Actions-Schreibrechten getestet werden.

## Entwicklung / Status

- Godot: **4.7.2**, GL Compatibility Renderer.
- CI: `.github/workflows/validate.yml` (Projektprüfung) und `.github/workflows/android.yml` (Android Debug APK).
- Android-Internetberechtigung: `permissions/internet=true` in `export_presets.cfg`.
- Der GitHub-Dateibrowser und das Laden von Titan-Legends-Textdateien wurden auf Android getestet.
- Der authentifizierte GitHub-Schreibpfad und das manuelle Auslösen des Android-Workflows sind **neu implementiert und müssen noch auf Android getestet** werden.
- Der KI-Chat ist noch nicht mit einem Backend verbunden.
- Der vollständige Spielstand von Titan Legends (Update 168) befindet sich noch nicht vollständig im GitHub-Repository.

Private Tokens, Release-Keystores und sonstige Secrets niemals in das öffentliche Repository committen.
