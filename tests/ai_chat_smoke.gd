extends SceneTree

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var script_resource: Script = load("res://app/ai_chat_service.gd")
    if script_resource == null:
        _fail("AI chat service script missing")
        return
    var service = script_resource.new()
    root.add_child(service)
    if service.send("gemini", "gemini-2.5-flash", "", "GameForge AI", "Test", []) != ERR_UNAUTHORIZED:
        _fail("Gemini without key must be rejected")
        return
    if service.send("gemini", "invalid model!", "not-a-real-key", "GameForge AI", "Test", []) != ERR_INVALID_PARAMETER:
        _fail("Invalid Gemini model name must be rejected")
        return
    var answers: Array = []
    service.answered.connect(func(ok: bool, reply: String) -> void:
        answers.append({"ok": ok, "reply": reply})
    )
    service.request_running = true
    service.current_provider = "gemini"
    var google_response := JSON.stringify({
        "candidates": [
            {"content": {"parts": [{"text": "Hallo "}, {"text": "aus Gemini"}]}}
        ]
    })
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), google_response.to_utf8_buffer())
    if answers.size() != 1 or not answers[0].get("ok", false) or answers[0].get("reply", "") != "Hallo aus Gemini":
        _fail("Gemini response parsing failed")
        return
    service.request_running = true
    service.current_provider = "omniroute"
    var omni_response := JSON.stringify({
        "choices": [{"message": {"role": "assistant", "content": "Hallo aus OmniRoute"}}]
    })
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), omni_response.to_utf8_buffer())
    if answers.size() != 2 or not answers[1].get("ok", false) or answers[1].get("reply", "") != "Hallo aus OmniRoute":
        _fail("OmniRoute response parsing failed")
        return
    service.request_running = true
    service.current_provider = "gemini"
    service._on_request_completed(HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), PackedByteArray())
    if answers.size() != 3 or answers[2].get("ok", true):
        _fail("HTTP errors must not be reported as success")
        return
    print("AI chat offline smoke tests passed: Gemini + OmniRoute + error handling")
    service.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
