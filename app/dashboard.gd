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
var project_names: Array[String] = ["GameForge AI", "Titan Legends", "MangaForge AI"]
var file_names: Array[String] = ["main.gd", "notes.txt"]

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _ensure_workspace()
    github_request = HTTPRequest.new()
    add_child(github_request)
    github_request.request_completed.connect(_github_response)
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
    active_project = name
    status.text = "Aktives Projekt: " + active_project
    _render_tab()

func _load_local_file() -> void:
    if editor == null or file_picker == null:
        return
    var filename := file_names[file_picker.selected]
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
    var filename := file_names[file_picker.selected]
    var file := FileAccess.open(_workspace_path(filename), FileAccess.WRITE)
    if file == null:
        status.text = "Speichern fehlgeschlagen: " + filename
        return
    file.store_string(editor.text)
    file.flush()
    status.text = "Lokal gespeichert: " + filename


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
    editor.text = bytes.get_string_from_utf8()
    status.text = "GitHub-Datei geladen (nur lesen): " + str(data.get("path", ""))

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
            github_list = VBoxContainer.new()
            github_list.add_theme_constant_override("separation", 8)
            content.add_child(github_list)
        "Builds":
            _add_label("GitHub Actions: xynewageyx/GameForge-AI")
            _add_label("APK-Build erfolgreich. Live-Status folgt.")
        "Einstellungen":
            _add_label("GitHub-Repository: xynewageyx/GameForge-AI")
            _add_label("API-Schlüssel werden nicht in der App gespeichert.")
