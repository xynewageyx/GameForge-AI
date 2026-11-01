extends RefCounted
## Speichert nur den zuletzt gewählten Projektnamen lokal auf Android.
## Keine GitHub- oder KI-Zugangsdaten werden hier abgelegt.

const SETTINGS_PATH: String = "user://gameforge_preferences.cfg"
const SECTION: String = "workspace"
const PROJECT_KEY: String = "active_project"

static func load_active_project(allowed_projects: Array[String], fallback: String = "GameForge AI", settings_path: String = SETTINGS_PATH) -> String:
    var settings := ConfigFile.new()
    if settings.load(settings_path) != OK:
        return fallback
    var stored: Variant = settings.get_value(SECTION, PROJECT_KEY, fallback)
    if typeof(stored) != TYPE_STRING:
        return fallback
    var project: String = stored
    if not allowed_projects.has(project):
        return fallback
    return project

static func save_active_project(project: String, allowed_projects: Array[String], settings_path: String = SETTINGS_PATH) -> Error:
    if not allowed_projects.has(project):
        return ERR_INVALID_PARAMETER
    var settings := ConfigFile.new()
    if FileAccess.file_exists(settings_path):
        var load_error := settings.load(settings_path)
        if load_error != OK:
            return load_error
    settings.set_value(SECTION, PROJECT_KEY, project)
    return settings.save(settings_path)
