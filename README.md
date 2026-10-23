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

## KI-Chat: OmniRoute oder Gemini

Unter **KI-Chat** können zwei Anbindungen gewählt werden. Beide erzeugen nur **Antworten und Codevorschläge**. Die App führt KI-Antworten nicht automatisch aus und verändert weder Projektdateien noch GitHub ohne einen separaten Bedienvorgang.

**1. OmniRoute direkt auf dem Android-Handy (Termux)**

- OmniRoute muss auf **demselben Android-Handy** in Termux laufen. Bei vorhandener Installation beispielsweise `npx -y omniroute` in Termux starten.
- Im Browser kann `http://127.0.0.1:20128` zum Prüfen der lokalen Oberfläche geöffnet werden. Der Chat nutzt intern `http://127.0.0.1:20128/v1/chat/completions` im OpenAI-kompatiblen Format.
- In GameForge AI den Anbieter **OmniRoute (Termux, lokal)** wählen. Als Modell ist `auto/coding` voreingestellt. Ein anderer im OmniRoute-Dashboard verfügbarer Modellname ist ebenfalls möglich.
- Einen **Endpoint-API-Key** nur eintragen, wenn die eigene OmniRoute-Konfiguration einen benötigt. Ist der lokale Server ohne Client-Key freigeschaltet, darf das Feld leer bleiben.
- Die `auto/coding`-Route benötigt mindestens einen geeigneten verbundenen Provider. Sie garantiert weder kostenlose Antworten noch kostenlose Nutzung. Providerpreise und Kontingente vor dem Test prüfen.
- Falls keine Verbindung hergestellt werden kann: Funktioniert die Dashboard-Adresse in Android-Chrome? Ist der Termux-Prozess noch aktiv? Android kann im Hintergrund laufende Dienste stoppen.

**2. Gemini Developer API direkt**

- In [Google AI Studio](https://aistudio.google.com/apikey) einen Gemini-API-Key erstellen.
- In GameForge AI den Anbieter **Gemini API (Google direkt)** auswählen.
- Modell ist zunächst `gemini-2.5-flash`; falls Google den Zugriff oder ein Modell ändert, einen aktuell verfügbaren Modellnamen eintragen.
- API-Key in das geschützte Feld eingeben und eine Nachricht senden. Die App verwendet `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` und den Header `x-goog-api-key`.
- Auch bei Gemini hängen eventuelle Kosten und Limits vom Google-Konto und vom verwendeten Modell ab.

**Privatsphäre und Sicherheit:** Weder Schlüssel noch Unterhaltung werden als Dateien gespeichert oder an GitHub übertragen. Der Gesprächsverlauf bleibt nur während der geöffneten App-Sitzung im Arbeitsspeicher; beim Wechsel zwischen Projekten wird er geleert. Die Schlüssel-Eingabe wird beim Verlassen des KI-Chats gelöscht. Die Nachricht wird an den ausgewählten Dienst gesendet und kann gemäß dessen Bedingungen verarbeitet werden. Keine Passwörter, Tokens oder privaten Repository-Dateien in Nachrichten kopieren. Es werden **keine Projektdateien automatisch an die KI gesendet**, lediglich der Projektname und die von dir selbst geschriebenen Nachrichten.

Die neue KI-Integration muss noch auf Android in beiden Modi praktisch getestet werden.

## Entwicklung / Status

- Godot: **4.7.2**, GL Compatibility Renderer.
- CI: `.github/workflows/validate.yml` (Projektprüfung) und `.github/workflows/android.yml` (Android Debug APK).
- Android-Internetberechtigung: `permissions/internet=true` in `export_presets.cfg`.
- Der GitHub-Dateibrowser und das Laden von Titan-Legends-Textdateien wurden auf Android getestet.
- Der authentifizierte GitHub-Schreibpfad und das manuelle Auslösen des Android-Workflows sind **neu implementiert und müssen noch auf Android getestet** werden.
- Der KI-Chat unterstützt Gemini Developer API und eine lokale OmniRoute-Instanz über HTTPRequest; **die Anbindungen sind noch nicht auf Android praktisch bestätigt**.
- Der vollständige Spielstand von Titan Legends (Update 168) befindet sich noch nicht vollständig im GitHub-Repository.

Private Tokens, Release-Keystores und sonstige Secrets niemals in das öffentliche Repository committen.
