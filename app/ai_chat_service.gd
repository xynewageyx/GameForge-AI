extends Node
## Kleine, zustandslose HTTP-Anbindung für Gemini und OmniRoute.
## Geheimnisse werden nur als HTTP-Header verwendet und nicht auf Platte gespeichert.

signal answered(success: bool, reply: String)

var http_request: HTTPRequest
var request_running: bool = false
var current_provider: String = ""

func _ready() -> void:
    http_request = HTTPRequest.new()
    http_request.timeout = 90.0
    http_request.body_size_limit = 2097152
    http_request.max_redirects = 0
    add_child(http_request)
    http_request.request_completed.connect(_on_request_completed)

func is_busy() -> bool:
    return request_running

func cancel() -> void:
    if request_running:
        http_request.cancel_request()
        request_running = false

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
