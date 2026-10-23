extends RefCounted
## Extrahiert nur einen Markdown-GDScript-Codeblock aus einer KI-Antwort.
## Keine Ausführung, Speicherung oder Projektänderung.

static func extract_first_gdscript(answer: String) -> String:
    var cursor := 0
    while cursor < answer.length():
        var opening := answer.find("``", cursor)
        if opening < 0:
            return ""
        var header_end := answer.find("\n", opening + 3)
        if header_end < 0:
            return ""
        var language := answer.substr(opening + 3, header_end - opening - 3).strip_edges().to_lower()
        var closing := answer.find("``", header_end + 1)
        if closing < 0:
            return ""
        if language == "gdscript" or language == "gd" or language == "":
            var code := answer.substr(header_end + 1, closing - header_end - 1).strip_edges()
            if not code.is_empty() and code.to_utf8_buffer().size() <= 1048576:
                return code + "\n"
        cursor = closing + 3
    return ""
