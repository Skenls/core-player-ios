# Core Player for iOS

iOS-порт [Core Player для Android](https://github.com/Skenls/core-player-android) на SwiftUI + AVFoundation. Работает с тем же backend API, что Android и веб-плеер.

- iOS 15.0+
- iPhone, портрет и ландшафт
- Тёмная тема, русский интерфейс
- Без сторонних зависимостей (только Apple frameworks)

> Полная документация — **[DOCS.md](DOCS.md)**: архитектура, экраны, плеер, кэш, API, сборка, CI, тесты, troubleshooting.

> Приложение собирается на GitHub Actions (см. CI в DOCS.md), свежий IPA — артефактом.
## Быстрый старт

```bash
brew install xcodegen
xcodegen generate
open CorePlayer.xcodeproj
```

В Xcode выберите team для подписи (или соберите без подписи для TrollStore) и запустите на iPhone.

### Локальный сервер

```bash
# в репозитории core-player
docker compose up -d
```

- Симулятор: `http://localhost:3000`
- Устройство: `http://<IP-мака>:3000`
- Логин: `admin` / `admin123`

Сервер можно указать на экране входа. HTTP разрешён через ATS (`NSAllowsArbitraryLoads`).
## Функции

- Вход по адресу сервера, логин/пароль, сохранение сессии в Keychain
- Главная: недавние, избранное, плейлисты, исполнители
- Поиск с debounce 300 мс и историей
- «Все треки»: альбомы, исполнители, треки
- Медиатека: избранные треки, плейлисты, создание плейлиста
- Детали альбома/исполнителя/плейлиста
- Плеер: очередь, shuffle, repeat (off/all/one), seek, next/prev
- Фон, экран блокировки, пульт, прерывания звонками, смена маршрута
- Синхронные тексты LRC с подсветкой и переходом по строке
- Обложки с дисковым кэшем, blur-фон, AMOLED, адаптивный мини-плеер
- Кэш треков 500 МБ (Prefetch, LRU) и офлайн-воспроизведение
- Настройки: фон, AMOLED, кодек (Auto/MP3/FLAC), выход
## Отличия от Android (технические)

- **Нет Opus**: AVPlayer не воспроизводит Ogg/Opus. В настройках доступны Auto/MP3/FLAC; для библиотек с Ogg используйте MP3.
- **Нет кроссфейда**: по требованию исключён.
- **Кэш**: треки докачиваются целиком в фоне (Prefetch текущего и следующего), а не байтовым Range-кэшем, как ExoPlayer `SimpleCache`. Офлайн-повторное воспроизведение работает, частичный стриминг-кэш — нет.
- **Нет iPad**: только iPhone; портрет и ландшафт.
- **Плейлисты**: экран показывает состав и воспроизведение; удаление/перестановка треков пока не вынесены в UI.
## TrollStore (unsigned IPA)

```bash
xcodebuild -project CorePlayer.xcodeproj -scheme CorePlayer \
  -configuration Release -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO

mkdir -p Payload
cp -R build/Build/Products/Release-iphoneos/CorePlayer.app Payload/
zip -r CorePlayer.ipa Payload
```

Полученный `CorePlayer.ipa` открыть в TrollStore. Подпись не нужна.

## Логика и тесты

```bash
./scripts/run-logic-tests.sh
```

Покрыты: LRC-парсер, очередь/repeat/shuffle, URL стрима и обложек, декодирование моделей, flexible-обёртки API.

Xcode-тесты: `CorePlayerTests/CorePlayerTests.swift` (XCTest).

## Статус

Код собирается на CI (GitHub Actions, unsigned IPA): в системе нет Xcode, а `xcodebuild` по просьбе не запускался. Первый запуск в Xcode может потребовать правок под версию SDK.
