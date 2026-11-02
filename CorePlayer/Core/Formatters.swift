import Foundation

enum Formatters {
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func totalDuration(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "" }
        let minutes = max(1, seconds / 60)
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
        }
        return "\(minutes) мин"
    }

    static func trackCount(_ count: Int?) -> String {
        let n = count ?? 0
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "\(n) трек" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(n) трека" }
        return "\(n) треков"
    }

    static func albumCount(_ count: Int?) -> String {
        let n = count ?? 0
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "\(n) альбом" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(n) альбома" }
        return "\(n) альбомов"
    }
}
