extends Node
## Kleine, zustandslose HTTP-Anbindung für Gemini und OmniRoute.
## Geheimnisse werden nur als HTTP-Header verwendet und nicht auf Platte gespeichert.

signal answered(success: bool, reply: String)
signal diagnosed(success: bool, details: String)

var http_request: HTTPRequest
var request_running: bool = false
var current_provider: String = ""
var diagnostic_request: HTTPRequest
var diagnostic_running: bool = false
var diagnostic_provider: String = ""

func _ready() -> void:
    http_request = HTTPRequest.new()
    http_request.timeout = 90.0
    http_request.body_size_limit = 2097152
    http_request.max_redirects = 0
    add_child(http_request)
    http_request.request_completed.connect(_on_request_completed)
    diagnostic_request = HTTPRequest.new()
    diagnostic_request.timeout = 12.0
    diagnostic_request.body_size_limit = 1048576
    diagnostic_request.max_redirects = 0
    add_child(diagnostic_request)
    diagnostic_request.request_completed.connect(_on_diagnostic_completed)

func is_busy() -> bool:
    return request_running

func cancel() -> void:
    if request_running:
        http_request.cancel_request()
        request_running = false

## Prüft nur feste Modellkatalog-Endpunkte, ohne Chattext oder Projektcode zu senden.
func is_diagnosing() -> bool:
    return diagnostic_running

func cancel_diagnosis() -> void:
    if diagnostic_running:
        diagnostic_request.cancel_request()
        diagnostic_running = false

func diagnose(provider: String, api_key: String) -> int:
    if diagnostic_running or request_running:
        return ERR_BUSY
    var url := ""
    var headers := PackedStringArray(["Accept: application/json"])
    if provider == "omniroute":
        url = "http://127.0.0.1:20128/v1/models"
        if not api_key.is_empty():
            headers.append("Authorization: Bearer " + api_key)
    elif provider == "gemini":
        if api_key.is_empty():
            return ERR_UNAUTHORIZED
        url = "https://generativelanguage.googleapis.com/v1beta/models"
        headers.append("x-goog-api-key: " + api_key)
    else:
        return ERR_INVALID_PARAMETER
    var err := diagnostic_request.request(url, headers, HTTPClient.METHOD_GET)
    if err == OK:
        diagnostic_running = true
        diagnostic_provider = provider
    return err

func _on_diagnostic_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if not diagnostic_running:
        return
    diagnostic_running = false
    var service_name := "OmniRoute" if diagnostic_provider == "omniroute" else "Gemini"
    if result != HTTPRequest.RESULT_SUCCESS:
        var hint := service_name + ": Netzwerkfehler " + str(result) + "."
        if diagnostic_provider == "omniroute":
            hint += " OmniRoute in Termux starten und 127.0.0.1:20128 prüfen."
        else:
            hint += " Internetverbindung und Android-INTERNET-Berechtigung prüfen."
        diagnosed.emit(false, hint)
        return
    if code == 401 or code == 403:
        diagnosed.emit(false, service_name + ": HTTP " + str(code) + " – API-Schlüssel bzw. Endpoint-Berechtigung prüfen.")
        return
    if code == 404:
        diagnosed.emit(false, service_name + ": HTTP 404 – der Modell-Endpunkt ist nicht vorhanden.")
        return
    if code == 429:
        diagnosed.emit(false, service_name + ": HTTP 429 – zu viele Anfragen oder Kontingent erreicht.")
        return
    if code != 200:
        diagnosed.emit(false, service_name + ": HTTP " + str(code) + " – bitte die Servereinstellungen prüfen.")
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not data is Dictionary:
        diagnosed.emit(false, service_name + ": HTTP 200, aber keine gültige JSON-Modellliste.")
        return
    var entries: Variant = data.get("data", []) if diagnostic_provider == "omniroute" else data.get("models", [])
    if not entries is Array:
        diagnosed.emit(false, service_name + ": erreichbar, aber Modellliste hat ein unbekanntes Format.")
        return
    var examples := ""
    var shown := 0
    for entry in entries:
        if not entry is Dictionary or shown >= 3:
            continue
        var model_id := str(entry.get("id", "")) if diagnostic_provider == "omniroute" else str(entry.get("name", ""))
        if model_id.is_empty():
            continue
        examples += (", " if shown > 0 else "") + model_id
        shown += 1
    var message := service_name + " erreichbar. " + str(entries.size()) + " Modelle gefunden."
    if shown > 0:
        message += " Beispiele: " + examples
    else:
        message += " Noch kein Modell sichtbar; Modell/Routing prüfen."
    message += " (Kein Test einer Chat-Antwort.)"
    diagnosed.emit(true, message)

func send(provider: String, model: String, api_key: String, project_name: String, user_text: String, history: Array) -> int:
    if request_running:
        return ERR_BUSY
    if model.is_empty() or model.length() > 120:
        return ERR_INVALID_PARAMETER
    if user_text.is_empty() or user_text.length() > 12000:
        return ERR_INVALID_PARAMETER
    var system_prompt := "Du bist GameForge AI, ein deutschsprachiger Entwicklungsassistent für Godot 4.7.2 und Android. Aktives Projekt: " + project_name + ". Gib nachvollziehbare GDScript-Vorschläge und weise auf ungetesteten Code hin. Du hast hier keinen automatischen Zugriff auf Repository-Dateien, Projektzustände oder Gerätefunktionen. Antworte konkret und führe keine Änderungen oder Commits eigenständig aus. Wenn du GDScript-Code lieferst, verwende einen vollständigen Markdown-Codeblock mit der Sprachangabe gdscript, damit der Benutzer ihn bewusst in den lokalen Code-Editor übernehmen kann."
    var url := ""
    var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
    var payload := ""
    if provider == "gemini":
        if api_key.is_empty():
            return ERR_UNAUTHORIZED
        for ch in model:
            if not (ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"):
                return ERR_INVALID_PARAMETER
        url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent"
        headers.append("x-goog-api-key: " + api_key)
        var contents: Array = []
        for entry in history:
            if not entry is Dictionary:
                continue
            var role := "model" if str(entry.get("role", "")) == "assistant" else "user"
            contents.append({"role": role, "parts": [{"text": str(entry.get("content", ""))}]})
        contents.append({"role": "user", "parts": [{"text": user_text}]})
        payload = JSON.stringify({
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": contents,
            "generationConfig": {"maxOutputTokens": 2048}
        })
    elif provider == "omniroute":
        # Die App spricht ausschließlich den Loopback-Server auf demselben Gerät an.
        url = "http://127.0.0.1:20128/v1/chat/completions"
        if not api_key.is_empty():
            headers.append("Authorization: Bearer " + api_key)
        var messages: Array = [{"role": "system", "content": system_prompt}]
        for entry in history:
            if not entry is Dictionary:
                continue
            messages.append({"role": str(entry.get("role", "user")), "content": str(entry.get("content", ""))})
        messages.append({"role": "user", "content": user_text})
        payload = JSON.stringify({"model": model, "messages": messages, "stream": false, "max_tokens": 2048})
    else:
        return ERR_INVALID_PARAMETER
    current_provider = provider
    var error := http_request.request(url, headers, HTTPClient.METHOD_POST, payload)
    if error == OK:
        request_running = true
    return error

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if not request_running:
        return
    request_running = false
    if result != HTTPRequest.RESULT_SUCCESS:
        var hint := "Netzwerkfehler " + str(result)
        if current_provider == "omniroute":
            hint += ". Bitte prüfen, ob OmniRoute in Termux läuft (127.0.0.1:20128)."
        answered.emit(false, hint)
        return
    if code != 200:
        var hint := "HTTP " + str(code)
        if code == 401 or code == 403:
            hint += " – API-Schlüssel oder Berechtigung prüfen."
        elif code == 404:
            hint += " – Modell oder Endpunkt nicht gefunden."
        elif code == 429:
            hint += " – Rate-Limit oder Kontingent erreicht."
        elif code >= 500:
            hint += " – Serverfehler; später erneut versuchen."
        answered.emit(false, hint)
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not data is Dictionary:
        answered.emit(false, "Die KI hat keine gültige JSON-Antwort geliefert.")
        return
    var reply := ""
    if current_provider == "gemini":
        var candidates: Variant = data.get("candidates", [])
        if candidates is Array and not candidates.is_empty():
            var candidate: Variant = candidates[0]
            if candidate is Dictionary:
                var response_content: Variant = candidate.get("content", {})
                if response_content is Dictionary:
                    var parts: Variant = response_content.get("parts", [])
                    if parts is Array:
                        for part in parts:
                            if part is Dictionary:
                                reply += str(part.get("text", ""))
    else:
        var choices: Variant = data.get("choices", [])
        if choices is Array and not choices.is_empty():
            var choice: Variant = choices[0]
            if choice is Dictionary:
                var message: Variant = choice.get("message", {})
                if message is Dictionary:
                    reply = str(message.get("content", ""))
    if reply.strip_edges().is_empty():
        answered.emit(false, "Die KI hat keine Textantwort zurückgegeben (mögliche Sicherheitsfilter oder Modellauswahl).")
        return
    answered.emit(true, reply)
