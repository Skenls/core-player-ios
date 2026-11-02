import Foundation

// Port of the Android artist-name cleaner: strips patronymic "ФИО" credits that
// ID3 tags attach to artist fields, e.g. "madk1d • Серков Марк Робертович" -> "madk1d".

private func isFio(_ part: String) -> Bool {
    let words = part.trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
    guard words.count >= 2, words.count <= 4 else { return false }

    let patronymic = ".*(ович|евич|ич|овна|евна|ична|инична)$"
    let cyrillic = "^[А-Яа-яЁё\\-]+$"

    let hasPatronymic = words.contains { $0.range(of: patronymic, options: [.regularExpression, .caseInsensitive]) != nil }
    let allCyrillic = words.allSatisfy { $0.range(of: cyrillic, options: [.regularExpression]) != nil }
    return hasPatronymic && allCyrillic
}

func cleanArtistName(_ raw: String?) -> String {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if isFio(trimmed) { return "" }

    func filtered(_ parts: [String]) -> [String] {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isFio($0) }
    }

    for (separator, joined) in [("•", " • "), ("/", ", "), (",", ", "), (";", ", ")] {
        if trimmed.contains(separator) {
            let parts = filtered(trimmed.components(separatedBy: separator))
            if !parts.isEmpty {
                return parts.joined(separator: joined)
            }
        }
    }
    return trimmed
}
