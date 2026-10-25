extends Node
## Kleine, zustandslose HTTP-Anbindung für Gemini und OmniRoute.
## Geheimnisse werden nur als HTTP-Header verwendet und nicht auf Platte gespeichert.

signal answered(success: bool, reply: String)
signal diagnosed(success: bool, details: String)
signal chat_tested(success: bool, details: String)

var http_request: HTTPRequest
var request_running: bool = false
var current_provider: String = ""
var diagnostic_request: HTTPRequest
var diagnostic_running: bool = false
var diagnostic_provider: String = ""
var chat_test_request: HTTPRequest
var chat_test_running: bool = false
var chat_test_provider: String = ""

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
    chat_test_request = HTTPRequest.new()
    chat_test_request.timeout = 25.0
    chat_test_request.body_size_limit = 131072
    chat_test_request.max_redirects = 0
    add_child(chat_test_request)
    chat_test_request.request_completed.connect(_on_chat_test_completed)

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
    if diagnostic_running or request_running or chat_test_running:
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
        if diagnostic_provider == "omniroute":
            diagnosed.emit(false, "OmniRoute: HTTP " + str(code) + " für /v1/models. Unter Dashboard > Endpoints einen Endpoint-Key erstellen und oben eingeben. Hinweis: Modellliste und Chat können unterschiedlich geschützt sein; 401 hier beweist noch keinen Chatfehler.")
        else:
            diagnosed.emit(false, "Gemini: HTTP " + str(code) + " – Gemini-API-Schlüssel und Berechtigungen prüfen.")
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

## Kurze echte Modellanfrage mit expliziter Nutzeraktion. Keine Projektdateien oder Chat-Historie.
## Sie kann bei dem verbundenen Anbieter Tokens/Kontingent verbrauchen.
func is_testing_chat() -> bool:
    return chat_test_running

func cancel_chat_test() -> void:
    if chat_test_running:
        chat_test_request.cancel_request()
        chat_test_running = false

func test_chat(provider: String, model: String, api_key: String) -> int:
    if diagnostic_running or request_running or chat_test_running:
        return ERR_BUSY
    if model.is_empty() or model.length() > 120 or model.contains("\n") or model.contains("\r"):
        return ERR_INVALID_PARAMETER
    var url := ""
    var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
    var payload := ""
    if provider == "omniroute":
        url = "http://127.0.0.1:20128/v1/chat/completions"
        if not api_key.is_empty():
            headers.append("Authorization: Bearer " + api_key)
        payload = JSON.stringify({
            "model": model,
            "messages": [{"role": "user", "content": "Antworte ausschließlich mit OK."}],
            "max_tokens": 128,
            "stream": false
        })
    elif provider == "gemini":
        if api_key.is_empty():
            return ERR_UNAUTHORIZED
        for ch in model:
            if not (ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"):
                return ERR_INVALID_PARAMETER
        url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent"
        headers.append("x-goog-api-key: " + api_key)
        payload = JSON.stringify({
            "contents": [{"role": "user", "parts": [{"text": "Antworte ausschließlich mit OK."}]}],
            "generationConfig": {"maxOutputTokens": 128}
        })
    else:
        return ERR_INVALID_PARAMETER
    var err := chat_test_request.request(url, headers, HTTPClient.METHOD_POST, payload)
    if err == OK:
        chat_test_running = true
        chat_test_provider = provider
    return err

## Nur bekannte Fehlerursachen zuordnen. Rohmeldungen können sensible Anbieter-Details enthalten.
func _omniroute_503_hint(body: PackedByteArray) -> String:
    if body.size() > 16384:
        return "Antwort zu groß für eine sichere Diagnose. Providers und Monitoring prüfen."
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not parsed is Dictionary:
        return "Kein nutzbarer Fehlergrund. Providers und Monitoring prüfen."
    var error_data: Variant = parsed.get("error", {})
    var error_text := ""
    if error_data is Dictionary:
        error_text = str(error_data.get("code", "")) + " " + str(error_data.get("message", ""))
    elif error_data is String:
        error_text = error_data
    error_text = error_text.to_lower()
    if error_text.contains("usage_limit") or error_text.contains("quota") or error_text.contains("limit_reached"):
        return "Anbieter-Kontingent oder Nutzungslimit erreicht. Anbieter und Quota prüfen."
    if error_text.contains("auth_unavailable") or error_text.contains("no auth available") or error_text.contains("upstream accounts are unavailable"):
        return "Keine einsatzbereiten Provider-Zugangsdaten. Unter Providers Verbindung erneuern."
    if error_text.contains("circuit") or error_text.contains("temporarily unavailable"):
        return "Anbieter vorübergehend blockiert/nicht verfügbar. Monitoring/Health prüfen."
    if error_text.contains("no eligible") or error_text.contains("no available provider") or error_text.contains("no route") or error_text.contains("no candidates"):
        return "Keine geeignete Modellroute. Unter Providers einen aktiven Anbieter verbinden; Modell 'auto' probieren."
    return "Routing oder Anbieter derzeit nicht verfügbar. Unter Providers und Monitoring nachsehen."

## Only final, user-visible content is returned; never substitute reasoning_content.
## OpenAI-compatible providers may return either a plain string or content parts.
func _visible_content(value: Variant) -> String:
    if value is String:
        return value
    if value is Array:
        var pieces := ""
        for part in value:
            if part is String:
                pieces += part
            elif part is Dictionary:
                var kind := str(part.get("type", ""))
                if kind == "text" or kind == "output_text" or kind.is_empty():
                    if part.get("text", null) is String:
                        pieces += str(part.get("text", ""))
        return pieces
    return ""

func _extract_final_chat_text(data: Dictionary, provider: String) -> String:
    var reply := ""
    if provider == "omniroute":
        var choices: Variant = data.get("choices", [])
        if choices is Array:
            for choice in choices:
                if choice is Dictionary:
                    var message: Variant = choice.get("message", {})
                    if message is Dictionary:
                        reply = _visible_content(message.get("content", null))
                        if not reply.strip_edges().is_empty():
                            break
    else:
        var candidates: Variant = data.get("candidates", [])
        if candidates is Array:
            for candidate in candidates:
                if candidate is Dictionary:
                    var candidate_content: Variant = candidate.get("content", {})
                    if candidate_content is Dictionary:
                        var parts: Variant = candidate_content.get("parts", [])
                        if parts is Array:
                            for part in parts:
                                if part is Dictionary and not bool(part.get("thought", false)):
                                    reply += _visible_content(part.get("text", null))
                        if not reply.strip_edges().is_empty():
                            break
    return reply

## Never echo arbitrary upstream JSON/error text, keys, prompts, or reasoning.
func _empty_chat_explanation(data: Dictionary, provider: String) -> String:
    if provider == "omniroute":
        var choices: Variant = data.get("choices", [])
        if not choices is Array or choices.is_empty():
            return "OmniRoute lieferte HTTP 200 ohne choices. Provider-Routing und Monitoring prüfen."
        var first: Variant = choices[0]
        if not first is Dictionary:
            return "OmniRoute lieferte kein lesbares Antwortobjekt."
        var reason := str(first.get("finish_reason", ""))
        if reason == "length":
            return "OmniRoute: Ausgabe vor sichtbarem Text am Token-Limit beendet (finish_reason=length). Anderes Modell wählen oder Ausgabe-Limit erhöhen."
        if reason == "content_filter":
            return "OmniRoute: Der Anbieter hat die Ausgabe gefiltert (content_filter)."
        if reason == "tool_calls" or reason == "function_call":
            return "OmniRoute: Das Modell wollte ein Tool ausführen, hat aber keine Textantwort geliefert."
        var usage: Variant = data.get("usage", {})
        if usage is Dictionary:
            var completion_count: Variant = usage.get("completion_tokens", -1)
            if (completion_count is int or completion_count is float) and int(completion_count) == 0:
                return "OmniRoute: Der Anbieter meldet 0 Ausgabetokens trotz HTTP 200. Provider/Modell im Dashboard prüfen."
        var message: Variant = first.get("message", {})
        if message is Dictionary:
            var refusal: Variant = message.get("refusal", null)
            if refusal is String and not refusal.is_empty():
                return "OmniRoute: Der Anbieter hat eine Textantwort abgelehnt."
            var thinking: Variant = message.get("reasoning_content", null)
            if thinking is String and not thinking.is_empty():
                return "OmniRoute: Nur interne Modellverarbeitung, kein sichtbarer Antworttext. Anderes Modell oder größeres Token-Limit probieren."
        return "OmniRoute: HTTP 200, aber kein sichtbarer Text (finish_reason=" + ("stop" if reason == "stop" else "unbekannt") + "). Modell und Monitoring prüfen."
    var candidates: Variant = data.get("candidates", [])
    if not candidates is Array or candidates.is_empty():
        return "Gemini: Keine Text-Kandidaten zurückgegeben. Filter, Modell und Kontingent prüfen."
    var candidate: Variant = candidates[0]
    if candidate is Dictionary:
        var reason := str(candidate.get("finishReason", ""))
        if reason == "MAX_TOKENS":
            return "Gemini: Ausgabe-Limit vor sichtbarem Text erreicht (MAX_TOKENS)."
        if reason == "SAFETY" or reason == "BLOCKLIST" or reason == "PROHIBITED_CONTENT":
            return "Gemini: Der Anbieter hat die Textausgabe gefiltert."
    return "Gemini: HTTP 200, aber ohne lesbaren Antworttext. Modell und Ausgabelimit prüfen."

func _on_chat_test_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if not chat_test_running:
        return
    chat_test_running = false
    var service_name := "OmniRoute" if chat_test_provider == "omniroute" else "Gemini"
    if result != HTTPRequest.RESULT_SUCCESS:
        chat_tested.emit(false, service_name + ": Netzwerkfehler " + str(result) + ". Server und Internet prüfen.")
        return
    if code == 401 or code == 403:
        chat_tested.emit(false, service_name + ": Chat HTTP " + str(code) + " – hier fehlt der API-Endpoint-Schlüssel oder eine Berechtigung.")
        return
    if code == 404:
        chat_tested.emit(false, service_name + ": Chat HTTP 404 – Modell oder Chat-Endpunkt nicht gefunden. Modellname prüfen (OmniRoute ggf. auto).")
        return
    if code == 402 or code == 429:
        chat_tested.emit(false, service_name + ": Chat HTTP " + str(code) + " – Kontingent, Abrechnung oder Rate-Limit prüfen.")
        return
    if code == 503:
        var hint := _omniroute_503_hint(body) if chat_test_provider == "omniroute" else "Der KI-Anbieter ist momentan nicht verfügbar."
        chat_tested.emit(false, service_name + ": Chat HTTP 503 – " + hint)
        return
    if code != 200:
        chat_tested.emit(false, service_name + ": Chat HTTP " + str(code) + " – Modellrouting oder Provider-Zustand prüfen.")
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not data is Dictionary:
        chat_tested.emit(false, service_name + ": Chat HTTP 200, aber ungültiges JSON.")
        return
    var reply := _extract_final_chat_text(data, chat_test_provider)
    if reply.strip_edges().is_empty():
        chat_tested.emit(false, _empty_chat_explanation(data, chat_test_provider))
        return
    chat_tested.emit(true, service_name + ": Testantwort erhalten: " + reply.strip_edges().substr(0, 160) + " (kein Projektcode gesendet).")

func send(provider: String, model: String, api_key: String, project_name: String, user_text: String, history: Array) -> int:
    if request_running or chat_test_running or diagnostic_running:
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
        elif code == 503 and current_provider == "omniroute":
            hint += " – " + _omniroute_503_hint(body)
        elif code >= 500:
            hint += " – Serverfehler; später erneut versuchen."
        answered.emit(false, hint)
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not data is Dictionary:
        answered.emit(false, "Die KI hat keine gültige JSON-Antwort geliefert.")
        return
    var reply := _extract_final_chat_text(data, current_provider)
    if reply.strip_edges().is_empty():
        answered.emit(false, _empty_chat_explanation(data, current_provider))
        return
    answered.emit(true, reply)
