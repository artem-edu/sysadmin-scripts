# Setup script

Скрипт принимает аргумент (имя пользователя), создает директория, файл .bashrc, выдает приветсвие и записывает факт создания в лог.

Запуск скрипта
```bash
chmod +x script.sh
USER_NAME=<userName> ./script.sh
```

## Сборка образа
```bash
docker build -t sysadmin-script .
```

## Запуск котейнера
```bash
docker run -d -p 8080:8080 -e USER_NAME=<userName> --name sysadmin-app sysadmin-script
```
