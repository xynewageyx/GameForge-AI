extends Control

var selected_tab: String = "Projekte"
var tabs: Array[String] = ["Projekte", "KI-Chat", "Code", "Builds", "Einstellungen"]
var content: VBoxContainer
var status: Label
var navigation: HFlowContainer

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

func _render_tab() -> void:
    for child in content.get_children():
        child.queue_free()
    _add_label(selected_tab, 30)
    match selected_tab:
        "Projekte":
            _add_label("GameForge AI Starter\nGodot 4.7.2  |  Android")
            _add_label("Projektverwaltung über GitHub folgt.")
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
            _add_label("GDScript-Editor folgt. Noch keine Dateibearbeitung.")
        "Builds":
            _add_label("GitHub Actions: xynewageyx/GameForge-AI")
            _add_label("APK-Build erfolgreich. Live-Status folgt.")
        "Einstellungen":
            _add_label("GitHub-Repository: xynewageyx/GameForge-AI")
            _add_label("API-Schlüssel werden nicht in der App gespeichert.")
