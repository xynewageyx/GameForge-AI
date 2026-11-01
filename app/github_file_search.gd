extends RefCounted
## Durchsucht einen von GitHub gelieferten rekursiven Dateibaum.
## Nur Dateipfade, kein Dateiinhalt und kein GitHub-Schreibzugriff.

static func filter_tree(payload: Dictionary, search_term: String, max_results: int = 75) -> Dictionary:
    var term := search_term.strip_edges().to_lower()
    if term.length() < 2:
        return {"files": [], "total_matches": 0, "truncated": false, "error": "Bitte mindestens zwei Zeichen eingeben."}
    var tree: Variant = payload.get("tree", [])
    if not tree is Array:
        return {"files": [], "total_matches": 0, "truncated": false, "error": "Ungültige GitHub-Dateiliste."}
    var limit := clampi(max_results, 1, 100)
    var files: Array[Dictionary] = []
    var matches := 0
    for item in tree:
        if not item is Dictionary or str(item.get("type", "")) != "blob":
            continue
        var path := str(item.get("path", ""))
        if path.is_empty() or not path.to_lower().contains(term):
            continue
        matches += 1
        if files.size() < limit:
            files.append({"path": path, "name": path.get_file(), "type": "file"})
    return {
        "files": files,
        "total_matches": matches,
        "truncated": bool(payload.get("truncated", false)),
        "error": ""
    }
