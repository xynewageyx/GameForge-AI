extends SceneTree

const AI_CODE_TOOLS = preload("res://app/ai_code_tools.gd")

var answers: Array = []

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var fence := "```"
    var sample := "Ein Beispiel:\n" + fence + "python\nprint('skip')\n" + fence + "\n"
    sample += fence + "gdscript\nextends Node\n\nfunc _ready() -> void:\n    print(\"OK\")\n" + fence
    var extracted: String = AI_CODE_TOOLS.extract_first_gdscript(sample)
    if extracted != "extends Node\n\nfunc _ready() -> void:\n    print(\"OK\")\n":
        _fail("GDScript extraction returned unexpected code")
        return
    if AI_CODE_TOOLS.extract_first_gdscript("Nur ein Text ohne Codeblock") != "":
        _fail("Plain KI text must not be injected into code editor")
        return
    if AI_CODE_TOOLS.extract_first_gdscript(fence + "python\nprint(1)\n" + fence) != "":
        _fail("Non-GDScript code block must be ignored")
        return
    if AI_CODE_TOOLS.extract_first_gdscript(fence + "gdscript\nextends Node\n") != "":
        _fail("Unclosed markdown code block must be rejected")
        return
    var gd_source := "extends Node\n\nfunc _ready() -> void:\n    print(\"Test\")\n"
    var review: Dictionary = AI_CODE_TOOLS.build_analysis_request("scripts/player.gd", gd_source, "Kritische Treffer sicher berechnen")
    if not bool(review.get("ok", false)):
        _fail("Valid GDScript analysis request was rejected")
        return
    var prompt := str(review.get("prompt", ""))
    if prompt.length() > 12000 or not prompt.contains("Kritische Treffer") or not prompt.contains("extends Node"):
        _fail("GDScript review prompt missing code or request")
        return
    if AI_CODE_TOOLS.build_analysis_request("README.md", gd_source, "Analysiere").get("ok", false):
        _fail("Non-GDScript file must not be sent for code analysis")
        return
    if AI_CODE_TOOLS.build_analysis_request("player.gd", "", "Analysiere").get("ok", false):
        _fail("Empty GDScript must not be sent")
        return
    if AI_CODE_TOOLS.build_analysis_request("player.gd", gd_source, "").get("ok", false):
        _fail("Missing change request must not be sent")
        return
    if AI_CODE_TOOLS.build_analysis_request("player.gd", "a".repeat(10001), "Analysiere").get("ok", false):
        _fail("Oversize source must not be sent")
        return
    if AI_CODE_TOOLS.build_analysis_request("player.gd", gd_source, "a".repeat(901)).get("ok", false):
        _fail("Oversize instructions must not be sent")
        return
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
    service.connect("answered", Callable(self, "_record_answer"))
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
    # Integration: Editor lädt lokale Datei, bereitet KI-Analyse vor – OHNE HTTP-Request.
    var dashboard_script: Script = load("res://app/dashboard.gd")
    if dashboard_script == null:
        _fail("GameForge dashboard script missing")
        return
    var dashboard = dashboard_script.new()
    root.add_child(dashboard)
    if dashboard.content_scroll.get_v_scroll_bar().custom_minimum_size.x < 44.0:
        _fail("Main Android scrollbar is too narrow for touch")
        return
    if dashboard.content_scroll.scroll_deadzone > 12:
        _fail("Touch scroll deadzone too large")
        return
    dashboard._select_tab("Code")
    if dashboard.editor.get_v_scroll_bar().custom_minimum_size.x < 44.0:
        _fail("Code editor scrollbar is too narrow for touch")
        return
    dashboard._scroll_main_page(1)
    dashboard._scroll_main_page(-1)
    dashboard._scroll_text_page(dashboard.editor, 1)
    dashboard._scroll_text_page(dashboard.editor, -1)
    var example_code := "extends Node\n\nfunc _ready() -> void:\n    print(\"Analyse\")\n"
    dashboard.editor.text = example_code
    dashboard._save_local_file()
    dashboard.analysis_change_input.text = "Behalte alle vorhandenen Methoden bei und prüfe den Code"
    dashboard._prepare_code_analysis()
    if dashboard.selected_tab != "KI-Chat":
        _fail("Code analysis did not open KI-Chat review")
        return
    if dashboard.pending_analysis.get("file", "") != "main.gd":
        _fail("Incorrect file prepared for analysis")
        return
    if dashboard.ai_service.call("is_busy"):
        _fail("Code review sent a request without confirmation")
        return
    dashboard._discard_pending_analysis()
    if not dashboard.pending_analysis.is_empty():
        _fail("Discard did not clear staged source")
        return
    dashboard._select_tab("Code")
    if dashboard.editor.text != example_code:
        _fail("Original file was not restored after review")
        return
    dashboard._select_tab("KI-Chat")
    if dashboard.ai_chat_log.get_v_scroll_bar().custom_minimum_size.x < 44.0:
        _fail("Chat history scrollbar is too narrow for touch")
        return
    dashboard._scroll_text_page(dashboard.ai_chat_log, 1)
    dashboard._scroll_text_page(dashboard.ai_chat_log, -1)
    dashboard.queue_free()
    print("AI chat offline smoke tests passed: Gemini + OmniRoute + touch scrolling + code review staging + error handling")
    service.queue_free()
    quit(0)

func _record_answer(ok: bool, reply: String) -> void:
    answers.append({"ok": ok, "reply": reply})

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
