extends SceneTree

const PROJECT_PREFERENCES = preload("res://app/project_preferences.gd")
const TEST_PATH: String = "user://project_preferences_smoke.cfg"

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var projects: Array[String] = ["GameForge AI", "Titan Legends", "MangaForge AI"]
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

    if PROJECT_PREFERENCES.load_active_project(projects, "GameForge AI", TEST_PATH) != "GameForge AI":
        _fail("Missing settings must return default project")
        return

    if PROJECT_PREFERENCES.save_active_project("Titan Legends", projects, TEST_PATH) != OK:
        _fail("Cannot save valid project")
        return

    if PROJECT_PREFERENCES.load_active_project(projects, "GameForge AI", TEST_PATH) != "Titan Legends":
        _fail("Last selected project was not persisted")
        return

    if PROJECT_PREFERENCES.save_active_project("Unknown", projects, TEST_PATH) != ERR_INVALID_PARAMETER:
        _fail("Unknown projects must be rejected")
        return

    var settings := ConfigFile.new()
    if settings.load(TEST_PATH) != OK:
        _fail("Cannot load test settings")
        return
    settings.set_value("workspace", "active_project", "Unknown")
    if settings.save(TEST_PATH) != OK:
        _fail("Cannot store test invalid project")
        return
    if PROJECT_PREFERENCES.load_active_project(projects, "GameForge AI", TEST_PATH) != "GameForge AI":
        _fail("Unlisted project must fall back safely")
        return

    settings.set_value("workspace", "active_project", 123)
    if settings.save(TEST_PATH) != OK:
        _fail("Cannot store test invalid type")
        return
    if PROJECT_PREFERENCES.load_active_project(projects, "GameForge AI", TEST_PATH) != "GameForge AI":
        _fail("Non-string settings must fall back safely")
        return

    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    print("Project preferences smoke tests passed")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    quit(1)
