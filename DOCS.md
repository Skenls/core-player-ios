# Core Player for iOS — документация

Полная документация приложения: архитектура, экраны, плеер, кэш, сеть, настройки, сборка, тесты, ограничения.

Оглавление:
1. [Обзор](#1-обзор)
2. [Структура проекта](#2-структура-проекта)
3. [Архитектура](#3-архитектура)
4. [Хранение данных](#4-хранение-данных)
5. [Экраны](#5-экраны)
6. [Плеер и воспроизведение](#6-плеер-и-воспроизведение)
7. [Кэш](#7-кэш)
8. [Работа с сетью и API](#8-работа-с-сетью-и-api)
9. [Тексты песен (lyrics)](#9-тексты-песен-lyrics)
10. [Тема и дизайн](#10-тема-и-дизайн)
11. [Настройки](#11-настройки)
12. [Сборка и установка](#12-сборка-и-установка)
13. [CI: сборка IPA в GitHub Actions](#13-ci-сборка-ipa-в-github-actions)
14. [Тесты](#14-тесты)
15. [Отличия от Android-версии](#15-отличия-от-android-версии)
16. [Известные ограничения и TODO](#16-известные-ограничения-и-todo)
17. [Troubleshooting](#17-troubleshooting)

---

## 1. Обзор

Core Player iOS — нативный клиент музыкального сервера (FastAPI-прокси к Navidrome), порт [Android-версии](https://github.com/Skenls/core-player-android). Работает с тем же backend API, что Android и веб-плеер (репозиторий [core-player](https://github.com/Skenls/core-player)).

**Платформа и стек**

| Параметр | Значение |
|---|---|
| ОС | iOS 15.0+ |
| Устройства | iPhone (портрет + ландшафт), iPad не поддерживается |
| UI | SwiftUI |
| Аудио | AVFoundation (AVPlayer) |
| Язык | Swift 5, async/await, без сторонних зависимостей |
| Интерфейс | Русский, тёмная тема |
| Проект | XcodeGen (`project.yml`), bundle id `com.coreplayer.app` |
| Установка | Запуск из Xcode или unsigned IPA через TrollStore |

**Функционал**: вход по адресу сервера, поиск с историей, главная с недавними/избранным/плейлистами/исполнителями, медиатека с плейлистами (создание, сортировка, удаление), альбомы и исполнители, плеер с очередью/shuffle/repeat, синхронные тексты песен, фоновое воспроизведение + управление с экрана блокировки, кэш треков 500 МБ, обложки с кэшем, AMOLED-режим, адаптивный плавающий мини-плеер.

**Сознательные исключения** (по заданию): нет Opus (AVPlayer не воспроизводит Ogg/Opus) и нет кроссфейда.

---

## 2. Структура проекта

```
webplayer-ios/
├── project.yml                  # XcodeGen: 2 таргета (CorePlayer, CorePlayerTests)
├── CorePlayer/
│   ├── App/
│   │   ├── CorePlayerApp.swift  # @main, композиция окружения
│   │   ├── AppContainer.swift   # фабрика всех store'ов, appearance, URLCache
│   │   ├── RootView.swift       # Splash / Login / Main по состоянию сессии
│   │   └── MainView.swift       # 4 таба + плавающий мини-плеер + таб-бар
│   ├── Core/
│   │   ├── Models.swift         # DTO + «терпимые» декодеры (FlexibleList и др.)
│   │   ├── APIClient.swift      # транспорт, сессия, все эндпоинты
│   │   ├── StreamURLBuilder.swift # URL стримов и обложек (cookie в query)
│   │   ├── AudioCodec.swift     # auto / mp3 / flac
│   │   ├── AuthStore.swift      # логин, restore, logout
│   │   ├── Keychain.swift       # обёртка kSecClassGenericPassword
│   │   ├── SettingsStore.swift  # codec, background, adaptiveBubble, amoled
│   │   ├── FavoritesStore.swift # id-наборы избранного + optimistic toggle
│   │   ├── Stores.swift         # RecentStore, SearchHistoryStore
│   │   ├── ArtistUtils.swift    # чистка ФИО из поля артиста (порт с Android)
│   │   ├── ImageCache.swift     # NSCache + URLSession для обложек
│   │   ├── PaletteUtils.swift   # адаптивная палитра обложки для пузыря
│   │   ├── LRCParser.swift      # парсер LRC + поиск активной строки
│   │   ├── Theme.swift          # палитра цветов
│   │   ├── Formatters.swift     # время / кол-во треков / альбомов
│   │   ├── CoreTabBar.swift     # нижний таб-бар
│   │   ├── MiniPlayerView.swift # плавающий пузырь-плеер
│   │   ├── SegmentedPicker.swift# табы с белым подчёркиванием
│   │   ├── Cards.swift          # AlbumCard, ArtistCard, RecentCard, FavoriteBanner
│   │   ├── TrackRow.swift       # строка трека + AddToPlaylistSheet + BlurredCoverBackground
│   │   ├── Components.swift     # RemoteImage, CoverView, Empty/Error/Loading, SectionHeader
│   │   └── EnvironmentValues+API.swift # доступ к APIClient из SwiftUI
│   ├── Playback/
│   │   ├── PlayerStore.swift    # логика плеера: очередь, seek, now playing
│   │   ├── PlayerEngine.swift   # AVPlayer + буфер + watchdog сетевых пауз
│   │   ├── QueueState.swift     # очередь + shuffle-порядок
│   │   ├── TrackCache.swift     # LRU-кэш файлов 500 МБ
│   │   ├── AudioSessionManager.swift # AVAudioSession + прерывания/роуты
│   │   └── NowPlayingCenter.swift    # MPRemoteCommandCenter / MPNowPlayingInfoCenter
│   ├── Features/
│   │   ├── Login/LoginView.swift
│   │   ├── Home/HomeView.swift (+ HomeViewModel)
│   │   ├── Search/SearchView.swift (+ SearchViewModel, SearchResultsView)
│   │   ├── Browse/BrowseView.swift (+ BrowseViewModel)
│   │   ├── Browse/AlbumDetailView.swift, ArtistDetailView.swift
│   │   ├── Library/LibraryView.swift (+ LibraryViewModel),
│   │   │        PlaylistDetailView.swift, CreatePlaylistSheet.swift
│   │   ├── NowPlaying/NowPlayingView.swift, NowPlayingProgress.swift,
│   │   │        NowPlayingLyrics.swift, SyncedLyricsView.swift
│   │   └── Settings/SettingsView.swift
│   └── Resources/
│       ├── Info.plist           # ATS arbitrary loads, UIBackgroundModes audio, ориентации
│       └── Assets.xcassets      # AppIcon 1024, AccentColor
├── CorePlayerTests/CorePlayerTests.swift   # XCTest (для Xcode)
├── scripts/
│   ├── LogicTests.swift         # CLI-тесты логики (без Xcode)
│   ├── ArtistUtilsTests.swift   # CLI-тесты чистки ФИО
│   └── run-logic-tests.sh       # компилирует и запускает оба
├── .github/workflows/build.yml  # CI: unsigned IPA
├── PLAN.md                      # исходный план порта (история)
├── README.md                    # краткое readme
└── DOCS.md                      # этот файл
```

Итого: ~50 Swift-файлов, ~5 600 строк.

---

## 3. Архитектура

Слои: **Stores (состояние) → Views (SwiftUI) → сервисы (APIClient, Playback)**. Сторонних фреймворков нет, поэтому всё на `ObservableObject`.

### 3.1 Композиция окружения

`AppContainer` (создаётся единожды в `CorePlayerApp`) владеет всеми долгоживущими объектами и публикует их в окружение:

| Экземпляр | Роль |
|---|---|
| `APIClient` | HTTP, сессия, URL-билдеры |
| `TrackCache` | файловый кэш треков |
| `SettingsStore` | codec / background / adaptiveBubble / amoled |
| `AuthStore` | логин/restore/logout; сервер — UserDefaults, `session_id` — Keychain |
| `FavoritesStore` | trackIDs/albumIDs + оптимистичный toggle |
| `RecentStore`, `SearchHistoryStore` | локальные списки (UserDefaults) |
| `PlayerStore` | плеер; связывает engine, аудиосессию, Now Playing |

Инъекция: `environmentObject` для store'ов + `EnvironmentValues.api` (`\.api`) для view, которым нужен `APIClient`.

### 3.2 Потоки данных

- **Аутентификация**: `RootView` смотрит `auth.isRestoring` / `auth.isAuthenticated`. При старте `AuthStore.restore()` читает пользователя из UserDefaults и сессию из Keychain, затем валидирует `GET /api/auth/me`; 401 → разлогин.
- **Воспроизведение**: события `PlayerEngine` (время, конец, ошибка, готовность) → коллбеки в `PlayerStore` → `@Published` состояние → SwiftUI. `PlayerStore` сам обновляет `MPNowPlayingInfoCenter` (не чаще 1 раза в секунду).
- **Избранное**: `FavoritesStore.reload()` после логина; toggle меняет Set сразу, откат при ошибке.
- **Выход**: `AuthStore.logout()` → POST logout, чистка сессии, событие `.corePlayerDidLogout` → MainView сбрасывает плеер, избранное, недавние.

### 3.3 Плеерская связка

`PlayerStore` — фасад; под ним `PlayerEngine` (AVPlayer), `AudioSessionManager`, `NowPlayingCenter`, `TrackCache`. Очередь — чистая логика в `QueueState` (покрыта тестами): `setQueue(list, startAt)`, `nextIndex/previousIndex`, shuffle — пересортированный порядок с фиксированным текущим элементом, `RepeatMode` off/all/one.

---

## 4. Хранение данных

| Что | Где | Ключ / лимиты |
|---|---|---|
| `session_id` | Keychain | service `com.coreplayer.app`, account `session_id` |
| Пользователь (кэш) | UserDefaults | JSON, key `coreplayer.user` |
| Адрес сервера | UserDefaults | `coreplayer.serverURL` |
| Недавние треки | UserDefaults | `coreplayer.recentTracks`, максимум 12 |
| История поиска | UserDefaults | `coreplayer.searchHistory`, максимум 10 |
| Настройки | UserDefaults | `coreplayer.codec`, `.background`, `.adaptiveBubble`, `.amoled` |
| Файлы треков | Caches/CorePlayerTracks | `<trackId>-<codec>.<ext>`, LRU по mtime, ≤ 500 МБ |
| Обложки (URLCache) | Caches/coreplayer.images | 256 МБ диск / 32 МБ память |
| Обложки (память) | NSCache | 250 объектов / 80 МБ |

Файлы кэша помечены `isExcludedFromBackup` — не попадают в iCloud-бэкапы.

---

## 5. Экраны

> «Все элементы — белые либо адаптивные» — оранжевый используется только там, где он есть в Android-оригинале: кольцо прогресса пузыря и подсветка активного трека в списках.

### 5.1 Login
- Поля: СЕРВЕР (подставляется последним), ЛОГИН, ПАРОЛЬ.
- Кнопка белая с чёрным текстом, спиннер во время запроса, ошибки под формой.
- После входа: `session_id` → Keychain, переход на Main.

### 5.2 Main (4 таба)
Плавающий пузырь-плеер (если играет трек) поверх solid таб-бара. Табы: Главная / Поиск / Все треки / Медиатека. Отдельного экрана очереди нет — как в Android.

**Мини-плеер (пузырь)**
- Форма: стадион-капсула; фон — градиент (фикс-твилайт `0x161C26 → 0x12344E`, либо при «адаптивном пузыре» — цвета из палитры обложки), тень, белая обводка 1pt.
- Слева: белая круглая кнопка play/pause (чёрная иконка) в оранжевом прогресс-кольце — кольцо заполняется по позиции трека.
- Центр: название (белый, 15 pt semibold) + исполнитель (13 pt, серый).
- Справа: сердце (белое контурное / красное заполненное).
- Жесты: тап — открыть плеер; свайп вверх — открыть; свайп влево — следующий трек; свайп вправо — предыдущий.

### 5.3 Главная
- Недавние (до 8 карточек; если пусто — random 20).
- Баннер «Мои треки · Плейлист · N» (закатный градиент + обложка первого избранного; тап — играть всё).
- Плейлисты (горизонтальная лента), Исполнители, шестерёнка настроек.
- Pull-to-refresh; ошибка — ErrorStateView с кнопкой повтора.

### 5.4 Поиск
- Debounce 300 мс; история чипами + «Очистить».
- Результаты: треки (TrackRow), альбомы (лента карточек), исполнители (круглые фотографии).

### 5.5 Все треки (Browse)
Табы с белым подчёркиванием: Альбомы (сетка) / Исполнители (список) / Треки (все, до 2000).
- **AlbumDetail**: шапка с обложкой, год • кол-во треков • длительность, кнопки «Слушать» / «Перемешать» (белые), сердце альбома, треки с нумерацией — номер и название активного трека оранжевые.
- **ArtistDetail**: шапка, альбомы сеткой, «Слушать».

### 5.6 Медиатека
- Табы: «Мои треки» (избранные; сверху play/shuffle) и «Плейлисты».
- Плейлисты: строка с обложкой, long-press → удалить; белая пилюля «Создать плейлист».
- **PlaylistDetail**: List — свайп вправо удаляет трек, EditButton включает перестановку (reorder API), корзина в тулбаре — удалить плейлист целиком, тап — играть.

### 5.7 Now Playing (полноэкранный)
- Top-bar: chevron вниз | «ИГРАЕТ ИЗ» + «Альбом «X»» или «Медиатека» | «в плейлист» + кнопка текста (toggle).
- Центр (занимает свободное место): обложка (85% ширины, радиус 24, тень; **тап по обложке → текст песни**) ⇄ SyncedLyricsView (плавный crossfade).
- Низ: название 22 pt bold + чистый артист 16 pt + сердце 26 pt; скраббер (линия 3 pt, ползунок 10 pt, тап/свайп — seek) с текущим/полным временем; контролы: shuffle / prev / **белый круг 72 pt с чёрной иконкой (спиннер во время загрузки)** / next / repeat (repeat-1 в режиме one).
- Фон: «Под обложку» — blur обложки + затемнение 0.82; иначе плоский фон; AMOLED — чистый чёрный.

### 5.8 Settings (sheet)
Фон плеера (Под обложку/Тёмный), AMOLED, Адаптивный пузырь, Кодек (Авто/MP3/FLAC; подпись «Opus недоступен на iOS»), Аккаунт (адрес сервера, «Выйти»).

---

## 6. Плеер и воспроизведение

### 6.1 Движок (PlayerEngine)
- `AVPlayer`, `automaticallyWaitsToMinimizeStalling = true`, `actionAtItemEnd = .pause`.
- Каждый item получает `preferredForwardBufferDuration = 30` — буфер 30 с вперёд, короткие сетевые провалы не рвут звук.
- Time-observer каждые 0.5 с → позиция/длительность; `AVPlayerItemDidPlayToEndTime` → `handleEnded`.
- KVO `AVPlayer.timeControlStatus` → watchdog: если 8 секунд подряд `waitingToPlayAtSpecifiedRate` (сетевая пробка) — мягкий рестарт `pause()+play()` (и не более одного повторного kick). Это лечит эффект «постоянно пытается подгружать».
- `.failed` у item: одна автоматическая перезагрузка через 2 с; повторный отказ → сообщение об ошибке.

### 6.2 Логика PlayerStore
- `play(track:in:source:)` — строит очередь (если трек уже в текущей — она же), затем `loadCurrent()`.
- `next/previous`: previous при >3 с воспроизведения — seek(0), иначе шаг назад (или seek 0, если он первый); next — шаг вперёд, на последнем — пауза в конце.
- Конец трека: repeat.one → seek(0)+play; иначе следующий из очереди; если очереди нет — остановка на финальной позиции.
- `loadCurrent()`:
  1. локальный файл из `TrackCache`, иначе remote URL из `APIClient`;
  2. активация аудиосессии, play;
  3. `RecentStore.add`;
  4. prefetch **только следующего** трека (текущий намеренно не качается: двойной трафик душил стрим — прошлый баг);
  5. обновление Now Playing.
- Seek из UI — точный (tolerance 0).

### 6.3 AVAudioSession
- Категория `.playback` без опций; активируется на play/load, деактивируется на stop/logout с `notifyOthersOnDeactivation`.
- Прерывание (звоночки, Siri): began → пауза (запоминаем «играли»); ended → resume, только если система сказала `shouldResume`.
- Смена маршрута: пауза только на `.oldDeviceUnavailable` (вытащили наушники). Подключение наушников музыку не прерывает.
- Фон: `UIBackgroundModes = audio` в Info.plist.

### 6.4 Lock screen и пульт (NowPlayingCenter)
- Команды: play, pause, toggle, next, prev, seek.
- Данные: title, артист (чистый), duration, elapsed, rate, обложка 1200 px. Обновление не чаще 1 раза в секунду; немедленное — при play/смене трека.

### 6.5 Что сделано против «постоянных прерываний»
1. Prefetch только следующего трека (раньше качали и текущий — двойной трафик на сервере).
2. Буфер вперёд 30 с на каждый трек.
3. Watchdog «waiting» 8 с → kick (+ один повторный kick).
4. `auto` теперь шлёт URL без лишних параметров: сырой файл с честным Content-Length (Android parity).
5. `estimateContentLength=true` только при явном codec (mp3/flac) — на транскоде.

Воспроизведение проверено AVPlayer-пробой против живого backend: ноль подтормаживаний на FLAC и MP3 (сырой и транскод).

---

## 7. Кэш

### 7.1 Треки — TrackCache
- Каталог `Caches/CorePlayerTracks`, имя файла `<trackId>-<codec>.<ext>` (расширение определяется по Content-Type: mp3/flac/m4a/ogg/audio).
- Скачивание: `URLSession.download` → атомарный move (частичных файлов на диске не бывает). In-flight Set защищает от дублей.
- LRU-вытеснение по modification date до 500 МБ; при каждом чтении mtime обновляется.
- Prefetch — следующий трек очереди, приоритет `.utility`, чтобы не конкурировать со стримом.
- Кэш-хит → играется локальный файл (для повторов интернет не нужен).

### 7.2 Обложки
- `ImageCache`: NSCache в памяти (250 шт / 80 МБ) + `URLCache` на диске (256 МБ, папка `coreplayer.images`), политика `returnCacheDataElseLoad`.
- Размеры: строки 300 px, карточки 600 px, Now Playing 1200 px, палитра пузыря 200 px.

### 7.3 Адаптивная палитра (PaletteUtils)
При включённом «адаптивном пузыре»: два полукадровых усреднения обложки (CIAreaAverage) → доминирующий + самый насыщенный цвет, зажатые в диапазон яркости 0.18–0.8; результат кэшируется по URL. Градиент пузыря: `[0x10141D, primary, secondary]`.

---

## 8. Работа с сетью и API

### 8.1 Транспорт
- `URLSessionConfiguration.default`, таймаут запроса 10 с.
- Заголовок `Cookie: session_id=<sid>` (куку парсим из `Set-Cookie` вручную — httpOnly не попадает в общий cookie store) **и** `?session_id=` в query для стрима и обложек — так AVPlayer гарантированно авторизован.
- Ошибки (`APIError`): invalidURL, unauthorized (401), server(code, detail), decoding, network, unknown — с русскими текстами.

### 8.2 Список эндпоинтов

| Метод | Путь | Назначение |
|---|---|---|
| POST | `/api/auth/login` | JSON `{username, password}`; `session_id` из Set-Cookie |
| GET | `/api/auth/me` | подтвердить сессию при старте |
| POST | `/api/auth/logout` | logout |
| GET | `/api/library/artists` | исполнители |
| GET | `/api/library/albums?all=&type=&size=&offset=` | альбомы (пагинация) |
| GET | `/api/library/tracks?all=&size=` | все треки |
| GET | `/api/library/albums/{id}` · `/api/library/artists/{id}` | детали с треками/альбомами |
| GET | `/api/library/playlists` · `/api/library/playlists/{id}` | плейлисты / их состав |
| POST | `/api/library/playlists` | создать `{name}` |
| DELETE | `/api/library/playlists/{id}` | удалить плейлист |
| POST | `/api/library/playlists/{id}/tracks` | добавить `{track_id}` |
| DELETE | `/api/library/playlists/{id}/tracks/{tid}` | убрать трек |
| PUT | `/api/library/playlists/{id}/reorder` | `{track_ids:[...]}` — новый порядок |
| GET | `/api/library/favorites/ids` | `{tracks:[], albums:[]}` |
| POST | `/api/library/favorites/toggle` | `{id,type}` → `{starred}` |
| GET | `/api/library/favorites/tracks` | избранные треки объектами |
| GET | `/api/library/random?size=` | случайные треки |
| GET | `/api/library/search?q=` | треки + альбомы + исполнители |
| GET | `/api/lyrics/{id}?artist=&title=[&album=][&duration=]` | текст (LRC) |
| GET | `/api/stream/{id}[?format=mp3|flac&estimateContentLength=true&session_id=]` | аудиострим, Range/206 |
| GET | `/api/stream/cover/{coverId}?size=&session_id=` | обложка |

Backend сам ничего не транскодирует — `format` передаётся в Navidrome.

### 8.3 «Терпимый» декодинг
Backend/Navidrome отдают составы по-разному (`tracks` / `songs` / `song`, `entry`, обёртка `results`, массив или обёртка). Для этого:
- `FlexibleList<Element>` — массив | обёртка | null → [];
- `SearchResponse` — вложенный `results` или плоский ответ;
- `AlbumDetailResponse` / `ArtistDetailResponse` / `PlaylistDetailResponse` — `{album:{...}}` или сам объект;
- `FavoritesIdsResponse` — по три варианта ключей (`track_ids`/`tracks`/`trackIds`) на каждую группу.

### 8.4 ATS
`NSAppTransportSecurity → NSAllowsArbitraryLoads = true` — cleartext-серверы в локальной сети обязаны работать.

### 8.5 Чистка артистов
`ArtistUtils.cleanArtistName` (порт с Android): если «сырой» артист содержит ФИО (кириллические слова, одно из которых с патронимическим суффиксом ович/евич/ич/овна/евна/ична/инична), ФИО вырезается по разделителям `/ , • ;`. Пример: `Kai Angel, 9mice • Дмитрий Олегович Ицков` → `Kai Angel, 9mice`. Используется везде через `TrackDto.displayArtist`; fallback — «Неизвестный исполнитель».

---

## 9. Тексты песен (lyrics)

- Запрос: `GET /api/lyrics/{trackId}?artist=&title=[&album=][&duration=]`, ответ `{synced?, text?, lines?}`.
- Парсер `LRCParser.parse`: теги `[mm:ss.xx]` (и `[mm:ss:xx]`, доля любой длины), несколько меток на строке, сортировка по времени. `currentIndex(lines, at:)` — бинарный поиск активной строки.
- Вид `SyncedLyricsView` (порт Android):
  - активная строка: белая, **bold 23 pt**, масштаб 1.05;
  - неактивные: medium 19 pt, прозрачность 0.32, **blur 2.5**;
  - когда пользователь листает руками — блюр снимается, прозрачность 0.72; через 2.5 с бездействия автоскролл и фокус возвращаются;
  - тап по строке — seek (и восстановление фокуса);
  - автоскролл к активной строке по центру, плавный;
  - пустая строка → «♪»; нет текста → «Текст песни недоступен» + кнопка «Повторить»;
  - при смене трека — повторный `loadLyrics()`; race-guard: ответ трека, который уже ушёл, отбрасывается.
- Показываются только **синхронные** (LRC) тексты — как в Android-версии.

---

## 10. Тема и дизайн

Палитра (`CoreColors`, перенесена с Android):

| Токен | HEX | Где используется |
|---|---|---|
| background | 0x0B0F17 | фоны экранов |
| surface | 0x131A26 | карточки, строки |
| surfaceVariant | 0x1A2232 | вторичные поверхности, обложка-заглушка |
| bottomBar | 0x080C14 | таб-бар |
| divider | 0x1E2638 | рамки |
| accent | 0xFF5722 | только кольцо прогресса пузыря + активный трек в списках |
| favorite | 0xEF4444 | заполненное сердце |
| textPrimary | white | всё остальное — белое |
| textSecondary | 0x8E95A5 | артисты, подписи |
| pill-градиент | 0x161C26 → 0x162334 → 0x152A3F → 0x12344E | фон пузыря без адаптива |

AMOLED-режим: background — чистый чёрный, surface 0x101010, variant 0x222222.

Info.plist: `UIUserInterfaceStyle: Dark`, пустой launch screen, ориентации portrait + landscape left/right, AppIcon 1024.

---

## 11. Настройки

| Настройка | Тип | Эффект |
|---|---|---|
| Кодек | auto / mp3 / flac | влияет на URL стрима; mp3/flac → `format=` + `estimateContentLength=true`; auto — сырой файл; flac — без потерь |
| Фон плеера | cover / dark | blurred обложка в Now Playing против плоского фона |
| AMOLED | bool | чистый чёрный фон |
| Адаптивный пузырь | bool | мини-плееру градиент из палитры обложки вместо фиксированного |

Данных сброс — через logout (сессия/сервер/пользователь); кэш треков ужимается автоматически до 500 МБ, полный `clear()` есть на `stop()`/logout.

---

## 12. Сборка и установка

### 12.1 Локально в Xcode
```bash
brew install xcodegen
xcodegen generate          # создаёт CorePlayer.xcodeproj
open CorePlayer.xcodeproj
```
- Выбрать team для подписи (или собираем без подписи ради TrollStore).
- Таргеты: CorePlayer (app) и CorePlayerTests (unit, host app).

### 12.2 Локальный сервер для проверки
```bash
# в репозитории core-player
docker compose up -d       # веб+бэкенд на http://localhost:3000
```
- Симулятор: `http://localhost:3000`
- Устройство: `http://<IP-Mac>:3000`
- Логин: `admin` / `admin123`

### 12.3 Unsigned IPA (TrollStore) вручную
```bash
xcodegen generate
xcodebuild -project CorePlayer.xcodeproj -scheme CorePlayer \
  -configuration Release -sdk iphoneos -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

mkdir Payload && cp -R build/Build/Products/Release-iphoneos/CorePlayer.app Payload/
zip -r CorePlayer.ipa Payload
```
Открыть `.ipa` в TrollStore — подпись не нужна.

---

## 13. CI: сборка IPA в GitHub Actions

`.github/workflows/build.yml`:
- Триггеры: push в `main` и ручной `workflow_dispatch`.
- Runner: `macos-15`.
- Шаги: checkout → `brew install xcodegen` → `xcodegen generate` → `xcodebuild` (Release, sdk iphoneos, без подписи) → упаковка `Payload/CorePlayer.app` → zip → `upload-artifact` (`CorePlayer-ipa`).
- Артефакт (`CorePlayer.ipa`) скачивается со страницы Actions; свежая копия также лежит в рабочей папке `build/CorePlayer.ipa`.

---

## 14. Тесты

### 14.1 CLI-тесты (работают без Xcode)
```bash
./scripts/run-logic-tests.sh
```
Компилирует чистые модули (Models, LRCParser, StreamURLBuilder, QueueState, AudioCodec, ArtistUtils) и прогоняет два тестовых набора:
- **LogicTests**: LRC (время, множественные метки, доли, индекс текущей строки), QueueState (next/repeat/shuffle), StreamURLBuilder (auto без параметров, mp3 с format+estimateContentLength, session_id, путь cover), декодинг моделей (FlexibleList, SearchResponse, обёртки деталей, FavoritesIds).
- **ArtistUtilsTests**: отдельный бинарь — чистка ФИО по • / , / ;, кириллица без патронимика остаётся, nil/пустые → пустая строка.

### 14.2 XCTest в Xcode
`CorePlayerTests/CorePlayerTests.swift` — минимальный набор (LRC, URL стрима, очередь) для запуска из IDE.

---

## 15. Отличия от Android-версии

| Аспект | Android | iOS |
|---|---|---|
| Аудио-движок | ExoPlayer (Media3) | AVPlayer |
| Opus/Ogg | играет | **не играет** (исключено сознательно) |
| Кроссфейд | есть | **нет** (по требованию) |
| Кэш файлов | ExoPlayer SimpleCache (байтовые диапазоны) | целые файлы, LRU 500 МБ, prefetch следующего |
| Ландшафт | two-column плеер | two-column плеер |
| Ноль экрана очереди | нет отдельного экрана | нет отдельного экрана |
| Тексты | blur + караоке | blur + караоке (тоже только синхронные) |
| Плейлист-редактор | полный | упрощён (состав, reorder, удаление плейлиста) |

Функциональный паритет: авторизация, библиотека, альбомы/исполнители, плейлисты, избранное, поиск, shuffle/repeat, фон/lock screen/пульт, прерывания звонком, смена маршрута, LRC, кэш, чистка ФИО.

---

## 16. Известные ограничения и TODO

- **Opus/Ogg** не воспроизводится принципиально; для библиотек с ogg-исходниками ставьте codec mp3 (Navidrome транскодирует).
- Несинхронные тексты не отображаются (в Android тоже).
- PlaylistDetail без переименования и без собственной обложки плейлиста.
- При codec=mp3 длина транскода у Navidrome приблизительная (`estimateContentLength`): на последних секундах транскода возможен короткий «дожим».
- Визуальная сверка с эталонными скриншотами (папка «скриншоты») не проведена — сверить, когда появятся.

---

## 17. Troubleshooting

| Симптом | Причина | Решение |
|---|---|---|
| «Сессия истекла. Войдите снова» | cookie протух (30 дней) или сервер перезапустился | перелогиниться |
| 401 на всё | прокси потерял креды Navidrome | backend-логи; приложение ни при чём |
| «Не удалось подключиться к серверу» | неверный IP/порт | на устройстве — IP хоста, не localhost; port 3000 |
| Звук есть, экран блокировки пуст | не активен BG-режим | проверить `UIBackgroundModes=audio` (в репо есть) |
| Тексты нет | в Navidrome нет LRC / не совпал artist | кнопка «Повторить» в плеере |
| Кэш разросся | это база | лимит 500 МБ, LRU сам урежет |
| CI упал на runner'е | macos-15 обновили | перезапустить workflow (`workflow_dispatch`) |
