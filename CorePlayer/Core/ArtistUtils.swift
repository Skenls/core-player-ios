import Foundation

// Port of the web artist-name cleaner (frontend/src/lib/formatters.ts): strips
// patronymic "ФИО" credits that ID3 tags attach to artist fields, in Russian and
// Latin, e.g. "Kai Angel • Ицков Дмитрий Олегович" or "Kai Angel (Dmitriy Olegovich
// Itskov)" -> "Kai Angel".

private let explicitFioPattern = "^(?:ф\\s*[.\\s]*и\\s*[.\\s]*о|фио|f\\s*[.\\s]*i\\s*[.\\s]*o|fio)$"

// Latin words are matched without the bare "ich"/"ich" endings to keep names like
// "Swedish House Mafia" safe; Cyrillic keeps "ич" for patronymics like "Никитович".
private let patronymicPattern =
    "(ович|евич|ич|овна|евна|ична|инична|ovich|evich|ovna|evna|ichna|inichna|ovych|evych|ivna|avna)$"

private let surnamePattern =
    "(ов|ова|ев|ева|ёв|ёва|ин|ина|ын|ына|ский|ская|ской|цкий|цкая|енко|чук|ov|ova|ev|eva|off|in|ina|yn|yna|sky|skiy|skaya|tsky|tskiy|enko|chuk)$"

private let commonFirstNamesPattern = "^(?:dmitri|dmitriy|dmitry|dima|sergei|sergey|serezha|nikolai|nikolay|kolya|grigori|grigoriy|grigory|grisha|aleksandr|alexander|alexandr|sasha|shura|aleksei|aleksey|alexey|lesha|ivan|vanya|mikhail|misha|maksim|maxim|artem|artyom|tema|danil|daniil|danila|danya|vladimir|vova|volodya|vladislav|vlad|denis|pavel|pasha|egor|ilya|ilyusha|kirill|timur|roman|roma|anton|antoha|oleg|gleb|matvey|yaroslav|fedor|fedya|stepan|styopa|anna|anya|elena|lena|olga|olya|tatiana|tatyana|tanya|ekaterina|katya|maria|masha|anastasia|nastya|polina|daria|dasha|alisa|ksenia|ksyusha|дмитрий|дима|сергей|серёжа|николай|коля|григорий|гриша|александр|саша|алексей|лёша|иван|ваня|михаил|миша|максим|артём|артем|данил|даниил|данила|владимир|вова|владислав|влад|денис|павел|паша|егор|илья|кирилл|тимур|роман|антон|олег|глеб|матвей|ярослав|фёдор|федор|степан|стёпа|анна|елена|ольга|татьяна|екатерина|мария|анастасия|полина|дарья|алиса|ксения)$"

private func words(of text: String) -> [String] {
    text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
}

func isFioSegment(_ segment: String) -> Bool {
    let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    if trimmed.range(of: explicitFioPattern, options: [.regularExpression, .caseInsensitive]) != nil {
        return true
    }

    let parts = words(of: trimmed)
    guard parts.count >= 2, parts.count <= 4 else { return false }

    let cyrillic = "^[А-Яа-яЁё.\\-]+$"
    let latin = "^[A-Za-z.\\-']+$"
    let allCyrillic = parts.allSatisfy { $0.range(of: cyrillic, options: [.regularExpression]) != nil }
    let allLatin = parts.allSatisfy { $0.range(of: latin, options: [.regularExpression]) != nil }
    guard allCyrillic || allLatin else { return false }

    let hasPatronymic = parts.contains {
        $0.range(of: patronymicPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    if hasPatronymic { return true }

    let hasInitials = parts.contains {
        $0.range(of: "^[А-Яа-яЁёA-Za-z]\\.$", options: [.regularExpression]) != nil
    }
    if hasInitials { return true }

    let hasFirstName = parts.contains {
        $0.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .range(of: commonFirstNamesPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    let hasSurname = parts.contains {
        $0.range(of: surnamePattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    return hasFirstName && hasSurname
}

func cleanArtistName(_ raw: String?) -> String {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
    var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if isFioSegment(cleaned) { return "" }

    // Parenthetical credits: "(ф и о)", "(Ицков Дмитрий Олегovich)", "(Ицков Д. О.)".
    cleaned = cleaned.replacingOccurrences(
        of: "\\s*\\(\\s*(?:ф\\s*[.\\s]*и\\s*[.\\s]*о|фио|f\\s*[.\\s]*i\\s*[.\\s]*o|fio)\\s*\\)",
        with: "",
        options: [.regularExpression, .caseInsensitive]
    )
    cleaned = cleaned.replacingOccurrences(
        of: "\\s*\\([^)]*(?:ович|евич|ич|овна|евна|ична|инична|ovich|evich|ovna|evna|ichna|inichna|ovych|evych|ivna|avna)[^)]*\\)",
        with: "",
        options: [.regularExpression, .caseInsensitive]
    )
    cleaned = cleaned.replacingOccurrences(
        of: "\\s*\\((?:[A-ZА-ЯЁ][a-zа-яё]+\\s+(?:[A-ZА-ЯЁ]\\.\\s*)+|(?:[A-ZА-ЯЁ]\\.\\s*)+[A-ZА-ЯЁ][a-zа-яё]+)\\)",
        with: "",
        options: [.regularExpression]
    )

    // Dash separator with FIO on one side: "Kai Angel - Dmitriy Olegovich Itskov".
    if let dash = cleaned.range(of: "\\s+[-—–]\\s+", options: [.regularExpression]) {
        let head = String(cleaned[..<dash.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = String(cleaned[dash.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if isFioSegment(tail) {
            cleaned = head
        } else if isFioSegment(head) {
            cleaned = tail
        }
    }

    func filtered(_ parts: [String]) -> [String] {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isFioSegment($0) }
    }

    for (separator, joined) in [("•", " • "), ("·", " • "), ("|", " • "), ("/", ", "), (",", ", "), (";", ", ")] {
        if cleaned.contains(separator) {
            let parts = filtered(cleaned.components(separatedBy: separator))
            if !parts.isEmpty {
                cleaned = parts.joined(separator: joined)
            }
            break
        }
    }

    return isFioSegment(cleaned) ? "" : cleaned
}
