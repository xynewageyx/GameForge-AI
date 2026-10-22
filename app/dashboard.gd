extends Control

var selected_tab: String = "Projekte"
var tabs: Array[String] = ["Projekte", "KI-Chat", "Code", "Builds", "Einstellungen"]
var content: VBoxContainer
var status: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_ui()

func _build_ui() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var heading := Label.new()
    heading.text = "GAMEFORGE AI"
    heading.add_theme_font_size_override("font_size", 30)
    root.add_child(heading)

    status = Label.new()
    status.text = "Android Game Studio · Vorschau"
    root.add_child(status)

    var navigation := HFlowContainer.new()
    root.add_child(navigation)
    for tab in tabs:
        var button := Button.new()
        button.text = tab
        button.pressed.connect(_select_tab.bind(tab))
        navigation.add_child(button)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)
    _render_tab()

func _select_tab(tab: String) -> void:
    selected_tab = tab
    _render_tab()

func _add_label(message: String) -> void:
    var label := Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(label)

func _render_tab() -> void:
    for child in content.get_children():
        child.queue_free()
    _add_label(selected_tab)
    match selected_tab:
        "Projekte":
            _add_label("GameForge AI Starter\nGodot 4 · Android")
            _add_label("Projektverwaltung über GitHub folgt.")
        "KI-Chat":
            _add_label("KI-Verbindung noch nicht eingerichtet.")
            var prompt := TextEdit.new()
            prompt.custom_minimum_size.y = 180
            prompt.placeholder_text = "Beschreibe dein Spiel oder deine Änderung..."
            content.add_child(prompt)
            var send := Button.new()
            send.text = "KI-Verbindung vorbereiten"
            send.pressed.connect(func(): status.text = "Noch kein KI-Backend verbunden")
            content.add_child(send)
        "Code":
            _add_label("GDScript-Editor folgt. Noch keine Dateibearbeitung.")
        "Builds":
            _add_label("GitHub Actions: xynewageyx/GameForge-AI")
            _add_label("Live-Status und APK-Download folgen.")
        "Einstellungen":
            _add_label("GitHub-Repository: xynewageyx/GameForge-AI")
            _add_label("API-Schlüssel werden nicht in der App gespeichert.")
