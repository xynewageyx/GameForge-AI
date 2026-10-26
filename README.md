# GameForge AI — Android Game Studio

GameForge AI ist ein Godot-4.7.2-Projekt für Android. Der Quellcode wird über GitHub gepflegt. GitHub Actions erstellt Debug-APKs.

## Auf Android installieren

1. [Android debug APK](https://github.com/xynewageyx/GameForge-AI/actions/workflows/android.yml) öffnen.
2. Einen **erfolgreichen** Workflow-Lauf auswählen.
3. Unter **Artifacts** `GameForgeAI-debug-APK` herunterladen.
4. ZIP entpacken, `GameForgeAI.apk` installieren.

**Achtung:** Die CI unterstützt inzwischen eine **dauerhafte Debug-Signatur über das Repository Secret** `GAMEFORGE_DEBUG_KEYSTORE_BASE64`. Solange dieses Secret fehlt, erzeugt der Workflow weiterhin einen neuen temporären Keystore pro Build. Bei abweichender Signatur kann Android ein Update verweigern. Eine Deinstallation löscht lokale App-Daten; vorher wichtige Dateien sichern. Anleitung unter **Dauerhafte Debug-Signatur** weiter unten.

## Dauerhafte Debug-Signatur für APK-Updates (einmalig auf Android)

Der Android-Workflow kann dieselbe Debug-Signatur in jedem Build verwenden. Dafür muss das **GitHub Actions Repository Secret** `GAMEFORGE_DEBUG_KEYSTORE_BASE64` einmalig eingerichtet werden. Der geheime Keystore wird **nicht** in Git getrackt, ist **nicht** in der APK enthalten und wird in GitHub Actions erst während des Builds entschlüsselt. **Base64 ist keine Verschlüsselung**; den erzeugten Text ausschließlich in GitHub Secrets speichern und niemals in Issues, Commits, Chats oder Screenshots veröffentlichen.

**Einrichtung in Termux auf dem Android-Handy:**

```bash
pkg update
pkg install openjdk-21 gh
mkdir -p ~/.android
keytool -genkeypair -keystore ~/.android/gameforge-debug.keystore \
  -storepass android -alias androiddebugkey -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=GameForge AI Debug,O=GameForge AI,C=DE" -noprompt
gh auth login
base64 -w0 ~/.android/gameforge-debug.keystore | gh secret set GAMEFORGE_DEBUG_KEYSTORE_BASE64 -R xynewageyx/GameForge-AI
```

Die Befehle erzeugen bewusst nur einen **Debug-Schlüssel** mit dem üblichen Android-Debug-Passwort. Er ist **nicht für eine öffentliche Release-Version/Play-Store-Publikation** geeignet. Der GitHub-CLI-Login erfolgt über das eigene GitHub-Konto. Falls Termux `openjdk-21` nicht anbietet, mit `pkg search openjdk` die verfügbaren Pakete prüfen und ein OpenJDK-Paket mit `keytool` installieren.

**Alternativ über GitHub im Browser:** Den Base64-Inhalt von `base64 -w0 ~/.android/gameforge-debug.keystore` als neuen Repository-Secret-Wert unter **Settings → Secrets and variables → Actions → New repository secret** hinterlegen. Den vollständigen Base64-Text **nicht** hier in den Chat einfügen.

Danach den Workflow **Android debug APK** erneut starten. In der Build-Zusammenfassung muss `persistent keystore from GitHub Actions secret` stehen; der im Log angezeigte Zertifikatsfingerabdruck (SHA256) sollte in allen weiteren Builds identisch sein. Die Android-`versionCode` wird automatisch aus der GitHub-Actions-Laufnummer abgeleitet.

**Wichtige Einschränkungen:** Ohne das Secret läuft der Build weiterhin, aber mit einem **neuen temporären Debug-Schlüssel**, der nicht für normale App-Updates taugt; GitHub Actions zeigt eine Warnung. Auch die **erste** APK mit dem neu eingerichteten dauerhaften Schlüssel hat eine andere Signatur als die zuvor zufällig signierten Versionen. Eine **einmalige** Deinstallation kann daher notwendig sein. Vorher unbedingt alle wichtigen lokalen Dateien und Auto-Sicherungen außerhalb der App sichern. Spätere Builds mit **demselben** Secret können bei unveränderter Paketkennung in der Regel als Updates installiert werden. Den Keystore zusätzlich sicher außerhalb von GitHub sichern: Geht er verloren, sind zukünftige signaturgleiche Updates nicht mehr möglich.

## Automatische Sicherung im Code-Editor

Der Code-Editor sichert geänderte Texte **automatisch**, ohne dass die Schaltfläche „Lokal speichern“ gedrückt werden muss.

- **Nach etwa 3 Sekunden ohne neue Eingabe** wird der aktuelle Editorinhalt lokal gesichert.
- Beim Wechsel zwischen Reitern oder Projekten und beim Pausieren/Schließen der App wird nach Möglichkeit sofort gesichert.
- Für verschiedene lokale oder GitHub-Dateien werden getrennte Wiederherstellungen abgelegt: `user://<Projekt>/recovery/<Datei-ID>.json`.
- Die Wiederherstellungen liegen **nur im privaten App-Speicher**. Es gibt keine automatische GitHub-Übertragung.
- Im Reiter **Code** unter **Auto-Sicherungen anzeigen** lassen sich Sicherungen öffnen. Sie werden absichtlich **als eigenständige Entwürfe** wiederhergestellt, damit die ursprünglich geladene Datei nicht unbemerkt überschrieben wird.
- Mit **KI-Entwurf als neue Datei speichern** lässt sich ein wiederhergestellter Entwurf unter einem neuen Dateinamen im Projektverzeichnis `ai_drafts/` speichern. Der Button funktioniert auch für wiederhergestellte Textentwürfe.
- Bei einem absichtlichen lokalen Speichern wird die entsprechende automatische Sicherung gelöscht.
- Auto-Sicherungen sind auf 1 MB pro Datei begrenzt. Bei einem Fehler zeigt der Editor eine Warnung; **Editorinhalt als Backup kopieren** dient als zusätzliche Notlösung.

**Wichtig:** Die Funktion schützt gegen versehentlichen Tabwechsel oder App-Neustart, **nicht** gegen das Löschen von App-Daten oder eine Deinstallation. Da unsere Android-Debug-Builds derzeit wechselnde Signaturen benutzen und eventuell deinstalliert werden müssen, sind wichtige Entwürfe vor einem APK-Update weiterhin außerhalb der App zu sichern. Sie ersetzt auch nicht das regelmäßige Speichern kritischer GitHub-Projektdateien.

Diese Auto-Sicherung gehört zum **GameForge-AI-Code-Editor**. Sie ist nicht mit der getrennten Spielstand-Autosave-Funktion von Titan Legends gleichzusetzen.

## Touch-Bedienung: Scrollen auf Android

Die Oberfläche hat größere Scrollbalken (mindestens 46 Godot-UI-Pixel) und eine empfindliche Touch-Wischbewegung im Hauptbereich. Rechts muss kein schmaler Griff mehr exakt getroffen werden.

- Direkt unter der Menüleiste sind zwei **dauerhaft sichtbare** Tasten: **▲ Seite hoch** und **▼ Seite runter**. Diese verschieben den gesamten Hauptbereich schrittweise um etwa drei Viertel der sichtbaren Höhe.
- Das **KI-Chatprotokoll** hat eigene Tasten **▲ Chat hoch / ▼ Chat runter**.
- Der **GDScript-Editor** hat eigene Tasten **▲ Code hoch / ▼ Code runter**.
- Auch die Scrollleisten innerhalb der Texteingabefelder sind verbreitert. Damit kann zwischen dem Scrollen der gesamten Seite und dem Scrollen innerhalb einer langen Datei unterschieden werden.
- Die Textfelder und ihre bestehenden Daten bleiben dabei unverändert; die Tasten ändern nur den sichtbaren Ausschnitt.

Bitte nach einem erfolgreichen GitHub-Actions-Build auf Android testen. Auf dem Handy ist das Scrollen mit dem Finger durch freie Bereiche der Seite ebenfalls möglich; innerhalb eines TextEditors scrollt man dessen Inhalt separat. Die tatsächliche Touch-Bedienbarkeit kann erst am Gerät vollständig bestätigt werden.

## Android-Editor: Text und Funktionen suchen

Im Reiter **Code** unter dem Editor befindet sich ein Suchfeld mit der Schaltfläche **„Nächsten Treffer suchen“**. Die Suche ignoriert Groß-/Kleinschreibung, markiert die Fundstelle und zeigt Zeile/Spalte an. Wiederholtes Tippen springt zum nächsten Treffer und setzt nach dem letzten Fund am Dateianfang fort. Die Suche ändert den Dateiinhalt nicht und sendet keine Daten an die KI oder an GitHub.

## GDScript-Editor mit CodeEdit

Die Code-Ansicht verwendet jetzt Godots `CodeEdit` statt eines einfachen Textfelds. Für `.gd`-Dateien gibt es **Zeilennummern, Syntaxhervorhebung** (Schlüsselwörter, Kommentare, Zahlen und Strings), automatische Einrückung und Klammerergänzung. Bei `.txt`-Dateien wird die GDScript-Farbgebung deaktiviert. Beim Wechsel zwischen lokalen Dateien, GitHub-Dateien und KI-Entwürfen wird die Hervorhebung aktualisiert.

Die Funktionen verändern **weder Code noch Dateien von selbst**. Der bestehende lokale Speichern-/Auto-Sicherungsprozess und die separate GitHub-Uploadbestätigung bleiben bestehen. Die neuen Editorfunktionen werden in den Offline-CI-Tests überprüft; Touch-Tastatur, Eingabe und Scrollen müssen auf Android zusätzlich praktisch getestet werden.

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

## KI-Verbindungstest in GameForge AI

Im Reiter **KI-Chat** gibt es die Schaltfläche **„OmniRoute / Gemini Verbindung testen“**. Sie ruft **nur den Modellkatalog** ab – keine Chatnachricht, keine Editor-Datei und keinen Analyseauftrag. Die Verbindungsprüfung testet daher **nicht**, ob das ausgewählte Chatmodell tatsächlich eine Antwort erzeugen kann.

- **OmniRoute in Termux**: `npx -y omniroute` starten und in GameForge AI „OmniRoute“ auswählen. Die App prüft ausschließlich `http://127.0.0.1:20128/v1/models`. Bei Verbindungsfehlern sicherstellen, dass der lokale Server läuft und seine API erreichbar ist. Als Chatmodell im Feld den tatsächlich von OmniRoute unterstützten Modellnamen verwenden.
- **Gemini direkt**: Anbieter „Gemini API“ auswählen, einen API-Key in das geschützte Eingabefeld einfügen und den Verbindungstest starten. Die App prüft `https://generativelanguage.googleapis.com/v1beta/models`, überträgt den Schlüssel ausschließlich im HTTP-Header und speichert ihn nicht dauerhaft.

**Ergebnisse**: HTTP 401/403 beim Modellkatalog kann auf eine geschützte Dashboard-/Modelllisten-Sitzung oder fehlenden Endpoint-Key hinweisen und bedeutet nicht zwingend, dass der eigentliche Chat-Endpoint ebenfalls blockiert ist. In OmniRoute unter **Dashboard → Endpoints** einen eigenen Endpoint-API-Key erstellen und in der App eingeben. Das ist weder der GitHub- noch der Gemini-Schlüssel. HTTP 404 zeigt einen nicht gefundenen Endpunkt an; Netzwerkfehler weisen auf fehlende Erreichbarkeit hin. Bei HTTP 200 werden die Anzahl und höchstens drei Modellnamen als Hilfestellung angezeigt. **„Erreichbar“ bedeutet nicht, dass kostenloses Modellkontingent verfügbar ist.**

Nach erfolgreicher Diagnose kann eine **kurze, unkritische Testnachricht** gesendet werden, beispielsweise „Antworte mit OK“. Bei fehlgeschlagenem Test keine Geheimnisse in Screenshots oder in diesen Chat kopieren.

## OmniRoute Chat HTTP 200 ohne lesbaren Text

Wenn im **KI-Chat** beim Kurztest `HTTP 200` zurückkommt, aber kein sichtbarer Text, ist nur der HTTP-Aufruf erfolgreich – **noch keine KI-Textantwort**. Mögliche Ursachen: Das Token-Limit ist während interner Modellverarbeitung erreicht worden (`finish_reason=length`), ein Provider lieferte null Ausgabetokens, die Ausgabe wurde gefiltert, oder ein von OmniRoute weitergereichtes Modell liefert ein anderes Inhaltsformat. Für bestimmte Routing-/Reasoning-Modelle ist dieses Verhalten bereits beobachtet worden; es kann auch bei scheinbar erfolgreichem Provider-HTTP-Status auftreten.

**Neuer Kurztest:** Das sichtbare Antwortlimit wurde von 20 auf **128 Tokens** erhöht, damit ein Modell mit internem Denkaufwand überhaupt Raum für eine sichtbare Antwort hat. Das kann bei einem abrechnenden Anbieter mehr Kontingent als zuvor verbrauchen. Ein Fehler löst **keinen** automatischen, zusätzlichen KI-Aufruf aus. Die App wertet sowohl Textzeichenketten als auch unterstützte Inhaltsbausteine (`content`-Array) aus, zeigt aber **keine** internen `reasoning_content`-Inhalte. Fehlende sichtbare Antworten werden anhand sicherer Metadaten wie `finish_reason` und `usage.completion_tokens` eingeordnet, ohne Original-Antworten oder sensible Provider-Daten einzublenden.

**Prüfen:** Zuerst das Modell `auto` im KI-Chat wählen und **einmal** bewusst den Kurztest starten. Wenn weiterhin `HTTP 200` ohne Antwort erscheint, bei **OmniRoute → Monitoring/Logs** den `finish_reason`, die ausgegebenen Tokens und das verwendete Modell nachsehen. Keine Zugangsschlüssel, Antworten mit persönlichen Daten oder Roh-JSON mit Geheimnissen im Chat teilen. Die Modellliste `GET /v1/models` kann weiter HTTP 401 melden, obwohl der Chat-Endpunkt antwortet; das sind separate Prüfungen.

## OmniRoute Chat HTTP 503: kein einsatzbereiter Anbieter

Wenn GameForge AI beim **echten KI-Chat** `HTTP 503` meldet, ist der lokale OmniRoute-Server zwar erreichbar, aber das angeforderte Modell/der Upstream momentan nicht verfügbar. Häufige Ursachen: kein aktives Provider-Konto für die automatische Route, abgelaufene Upstream-Anmeldung, Provider-Circuit-Breaker oder ein ausgeschöpftes Kontingent. Ein `503` allein beweist **nicht**, welche der Ursachen zutrifft.

**Prüfen:** `http://127.0.0.1:20128/dashboard/providers` öffnen und sicherstellen, dass mindestens ein mit OmniRoute verbundener Anbieter aktiv ist. Unter **Monitoring/Logs** die betroffene Anfrage und deren upstream Fehlergrund prüfen. Wenn ein Anbieter verfügbar ist, im Feld **Modell** testweise `auto` statt `auto/coding` verwenden. `auto` versucht das allgemeine Routing; `auto/coding` bevorzugt Coding-Modelle. Auch `auto` benötigt einen funktionierenden Upstream und gewährleistet weder kostenlose noch erfolgreiche Antworten.

In neueren GameForge-AI-Versionen existieren im **KI-Chat** die Schaltflächen **„OmniRoute-Modell auf auto umstellen (kein Teststart)“** und **„OmniRoute-Provider-Verbindungen öffnen“**. Der Modellwechsel sendet **keine** automatische Anfrage. Erst die separate Schaltfläche **„Kurze KI-Testantwort anfordern“** sendet eine kleine Inferenzanfrage, die Provider-Kontingent verbrauchen kann.

Bei `HTTP 503` versucht die App bekannte Fehlerklassen (z. B. `auth_unavailable`, `usage_limit_reached`, `no eligible candidates` oder Circuit Breaker) aus der JSON-Antwort zu unterscheiden und eine lokale Hilfestellung anzuzeigen. **Die ursprüngliche Serverfehlermeldung wird nicht ungefiltert eingeblendet**, weil sie sensible Anbieterinformationen enthalten kann. Die beste Detaildiagnose bleibt die lokale Monitoring-Ansicht von OmniRoute.

## Separater Chat-Endpunkt-Test bei OmniRoute HTTP 401

`GET /v1/models` und `POST /v1/chat/completions` können in OmniRoute **unterschiedliche Authentifizierungsregeln** haben. Ein `HTTP 401` im Modelllisten-Test beweist **nicht**, dass der eigentliche Chat ebenfalls gesperrt ist.

Im Reiter **KI-Chat** stehen zwei getrennte Schaltflächen bereit:

- **OmniRoute / Gemini Verbindung testen**: Prüft nur `GET /v1/models` beziehungsweise die Gemini-Modellliste; sendet keine Nachricht und verbraucht keine Inferenz-Tokens.
- **Kurze KI-Testantwort anfordern**: Ruft den **echten Chat-Endpunkt** mit der Nachricht „Antworte ausschließlich mit OK.“ auf. Es werden **keine** privaten Projektdateien, kein Chatverlauf und kein GDScript übertragen. Die Antwort ist auf maximal 20 Ausgabe-Tokens begrenzt. **Der Provider kann hierfür trotzdem Inferenzkontingent verbrauchen oder Gebühren berechnen**; deshalb nur bewusst betätigen.

Wenn nur die Modellliste `401` meldet, lässt sich ein funktionierender Chat mit dem zweiten Test unabhängig bestätigen. Ein `401/403` beim Chat-Test deutet auf fehlenden oder nicht akzeptierten Endpoint-Schlüssel hin; `404` eher auf ein nicht vorhandenes Modell oder eine nicht passende Route und `429` auf Rate-Limits/Kontingente. Bei OmniRoute ggf. statt `auto/coding` den Modellnamen `auto` probieren, falls dieser in der lokalen Konfiguration unterstützt wird.

Die Schaltflächen zeigen Ergebnisse getrennt an. Der Test wird beim Verlassen des Chats abgebrochen und verändert keine GitHub-Dateien. Geheimnisse werden nur in HTTP-Headern verwendet und nicht dauerhaft gespeichert.

## Android: Nachrichtenfeld schnell erreichen

Im Reiter **KI-Chat** steht direkt nach der Modell- und Schlüsselauswahl die Schaltfläche **„Nachricht schreiben – direkt zum Eingabefeld“**. Sie fokussiert das Nachrichtenfeld und scrollt zu ihm. Das Chatfenster mit **„Nachricht an KI senden“** befindet sich jetzt **vor** den längeren Diagnose- und Verbindungstests, damit es auch auf kleinen Android-Displays gut erreichbar ist. Der Schnellzugriff sendet selbst keine Nachricht und verändert keine Projektdateien.

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

**Privatsphäre und Sicherheit:** Weder Schlüssel noch Unterhaltung werden als Dateien gespeichert oder an GitHub übertragen. Der Gesprächsverlauf bleibt nur während der geöffneten App-Sitzung im Arbeitsspeicher; beim Wechsel zwischen Projekten wird er geleert. Die Schlüssel-Eingabe wird beim Verlassen des KI-Chats gelöscht. Die Nachricht wird an den ausgewählten Dienst gesendet und kann gemäß dessen Bedingungen verarbeitet werden. Keine Passwörter, Tokens oder privaten Repository-Dateien in Nachrichten kopieren. Es werden **keine Projektdateien automatisch an die KI gesendet**: Nur beim eigens bestätigten Analyseauftrag wird zusätzlich der im Code-Editor angezeigte Dateiinhalt übertragen.

Die neue KI-Integration muss noch auf Android in beiden Modi praktisch getestet werden.

## Vorhandene GDScript-Datei mit KI analysieren

1. Unter **Projekte** das gewünschte Projekt auswählen, z. B. **Titan Legends**.
2. Unter **Code** eine bereits gespeicherte lokale `.gd`-Datei laden oder eine `.gd`-Datei aus GitHub öffnen. Eine unspeicherte, noch nicht existierende Datei muss zuerst lokal gesichert werden.
3. Im Bereich **Vorhandene GDScript-Datei mit KI analysieren** die gewünschte Änderung beschreiben, beispielsweise: „Überarbeite die Berechnung kritischer Treffer, ohne andere Kampffunktionen zu verändern.“
4. **GDScript-Analyse im KI-Chat vorbereiten** drücken. Die App prüft Dateityp, Leerinhalt und Größenlimits, erstellt einen nur im Arbeitsspeicher befindlichen Analyseauftrag und öffnet den KI-Chat.
5. **Noch wird kein Code übertragen.** Die Vorschau zeigt Dateiname, Quelle und Anzahl der Bytes. Erst nach Auswahl des KI-Anbieters und Betätigen von **Dateiinhalt und Änderungswunsch jetzt an KI senden** gehen die Daten an OmniRoute beziehungsweise Gemini. Entferne zuvor API-Tokens, Passwörter oder sonstige Geheimnisse aus dem Code.
6. Die KI soll Fehler/Risiken erklären, die gewünschte Änderung begründen, den vollständigen vorgeschlagenen Dateicode in einem `gdscript`-Markdown-Codeblock liefern und Tests nennen.
7. Nach der Antwort über **GDScript aus KI-Antwort im Editor öffnen** nur den vorgeschlagenen Code als **neuen, ungespeicherten Entwurf** öffnen. Über **KI-Entwurf als neue Datei speichern** wird eine eigenständige lokale Kopie erstellt.

**Wichtig:** Die Originaldatei wird durch die Analyse niemals automatisch überschrieben. GitHub-Commits erfolgen nur separat über die vorhandene bestätigte Upload-Funktion. Die KI führt vorgeschlagenen Code nicht aus. Die Quelldatei wird nicht automatisch im Chatverlauf für Folgeanfragen erneut übertragen. Der Analyseauftrag ist auf 10.000 Zeichen Quellcode und maximal 900 Zeichen Änderungswunsch begrenzt; bei längeren Dateien muss zunächst ein relevanter Ausschnitt im Editor vorbereitet werden. Die Übertragung an den KI-Anbieter kann je nach Modell Kosten verursachen. Die neue Funktion muss noch in der Android-App getestet werden.

## Schnelle GDScript-Übernahme aus dem KI-Chat

Nach einer erfolgreichen Chat-Antwort erkennt GameForge AI einen vollständigen `gdscript`-Codeblock. Direkt unter **„Nachricht an KI senden“** stehen dann **„GDScript aus letzter KI-Antwort als Entwurf öffnen“** und eine Anzeige der erkannten Zeilenanzahl. Bei Antworten ohne passenden Codeblock bleibt die Schaltfläche deaktiviert. Die Übernahme öffnet den Code als **ungespeicherten Entwurf** im Editor; sie verändert weder die ursprüngliche Projektdatei noch das GitHub-Repository.

Wenn im aktuellen Projekt schon ein ungespeicherter KI-Entwurf vorhanden ist, wird eine erneute Übernahme **blockiert**, damit dieser nicht versehentlich überschrieben wird. Erst über **„KI-Entwurf als neue Datei speichern“** eine eigene Kopie anlegen. Es erfolgt kein automatischer Commit und kein automatisches Ausführen des generierten Codes. Die automatische Prüfung deckt die neue Schaltfläche, das Erkennen von Codeblöcken und den Schutz vorhandener Entwürfe ab; die Bedienung auf Android wird separat geprüft.

## KI-Code in den lokalen Editor übernehmen

Der KI-Chat kann GDScript aus einer KI-Antwort an den Code-Editor übergeben, ohne vorhandene Dateien zu überschreiben oder Code auszuführen.

1. Im Bereich **Projekte** zum Beispiel **Titan Legends** aktivieren.
2. Unter **KI-Chat** eine konkrete Frage stellen, z. B.: *Schreibe eine GDScript-Funktion zum Berechnen kritischer Treffer. Antworte mit einem gdscript-Codeblock.*
3. Nachdem die KI geantwortet hat, **GDScript aus KI-Antwort im Editor öffnen** wählen.
4. GameForge AI übernimmt ausschließlich den ersten vollständigen Markdown-Codeblock mit Sprache `gdscript`, `gd` oder ohne Sprachangabe. Andere Sprachen und reine Prosa werden nicht als GDScript eingefügt.
5. Der Bereich **Code** öffnet sich mit **Aktuelle Datei: KI-Entwurf (noch nicht gespeichert)**. Den vorgeschlagenen Code prüfen und gegebenenfalls bearbeiten.
6. **KI-Entwurf als neue Datei speichern** drücken. Die App legt eine neue Datei im Verzeichnis `user://<Projekt>/ai_drafts/ki_entwurf_YYYYMMDD_HHMMSS.gd` an. Existiert der Name bereits, wird eine freie Nummer ergänzt. Bestehende Dateien bleiben unverändert.
7. Im Dateiauswahl-Menü können gespeicherte `ai_drafts/*.gd`-Dateien später wieder geladen und bearbeitet werden.

Während der App-Sitzung kann ein noch nicht gespeicherter KI-Entwurf über **Ungespeicherten KI-Entwurf wieder öffnen** wiederhergestellt werden, auch wenn zwischen Menüs gewechselt wurde. Mit **Editorinhalt als Backup kopieren** lässt sich der Code zum Sichern in eine andere Android-App kopieren. Beim Beenden oder Deinstallieren der App gehen ungespeicherte Entwürfe beziehungsweise private App-Daten möglicherweise verloren. Insbesondere die derzeitige Debug-Signierung kann Neuinstallationen erforderlich machen: **Wichtige Dateien vor jedem APK-Update außerhalb der App sichern.**

**Wichtig:** Die KI-Datei ist ein lokaler Textentwurf. Sie wird **nicht** automatisch in die aktive Godot-Spielszene eingebunden, nicht ausgeführt und nicht auf GitHub hochgeladen. Die KI kann Fehler enthalten; alle Codeänderungen müssen überprüft und getestet werden. Für einen anschließenden GitHub-Commit wird ein eigener, bestätigter Upload-Vorgang benötigt. Diese neue Funktion muss noch auf Android getestet werden.

## Entwicklung / Status

- Godot: **4.7.2**, GL Compatibility Renderer.
- CI: `.github/workflows/validate.yml` (Projektprüfung) und `.github/workflows/android.yml` (Android Debug APK).
- Android-Internetberechtigung: `permissions/internet=true` in `export_presets.cfg`.
- Der GitHub-Dateibrowser und das Laden von Titan-Legends-Textdateien wurden auf Android getestet.
- Der authentifizierte GitHub-Schreibpfad, das manuelle Auslösen des Android-Workflows, der KI-Code-Entwurfseditor und die bestätigte KI-Dateianalyse sind **implementiert, aber noch nicht vollständig auf Android getestet**.
- Der KI-Chat unterstützt Gemini Developer API und eine lokale OmniRoute-Instanz über HTTPRequest; **die Anbindungen sind noch nicht auf Android praktisch bestätigt**.
- Der vollständige Spielstand von Titan Legends (Update 168) befindet sich noch nicht vollständig im GitHub-Repository.

Private Tokens, Release-Keystores und sonstige Secrets niemals in das öffentliche Repository committen.
