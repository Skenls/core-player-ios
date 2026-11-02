import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let time: Double
    let text: String
}

enum LRCParser {
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]"#
    )

    static func parse(_ raw: String) -> [LyricLine] {
        guard !raw.isEmpty else { return [] }

        var entries: [(time: Double, text: String, order: Int)] = []
        var order = 0

        raw.components(separatedBy: .newlines).forEach { line in
            let nsLine = line as NSString
            let matches = timestampRegex.matches(
                in: line,
                range: NSRange(location: 0, length: nsLine.length)
            )
            guard !matches.isEmpty else { return }

            let text = timestampRegex
                .stringByReplacingMatches(
                    in: line,
                    range: NSRange(location: 0, length: nsLine.length),
                    withTemplate: ""
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

            for match in matches {
                let minutes = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(nsLine.substring(with: match.range(at: 2))) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let rawFraction = nsLine.substring(with: match.range(at: 3))
                    fraction = (Double(rawFraction) ?? 0) / pow(10, Double(rawFraction.count))
                }
                entries.append((minutes * 60 + seconds + fraction, text, order))
                order += 1
            }
        }

        entries.sort {
            if abs($0.time - $1.time) > 0.0001 { return $0.time < $1.time }
            return $0.order < $1.order
        }

        return entries.enumerated().map { index, entry in
            LyricLine(id: index, time: entry.time, text: entry.text)
        }
    }

    /// Index of the line that should be highlighted at `time`.
    static func currentIndex(_ lines: [LyricLine], at time: Double) -> Int? {
        guard !lines.isEmpty else { return nil }
        var low = 0
        var high = lines.count - 1
        var answer: Int?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= time + 0.05 {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }
}
