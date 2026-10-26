extends SceneTree

const AI_CODE_TOOLS = preload("res://app/ai_code_tools.gd")
const EDITOR_RECOVERY = preload("res://app/editor_recovery.gd")

var answers: Array = []
var diagnostic_answers: Array = []
var chat_test_answers: Array = []

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
    # Lokaler Modell-Endpunkt-Test ohne Netzwerkanfrage und ohne Übertragung von Chattext.
    if service.diagnose("gemini", "") != ERR_UNAUTHORIZED:
        _fail("Gemini diagnostic without API key must be rejected")
        return
    if service.diagnose("invalid_provider", "x") != ERR_INVALID_PARAMETER:
        _fail("Unknown diagnostic provider must be rejected")
        return
    service.connect("diagnosed", Callable(self, "_record_diagnosis"))
    service.diagnostic_running = true
    service.diagnostic_provider = "omniroute"
    var models_reply := JSON.stringify({"data": [{"id": "auto/coding"}, {"id": "gemini/example"}]})
    service._on_diagnostic_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), models_reply.to_utf8_buffer())
    if diagnostic_answers.size() != 1 or not diagnostic_answers[0].get("ok", false):
        _fail("OmniRoute model listing diagnostic failed")
        return
    if not str(diagnostic_answers[0].get("details", "")).contains("auto/coding"):
        _fail("Diagnostic did not show the available model ID")
        return
    if service.is_diagnosing() or service.is_busy():
        _fail("Diagnostic must not keep HTTP request or chat marked busy")
        return
    service.diagnostic_running = true
    service.diagnostic_provider = "gemini"
    var gemini_models := JSON.stringify({"models": [{"name": "models/gemini-2.5-flash"}]})
    service._on_diagnostic_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), gemini_models.to_utf8_buffer())
    if diagnostic_answers.size() != 2 or not diagnostic_answers[1].get("ok", false):
        _fail("Gemini model listing diagnostic failed")
        return
    service.diagnostic_running = true
    service.diagnostic_provider = "omniroute"
    service._on_diagnostic_completed(HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), PackedByteArray())
    if diagnostic_answers.size() != 3 or diagnostic_answers[2].get("ok", true):
        _fail("Diagnostic must reject unauthorised requests")
        return
    if not str(diagnostic_answers[2].get("details", "")).contains("Endpoint-Key"):
        _fail("OmniRoute 401 must explain dashboard endpoint authentication")
        return
    service.diagnostic_running = true
    service.diagnostic_provider = "omniroute"
    service._on_diagnostic_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
    if diagnostic_answers.size() != 4 or diagnostic_answers[3].get("ok", true):
        _fail("Diagnostic must report local connection failure")
        return
    # Kurzer echter Inferenz-Test: nur lokale Parsing-Simulation, kein Netzwerk/keine Tokens.
    if service.test_chat("gemini", "gemini-2.5-flash", "") != ERR_UNAUTHORIZED:
        _fail("Gemini chat test without API key must be rejected")
        return
    if service.test_chat("omniroute", "", "") != ERR_INVALID_PARAMETER:
        _fail("Chat test must require a model name")
        return
    if service.test_chat("invalid_provider", "auto", "") != ERR_INVALID_PARAMETER:
        _fail("Unknown chat test provider must be rejected")
        return
    service.connect("chat_tested", Callable(self, "_record_chat_test"))
    service.chat_test_running = true
    service.chat_test_provider = "omniroute"
    var test_chat_reply := JSON.stringify({"choices": [{"message": {"role": "assistant", "content": "OK"}}]})
    service._on_chat_test_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), test_chat_reply.to_utf8_buffer())
    if chat_test_answers.size() != 1 or not chat_test_answers[0].get("ok", false) or not str(chat_test_answers[0].get("details", "")).contains("OK"):
        _fail("OmniRoute chat test response could not be parsed")
        return
    if service.is_testing_chat():
        _fail("Chat test remained busy after completion")
        return
    service.chat_test_running = true
    service.chat_test_provider = "omniroute"
    service._on_chat_test_completed(HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), PackedByteArray())
    if chat_test_answers.size() != 2 or chat_test_answers[1].get("ok", true):
        _fail("Inference 401 must be reported as chat authentication failure")
        return
    service.chat_test_running = true
    service.chat_test_provider = "gemini"
    var gemini_chat_reply := JSON.stringify({"candidates": [{"content": {"parts": [{"text": "OK"}]}}]})
    service._on_chat_test_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), gemini_chat_reply.to_utf8_buffer())
    if chat_test_answers.size() != 3 or not chat_test_answers[2].get("ok", false):
        _fail("Gemini chat test response could not be parsed")
        return
    service.chat_test_running = true
    service.chat_test_provider = "omniroute"
    service._on_chat_test_completed(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), PackedByteArray())
    if chat_test_answers.size() != 4 or chat_test_answers[3].get("ok", true):
        _fail("Chat test must not treat rate-limit as a success")
        return
    # 503-Diagnose: Nur bekannte Ursachen klassifizieren, niemals Rohfehler veröffentlichen.
    var no_auth_error := JSON.stringify({"error": {"message": "auth_unavailable: no auth available (provider secret DO_NOT_SHOW)"}})
    if not service._omniroute_503_hint(no_auth_error.to_utf8_buffer()).contains("Provider-Zugangsdaten"):
        _fail("OmniRoute unavailable-auth cause not recognized")
        return
    service.chat_test_running = true
    service.chat_test_provider = "omniroute"
    service._on_chat_test_completed(HTTPRequest.RESULT_SUCCESS, 503, PackedStringArray(), no_auth_error.to_utf8_buffer())
    if chat_test_answers.size() != 5 or chat_test_answers[4].get("ok", true):
        _fail("503 from OmniRoute must fail")
        return
    var displayed_503 := str(chat_test_answers[4].get("details", ""))
    if not displayed_503.contains("Provider-Zugangsdaten") or displayed_503.contains("DO_NOT_SHOW"):
        _fail("503 must be actionable and not disclose provider error body")
        return
    var quota_error := JSON.stringify({"error": {"message": "usage_limit_reached: quota exceeded"}})
    if not service._omniroute_503_hint(quota_error.to_utf8_buffer()).contains("Kontingent"):
        _fail("OmniRoute quota cause not recognized")
        return
    var route_error := JSON.stringify({"error": {"message": "no eligible candidates"}})
    if not service._omniroute_503_hint(route_error.to_utf8_buffer()).contains("Modellroute"):
        _fail("OmniRoute route cause not recognized")
        return
    # HTTP 200 darf bei leerem oder rein internem Reasoning nicht als Textantwort gelten.
    var omni_parts := {"choices": [{"message": {"content": [
        {"type": "text", "text": "O"},
        {"type": "output_text", "text": "K"}
    ]}, "finish_reason": "stop"}]}
    if service._extract_final_chat_text(omni_parts, "omniroute") != "OK":
        _fail("OmniRoute visible multi-part content parsing failed")
        return
    var omni_null := {"choices": [{"message": {"content": null, "reasoning_content": null}, "finish_reason": "length"}]}
    if not service._extract_final_chat_text(omni_null, "omniroute").is_empty():
        _fail("Null content must not be converted into user-visible text")
        return
    if not service._empty_chat_explanation(omni_null, "omniroute").contains("Token-Limit"):
        _fail("Missing finish_reason=length explanation for HTTP 200 empty response")
        return
    var zero_output := {"choices": [{"message": {"content": null}, "finish_reason": "stop"}], "usage": {"completion_tokens": 0}}
    if not service._empty_chat_explanation(zero_output, "omniroute").contains("0 Ausgabetokens"):
        _fail("Missing diagnostic for OmniRoute HTTP 200 zero output tokens")
        return
    var reasoning_only := {"choices": [{"message": {"content": null, "reasoning_content": "SECRET_THINKING"}, "finish_reason": "stop"}]}
    var thinking_hint: String = service._empty_chat_explanation(reasoning_only, "omniroute")
    if not thinking_hint.contains("interne Modellverarbeitung") or thinking_hint.contains("SECRET_THINKING"):
        _fail("Must not display hidden reasoning content")
        return
    var filter_only := {"choices": [{"message": {"content": null}, "finish_reason": "content_filter"}]}
    if not service._empty_chat_explanation(filter_only, "omniroute").contains("gefiltert"):
        _fail("Missing content_filter diagnostic")
        return
    var gemini_thought := {"candidates": [{"content": {"parts": [
        {"thought": true, "text": "PRIVATE_THOUGHT"},
        {"text": "OK"}
    ]}}]}
    if service._extract_final_chat_text(gemini_thought, "gemini") != "OK":
        _fail("Gemini thought part must not be shown as final text")
        return
    var gemini_length := {"candidates": [{"finishReason": "MAX_TOKENS", "content": {"parts": []}}]}
    if not service._empty_chat_explanation(gemini_length, "gemini").contains("MAX_TOKENS"):
        _fail("Missing Gemini empty MAX_TOKENS diagnostic")
        return
    service.chat_test_running = true
    service.chat_test_provider = "omniroute"
    service._on_chat_test_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(omni_null).to_utf8_buffer())
    if chat_test_answers.size() != 6 or chat_test_answers[5].get("ok", true) or not str(chat_test_answers[5].get("details", "")).contains("Token-Limit"):
        _fail("Empty HTTP 200 inference must explain the truncation, not be treated as success")
        return
    service.chat_test_running = true
    service.chat_test_provider = "omniroute"
    service._on_chat_test_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(omni_parts).to_utf8_buffer())
    if chat_test_answers.size() != 7 or not chat_test_answers[6].get("ok", false):
        _fail("OpenAI-compatible array-form response must be accepted")
        return
    # Speicherservice: eine separate Wiederherstellung je Projekt und Quelldatei.
    var recovery_project := "GameForge Autosave CI Test"
    var recovery_id: String = EDITOR_RECOVERY.snapshot_id(recovery_project, "local", "scripts/hero.gd", "")
    if EDITOR_RECOVERY.save_snapshot(recovery_project, "local", "scripts/hero.gd", "", "extends Node\n") != OK:
        _fail("Recovery snapshot cannot be created")
        return
    var recovered: Dictionary = EDITOR_RECOVERY.read_snapshot(recovery_project, recovery_id)
    if str(recovered.get("content", "")) != "extends Node\n":
        _fail("Saved editor snapshot cannot be restored")
        return
    if EDITOR_RECOVERY.save_snapshot(recovery_project, "local", "scripts/hero.gd", "", "extends Node2D\n") != OK:
        _fail("Atomic recovery snapshot update failed")
        return
    recovered = EDITOR_RECOVERY.read_snapshot(recovery_project, recovery_id)
    if str(recovered.get("content", "")) != "extends Node2D\n":
        _fail("Latest editor snapshot not retained")
        return
    if EDITOR_RECOVERY.list_snapshots(recovery_project).size() != 1:
        _fail("Recovery snapshot listing failed")
        return
    if not EDITOR_RECOVERY.read_snapshot(recovery_project, "../invalid").is_empty():
        _fail("Invalid recovery identifier was accepted")
        return
    if EDITOR_RECOVERY.delete_snapshot(recovery_project, recovery_id) != OK:
        _fail("Recovery snapshot could not be removed after explicit save")
        return
    if not EDITOR_RECOVERY.read_snapshot(recovery_project, recovery_id).is_empty():
        _fail("Deleted snapshot still readable")
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
    if not dashboard.editor is CodeEdit:
        _fail("Android code editor must be a CodeEdit for line numbers")
        return
    var code_edit: CodeEdit = dashboard.editor as CodeEdit
    if not code_edit.gutters_draw_line_numbers:
        _fail("Line-number gutter must be visible")
        return
    if not code_edit.indent_automatic or not code_edit.auto_brace_completion_enabled:
        _fail("GDScript editor indent and bracket assistance must be enabled")
        return
    if code_edit.syntax_highlighter == null:
        _fail("main.gd must have syntax highlighting")
        return
    if not code_edit.syntax_highlighter is CodeHighlighter:
        _fail("GDScript highlighting resource must use CodeHighlighter")
        return
    var syntax: CodeHighlighter = code_edit.syntax_highlighter as CodeHighlighter
    if not syntax.has_keyword_color("func") or not syntax.has_color_region("#"):
        _fail("GDScript keywords and comments are missing their highlighting")
        return
    dashboard.loaded_local_path = "notes.txt"
    dashboard._refresh_code_syntax()
    if dashboard.editor.syntax_highlighter != null:
        _fail("Plain text must not receive GDScript highlighting")
        return
    dashboard.loaded_local_path = "main.gd"
    dashboard._refresh_code_syntax()
    if dashboard.editor.syntax_highlighter == null:
        _fail("Switching back to GDScript must restore highlighting")
        return
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
    if dashboard.code_search_input == null or dashboard.code_search_feedback == null:
        _fail("Missing code editor search controls")
        return
    dashboard.code_search_input.text = "PRINT"
    dashboard.editor.set_caret_line(0)
    dashboard.editor.set_caret_column(0)
    dashboard._search_code_next()
    if not dashboard.code_search_feedback.text.contains("Zeile 4"):
        _fail("Case insensitive CodeEdit search did not locate print in line 4")
        return
    dashboard.code_search_input.text = "kein_treffer_123"
    dashboard._search_code_next()
    if not dashboard.code_search_feedback.text.contains("Kein Treffer"):
        _fail("Search miss should be reported without code modification")
        return
    if dashboard.editor.text != example_code:
        _fail("Code search must not modify the editor document")
        return
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
    if dashboard.ai_chat_test_button == null or dashboard.ai_chat_test_label == null:
        _fail("Missing separate in-app chat test controls")
        return
    dashboard._choose_omniroute_auto_model()
    if dashboard.ai_model_input.text != "auto":
        _fail("Cannot select OmniRoute default auto routing without a request")
        return
    if dashboard.ai_service.call("is_testing_chat") or dashboard.ai_service.call("is_busy"):
        _fail("Switching OmniRoute model must not start an inference request")
        return
    if dashboard.ai_diagnostic_button == null or dashboard.ai_diagnostic_label == null:
        _fail("Missing in-app AI connection test controls")
        return
    if dashboard.ai_diagnostic_button.disabled:
        _fail("Connection test must be available when chat is idle")
        return
    dashboard._on_ai_diagnosed(false, "OmniRoute: HTTP 401 – Endpoint-Key erforderlich")
    if not dashboard.status.text.contains("erreichbar"):
        _fail("Dashboard must distinguish OmniRoute auth from network failure")
        return
    if dashboard.ai_chat_log.get_v_scroll_bar().custom_minimum_size.x < 44.0:
        _fail("Chat history scrollbar is too narrow for touch")
        return
    dashboard._scroll_text_page(dashboard.ai_chat_log, 1)
    dashboard._scroll_text_page(dashboard.ai_chat_log, -1)
    # Editor-Integration: Änderungen automatisch sichern, als KOPIE wiederherstellen.
    dashboard._select_tab("Code")
    dashboard.editor.text = example_code + "# unsaved mobile edit\n"
    dashboard._autosave_now()
    var autosave_id: String = EDITOR_RECOVERY.snapshot_id("GameForge AI", "local", "main.gd", "")
    var saved_draft: Dictionary = EDITOR_RECOVERY.read_snapshot("GameForge AI", autosave_id)
    if str(saved_draft.get("content", "")) != dashboard.editor.text:
        _fail("Editor modifications were not auto-saved")
        return
    dashboard._select_tab("Projekte")
    dashboard._select_tab("Code")
    dashboard._restore_saved_recovery(autosave_id)
    if dashboard.loaded_source != "ai_draft" or not dashboard.editor.text.contains("unsaved mobile edit"):
        _fail("Autosaved editor changes could not be restored as a draft")
        return
    dashboard._save_ai_draft()
    if dashboard.loaded_source != "local" or not dashboard.loaded_local_path.begins_with("ai_drafts/"):
        _fail("Recovered draft was not saved as a distinct local file")
        return
    var original_file := FileAccess.open(dashboard._workspace_path("main.gd"), FileAccess.READ)
    if original_file == null or original_file.get_as_text() != example_code:
        _fail("Original file changed during autosave recovery")
        return
    EDITOR_RECOVERY.delete_snapshot("GameForge AI", autosave_id)
    dashboard.queue_free()
    print("AI chat offline smoke tests passed: Gemini + OmniRoute + empty-200 and content parsing + model diagnostics + short inference test + touch scrolling + autosave recovery + code review staging + error handling")
    service.queue_free()
    quit(0)

func _record_answer(ok: bool, reply: String) -> void:
    answers.append({"ok": ok, "reply": reply})

func _record_diagnosis(ok: bool, details: String) -> void:
    diagnostic_answers.append({"ok": ok, "details": details})

func _record_chat_test(ok: bool, details: String) -> void:
    chat_test_answers.append({"ok": ok, "details": details})

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
