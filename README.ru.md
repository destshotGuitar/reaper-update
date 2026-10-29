# Update REAPER

[English](README.md) · **Русский**

Действие для REAPER, которое обновляет сам REAPER в один клик: проверяет на
[reaper.fm](https://www.reaper.fm/download.php), есть ли новая версия, закрывает
REAPER (предложив сохранить проекты), скачивает и ставит обновление и снова
запускает REAPER.

Работает на **Windows**, **macOS** и **Linux**.

## Установка

### Через ReaPack (удобнее)

1. Extensions → ReaPack → Import repositories…
2. Вставьте адрес и нажмите OK:
   ```
   https://github.com/destshotGuitar/reaper-update/raw/main/index.xml
   ```
3. Extensions → ReaPack → Browse packages, найдите **Update REAPER**, правый клик → Install, затем Apply.

Новые версии скрипта ReaPack будет привозить сам.

### Вручную

1. Скопируйте содержимое папки `Various` в папку `Scripts` внутри папки ресурсов
   REAPER (Options → Show REAPER resource path in explorer/finder).
   `Update REAPER.lua` и папка `reaper-update` должны лежать рядом.
2. Actions → Show action list → New action → Load ReaScript… → выберите `Update REAPER.lua`.

## Как пользоваться

Запустите **Script: Update REAPER.lua** из списка действий. Чтобы было под рукой:

- **Меню Actions:** в списке действий New action → New custom action…, назовите
  «Обновить REAPER», добавьте в него *Script: Update REAPER.lua* и поставьте
  галочку **Show in actions menu**.
- **Панель инструментов:** правый клик по панели → Customize toolbar → Add.

Если есть обновление, скрипт покажет, какая версия стоит и какая доступна.
Нажмите **Yes**: REAPER закроется, через несколько секунд после этого
обновление установится и REAPER запустится снова. По ходу будут уведомления,
а если что-то пойдёт не так — сообщение об ошибке.

Пароль администратора спрашивается, только если REAPER стоит в папке, куда у
пользователя нет прав на запись (`C:\Program Files`, `/opt`, иногда `/Applications`).

## Как устроено

`Update REAPER.lua` спрашивает последнюю версию у помощника, который лежит
рядом: `update.ps1` (PowerShell) на Windows, `update.sh` (bash) на macOS и
Linux. Помощник читает страницу загрузки, выбирает файл под вашу систему и,
после подтверждения, ждёт закрытия REAPER и ставит обновление:

| Система | Что скачивает | Как ставит | Пароль спрашивает |
|---|---|---|---|
| Windows x64 / x86 / ARM64EC | `reaperNNN_x64-install.exe`, `reaperNNN-install.exe`, `…_win11_arm64ec…-install.exe` | официальный установщик в тихом режиме (`/S /D=<папка REAPER>`) | UAC |
| macOS (Intel и Apple Silicon) | `reaperNNN_universal.dmg` | заменяет `REAPER.app` версией из образа диска | системное окно macOS |
| Linux x86_64 / aarch64 / armv7l / i686 | `reaperNNN_linux_<arch>.tar.xz` | копирует новые файлы поверх папки REAPER (то же делает `install-reaper.sh`) | `pkexec` (polkit) |

REAPER ставится туда же, откуда запущен (`reaper.GetExePath()`), поэтому
нестандартные и портативные установки тоже работают. Настройки, плагины и
скрипты лежат в папке ресурсов, их обновление не трогает.

Подробности:

- **Прокси.** Программы, запущенные из REAPER, не получают прокси из настроек
  рабочего стола. Помощник находит его сам: Windows использует системный прокси,
  на macOS он берётся из `scutil --proxy`, на Linux — из GNOME (`gsettings`) или
  KDE (`kioslaverc`). Переменная `https_proxy`, если задана, важнее.
- **Ярлык на Linux.** После обновления REAPER запускается через ярлык из меню
  (`cockos-reaper.desktop`), если ярлык запускает именно этот REAPER. Так
  сохраняются настройки вроде `pw-jack -p 128 /opt/REAPER/reaper`. Иначе
  запускается сам исполняемый файл.
- **Зависшая загрузка** обрывается (меньше 10 КБ/с в течение 30 с) с сообщением
  об ошибке, чтобы REAPER не оставался закрытым надолго.
- Если REAPER не закрылся за 5 минут (например, нажали «Отмена» в окне
  сохранения), обновление отменяется.

Логи:

- Windows: `%TEMP%\reaper-update.log`
- macOS: `~/Library/Logs/reaper-update.log`
- Linux: `~/.cache/reaper-update.log`

## Что проверено

| | Проверка версии | Полное обновление |
|---|---|---|
| Linux x86_64 (Fedora, GNOME) | ✅ | ✅ |
| Windows | ✅ | пока нет |
| macOS | ✅ | пока нет |

Будем рады отчётам с Windows и macOS: откройте issue и приложите лог.

## Что нужно

- REAPER 6 или новее.
- Windows: Windows PowerShell 5.1 (есть в Windows 10 и 11).
- macOS: ничего дополнительно.
- Linux: `bash`, `curl`, `tar`, `xz`; `pkexec`, если REAPER в системной папке;
  `notify-send` и `zenity` или `kdialog` для сообщений (необязательно).

## Лицензия

[MIT](LICENSE)
