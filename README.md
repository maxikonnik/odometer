# Odometer

Odometer — это лёгкое приложение для строки меню macOS, которое показывает
внимание-маячок (attention beacon), когда Claude Code ждёт вашей реакции в
одной из сессий.

## Сборка

Xcode не требуется — достаточно Command Line Tools.

```bash
swift build -c release
./Scripts/build-app.sh
```

`Scripts/build-app.sh` собирает исполняемый файл через SwiftPM, упаковывает
его в `Odometer.app` (с `Info.plist` и ad-hoc подписью через `codesign`) и
кладёт бандл в корень репозитория.

## Установка

```bash
cp -R Odometer.app /Applications/
./Scripts/install-hooks.sh
```

`Scripts/install-hooks.sh` копирует `Scripts/odometer-hook.py` в
`~/.claude/odometer/hook.py` и вписывает три хука (`Notification`,
`UserPromptSubmit`, `PostToolUse`) в `~/.claude/settings.json` — они создают и
убирают маячок внимания. Скрипт **не заменяет** файл настроек целиком: он
объединяет свои записи с уже существующими, сохраняя остальные хуки и
настройки нетронутыми.

Перед первым изменением файла скрипт делает его резервную копию —
`~/.claude/settings.json.odometer-backup`. Копия создаётся только один раз:
повторные запуски `install-hooks.sh` её не перезаписывают, чтобы не потерять
исходное состояние без хуков Odometer.

Если `~/.claude/settings.json` существует, но не парсится как корректный
JSON-объект, скрипт останавливается с ошибкой и ничего не меняет — ни файл
настроек, ни резервную копию.

## Первый запуск

При первом запуске macOS дважды спросит разрешение:

- доступ к Keychain — выберите **«Всегда разрешать»**;
- разрешение на показ уведомлений.

## Откат

Чтобы вернуть настройки Claude Code к состоянию до установки Odometer,
восстановите резервную копию:

```bash
cp ~/.claude/settings.json.odometer-backup ~/.claude/settings.json
```
