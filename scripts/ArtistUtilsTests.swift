import Foundation

@main
struct ArtistUtilsTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        if condition {
            print("  ok  \(message)")
        } else {
            failures += 1
            print("  FAIL \(message)")
        }
    }

    static func main() {
        print("cleanArtistName")
        expect(cleanArtistName("Kai Angel, 9mice • Дмитрий Олегович Ицков") == "Kai Angel, 9mice", "strips FIO after •")
        expect(cleanArtistName("madk1d / Серков Марк Робертович") == "madk1d", "strips FIO after /")
        expect(cleanArtistName("madk1d, Серков Марк Робертович") == "madk1d", "strips FIO after ,")
        expect(cleanArtistName("madk1d; Серков Марк Робертович") == "madk1d", "strips FIO after ;")
        expect(cleanArtistName("Kai Angel") == "Kai Angel", "keeps plain artist")
        expect(cleanArtistName("Серков Марк Робертович") == "", "empty when only FIO")
        expect(cleanArtistName("Куроедов Никитович") == "", "patronymic-only double word")
        expect(cleanArtistName("Кай Энгел") == "Кай Энгел", "cyrillic without patronymic stays")
        expect(cleanArtistName(nil) == "", "nil -> empty")
        expect(cleanArtistName("") == "", "blank -> empty")
        expect(cleanArtistName("Kai Angel • Dmitriy Olegovich Itskov") == "Kai Angel", "strips Latin FIO after •")
        expect(cleanArtistName("Kai Angel • Dmitri Itskov") == "Kai Angel", "strips Latin name+surname after •")
        expect(cleanArtistName("LIDA (Паньков Николай Романович)") == "LIDA", "strips cyrillic FIO in parentheses")
        expect(cleanArtistName("Kai Angel (Dmitriy Olegovich Itskov)") == "Kai Angel", "strips latin FIO in parentheses")
        expect(cleanArtistName("madk1d (ф и о)") == "madk1d", "strips explicit FIO parentheses")
        expect(cleanArtistName("OG Buda / Ляхов Григорий Алексеевич") == "OG Buda", "strips FIO after /")
        expect(cleanArtistName("9mice, Дмитриев Сергей Дмитриевич") == "9mice", "strips FIO after comma")
        expect(cleanArtistName("Kai Angel - Dmitriy Olegovich Itskov") == "Kai Angel", "strips FIO after dash")
        expect(cleanArtistName("Ицков Дмитрий Олегович") == "", "empty when only cyrillic FIO")
        expect(cleanArtistName("Dmitriy Olegovich Itskov") == "", "empty when only latin FIO")
        expect(cleanArtistName("Иванов И. И.") == "", "empty for initials form")
        expect(cleanArtistName("Kai Angel - Dmitri Itskov") == "Kai Angel", "dash with latin name+surname")
        expect(cleanArtistName("Swedish House Mafia") == "Swedish House Mafia", "latin trio without patronymic stays")
        expect(cleanArtistName("Kai Angel (The Best Of)") == "Kai Angel (The Best Of)", "non-FIO parentheses stay")

        print("TrackDto")
        let t = TrackDto(id: "1", title: "LIPSTICK", artist: "Kai Angel, 9mice • Дмитрий Олегович Ицков")
        expect(t.displayArtist == "Kai Angel, 9mice", "displayArtist cleaned")
        let t2 = TrackDto(id: "2", title: "x", artist: "Серков Марк Робертович")
        expect(t2.displayArtist == "Неизвестный исполнитель", "FIO-only falls back to unknown")

        if failures == 0 {
            print("All artist tests passed.")
        } else {
            print("\(failures) FAILED")
            exit(1)
        }
    }
}
