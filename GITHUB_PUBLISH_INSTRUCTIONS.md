# Загрузка v0.11.3 в GitHub

Цель: https://github.com/erasylmutalip9-rgb/University-Secrets-The-Last-Class

**Сначала распакуйте ZIP полностью.** В корне должны быть `project.godot`, `scenes/`, `scripts/`, `ai_service/`, `assets/`.

## Автоматическая загрузка через Git for Windows
1. Установить Git for Windows: https://git-scm.com/downloads/win
2. Дважды нажать `PUBLISH_TO_GITHUB_WINDOWS.bat`.
3. Войти в GitHub в открывшемся окне авторизации.
4. Если Git просит имя автора, указать в CMD:
   `git config --global user.name "Erasyl Mutalip"`
   `git config --global user.email "EMAIL_УКАЗАННЫЙ_В_ВАШЕМ_GITHUB"`
   Повторить: `git add .`, `git commit -m "Initial source release"`, `git push -u origin main`.
5. Проверить, что GitHub показывает `project.godot`, `scenes`, `scripts`, `ai_service` и `TEAM.md`.

Скрипт **не использует `--force`**. Если репозиторий оказался непустым, не перезаписывайте коммиты: получите последние изменения через GitHub Desktop и объедините их.

## Альтернатива через GitHub Desktop
1. Распаковать ZIP.
2. В GitHub Desktop: **File → Add local repository** и выбрать распакованную папку; при предложении создать Git-репозиторий согласиться.
3. Создать реальный первый коммит.
4. Подключить `origin` к указанному URL и опубликовать ветку `main`.

## Важные замечания
- Этот ZIP **не содержит Windows `.exe`**. Он предназначен для исходников.
- Папка `.godot` и Python-кэши удалены для чистой публикации.
- Модели MediaPipe и Vosk включены как файлы для воспроизведения автономной AI-функциональности; перед открытой публикацией проверить права на их распространение по документам поставщиков.
- Не нужно публиковать личные сохранения, журналы, пароли или токены.
- Для реального командного GitHub-трека второй участник должен делать собственные настоящие изменения под своим аккаунтом. Нельзя создавать поддельные коммиты.
