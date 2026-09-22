#!/usr/bin/env bash
set -e

install_docker() {
	if ! sudo -v &> /dev/null; then
		echo "Ошибка: Для установки docker необходимы права sudo!" >&2
		exit 1;
	fi

	sudo apt update
	sudo apt install -y docker.io docker-compose-v2
	sudo usermod -aG docker "$USER"

	if command -v docker &> /dev/null; then
		echo "Установка docker завершениа. $(docker --version)"
		echo "Перезапустите скрипт"
		echo "ВНИМАНИЕ! Перезапустите сессию терминала или выполните 'newgrp docker' вручную"
	else
		echo "Ошибка: не удалось установить docker." >&2
		exit 1
	fi
}

if ! command -v docker &> /dev/null; then
	echo "docker не установлен" >&2
	echo "начинаю установку docker" >&2
	install_docker
	exit 0
else
	USER_NAME="Ivan"
	IMAGE_NAME="sysadmin-script"
	TAG="1.0"
	CONTAINER_NAME="sysadmin-app"

	echo "Сборка образа ${IMAGE_NAME}:${TAG}"
	docker build -t "${IMAGE_NAME}:${TAG}" .

	echo "Остановка старого контейнера ${CONTAINER_NAME}"
	docker rm -f sysadmin-app 2>/dev/null || true

	echo "Запуск контейнера ${CONTAINER_NAME}"
	docker run -d \
		-p 8080:8080 \
		--name sysadmin-app \
		-e USER_NAME="$USER_NAME" \
		"${IMAGE_NAME}:${TAG}"

	echo "Контейнер ${CONTAINER_NAME} запущен на порту 8080"
fi
