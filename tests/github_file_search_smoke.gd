extends SceneTree

const SEARCH = preload("res://app/github_file_search.gd")

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var tree: Dictionary = {
        "truncated": false,
        "tree": [
            {"path": "scripts/BossController.gd", "type": "blob"},
            {"path": "scripts/player.gd", "type": "blob"},
            {"path": "scenes/boss/BossArena.tscn", "type": "blob"},
            {"path": "scripts/boss", "type": "tree"},
            {"path": "docs/BOSS_NOTES.md", "type": "blob"}
        ]
    }
    var matches: Dictionary = SEARCH.filter_tree(tree, "boss")
    if int(matches.get("total_matches", -1)) != 3:
        _fail("Case-insensitive repository-wide search must match three file paths")
        return
    var files: Array = matches.get("files", [])
    if files.size() != 3 or str(files[0].get("path", "")) != "scripts/BossController.gd":
        _fail("Search returned incorrect paths or included directories")
        return
    var limited: Dictionary = SEARCH.filter_tree(tree, "boss", 2)
    var limited_files: Array = limited.get("files", [])
    if int(limited.get("total_matches", 0)) != 3 or limited_files.size() != 2:
        _fail("Search result limit must not hide total match count")
        return
    var short_query: Dictionary = SEARCH.filter_tree(tree, "b")
    if str(short_query.get("error", "")).is_empty():
        _fail("Single-letter searches must be rejected")
        return
    var invalid: Dictionary = SEARCH.filter_tree({"tree": "invalid"}, "boss")
    if str(invalid.get("error", "")).is_empty():
        _fail("Invalid tree payload must be rejected")
        return
    tree["truncated"] = true
    var incomplete: Dictionary = SEARCH.filter_tree(tree, "player")
    if not bool(incomplete.get("truncated", false)):
        _fail("GitHub truncation must be surfaced to UI")
        return
    var empty: Dictionary = SEARCH.filter_tree(tree, "missing")
    if int(empty.get("total_matches", -1)) != 0:
        _fail("Unknown filenames must yield zero matches")
        return
    print("GitHub file search smoke tests passed")
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)
