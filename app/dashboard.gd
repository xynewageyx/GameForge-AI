extends Control

var selected_tab: String = "Projekte"
var tabs: Array[String] = ["Projekte", "KI-Chat", "Code", "Builds", "Einstellungen"]
var content: VBoxContainer
var status: Label
var navigation: HFlowContainer
var active_project: String = "GameForge AI"
var editor: TextEdit
var file_picker: OptionButton
var github_path_input: LineEdit
var github_request: HTTPRequest
var github_list: VBoxContainer
var github_request_mode: String = "file"
var current_file_label: Label
var loaded_source: String = "local"
var github_loaded_path: String = ""
var github_loaded_sha: String = ""
var github_loaded_repo: String = ""
var github_original_content: String = ""
var github_request_repo: String = ""
var upload_request: HTTPRequest
var upload_token_input: LineEdit
var upload_message_input: LineEdit
var upload_confirm_button: Button
var upload_preview_label: Label
var upload_state: String = ""
var prepared_content: String = ""
var prepared_path: String = ""
var prepared_repo: String = ""
var prepared_sha: String = ""
var build_status_request: HTTPRequest
var build_trigger_request: HTTPRequest
var build_token_input: LineEdit
var build_confirm_button: Button
var build_info: VBoxContainer
var build_confirmation_label: Label
var build_ready: bool = false
var build_in_progress: bool = false
var project_names: Array[String] = ["GameForge AI", "Titan Legends", "MangaForge AI"]
var file_names: Array[String] = ["main.gd", "notes.txt"]

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _ensure_workspace()
    github_request = HTTPRequest.new()
    add_child(github_request)
    github_request.request_completed.connect(_github_response)
    upload_request = HTTPRequest.new()
    upload_request.max_redirects = 0
    upload_request.timeout = 25.0
    add_child(upload_request)
    upload_request.request_completed.connect(_github_upload_response)
    build_status_request = HTTPRequest.new()
    build_status_request.timeout = 20.0
    add_child(build_status_request)
    build_status_request.request_completed.connect(_on_builds_received)
    build_trigger_request = HTTPRequest.new()
    build_trigger_request.timeout = 25.0
    build_trigger_request.max_redirects = 0
    add_child(build_trigger_request)
    build_trigger_request.request_completed.connect(_on_build_trigger_response)
    _build_ui()

func _build_ui() -> void:
    var background := ColorRect.new()
    background.color = Color("#111827")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 32)
    margin.add_theme_constant_override("margin_bottom", 24)
    add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 20)
    margin.add_child(root)

    var heading := Label.new()
    heading.text = "GAMEFORGE AI"
    heading.add_theme_font_size_override("font_size", 38)
    heading.add_theme_color_override("font_color", Color("#f8fafc"))
    root.add_child(heading)

    status = Label.new()
    status.text = "Android Game Studio  |  Godot 4.7.2"
    status.add_theme_font_size_override("font_size", 19)
    status.add_theme_color_override("font_color", Color("#94a3b8"))
    root.add_child(status)

    navigation = HFlowContainer.new()
    navigation.add_theme_constant_override("h_separation", 12)
    navigation.add_theme_constant_override("v_separation", 12)
    root.add_child(navigation)
    for tab in tabs:
        var button := Button.new()
        button.text = tab
        button.custom_minimum_size = Vector2(140, 64)
        button.add_theme_font_size_override("font_size", 20)
        button.pressed.connect(_select_tab.bind(tab))
        navigation.add_child(button)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    scroll.add_child(content)
    _render_tab()

func _select_tab(tab: String) -> void:
    _cancel_build_confirmation()
    _cancel_pending_upload()
    github_request.cancel_request()
    selected_tab = tab
    _render_tab()

func _add_label(message: String, font_size: int = 22) -> void:
    var label := Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("#e2e8f0"))
    content.add_child(label)

func _ensure_workspace() -> void:
    for project_name in project_names:
        var folder := "user://" + project_name.validate_filename().replace(" ", "_")
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
        var note_path := folder + "/notes.txt"
        if not FileAccess.file_exists(note_path):
            var file := FileAccess.open(note_path, FileAccess.WRITE)
            if file != null:
                file.store_string("Projekt: " + project_name + "\\nLokaler Arbeitsbereich auf Android.\\n")

func _workspace_path(filename: String) -> String:
    return "user://" + active_project.validate_filename().replace(" ", "_") + "/" + filename

func _add_button(caption: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size.y = 64
    button.add_theme_font_size_override("font_size", 20)
    button.pressed.connect(callback)
    content.add_child(button)

func _select_project(name: String) -> void:
    _cancel_build_confirmation()
    _cancel_pending_upload()
    github_request.cancel_request()
    active_project = name
    status.text = "Aktives Projekt: " + active_project
    _render_tab()

func _load_local_file() -> void:
    if editor == null or file_picker == null:
        return
    var filename := file_names[file_picker.selected]
    loaded_source = "local"
    github_loaded_path = ""
    github_loaded_sha = ""
    github_loaded_repo = ""
    github_original_content = ""
    _cancel_pending_upload()
    _set_current_file("Lokal: " + filename)
    var path := _workspace_path(filename)
    if not FileAccess.file_exists(path):
        editor.text = ""
        status.text = "Neue lokale Datei: " + filename
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        status.text = "Lesefehler: " + filename
        return
    editor.text = file.get_as_text()
    status.text = "Geladen: " + filename

func _save_local_file() -> void:
    if editor == null or file_picker == null:
        return
    if loaded_source == "github":
        status.text = "GitHub-Datei aktiv: Bitte GitHub-Kopie lokal speichern verwenden."
        return
    var filename := file_names[file_picker.selected]
    var file := FileAccess.open(_workspace_path(filename), FileAccess.WRITE)
    if file == null:
        status.text = "Speichern fehlgeschlagen: " + filename
        return
    file.store_string(editor.text)
    file.flush()
    status.text = "Lokal gespeichert: " + filename


func _set_current_file(value: String) -> void:
    if current_file_label != null and is_instance_valid(current_file_label):
        current_file_label.text = "Aktuelle Datei: " + value

func _save_github_copy() -> void:
    if editor == null or loaded_source != "github" or github_loaded_path.is_empty():
        status.text = "Bitte zuerst eine GitHub-Textdatei laden."
        return
    if github_loaded_path.contains("..") or github_loaded_path.begins_with("/"):
        status.text = "Unsicherer Dateipfad, Speichern abgebrochen."
        return
    var target := _workspace_path("github_import/" + github_loaded_path)
    var folder := target.get_base_dir()
    var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    if dir_error != OK:
        status.text = "Lokaler Ordner konnte nicht erstellt werden."
        return
    var base := target.get_basename()
    var extension := target.get_extension()
    var candidate := target
    var index := 1
    while FileAccess.file_exists(candidate) and index < 100:
        candidate = base + "_kopie_" + str(index)
        if not extension.is_empty():
            candidate += "." + extension
        index += 1
    if FileAccess.file_exists(candidate):
        status.text = "Zu viele lokale Kopien vorhanden."
        return
    var file := FileAccess.open(candidate, FileAccess.WRITE)
    if file == null:
        status.text = "GitHub-Kopie konnte nicht gespeichert werden."
        return
    file.store_string(editor.text)
    file.flush()
    status.text = "GitHub-Kopie gesichert: " + candidate.trim_prefix("user://")
    _set_current_file("GitHub: " + github_loaded_path + " (Kopie gespeichert)")

func _github_repo() -> String:
    if active_project == "Titan Legends":
        return "xynewageyx/TitanLegend"
    if active_project == "GameForge AI":
        return "xynewageyx/GameForge-AI"
    return ""

func _github_load() -> void:
    var repo := _github_repo()
    if repo.is_empty():
        status.text = "Kein GitHub-Repository konfiguriert."
        return
    var path := github_path_input.text.strip_edges().trim_prefix("/")
    if path.is_empty() or path.contains("..") or path.contains("?"):
        status.text = "Ungültiger Dateipfad."
        return
    var url := "https://api.github.com/repos/" + repo + "/contents/" + path.uri_encode().replace("%2F", "/")
    github_request_mode = "file"
    github_request_repo = repo
    var err := github_request.request(url, ["Accept: application/vnd.github+json", "User-Agent: GameForgeAI"])
    status.text = "Lade GitHub-Datei..." if err == OK else "Anfrage fehlgeschlagen: " + str(err)

func _github_browse() -> void:
    var repo := _github_repo()
    if repo.is_empty():
        status.text = "Kein GitHub-Repository konfiguriert."
        return
    var path := github_path_input.text.strip_edges().trim_prefix("/")
    if path.contains("..") or path.contains("?") or path.contains("#"):
        status.text = "Ungültiger Ordnerpfad."
        return
    github_request_mode = "browse"
    github_request_repo = repo
    var url := "https://api.github.com/repos/" + repo + "/contents"
    if not path.is_empty():
        url += "/" + path.uri_encode().replace("%2F", "/")
    var err := github_request.request(url, ["Accept: application/vnd.github+json", "User-Agent: GameForgeAI"])
    status.text = "Lade Dateiliste..." if err == OK else "Anfrage fehlgeschlagen: " + str(err)

func _github_pick(path: String, is_dir: bool) -> void:
    github_path_input.text = path
    if is_dir:
        _github_browse()
    else:
        _github_load()

func _github_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if selected_tab != "Code" or github_request_repo != _github_repo():
        return
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        status.text = "GitHub-Fehler: " + str(code) + " / " + str(result)
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if github_request_mode == "browse":
        if not data is Array:
            status.text = "Ordner nicht gefunden."
            return
        for child in github_list.get_children():
            child.queue_free()
        var count := 0
        for item in data:
            if not item is Dictionary:
                continue
            var kind := str(item.get("type", ""))
            if kind != "dir" and kind != "file":
                continue
            var path := str(item.get("path", ""))
            var button := Button.new()
            button.text = ("[Ordner] " if kind == "dir" else "[Datei] ") + str(item.get("name", ""))
            button.custom_minimum_size.y = 54
            button.pressed.connect(_github_pick.bind(path, kind == "dir"))
            github_list.add_child(button)
            count += 1
            if count >= 100:
                break
        status.text = "GitHub: " + str(count) + " Einträge (nur lesen)"
        return
    if not data is Dictionary:
        status.text = "Ungültige GitHub-Antwort."
        return
    if data.get("type", "") != "file" or data.get("encoding", "") != "base64":
        status.text = "Bitte eine einzelne Textdatei wählen."
        return
    var encoded: String = str(data.get("content", "")).replace("\\n", "").replace("\\r", "")
    var bytes := Marshalls.base64_to_raw(encoded)
    if bytes.size() > 1048576:
        status.text = "Datei zu groß."
        return
    if editor == null or not is_instance_valid(editor):
        status.text = "Editor nicht geöffnet."
        return
    var file_text := bytes.get_string_from_utf8()
    if file_text.contains("\u0000"):
        status.text = "Binärdatei: Bitte nur Textdateien öffnen."
        return
    editor.text = file_text
    loaded_source = "github"
    github_loaded_path = str(data.get("path", ""))
    github_loaded_sha = str(data.get("sha", ""))
    github_loaded_repo = _github_repo()
    github_original_content = file_text
    _cancel_pending_upload()
    _set_current_file("GitHub: " + github_loaded_path + " (nur lesen)")
    status.text = "GitHub-Datei geladen: " + github_loaded_path + " (nur lesen)"

func _cancel_pending_upload() -> void:
    if upload_state == "upload":
        return
    if upload_state == "preflight":
        upload_request.cancel_request()
    upload_state = ""
    prepared_content = ""
    prepared_path = ""
    prepared_repo = ""
    prepared_sha = ""
    if upload_confirm_button != null and is_instance_valid(upload_confirm_button):
        upload_confirm_button.disabled = true
    if upload_preview_label != null and is_instance_valid(upload_preview_label):
        upload_preview_label.text = ""

func _github_upload_url(repo: String, path: String) -> String:
    return "https://api.github.com/repos/" + repo + "/contents/" + path.uri_encode().replace("%2F", "/")

func _prepare_github_upload() -> void:
    if upload_state != "":
        status.text = "Es läuft bereits eine GitHub-Anfrage."
        return
    if editor == null or loaded_source != "github" or github_loaded_sha.is_empty():
        status.text = "Bitte zuerst eine GitHub-Datei im Editor öffnen."
        return
    if github_loaded_repo != _github_repo() or github_loaded_path.is_empty():
        status.text = "Repository gewechselt. GitHub-Datei bitte neu öffnen."
        return
    if github_loaded_path.contains("..") or github_loaded_path.begins_with("/"):
        status.text = "Unsicherer GitHub-Dateipfad."
        return
    if editor.text == github_original_content:
        status.text = "Keine Änderungen zum Hochladen vorhanden."
        return
    var new_size := editor.text.to_utf8_buffer().size()
    if new_size > 1048576:
        status.text = "Datei zu groß: maximal 1 MB."
        return
    var token := upload_token_input.text.strip_edges()
    if token.is_empty() or token.contains("\n") or token.contains("\r"):
        status.text = "Bitte gültigen GitHub-Token eingeben."
        return
    prepared_repo = github_loaded_repo
    prepared_path = github_loaded_path
    prepared_sha = github_loaded_sha
    prepared_content = editor.text
    upload_state = "preflight"
    upload_confirm_button.disabled = true
    upload_preview_label.text = "Prüfe aktuelle Dateiversion auf GitHub..."
    var headers := ["Accept: application/vnd.github+json", "User-Agent: GameForgeAI", "Authorization: Bearer " + token]
    var err := upload_request.request(_github_upload_url(prepared_repo, prepared_path), headers)
    if err != OK:
        _cancel_pending_upload()
        status.text = "GitHub-Prüfung fehlgeschlagen: " + str(err)
        return
    status.text = "Prüfe GitHub-Version der Datei..."

func _confirm_github_upload() -> void:
    if upload_state != "ready" or upload_confirm_button == null or upload_confirm_button.disabled:
        return
    if selected_tab != "Code" or editor == null or editor.text != prepared_content:
        _cancel_pending_upload()
        status.text = "Editorinhalt wurde verändert. Upload bitte erneut prüfen."
        return
    if _github_repo() != prepared_repo or github_loaded_sha != prepared_sha:
        _cancel_pending_upload()
        status.text = "Projekt oder Dateiversion hat sich geändert. Erneut laden."
        return
    var token := upload_token_input.text.strip_edges()
    if token.is_empty() or token.contains("\n") or token.contains("\r"):
        _cancel_pending_upload()
        status.text = "GitHub-Token fehlt."
        return
    var message := upload_message_input.text.strip_edges()
    if message.is_empty():
        message = "GameForge AI: " + prepared_path.get_file() + " aktualisieren"
    if message.length() > 200:
        _cancel_pending_upload()
        status.text = "Commit-Nachricht zu lang (maximal 200 Zeichen)."
        return
    var payload := JSON.stringify({
        "message": message,
        "content": Marshalls.raw_to_base64(prepared_content.to_utf8_buffer()),
        "sha": prepared_sha
    })
    var headers := ["Accept: application/vnd.github+json", "Content-Type: application/json", "User-Agent: GameForgeAI", "Authorization: Bearer " + token]
    upload_state = "upload"
    upload_confirm_button.disabled = true
    upload_preview_label.text = "Sende bestätigte Änderung. App nicht schließen."
    var err := upload_request.request(_github_upload_url(prepared_repo, prepared_path), headers, HTTPClient.METHOD_PUT, payload)
    if err != OK:
        upload_state = ""
        status.text = "Upload-Anfrage fehlgeschlagen: " + str(err)
        upload_preview_label.text = "Nicht gesendet. Erneut prüfen."
        return
    status.text = "Übertrage Änderung nach GitHub..."

func _github_upload_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var stage := upload_state
    if stage != "preflight" and stage != "upload":
        return
    if result != HTTPRequest.RESULT_SUCCESS:
        upload_state = ""
        status.text = "Netzwerkfehler bei GitHub: " + str(result) + ". Status im Browser überprüfen."
        if upload_preview_label != null and is_instance_valid(upload_preview_label):
            upload_preview_label.text = "Anfrage nicht bestätigt."
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if stage == "preflight":
        if code != 200 or not data is Dictionary:
            _cancel_pending_upload()
            status.text = "Versionsprüfung HTTP " + str(code) + ". Token und Berechtigungen prüfen."
            return
        var remote_sha := str(data.get("sha", ""))
        if remote_sha.is_empty() or remote_sha != prepared_sha:
            _cancel_pending_upload()
            status.text = "Konflikt: Datei wurde auf GitHub geändert. Bitte neu laden."
            return
        upload_state = "ready"
        upload_confirm_button.disabled = false
        upload_preview_label.text = "Bereit zum Hochladen:\nRepository: " + prepared_repo + "\nDatei: " + prepared_path + "\nGitHub-Version: " + prepared_sha.substr(0, 12) + "\nGröße: " + str(prepared_content.to_utf8_buffer().size()) + " Bytes\nErst mit 'Hochladen verbindlich bestätigen' wird ein Commit erstellt."
        status.text = "Dateiversion geprüft. Bestätigung erforderlich."
        return
    upload_state = ""
    if code != 200 and code != 201:
        var message := ""
        if data is Dictionary:
            message = str(data.get("message", ""))
        if code == 409 or code == 422:
            status.text = "GitHub-Konflikt (HTTP " + str(code) + "). Datei neu laden und Änderungen vergleichen."
        elif code == 401 or code == 403:
            status.text = "GitHub HTTP " + str(code) + ": Token oder Contents-Schreibrecht prüfen."
        else:
            status.text = "GitHub-Upload fehlgeschlagen: HTTP " + str(code)
        if upload_preview_label != null and is_instance_valid(upload_preview_label):
            upload_preview_label.text = "Kein erfolgreicher Commit bestätigt. " + message.substr(0, 150)
        return
    if not data is Dictionary:
        status.text = "Antwort unklar. Commit bitte im GitHub-Browser prüfen."
        return
    var content_info: Variant = data.get("content", {})
    if not content_info is Dictionary:
        status.text = "Upload-Antwort unvollständig. Commit bitte bei GitHub prüfen."
        return
    var new_sha := str(content_info.get("sha", ""))
    if new_sha.is_empty():
        status.text = "Neuer Datei-Hash fehlt. Commit bei GitHub prüfen."
        return
    if github_loaded_repo == prepared_repo and github_loaded_path == prepared_path and loaded_source == "github":
        github_loaded_sha = new_sha
        github_original_content = prepared_content
        _set_current_file("GitHub: " + github_loaded_path + " (hochgeladen)")
    if upload_token_input != null and is_instance_valid(upload_token_input):
        upload_token_input.clear()
    if upload_preview_label != null and is_instance_valid(upload_preview_label):
        upload_preview_label.text = "Erfolgreich! GitHub-Datei aktualisiert. Token-Eingabe geleert."
    status.text = "GitHub-Commit erfolgreich: " + prepared_path

func _cancel_build_confirmation() -> void:
    build_ready = false
    if build_confirm_button != null and is_instance_valid(build_confirm_button):
        build_confirm_button.disabled = true
    if build_confirmation_label != null and is_instance_valid(build_confirmation_label):
        build_confirmation_label.text = ""
    if build_token_input != null and is_instance_valid(build_token_input):
        build_token_input.clear()

func _open_builds_in_browser() -> void:
    OS.shell_open("https://github.com/xynewageyx/GameForge-AI/actions/workflows/android.yml")

func _open_specific_build(run_id: int) -> void:
    if run_id > 0:
        OS.shell_open("https://github.com/xynewageyx/GameForge-AI/actions/runs/" + str(run_id))

func _refresh_builds() -> void:
    if selected_tab != "Builds":
        return
    var url := "https://api.github.com/repos/xynewageyx/GameForge-AI/actions/workflows/android.yml/runs?per_page=5"
    var headers := ["Accept: application/vnd.github+json", "User-Agent: GameForgeAI"]
    var err := build_status_request.request(url, headers)
    if err != OK:
        status.text = "Build-Liste konnte nicht gestartet werden: " + str(err)
        return
    status.text = "Lade aktuelle GitHub-Builds..."

func _on_builds_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if selected_tab != "Builds" or build_info == null or not is_instance_valid(build_info):
        return
    for child in build_info.get_children():
        child.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS:
        status.text = "GitHub-Build-Liste: Netzwerkfehler " + str(result)
        return
    if code != 200:
        status.text = "GitHub-Build-Liste: HTTP " + str(code) + " (ggf. Rate-Limit)."
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not data is Dictionary:
        status.text = "GitHub-Build-Liste: ungültige Antwort."
        return
    var runs: Variant = data.get("workflow_runs", [])
    if not runs is Array:
        status.text = "GitHub: Keine gültige Build-Liste erhalten."
        return
    var shown := 0
    for run in runs:
        if not run is Dictionary:
            continue
        var run_id := int(run.get("id", 0))
        if run_id <= 0:
            continue
        var state := str(run.get("status", "unknown"))
        var conclusion := str(run.get("conclusion", ""))
        if conclusion != "" and conclusion != "<null>":
            state += " / " + conclusion
        var time_value := str(run.get("created_at", ""))
        var button := Button.new()
        button.text = "#" + str(run.get("run_number", run_id)) + "  " + state + "\n" + time_value
        button.custom_minimum_size.y = 74
        button.add_theme_font_size_override("font_size", 18)
        button.pressed.connect(_open_specific_build.bind(run_id))
        build_info.add_child(button)
        shown += 1
        if shown >= 5:
            break
    status.text = "GitHub-Builds abgerufen: " + str(shown) + " Einträge."
    if shown == 0:
        var hint := Label.new()
        hint.text = "Noch keine Build-Läufe vorhanden."
        build_info.add_child(hint)

func _prepare_build() -> void:
    if selected_tab != "Builds" or build_in_progress:
        status.text = "Derzeit kann kein weiterer Build gestartet werden."
        return
    var token := build_token_input.text.strip_edges()
    if token.is_empty() or token.contains("\n") or token.contains("\r"):
        status.text = "Bitte einen gültigen GitHub-Token mit Actions-Schreibrecht eingeben."
        return
    build_ready = true
    build_confirm_button.disabled = false
    build_confirmation_label.text = "Neuer Cloud-Build:\nRepository: xynewageyx/GameForge-AI\nWorkflow: android.yml\nBranch: main\nKeine APK wird auf dem Handy erzeugt. Erst die Bestätigung startet GitHub Actions."
    status.text = "Build-Auftrag vorbereitet. Bestätigung erforderlich."

func _trigger_build() -> void:
    if not build_ready or build_in_progress or selected_tab != "Builds":
        return
    var token := build_token_input.text.strip_edges()
    if token.is_empty() or token.contains("\n") or token.contains("\r"):
        _cancel_build_confirmation()
        status.text = "GitHub-Token fehlt."
        return
    var url := "https://api.github.com/repos/xynewageyx/GameForge-AI/actions/workflows/android.yml/dispatches"
    var headers := ["Accept: application/vnd.github+json", "Content-Type: application/json", "User-Agent: GameForgeAI", "Authorization: Bearer " + token]
    build_ready = false
    build_confirm_button.disabled = true
    var body := JSON.stringify({"ref": "main"})
    var err := build_trigger_request.request(url, headers, HTTPClient.METHOD_POST, body)
    build_token_input.clear()
    if err != OK:
        status.text = "Build-Anfrage konnte nicht gesendet werden: " + str(err)
        build_confirmation_label.text = "Nicht gestartet. Erneut vorbereiten."
        return
    build_in_progress = true
    status.text = "GitHub-Build wird angefordert..."
    build_confirmation_label.text = "Anfrage gesendet. Bestätigung von GitHub wird geprüft."

func _on_build_trigger_response(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    if not build_in_progress:
        return
    build_in_progress = false
    if result != HTTPRequest.RESULT_SUCCESS:
        status.text = "Netzwerkfehler: " + str(result) + ". Bitte GitHub Actions im Browser prüfen."
    elif code == 204:
        status.text = "Build angefordert! Fortschritt unter GitHub Actions prüfen."
    elif code == 401 or code == 403:
        status.text = "Build abgelehnt (HTTP " + str(code) + "): Actions-Schreibrecht oder Token prüfen."
    elif code == 404:
        status.text = "Workflow nicht gefunden oder kein Zugriff (HTTP 404)."
    elif code == 422:
        status.text = "Build-Aktion ungültig (HTTP 422): Branch/Workflow prüfen."
    else:
        status.text = "GitHub hat den Build nicht bestätigt (HTTP " + str(code) + ")."
    if selected_tab == "Builds" and build_confirmation_label != null and is_instance_valid(build_confirmation_label):
        build_confirmation_label.text = "Anfrage abgeschlossen. Build-Status mit der Schaltfläche oben aktualisieren."

func _render_tab() -> void:
    for child in content.get_children():
        child.queue_free()
    _add_label(selected_tab, 30)
    match selected_tab:
        "Projekte":
            _add_label("Aktives Projekt: " + active_project, 22)
            for project_name in project_names:
                _add_button(project_name, _select_project.bind(project_name))
            _add_label("Lokale Arbeitsbereiche. GitHub-Synchronisierung folgt.", 18)
        "KI-Chat":
            _add_label("KI-Verbindung noch nicht eingerichtet.")
            var prompt := TextEdit.new()
            prompt.custom_minimum_size.y = 240
            prompt.add_theme_font_size_override("font_size", 22)
            prompt.placeholder_text = "Beschreibe dein Spiel oder deine Änderung..."
            content.add_child(prompt)
            var send := Button.new()
            send.text = "KI-Verbindung vorbereiten"
            send.custom_minimum_size.y = 64
            send.add_theme_font_size_override("font_size", 20)
            send.pressed.connect(func(): status.text = "Noch kein KI-Backend verbunden")
            content.add_child(send)
        "Code":
            _add_label("Projekt: " + active_project, 20)
            _add_label("Lokaler Code-Editor (noch keine GitHub-Synchronisierung)", 18)
            file_picker = OptionButton.new()
            file_picker.custom_minimum_size.y = 60
            for filename in file_names:
                file_picker.add_item(filename)
            content.add_child(file_picker)
            current_file_label = Label.new()
            current_file_label.add_theme_font_size_override("font_size", 19)
            content.add_child(current_file_label)
            editor = TextEdit.new()
            editor.custom_minimum_size.y = 430
            editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            editor.add_theme_font_size_override("font_size", 20)
            content.add_child(editor)
            _add_button("Datei laden", _load_local_file)
            _add_button("Lokal speichern", _save_local_file)
            _load_local_file()
            _add_label("GitHub-Datei laden (öffentlich, nur lesen)", 19)
            github_path_input = LineEdit.new()
            github_path_input.placeholder_text = "z. B. project.godot"
            github_path_input.custom_minimum_size.y = 62
            content.add_child(github_path_input)
            _add_label("Repository: " + _github_repo(), 17)
            _add_button("Von GitHub laden", _github_load)
            _add_button("GitHub-Ordner anzeigen", _github_browse)
            _add_button("GitHub-Datei als lokale Kopie sichern", _save_github_copy)
            _add_label("Änderungen auf GitHub veröffentlichen (mit Bestätigung)", 19)
            upload_token_input = LineEdit.new()
            upload_token_input.secret = true
            upload_token_input.placeholder_text = "Fine-grained GitHub-Token (nur während dieser Ansicht)"
            upload_token_input.custom_minimum_size.y = 62
            content.add_child(upload_token_input)
            upload_message_input = LineEdit.new()
            upload_message_input.placeholder_text = "Commit-Nachricht (optional)"
            upload_message_input.custom_minimum_size.y = 62
            content.add_child(upload_message_input)
            _add_button("Änderung prüfen", _prepare_github_upload)
            upload_preview_label = Label.new()
            upload_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            upload_preview_label.add_theme_font_size_override("font_size", 19)
            content.add_child(upload_preview_label)
            upload_confirm_button = Button.new()
            upload_confirm_button.text = "Hochladen verbindlich bestätigen"
            upload_confirm_button.custom_minimum_size.y = 64
            upload_confirm_button.disabled = true
            upload_confirm_button.pressed.connect(_confirm_github_upload)
            content.add_child(upload_confirm_button)
            _add_label("Token nicht speichern oder im Chat teilen. GitHub-Zugriff: Contents (read/write) nur für das gewählte Repository.", 17)
            github_list = VBoxContainer.new()
            github_list.add_theme_constant_override("separation", 8)
            content.add_child(github_list)
        "Builds":
            _add_label("Android APK – GitHub Actions", 24)
            _add_label("Repository: xynewageyx/GameForge-AI  |  Branch: main", 19)
            _add_button("Letzte Build-Ergebnisse abrufen", _refresh_builds)
            _add_button("GitHub Actions im Browser öffnen", _open_builds_in_browser)
            build_info = VBoxContainer.new()
            build_info.add_theme_constant_override("separation", 12)
            content.add_child(build_info)
            _add_label("Neuen APK-Build manuell starten", 23)
            _add_label("Erfordert einen kurzlebigen GitHub-Token mit Actions: Read and write für GameForge-AI. Nicht im Chat teilen.", 18)
            build_token_input = LineEdit.new()
            build_token_input.secret = true
            build_token_input.placeholder_text = "GitHub-Token für Actions (nicht gespeichert)"
            build_token_input.custom_minimum_size.y = 64
            content.add_child(build_token_input)
            _add_button("Build-Auftrag prüfen", _prepare_build)
            build_confirmation_label = Label.new()
            build_confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            build_confirmation_label.add_theme_font_size_override("font_size", 19)
            content.add_child(build_confirmation_label)
            build_confirm_button = Button.new()
            build_confirm_button.text = "Android-Build verbindlich starten"
            build_confirm_button.custom_minimum_size.y = 70
            build_confirm_button.disabled = true
            build_confirm_button.pressed.connect(_trigger_build)
            content.add_child(build_confirm_button)
            _refresh_builds()
        "Einstellungen":
            _add_label("GitHub-Repository: xynewageyx/GameForge-AI")
            _add_label("API-Schlüssel werden nicht in der App gespeichert.")
