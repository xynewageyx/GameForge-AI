extends RefCounted
## Lokale Wiederherstellungs-Snapshots. Niemals GitHub-Dateien oder Originaldateien überschreiben.
## Pro Projekt und Quelldatei wird getrennt gespeichert.

const MAX_BYTES: int = 1048576
const MAX_ENTRIES: int = 100

static func _folder(project_name: String) -> String:
    return "user://" + project_name.validate_filename().replace(" ", "_") + "/recovery"

static func snapshot_id(project_name: String, source: String, file_path: String, repo: String = "") -> String:
    return (project_name + "|" + source + "|" + repo + "|" + file_path).sha256_text()

static func _snapshot_path(project_name: String, id: String) -> String:
    return _folder(project_name) + "/" + id + ".json"

static func _valid_id(id: String) -> bool:
    if id.length() != 64:
        return false
    for letter in id:
        if not letter in "0123456789abcdef":
            return false
    return true

static func save_snapshot(project_name: String, source: String, file_path: String, repo: String, code: String) -> Error:
    if project_name.is_empty() or file_path.strip_edges().is_empty():
        return ERR_INVALID_PARAMETER
    if source != "local" and source != "github" and source != "ai_draft":
        return ERR_INVALID_PARAMETER
    if code.to_utf8_buffer().size() > MAX_BYTES:
        return ERR_OUT_OF_MEMORY
    var folder := _folder(project_name)
    var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    if err != OK:
        return err
    var id := snapshot_id(project_name, source, file_path, repo)
    var path := _snapshot_path(project_name, id)
    var document := {
        "version": 1,
        "project": project_name,
        "source": source,
        "path": file_path,
        "repo": repo,
        "content": code,
        "saved_at": Time.get_datetime_string_from_system()
    }
    var temporary := path + ".tmp"
    var stream := FileAccess.open(temporary, FileAccess.WRITE)
    if stream == null:
        return FileAccess.get_open_error()
    stream.store_string(JSON.stringify(document))
    stream.flush()
    stream.close()
    err = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
    if err != OK:
        return err
    return OK

static func read_snapshot(project_name: String, id: String) -> Dictionary:
    if not _valid_id(id):
        return {}
    var path := _snapshot_path(project_name, id)
    if not FileAccess.file_exists(path):
        return {}
    var stream := FileAccess.open(path, FileAccess.READ)
    if stream == null or stream.get_length() > MAX_BYTES * 3:
        return {}
    var document: Variant = JSON.parse_string(stream.get_as_text())
    if not document is Dictionary:
        return {}
    if document.get("version", 0) != 1 or document.get("project", "") != project_name:
        return {}
    var source := str(document.get("source", ""))
    var file_path := str(document.get("path", ""))
    var repo := str(document.get("repo", ""))
    if snapshot_id(project_name, source, file_path, repo) != id:
        return {}
    if str(document.get("content", "")).to_utf8_buffer().size() > MAX_BYTES:
        return {}
    return document

static func list_snapshots(project_name: String) -> Array:
    var list: Array = []
    var directory := DirAccess.open(_folder(project_name))
    if directory == null:
        return list
    var files := directory.get_files()
    for filename in files:
        if not filename.ends_with(".json"):
            continue
        var id := filename.trim_suffix(".json")
        var snapshot := read_snapshot(project_name, id)
        if snapshot.is_empty():
            continue
        snapshot["id"] = id
        list.append(snapshot)
        if list.size() >= MAX_ENTRIES:
            break
    list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("saved_at", "")) > str(b.get("saved_at", ""))
    )
    return list

static func delete_snapshot(project_name: String, id: String) -> Error:
    if not _valid_id(id):
        return ERR_INVALID_PARAMETER
    var path := _snapshot_path(project_name, id)
    if not FileAccess.file_exists(path):
        return ERR_FILE_NOT_FOUND
    return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
