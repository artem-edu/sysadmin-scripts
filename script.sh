#!/usr/bin/env bash
USER_NAME="$1"

if [ -z "$USER_NAME" ]; then
	echo "Использование script.sh имя_пользователя" >&2
	exit 1;
fi

TARGET_DIR="$HOME/managed-users/$USERNAME"
mkdir -p "$TARGET_DIR"
echo "# настройки $USER_NAME" > "$TARGET_DIR/.bashrc"
echo "Добро пожаловать, $USER_NAME!"
echo "$(date): создан пользовательский каталог для $USER_NAME" >> setup.log
