#!/usr/bin/env bash
USER_NAME="${1:-}"
SCRIPT_NAME=$(basename "$0")

if [ -z "$USER_NAME" ]; then
	echo "Ошибка: не казано имя пользователя." >&2
	echo "Использование $SCRIPT_NAME имя_пользователя" >&2
	exit 1;
fi

TARGET_DIR="$HOME/managed-users/$USER_NAME"
BASHRC_PATH="$TARGET_DIR/.bashrc"

mkdir -p "$TARGET_DIR"

cat << EOF >> "$BASHRC_PATH"
# настройки $USER_NAME"

# Короткая команда обновления ОС
alias update='sudo apt update && sudo apt upgrade -y'

# Терминальный редактор по умолчанию vim
export EDITOR='vi'

# Функция создат папку и сразу войти в нее
mkcd() {
	mkdir -p "\$1" && cd "\$1"
}
EOF

echo "Добро пожаловать, $USER_NAME!"
echo "$(date): создан пользовательский каталог для $USER_NAME" >> setup.log
