#!/usr/bin/env bash
set -e

USER_NAME="Ivan"
CONTAINER_NAME="sysadmin-app"
IMAGE_NAME="sysadmin-script"
TAG="1.0"

install_docker() {
	sudo apt update -y >/dev/null 2>&1
	sudo apt install -y docker.io docker-compose-v2 >/dev/null 2>&1
	sudo usermod -aG docker "$USER"

	if command -v docker &>/dev/null; then
		echo "== [ok] Установка docker завершена. $(docker --version) =="
		echo "== Перезапустите скрипт =="
		echo "== ВНИМАНИЕ! Перезапустите сессию терминала или выполните 'newgrp docker' вручную =="
	else
		echo "== [Ошибка]: не удалось установить docker. ==" >&2
		exit 1
	fi
}

install_nginx() {
	if !command -v nginx &>/dev/null; then
		echo "== Nginx не найден. =="
		echo "== Установка nginx. =="

		sudo apt update -y >/dev/null 2>&1
		sudo apt install -y nginx >/dev/null 2>&1
		sudo rm -f /etc/nginx/sites-enabled/default
	fi

	echo "== Применения конфигурация nginx для ${CONTAINER_NAME} =="

	sudo tee /etc/nginx/sites-available/"${CONTAINER_NAME}" >/dev/null <<EOF
server {
	listen 80;
	server_name _;
	return 301 https://\$host\$request_uri;
}
server {
	listen 443 ssl;
	server_name _;
	ssl_certificate	/etc/ssl/certs/${CONTAINER_NAME}.crt;
	ssl_certificate_key /etc/ssl/private/${CONTAINER_NAME}.key;
	location / {
		proxy_pass http://127.0.0.1:8080;
	}
}
EOF
	sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout /etc/ssl/private/"${CONTAINER_NAME}".key \
		-out /etc/ssl/certs/"${CONTAINER_NAME}".crt \
		-subj "/CN=${CONTAINER_NAME}.local"

	sudo ln -sf /etc/nginx/sites-available/"${CONTAINER_NAME}" /etc/nginx/sites-enabled/
	sudo nginx -t && sudo systemctl reload nginx

	echo "== Конфигурация nginx завершена =="
}

raid_lvm() {
	echo "== Сборка RAID-1 =="
	sudo apt update -y >/dev/null 2>&1
	if ! command -v mdadm &>/dev/null; then
		echo "== Установка mdadm =="
		sudo apt install -y mdadm >/dev/null 2>&1
	fi

	sudo mkdir -p /mnt/raid-lab && cd /mnt/raid-lab
	[ -f disk1.img ] || sudo dd if=/dev/zero of=disk1.img bs=1M count=512
	[ -f disk2.img ] || sudo dd if=/dev/zero of=disk2.img bs=1M count=512
	[ -f disk3.img ] || sudo dd if=/dev/zero of=disk3.img bs=1M count=512

	LOOP1=$(sudo losetup -j disk1.img | cut -d':' -f1)
	[ -z "$LOOP1" ] && LOOP1=$(sudo losetup -fP --show disk1.img)

	LOOP2=$(sudo losetup -j disk2.img | cut -d':' -f1)
	[ -z "$LOOP2" ] && LOOP2=$(sudo losetup -fP --show disk2.img)

	LOOP3=$(sudo losetup -j disk3.img | cut -d':' -f1)
	[ -z "$LOOP3" ] && LOOP3=$(sudo losetup -fP --show disk3.img)

	echo "== Проверка состояния RAID =="
	if [ -b /dev/md0 ]; then
		echo "== [ok] Raid массив существует =="
	else
		echo "== [!] RAID не найден. Пытаемся собрать существующий =="
		if sudo mdadm --assemble --scan 2>/dev/null; then
			echo "[ОК] Существующий RAID успешно собран."
		else
			echo "[!] Сборка не удалась. Создаем НОВЫЙ RAID-1..."
			yes | sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 "$LOOP1" "$LOOP2"
			sudo mkfs.ext4 -F /dev/md0
			sudo mkdir -p /mnt/raid && sudo mount /dev/md0 /mnt/raid
			cat /proc/mdstat
		fi
	fi

	echo "== Настройка LVM =="
	if ! command -v lvm >/dev/null 2>&1; then
		echo "== Установка lvm2 =="
		sudo apt install -y lvm2 >/dev/null 2>&1
	fi

	if ! sudo pvs "$LOOP3" >/dev/null 2>&1; then
		sudo pvcreate -f --yes "$LOOP3"
		sudo vgcreate vg_data "$LOOP3"
	fi

	sudo lvs /dev/vg_data/lv_logs >/dev/null 2>&1 || sudo lvcreate -L 200M -n lv_logs vg_data
	sudo blkid /dev/vg_data/lv_logs | grep -q 'TYPE="ext4"' || sudo mkfs.ext4 /dev/vg_data/lv_logs
	sudo mkdir -p /mnt/logs
	mountpoint -q /mnt/logs || sudo mount /dev/vg_data/lv_logs /mnt/logs

	echo "== Результат =="
	df -h | grep -E "raid|logs"
}

systemd_config() {
	docker rm -f "${CONTAINER_NAME}"
	sudo tee /etc/systemd/system/"${CONTAINER_NAME}.service" <<EOF
[Unit]
Description=${CONTAINER_NAME} service
After=docker.service
Requires=docker.service

[Service]
ExecStart=docker start -a ${CONTAINER_NAME}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
	docker create -p 127.0.0.1:8080:8080 \
		--name "$CONTAINER_NAME" \
		-e USER_NAME="$USER_NAME" \
		"${IMAGE_NAME}:${TAG}"

	sudo systemctl daemon-reload
	sudo systemctl enable "$CONTAINER_NAME"
	sudo systemctl start "$CONTAINER_NAME"
	sleep 3
	sudo systemctl status "$CONTAINER_NAME"
}

if ! command -v docker &>/dev/null; then
	echo "docker не установлен" >&2
	echo "начинаю установку docker" >&2
	install_docker
	exit 0
else
	echo "Сборка образа ${IMAGE_NAME}:${TAG}"
	docker build -t "${IMAGE_NAME}:${TAG}" .

	echo "Остановка старого контейнера ${CONTAINER_NAME}"
	docker rm -f sysadmin-app 2>/dev/null || true

	echo "Запуск контейнера ${CONTAINER_NAME}"
	docker run -d \
		-p 127.0.0.1:8080:8080 \
		--name "$CONTAINER_NAME" \
		-e USER_NAME="$USER_NAME" \
		"${IMAGE_NAME}:${TAG}"

	echo "Контейнер ${CONTAINER_NAME} запущен на порту 8080"

	install_nginx
	raid_lvm
	systemd_config
fi
