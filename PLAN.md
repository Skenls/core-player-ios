# Core Player для iOS — план разработки

Дата проверки системы: 2026-11-01. Источник истины по функциям — `Skenls/core-player-android` (v0.2.4-b), API — `Skenls/core-player/backend`.

---

## 0. Коротко

- **Цель:** iOS-приложение с тем же набором функций и тем же поведением, что Android-плеер, на том же backend API.
- **Стек:** SwiftUI + AVFoundation + async/await. Обязательных сторонних библиотек нет.
- **Главный блокер:** на Mac **не установлен Xcode** (только Command Line Tools). Без полного Xcode собрать, запустить и подписать iOS-приложение нельзя.
- **Срок:** ~7–9 недель full-time для опытного iOS-разработчика. При совмещении с другой работой — 2,5–3,5 месяца.
- **Два места, где «идентично» потребует решения:** формат **Opus/Ogg** (AVPlayer его не играет) и **потоковый кэш 500 МБ** (в iOS нет готового аналога ExoPlayer `SimpleCache`).
- **Backend менять не обязательно** для v1. Все нужные эндпоинты уже есть, включая авторизацию через `?session_id=` (критично для AVPlayer).

---

## 1. Что уже есть

### 1.1 Android-приложение

| Параметр | Значение |
|---|---|
| Язык / UI | Kotlin, Jetpack Compose |
| Плеер | Media3 / ExoPlayer, два плеера для кроссфейда |
| minSdk / targetSdk | 26 / 35 |
| Версия | 0.2.4-b |
| Пакет | `com.coreplayer.app` |
| Сеть | Retrofit + OkHttp, cookie-jar с `session_id` |
| Кэш | Media3 `SimpleCache`, LRU, **500 МБ** |
| Фон | Foreground Service + MediaSession |

Экраны и компоненты:

- `Login` — адрес сервера, логин, пароль.
- `Home` — недавние/рекомендации, избранное, плейлисты, случайные треки.
- `Browse` («Все треки») — 3 вкладки: альбомы, исполнители, треки.
- `Library` («Медиатека») — 2 вкладки: «Мои треки» (избранное) и «Плейлисты».
- Детали: альбом, исполнитель, плейлист.
- `Search` — поиск по библиотеке + история запросов.
- `Now Playing` — нижний sheet: обложка, blur-фон, прогресс, текст песни, shuffle/repeat.
- `SyncedLyrics` — караоке-подсветка по LRC.
- `Settings` — фон плеера, AMOLED, «адаптивный пузырь», кроссфейд, кодек, выход.
- Mini-player — «пузырь» над таб-баром.

Функции плеера:

- очередь, следующий/предыдущий, seek;
- shuffle и repeat (off / all / one);
- автопереход;
- кроссфейд **3,5 с**, включается только для треков длиннее **12 с**, стартует за **4 с** до конца; работает и для repeat-one;
- фоновое воспроизведение, уведомление и экран блокировки;
- аудиофокус, пауза при звонке, обработка отключения наушников;
- предзагрузка следующего трека в кэш;
- выбор кодека: **Auto (исходный) / MP3 320 CBR / Opus 160 VBR / FLAC lossless**;
- настройки по умолчанию: фон «под обложку», адаптивный пузырь — вкл, AMOLED — выкл, кроссфейд — вкл, кодек — auto.

### 1.2 Backend (FastAPI + Navidrome)

- Авторизация: `POST /api/auth/login`, cookie `session_id` (HttpOnly, 30 дней).
- **Важно:** backend принимает `session_id` не только в cookie, но и как query-параметр `?session_id=...` для любого авторизованного эндпоинта. Это единственный надёжный способ авторизовать запросы AVPlayer (он не использует cookie из URLSession).
- Стриминг: `GET /api/stream/{track_id}?format=mp3|opus|flac&estimateContentLength=true`, Range-запросы проксируются в Navidrome.
- Обложки: `GET /api/stream/cover/{id}?size=300|600|1200`.
- Тексты: `GET /api/lyrics/{track_id}` (+ fallback по артисту/названию/альбому/длительности).
- Ответы — snake_case JSON, даты/числа — стандартные.

Полный список эндпоинтов — в приложении A.

### 1.3 Web-плеер

React 18 + Vite + HTMLAudio. Полезен как референс поведения API, но **эталон для iOS — Android-приложение**, а не веб.

---

## 2. Целевая архитектура iOS

```
CorePlayer (SwiftUI app)
├── App/                 App entry, DI-контейнер, роутинг
├── Core/
│   ├── Networking/      APIClient, Endpoint, ошибки, cookie/session
│   ├── Models/          Codable-модели (1:1 с Kotlin DTO)
│   ├── Storage/         Keychain, UserDefaults, файловый кэш
│   ├── DesignSystem/    цвета, типографика, компоненты
│   └── Utils/           URL-билдеры, LRC-парсер, форматтеры
├── Features/
│   ├── Login/
│   ├── Home/
│   ├── Library/
│   ├── Browse/
│   ├── Search/
│   ├── NowPlaying/
│   ├── Queue/
│   └── Settings/
├── Playback/
│   ├── AudioSession
│   ├── PlayerEngine     протокол + DualAVPlayerEngine
│   ├── PlayerStore      очередь, режимы, состояние
│   ├── NowPlayingCenter MPNowPlayingInfoCenter
│   ├── RemoteCommands   MPRemoteCommandCenter
│   ├── Crossfade
│   └── TrackCache       500 МБ LRU + prefetch
└── Resources/           Assets, Localizable.xcstrings, Info.plist
```

Принципы:

- **Никакого Rx/Swinject/Combine-стека.** `async/await` + `@Observable` (iOS 17+).
- **Слой API отделён от UI.** Экраны не знают про URLSession.
- **Движок плеера за протоколом.** Если Opus всё-таки понадобится — меняется только реализация.
- **Один источник настроек** — `SettingsStore` поверх `UserDefaults`, реактивно через `@Observable`.

Структура репозитория:

```
core-player-ios/
├── project.yml                 # XcodeGen (рекомендуется)
├── CorePlayer/
│   ├── App/
│   ├── Core/
│   ├── Features/
│   ├── Playback/
│   └── Resources/
├── CorePlayerTests/
├── CorePlayerUITests/
├── docs/
│   ├── PLAN.md                 # этот файл
│   ├── API.md
│   └── TESTPLAN.md
└── .github/workflows/ci.yml    # опционально
```

---

## 3. Паритет функций: Android → iOS

| Функция | Android | iOS-реализация | Сложность |
|---|---|---|---|
| Логин по адресу сервера | Retrofit + cookie | URLSession, `Set-Cookie` → Keychain | S |
| Хранение сессии | SharedPreferences + cookie | Keychain + UserDefaults (URL) | S |
| Home / Library / Browse / Search | Compose + ViewModel | SwiftUI + `@Observable` | M |
| Плейлисты: создать, добавить, удалить, reorder | REST | те же вызовы | M |
| Избранное (треки/альбомы/артисты) | REST | те же вызовы | S |
| Недавние треки (4) и история поиска | SharedPreferences | UserDefaults + `@Observable` | S |
| Обложки | Coil + disk cache | Kingfisher или свой URLCache-загрузчик | S |
| Очередь, shuffle, repeat | ExoPlayer | `PlayerStore` + AVPlayer | M |
| Кроссфейд | 2× ExoPlayer, 3,5 с / 1,0 с при ручном skip | 2× AVPlayer + ramp громкости | M |
| Фон и экран блокировки | MediaSession + Service | AVAudioSession + NowPlaying + RemoteCommands | M |
| Тексты LRC, караоке | Compose | SwiftUI + TimelineView | M |
| Кэш 500 МБ + prefetch | SimpleCache | `AVAssetResourceLoaderDelegate` + LRU | **L** |
| Настройки (фон, AMOLED, пузырь, кодек) | SharedPreferences | UserDefaults + SwiftUI | S |
| Выбор кодека | ExoPlayer | AVPlayer: MP3/FLAC/AAC; Opus — см. §4.3 | M |
| Обработка звонков/наушников | AudioFocus | AVAudioSession notifications | S |
| Русский UI | хардкод строк | String Catalog (`ru` base) | S |
| Виджеты, CarPlay, Siri, скачивание альбомов | нет | **вне скоупа** | — |

> **Про «идентично».** Функционально и по поведению — да, 1:1. Пиксель-в-пиксель UI не получится и не нужен: на iOS другие системные шрифты, отступы, переходы, sheet-механика и tab bar. Цвета, структура экранов, логика и тексты повторяются.

---

## 4. Ключевые технические решения

### 4.1 Аудиодвижок

**Выбор: AVPlayer, два экземпляра.**

- `AVPlayer` — нативный, аппаратное декодирование, поддержка фона, lock screen, AirPods, CarPlay-совместимых маршрутов.
- Два плеера нужны только для кроссфейда; в обычном режиме активен один.
- `AVQueuePlayer` не даёт кроссфейд, поэтому не подходит как основной.
- `AVAudioEngine` дал бы семпл-точный микс, но потребует собственной реализации стриминга, seek и кэша — на порядок больше работы. Не для v1.
- VLCKit/MobileVLCKit решил бы Opus, но весит ~100 МБ, хуже дружит с кроссфейдом и усложняет App Store. Не для v1.

Протокол:

```swift
protocol AudioEngine: AnyObject {
    var onStateChange: ((EngineState) -> Void)? { get set }
    func load(_ url: URL, autoplay: Bool) async throws
    func play(); func pause(); func seek(to seconds: Double)
    func setVolume(_ v: Float, fadeDuration: TimeInterval)
    func preload(_ url: URL)
}
```

### 4.2 Сеть и авторизация

- `URLSession` + `Codable`, `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` + явные `CodingKeys` для неоднозначных полей.
- Логин: `POST /api/auth/login`. Тело ответа **не содержит** `session_id` — его нужно достать из заголовка `Set-Cookie` (или `HTTPCookieStorage`) и положить в Keychain.
- Все обычные запросы: заголовок `Cookie: session_id=...`.
- Все медиа-запросы (stream, cover): `?session_id=...`, потому что AVPlayer не отправляет cookie.
- `401` → очистка сессии → экран логина. Тихого refresh нет (backend его не поддерживает).
- Таймауты: 15 с на API, 30 с на стрим; retry 2 раза с backoff на идемпотентные GET.

### 4.3 Форматы и Opus — главный компромисс

| Формат | AVPlayer | Комментарий |
|---|---|---|
| MP3 | ✅ | `format=mp3`, 320 CBR |
| AAC/M4A | ✅ | если исходники в библиотеке |
| FLAC | ✅ (iOS 11+) | `format=flac` |
| ALAC/WAV/AIFF | ✅ | исходники |
| **Ogg/Opus** | ❌ | backend отдаёт `audio/ogg`, AVPlayer его не открывает |

Варианты:

1. **v1 (рекомендуется):** в настройках iOS показывать `Auto / MP3 / FLAC`, пункт Opus скрыть или disabled с пояснением. Для `Auto` при ошибке загрузки трека автоматически повторять его с `format=mp3`.
2. **Правильное решение:** добавить на backend формат `aac`/`m4a`. Backend сам не транскодирует — он пробрасывает `format` в Navidrome, а Navidrome уже транскодирует через ffmpeg. Нужно добавить MIME-тип и проверить, что Navidrome отдаёт AAC. Тогда iOS получает нативный формат с лучшим качеством, чем MP3. Небольшое изменение backend, но отдельная задача и тесты.
3. **Дорого:** тащить libopus + Ogg-парсер и играть через AVAudioEngine. Не рекомендуется: недели работы ради одного кодека.

> Пока решение не принято, в плане заложен вариант 1. Если нужен именно Opus — это +1 неделя к сроку (вариант 2) или +3–4 недели (вариант 3).

### 4.4 Кэш 500 МБ

В iOS нет готового потокового кэша для AVPlayer. Три подхода:

| Вариант | Плюсы | Минусы |
|---|---|---|
| **A. `AVAssetResourceLoaderDelegate`** (рекомендуется) | Нет сторонних зависимостей, полный контроль, работает seek | ~300–400 строк, нужно аккуратно с Range и индексацией чанков |
| B. Локальный HTTP-прокси (FlyingFox/Swifter) | Проще логика Range, AVPlayer видит обычный URL | Лишний процесс/порт, зависимость, lifecycle |
| C. Только prefetch следующего трека | Просто | Не даёт офлайн-повтора и частичного кэша — расхождение с Android |

План: **A**, с абстракцией `MediaSource`, чтобы при проблемах откатиться на C без переписывания плеера.

Детали A:

- `AVURLAsset` с кастомной схемой `coreplayer-cache://`.
- Делегат перехватывает запросы, проверяет индекс кэша, при промахе идёт в backend с `Range` и `session_id`, пишет чанки в файл.
- Индекс: `trackId → [диапазоны, размер, lastAccess]`, хранится в JSON.
- LRU-эвикция при превышении 500 МБ, отдельный потолок на обложки (например, 200 МБ).
- Prefetch следующего трека после старта текущего; отмена при смене очереди.
- Проверка целостности при старте: битые/недокачанные файлы удаляются.
- `shortcut:` если стриминг с кэшем окажется нестабильным — v1 играет напрямую, кэш только для prefetch; расхождение фиксируется в docs.

### 4.5 Кроссфейд

Повторяем параметры Android:

- длительность **3,5 с**;
- только если текущий трек длиннее **12 с**;
- старт за **4 с** до конца;
- repeat-one кроссфейдит сам в себя;
- при ручном next/prev — короткий кроссфейд **1,0 с** (в Android именно так, `crossfadeTo(..., 1000L)`);
- при автоматическом переходе — 3,5 с.

Реализация: второй `AVPlayer` предзагружается за ~10 с до конца; за 4 с до конца запускается ramp громкости с шагом 50 мс. При ручном next/prev — ramp 1 с. Если следующий трек не готов, переходим без кроссфейда (не задерживаем переход).

### 4.6 Фон, экран блокировки, прерывания

- `AVAudioSession`: категория `.playback`, режим `.default`, `setActive(true)`.
- `Info.plist`: `UIBackgroundModes = [audio]`.
- `MPNowPlayingInfoCenter`: title, artist, album, duration, elapsed, rate, artwork.
- `MPRemoteCommandCenter`: play, pause, toggle, next, previous, changePlaybackPosition.
- `AVAudioSession.interruptionNotification`: пауза и корректное возобновление (не автоматически, как в Android — проверить поведение Android и повторить).
- `routeChangeNotification`: пауза при отключении наушников.
- `mediaServicesWereResetNotification`: пересоздать плеер.

### 4.7 HTTP и ATS

Backend у пользователя может быть `http://192.168.x.x:3000`. Android разрешает cleartext. На iOS:

- `NSAppTransportSecurity → NSAllowsArbitraryLoads = true` — самый простой путь к паритету.
- Для App Store это допустимо с пояснением «self-hosted media server», но ревью может спросить. Альтернатива: `NSAllowsLocalNetworking` (только локальная сеть) + требование HTTPS для внешнего адреса.
- Самоподписанные сертификаты **не обходить молча**. Либо валидный сертификат, либо установка CA-профиля пользователем. Android 7+ тоже не доверяет пользовательским CA без конфига, так что паритет сохраняется.

### 4.8 UI/дизайн

- Тёмная тема по умолчанию, палитра из Android.
- Фон Now Playing: размытая обложка + градиент; переключатель «обычный тёмный / под обложку».
- AMOLED: чистый чёрный фон.
- «Адаптивный пузырь» mini-player: градиент из доминирующих цветов обложки.
- Таб-бар: Главная / Поиск / Все треки / Медиатека; настройки — из Home.
- Now Playing — `.sheet` с `.presentationDetents([.large])` и drag-to-dismiss.
- Анимации: `.spring`, hero-переход обложки из mini-player.
- Доступность: VoiceOver, Dynamic Type, контраст, reduce motion.

### 4.9 Хранение

| Данные | Где |
|---|---|
| `session_id` | Keychain (`kSecAttrAccessibleAfterFirstUnlock`) |
| Адрес сервера, логин | UserDefaults |
| Настройки (тема, кодек, кроссфейд) | UserDefaults |
| Очередь | не сохраняется (в Android тоже) |
| Кэш | Caches directory: треки — LRU 500 МБ (паритет), обложки — LRU 200 МБ (наш лимит) |

---

## 5. Что нужно для разработки

### 5.1 Проверка системы (факт на 2026-11-01)

| Компонент | Статус | Нужен | Комментарий |
|---|---|---|---|
| macOS 26.7.1, arm64 | ✅ | да | 589 ГБ свободно — достаточно |
| Command Line Tools, Swift 6.4 | ✅ | да | компилятор есть, iOS SDK — нет |
| **Xcode.app** | ❌ | **да** | `xcode-select -p` → CommandLineTools; `xcodebuild` падает с «requires Xcode» |
| **iOS Simulator runtime** | ❌ | да | ставится вместе с Xcode / отдельным компонентом |
| **Сертификат подписи** | ❌ | да | `security find-identity` → 0 identities |
| Homebrew | ✅ | опц. | для XcodeGen и линтеров |
| git | ✅ | да | |
| Python 3.14, uv, Docker + Compose | ✅ | да | локальный backend + Navidrome для тестов |
| Node/npm | ✅ | нет | нужен только web-плееру |
| Java | ✅ | нет | Android |
| XcodeGen | ❌ | рек. | текстовый `project.yml` вместо ручного `.xcodeproj` |
| SwiftLint / SwiftFormat | ❌ | опц. | стиль и CI |
| xcbeautify | ❌ | опц. | читаемый вывод `xcodebuild` |
| fastlane | ❌ | опц. | TestFlight/App Store автоматизация |
| gh (GitHub CLI) | ❌ | опц. | создание репозитория/PR |
| CocoaPods / Carthage | ❌ | **нет** | используем SPM |
| Android SDK / Gradle | ❌ | нет | не нужно для iOS |

### 5.2 Что установить позже (сейчас — ничего не устанавливаем)

**Обязательно:**

1. **Xcode** — из App Store или с developer.apple.com. ~12–15 ГБ загрузка, ~40–60 ГБ на диске с симулятором. Требует Apple ID и пароль администратора. Агент не может установить его без вас.
2. **iOS Simulator runtime** — Xcode → Settings → Components (или `xcodebuild -downloadPlatform iOS`).
3. **Apple ID**:
   - бесплатный: установка на своё устройство, 7 дней, до 3 приложений, без TestFlight;
   - Apple Developer Program ($99/год): TestFlight, App Store, годовая подпись.

Команды после установки Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
xcodebuild -version
xcrun simctl list devices available
```

**Рекомендуется:**

```bash
brew install xcodegen
# опционально
brew install swiftlint swiftformat xcbeautify fastlane gh
```

**Не нужно:** CocoaPods, Carthage, Android SDK.

### 5.3 Что нужно от вас (доступы и данные)

- Apple ID / команда разработчика, Bundle ID (например, `com.coreplayer.ios`).
- URL тестового backend и тестовый аккаунт.
- Тестовая музыкальная библиотека в Navidrome (или разрешение поднять локальный `docker compose` с тестовыми файлами).
- Решение по Opus (§4.3) и по распространению (§10).
- Иконка 1024×1024, скриншоты, privacy policy URL — для App Store.

---

## 6. Поэтапный план

Оценки — в человеко-днях одного опытного iOS-разработчика, без учёта ожидания ревью Apple.

### Этап 0. Окружение и скелет проекта — 1–2 дня

- Установить Xcode и симулятор (ваше действие).
- Создать репозиторий `core-player-ios`, `.gitignore`, `README`.
- `project.yml` для XcodeGen: target `CorePlayer`, iOS 17.0, Bundle ID, Swift 6.
- Пустое SwiftUI-приложение с таб-баром-заглушкой.
- Настроить signing (automatic, личный team).
- Опционально: GitHub Actions (`macos-26` или актуальный macOS-runner) с `xcodebuild build` и `test`.

**Готово, когда:** приложение запускается на симуляторе, `xcodebuild build` проходит без ошибок, на устройство ставится debug-сборка.

### Этап 1. API-слой и авторизация — 3–4 дня

- Codable-модели: `UserDto`, `TrackDto`, `ArtistDto`, `AlbumDto`, `PlaylistDto`, `AlbumDetailResponse`, `ArtistDetailResponse`, `PlaylistDetailResponse`, `FavoritesIdsResponse`, `LyricsResponse`, `SearchResponse`, `AuthResponse` и request-модели.
- `Endpoint` enum, `APIClient`, маппинг ошибок (`APIError`: network/unauthorized/decoding/server).
- `AuthStore`: логин, логаут, `me`, Keychain, восстановление сессии.
- `ServerURL` — нормализация (схема, слэш, порт), запрет пустого/битого URL.
- Билдеры URL стрима и обложек с `session_id`.
- Unit-тесты на декодирование реальных JSON-фикстур и на билдеры URL.

**Готово, когда:** логин переживает перезапуск, `401` разлогинивает, все 21 эндпоинт декодируются, тесты зелёные.

### Этап 2. Дизайн-система и навигация — 2–3 дня

- Цвета, типографика, отступы, скругления.
- Компоненты: `TrackRow`, `AlbumCard`, `ArtistRow`, `SectionHeader`, `LoadingView`, `ErrorView`, `EmptyView`.
- `NavigationStack` + таб-бар из 4 вкладок: **Главная, Поиск, Все треки, Медиатека** + mini-player-заглушка.
- Экран логина (валидация, ошибки, «подключиться»).

**Готово, когда:** все состояния (loading/error/empty/content) выглядят одинаково во всех списках, логин работает end-to-end.

### Этап 3. Библиотека — 5–7 дней

- Home: секции как в Android (случайные, избранное, плейлисты, недавнее).
- Browse («Все треки»): вкладки «Альбомы / Исполнители / Треки», загрузка списков целиком, без пагинации.
- Library («Медиатека»): «Мои треки» (избранное) и «Плейлисты».
- Detail-экраны: альбом, исполнитель, плейлист.
- Search с debounce 300 мс + история поиска (как в Android).
- Недавние треки (последние 4) — локально.
- Плейлисты: создание, добавление/удаление трека, reorder.
- Избранное: toggle, списки.
- Загрузка обложек с дисковым кэшем и downsample.

**Готово, когда:** на реальном сервере открываются все разделы, избранное и плейлисты сохраняются после перезапуска, списки скроллятся без подвисаний.

### Этап 4. Ядро воспроизведения — 5–7 дней

- `AudioSession` (playback, активация, interruptions, route changes).
- `PlayerEngine` + `DualAVPlayerEngine`.
- `PlayerStore`: очередь, индекс, shuffle, repeat, автопереход, seek, next/prev.
- Now Playing info + remote commands + фон.
- Mini-player и полный Now Playing без текстов и кроссфейда.

**Готово, когда:** играет в фоне, управляется с lock screen и AirPods, корректно переживает звонок и отключение наушников, очередь и режимы совпадают с Android.

### Этап 5. Тексты — 2–3 дня

- LRC-парсер (несколько таймштампов в строке, offset, пустые строки).
- Караоке-подсветка, автоскролл, tap-to-seek.
- Unsynced-режим.
- Отдельного экрана очереди в Android нет — **не добавляем**.
- Кэш текстов в памяти.

**Готово, когда:** подсветка не уезжает на длинных треках, seek обновляет позицию, нет текста — аккуратный empty state.

### Этап 6. Кэш 500 МБ и prefetch — 4–7 дней (самый рискованный)

- `CachingResourceLoader` + файловый LRU.
- Range-запросы, частичные попадания, seek.
- Prefetch следующего трека, отмена, эвикция.
- Офлайн-повтор уже закэшированного трека.
- Метрики: hit rate, размер, время старта.
- Тесты: граница 500 МБ, битый файл, seek в незакэшированную область, смена очереди.

**Готово, когда:** размер не превышает лимит, повтор без сети работает, seek не ломается, старт трека не медленнее прямого стрима.

**Если не получается:** откат на вариант C (prefetch-only), зафиксировать расхождение в `docs/KNOWN-DIFFERENCES.md`.

### Этап 7. Кроссфейд — 2–3 дня

- Предзагрузка второго плеера.
- Ramp громкости, параметры Android.
- Repeat-one, короткие треки, ручной skip.
- Настройка вкл/выкл.

**Готово, когда:** нет щелчков и провалов, память не растёт, кроссфейд работает с кэшем и без.

### Этап 8. Настройки — 1–2 дня

- Фон: обычный / под обложку / адаптивный градиент.
- AMOLED.
- Кроссфейд.
- Кодек: Auto / MP3 / FLAC (+ обработка Opus).
- Выход, версия приложения.

**Готово, когда:** настройки применяются сразу и переживают перезапуск.

### Этап 9. Стабилизация — 4–6 дней

- Ошибки сети, retry, таймауты, пустые состояния.
- VoiceOver, Dynamic Type, контраст, reduce motion.
- RU-локализация через String Catalog.
- Haptics на управление.
- Unit + UI тесты, ручной тест-план на устройстве.
- Профилирование: Instruments (Time Profiler, Allocations, Energy).

**Готово, когда:** тест-план зелёный, нет крашей за часовой прогон, VoiceOver проходит основные сценарии.

### Этап 10. Бета и релиз — 2–4 дня + ревью

- Archive, TestFlight, внутренние тестеры.
- Privacy manifest, privacy policy, App Store Connect metadata, скриншоты.
- Export compliance (стандартный HTTPS — exemption).
- Если платного аккаунта нет — установка на устройство через free provisioning (7 дней).

**Готово, когда:** TestFlight-сборка ставится и играет, чек-лист релиза закрыт.

### Итого

| Этап | Дней |
|---|---|
| 0. Окружение | 1–2 |
| 1. API + auth | 3–4 |
| 2. Дизайн + навигация | 2–3 |
| 3. Библиотека | 5–7 |
| 4. Плеер | 5–7 |
| 5. Тексты | 2–3 |
| 6. Кэш | 4–7 |
| 7. Кроссфейд | 2–3 |
| 8. Настройки | 1–2 |
| 9. Стабилизация | 4–6 |
| 10. Бета/релиз | 2–4 |
| **Всего** | **31–48** |

**7–9 недель full-time.** Без потокового кэша — на 1–1,5 недели меньше. С Opus через backend AAC — +3–5 дней. С Opus через собственный движок — +3–4 недели.

---

## 7. Тестирование

### 7.1 Уровни

| Уровень | Инструмент | Что покрываем |
|---|---|---|
| Unit | Swift Testing | декодирование JSON, URL-билдеры, LRC, очередь/shuffle/repeat, LRU, настройки |
| UI | XCUITest | логин, навигация, Now Playing, настройки, пустые/ошибочные состояния |
| Integration | реальный backend + `docker compose` | стрим, seek, обложки, тексты, избранное, плейлисты |
| Manual | устройство | фон, lock screen, AirPods, звонки, сеть, кэш, кроссфейд |

### 7.2 Матрица устройств

- iPhone SE (маленький экран), iPhone 17 Pro (Dynamic Island), iPhone 17 Pro Max.
- iPad — только если решим поддерживать (§10).
- iOS 17.0 (минимум), iOS 18, iOS 26.

### 7.3 Обязательные сценарии

- Логин: верный/неверный пароль, недоступный сервер, HTTP и HTTPS, смена адреса.
- Сессия: истекла, сервер перезапущен, logout.
- Плеер: play/pause, seek вперёд/назад, next/prev в конце, repeat all/one, shuffle on/off, пустая очередь.
- Фон: lock screen, 30 минут, звонок, Siri, отключение наушников, переключение на Bluetooth.
- Сеть: Wi-Fi → LTE, offline, медленная сеть, обрыв на середине трека.
- Кэш: 500 МБ, повтор офлайн, seek в кэш и вне кэша, битый файл.
- Кроссфейд: трек 5 с, 13 с, repeat-one, ручной skip, выключенный кроссфейд.
- Тексты: нет, unsynced, synced, длинные, с несколькими таймштампами.
- UI: VoiceOver, Dynamic Type XXXL, reduce motion, светлая/тёмная системная тема (приложение тёмное).

### 7.4 Definition of Done (паритет)

Функция считается готовой, если:

1. Поведение совпадает с Android на одном и том же сервере и треке.
2. Есть обработка loading / error / empty.
3. Есть unit- или UI-тест на нетривиальную логику.
4. Проверено на симуляторе и физическом устройстве.
5. Нет утечек и роста памяти за 30 минут.

---

## 8. Риски

| Риск | Вероятность | Влияние | Решение |
|---|---|---|---|
| Нет Xcode → нельзя начать | 100% | блокер | установить Xcode (действие пользователя) |
| Opus/Ogg не играет | 100% | среднее | скрыть Opus в v1 / добавить AAC на backend / fallback на MP3 |
| Потоковый кэш сложнее ожидаемого | высокая | высокое | абстракция `MediaSource`, откат на prefetch-only |
| Кроссфейд щёлкает/лагает | средняя | среднее | предзагрузка, ramp 50 мс, отключение при неготовности |
| ATS/HTTP и App Store | средняя | среднее | `NSAllowsArbitraryLoads` + пояснение; рекомендация HTTPS |
| Самоподписанный TLS | средняя | низкое | не обходить; инструкция по CA-профилю |
| AVPlayer плохо ищет в транскоде | средняя | среднее | `estimateContentLength=true`, тест seek, fallback на MP3 |
| Истечение сессии во время игры | низкая | низкое | 401 → пауза + логин, сохранить очередь |
| Ревью Apple | низкая | среднее | privacy policy, privacy manifest, без приватных API |
| Оценка сроков | средняя | — | буфер 20%, кэш и Opus — отдельными вехами |

---

## 9. Что не входит в v1

- CarPlay, виджеты, Live Activities, Siri Shortcuts.
- Скачивание альбомов/плейлистов «навсегда» (в Android тоже нет).
- Эквалайзер, ReplayGain, sleep timer (в Android нет).
- iPad-специфичная вёрстка (если не попросите).
- Синхронизация настроек между устройствами.
- Локализация на английский (сразу закладываем String Catalog, но переводим позже).

---

## 10. Открытые вопросы (нужны решения до этапа 4)

1. **Распространение:** App Store, только TestFlight, или личная установка на устройство? От этого зависит наличие платного аккаунта и сроки.
2. **Минимальная iOS:** 17.0 (рекомендую) или 16.0? iPad нужен?
3. **Можно ли менять backend?** Если да — добавить `format=aac` и закрыть вопрос Opus нормально.
4. **Opus:** скрыть в iOS или реализовывать? (см. §4.3)
5. **Дизайн:** строгая копия Android или адаптация под iOS HIG?
6. **Репозиторий:** публичный/приватный, лицензия, Bundle ID.
7. **Есть ли уже Apple Developer Account?**
8. **Есть ли тестовый сервер Core Player с аккаунтом и медиатекой?** (или поднимаем локально через `docker-compose` + Navidrome)

---

## Приложение A. API

Базовый URL вводит пользователь. Все ответы — JSON, кроме стрима/обложек.

| Метод | Путь | Параметры / тело | Назначение |
|---|---|---|---|
| POST | `/api/auth/login` | `{username, password}` | логин, ставит cookie `session_id` |
| GET | `/api/auth/me` | — | текущий пользователь |
| POST | `/api/auth/logout` | — | выход |
| GET | `/api/library/artists` | — | исполнители (все, с индексами) |
| GET | `/api/library/artists/{artist_id}` | — | исполнитель + альбомы |
| GET | `/api/library/albums` | `type`, `size`, `offset`, `all` | альбомы |
| GET | `/api/library/albums/{album_id}` | — | альбом + треки |
| GET | `/api/library/tracks` | `size`, `offset`, `all` | треки |
| GET | `/api/library/playlists` | — | плейлисты |
| POST | `/api/library/playlists` | `{name}` | создать |
| GET | `/api/library/playlists/{playlist_id}` | — | плейлист + треки |
| DELETE | `/api/library/playlists/{playlist_id}` | — | удалить |
| POST | `/api/library/playlists/{playlist_id}/tracks` | `{track_id}` | добавить трек |
| DELETE | `/api/library/playlists/{playlist_id}/tracks/{track_id}` | — | убрать трек |
| PUT | `/api/library/playlists/{playlist_id}/reorder` | `{track_ids}` | порядок |
| GET | `/api/library/favorites/ids` | — | id избранного |
| POST | `/api/library/favorites/toggle` | `{id, type}` | toggle |
| GET | `/api/library/favorites/tracks` | — | избранные треки |
| GET | `/api/library/random` | `size` | случайные |
| GET | `/api/library/search` | `query` | поиск |
| GET | `/api/lyrics/{track_id}` | `artist`, `title`, `album`, `duration` (fallback) | текст |
| GET | `/api/stream/{track_id}` | `format`, `estimateContentLength`, `session_id` | аудио |
| GET | `/api/stream/cover/{id}` | `size`, `session_id` | обложка |

Особенности:

- `format`: `mp3` / `opus` / `flac`; без параметра — исходный файл.
- `estimateContentLength=true` — backend подставляет Content-Length, это помогает AVPlayer с seek.
- `session_id` в query — для AVPlayer и загрузки обложек.
- Range-запросы поддерживаются, статус `206`.

---

## Приложение B. Соответствие файлов Android → iOS

| Android | iOS |
|---|---|
| `data/api/CorePlayerApi.kt` | `Core/Networking/APIClient.swift`, `Endpoint.swift` |
| `data/model/Models.kt` | `Core/Models/*.swift` |
| `data/api/CookieJar.kt` | `Core/Storage/Keychain.swift` + `AuthStore` |
| `player/PlayerState.kt` | `Playback/PlayerStore.swift` |
| `player/PlayerControllerManager.kt` | `Playback/PlayerEngine.swift` |
| `player/PlaybackService.kt` | `Playback/AudioSession.swift`, `NowPlayingCenter.swift`, `RemoteCommands.swift` |
| `player/TrackCacheManager.kt` | `Playback/TrackCache.swift`, `CachingResourceLoader.swift` |
| `ui/screens/login` | `Features/Login` |
| `ui/screens/home` | `Features/Home` |
| `ui/screens/library` | `Features/Library` |
| `ui/screens/browse` | `Features/Browse` |
| `ui/screens/search` | `Features/Search` |
| `ui/screens/nowplaying` | `Features/NowPlaying` |
| `ui/screens/settings` | `Features/Settings` |
| `ui/util/ImageUtils.kt` | `Core/Utils/URLBuilder.swift` |
| `lyrics` | `Core/Utils/LRCParser.swift` |

---

## Приложение C. Проверки и команды

Проверить текущее состояние:

```bash
xcode-select -p                 # сейчас: /Library/Developer/CommandLineTools
xcodebuild -version             # ошибка: requires Xcode
xcrun simctl list devices       # симуляторов нет
security find-identity -v -p codesigning   # 0 identities
```

После установки Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS

xcodebuild -version
xcrun simctl list devices available
```

Сборка и тесты проекта:

```bash
xcodegen generate
xcodebuild -scheme CorePlayer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

xcodebuild -scheme CorePlayer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Локальный backend для интеграционных тестов:

```bash
cd core-player
docker compose up -d
# проверить http://localhost:3000 и настроить Navidrome
```

---

## Приложение D. Первый коммит: что создать

1. `README.md` — что это, как собрать, требования.
2. `.gitignore` — Xcode, DerivedData, `.env`, `*.xcuserstate`.
3. `project.yml` — target, iOS 17, Bundle ID, тесты, SPM-зависимости (если появятся).
4. `CorePlayer/App/CorePlayerApp.swift` — точка входа.
5. `CorePlayer/Resources/Info.plist` — `UIBackgroundModes`, ATS.
6. `CorePlayerTests/` — первый тест на декодирование `TrackDto`.
7. `docs/API.md` — выжимка из приложения A.
8. `docs/KNOWN-DIFFERENCES.md` — Opus, кэш, пиксельные отличия UI.

---

## Итог

Начинать можно только после установки Xcode — это единственный жёсткий блокер. Дальше порядок такой: API + логин → библиотека → плеер → тексты → кэш → кроссфейд → полировка → TestFlight. Самые рискованные части — кэш 500 МБ и Opus; их лучше вынести в отдельные вехи и не считать «готово» до тестов на устройстве.
