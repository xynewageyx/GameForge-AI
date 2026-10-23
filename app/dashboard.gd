extends Control

var selected_tab: String = "Projekte"
var tabs: Array[String] = ["Projekte", "KI-Chat", "Code", "Builds", "Einstellungen"]
var content: VBoxContainer
var status: Label
var navigation: HFlowContainer
var active_project: String = "GameForge AI"
var editor: TextEdit
var file_picker: OptionButton
var project_names: Array[String] = ["GameForge AI", "Titan Legends", "MangaForge AI"]
var file_names: Array[String] = ["main.gd", "notes.txt"]

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _ensure_workspace()
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
        "Builds":
            _add_label("GitHub Actions: xynewageyx/GameForge-AI")
            _add_label("APK-Build erfolgreich. Live-Status folgt.")
        "Einstellungen":
            _add_label("GitHub-Repository: xynewageyx/GameForge-AI")
            _add_label("API-Schlüssel werden nicht in der App gespeichert.")
