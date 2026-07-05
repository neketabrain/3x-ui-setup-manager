#!/bin/bash
# =========================================
# 3X-UI Setup Manager by neketabrain
# =========================================

BASE_PATH="/opt/3x-ui-setup"
DOCKER_COMPOSE_PATH="$BASE_PATH/docker-compose.yml"
CADDYFILE_PATH="$BASE_PATH/caddy/Caddyfile"
CADDY_ENV_PATH="$BASE_PATH/caddy.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NO_COLOR='\033[0m'

ColorRed() {
	echo -ne "${RED}${1}${NO_COLOR}"
}
ColorGreen() {
	echo -ne "${GREEN}${1}${NO_COLOR}"
}
ColorBlue() {
	echo -ne "${BLUE}${1}${NO_COLOR}"
}
ColorGray() {
	echo -ne "${GRAY}${1}${NO_COLOR}"
}

confirm_action() {
    read -p "$1 (y/n): " response
    case "$response" in
        [Yy][Ee][Ss]|[Yy]) return 0 ;;
        *) return 1 ;;
    esac
}

function press_any_key() {
    echo ""
	read -n 1 -s -r -p "$(ColorGray 'Нажмите любую кнопку, чтобы продолжить...')"
	echo ""
	echo ""
	echo ""
}

function start_container() {
    echo ""
    echo "Запускаю контейнер..."

	if output=$(docker compose -f $DOCKER_COMPOSE_PATH up -d 2>&1); then
		echo -e "$(ColorGreen 'Контейнер запущен')"
	else
		echo -e "${RED}${output}${NO_COLOR}"
	fi
}

function stop_container() {
    echo ""
    echo "Останавливаю контейнер..."

	if output=$(docker compose -f $DOCKER_COMPOSE_PATH down 2>&1); then
		echo -e "$(ColorGreen 'Контейнер остановлен')"
	else
		echo -e "${RED}${output}${NO_COLOR}"
	fi
}

function restart_container() {
    echo ""
    echo "Перезапускаю контейнер..."

	if ! output1=$(docker compose -f $DOCKER_COMPOSE_PATH down 2>&1); then
    	echo -e "${RED}${output1}${NO_COLOR}"
		return 1
	fi

	if ! output2=$(docker compose -f $DOCKER_COMPOSE_PATH up -d 2>&1); then
    	echo -e "${RED}${output2}${NO_COLOR}"
		return 1
	fi

    echo "$(ColorGreen 'Контейнер перезапущен')"
}

function upgrade_container() {
    echo ""
    echo "Останавливаю контейнер..."

	if ! output1=$(docker compose -f $DOCKER_COMPOSE_PATH down 2>&1); then
    	echo -e "${RED}${output1}${NO_COLOR}"
		return 1
	fi

    echo "Обновляю до последней версии..."

	if ! output2=$(docker compose -f $DOCKER_COMPOSE_PATH pull 2>&1); then
		echo -e "${RED}${output2}${NO_COLOR}"
		return 1
	fi

    echo "Запускаю контейнер..."

	if ! output3=$(docker compose -f $DOCKER_COMPOSE_PATH up -d 2>&1); then
		echo -e "${RED}${output3}${NO_COLOR}"
		return 1
	fi

    echo "$(ColorGreen 'Готово! Панель 3X-UI обновлена до последней версии')"
}

function set_rootless_access() {
    echo ""
	echo "Настраиваю доступ к Docker без root прав..."

	if ! getent group docker > /dev/null 2>&1; then
		sudo groupadd docker
	fi

	sudo usermod -aG docker $USER || true

	if confirm_action "Требуется перезапустить сессию в терминале, чтобы изменения вступили в силу. Сделать это сейчас?"; then
		echo "$(ColorGreen 'Rootless-режим для Docker установлен')"
		newgrp docker
	fi

	echo "$(ColorGreen 'Rootless-режим для Docker установлен')"
}

function install_docker() {
    echo ""
	if command -v docker &> /dev/null; then
		echo "Docker уже установлен"
	else
		echo "Устанавливаю Docker..."

		if ! output1=$(bash <(wget -qO- https://get.docker.com) @ -o get-docker.sh 2>&1); then
			echo -e "${RED}${output1}${NO_COLOR}"
			return 1
		fi

		if ! output2=$(docker --version 2>&1); then
			echo -e "${RED}${output2}${NO_COLOR}"
			return 1
		fi

		echo "$(ColorGreen 'Готово! Docker установлен')"

		if confirm_action "Настроить rootless-режим для Docker?"; then
    		set_rootless_access
		fi
	fi
}

function set_domain() {
    echo ""
    echo -ne "$(ColorBlue 'Введите ваш домен (example.com):') "
	read new_domain

	if output=$(sed -i'' -e "s/^USER_DOMAIN=.*/USER_DOMAIN=${new_domain}/" $CADDY_ENV_PATH 2>&1); then
    	echo "Домен $(ColorBlue $new_domain) установлен"
	else
		echo -e "${RED}${output}${NO_COLOR}"
	fi
}

function set_sub_path() {
    echo ""
    echo -ne "$(ColorBlue 'Введите путь до подписок (/sub-secret-path):') "
	read new_path

	if output=$(sed -i'' -e "s/^USER_SUB_PATH=.*/USER_SUB_PATH=${new_path}/" $CADDY_ENV_PATH 2>&1); then
    	echo "Путь до подписок $(ColorBlue $new_path) установлен"
	else
		echo -e "${RED}${output}${NO_COLOR}"
	fi
}

function install_3xui() {
	echo ""
	echo "Загружаю необходимые файлы..."

	mkdir -p $BASE_PATH/{3x-ui,caddy/templates}
	wget -qO $DOCKER_COMPOSE_PATH https://raw.githubusercontent.com/neketabrain/3x-ui-setup-manager/main/configs/docker-compose.yml
	wget -qO $CADDYFILE_PATH https://raw.githubusercontent.com/neketabrain/3x-ui-setup-manager/main/configs/Caddyfile
	wget -qO $CADDY_ENV_PATH https://raw.githubusercontent.com/neketabrain/3x-ui-setup-manager/main/configs/caddy.env
	wget -qO $BASE_PATH/caddy/templates/index.html https://raw.githubusercontent.com/neketabrain/3x-ui-setup-manager/main/configs/index.html
    
	set_domain
	start_container

	DOMAIN=$(grep '^USER_DOMAIN=' $CADDY_ENV_PATH | cut -d '=' -f2-)
	echo "$DOMAIN"

	echo ""
	echo -e "${GREEN}Готово! Панель 3X-UI установлена и доступна по адресу ${DOMAIN}:8443/${NO_COLOR}"
}

function menu() {
	echo -ne "
\033[1m3X-UI Setup Manager\033[0m

$(ColorGreen '1)') Установить и настроить 3X-UI
$(ColorGreen '2)') Обновить 3X-UI
$(ColorGreen '3)') Изменить домен
$(ColorGreen '4)') Изменить путь до подписок
$(ColorGreen '5)') Перезапустить контейнер
$(ColorGreen '6)') Запустить контейнер
$(ColorGreen '7)') Остановить контейнер
$(ColorGreen '8)') Установить Docker
$(ColorGreen '9)') Настроить rootless-режим для Docker
$(ColorGreen '0)') Выход

$(ColorBlue 'Выберите пункт меню:') "
    
	read a
    case $a in
		1) install_3xui ; press_any_key ; menu ;;
		2) upgrade_container ; press_any_key ; menu ;;
		3) set_domain ; press_any_key ; menu ;;
		4) set_sub_path ; press_any_key ; menu ;;
		5) restart_container ; press_any_key ; menu ;;
		6) start_container ; press_any_key ; menu ;;
		7) stop_container ; press_any_key ; menu ;;
		8) install_docker ; press_any_key ; menu ;;
		9) set_rootless_access ; press_any_key ; menu ;;
		0) exit 0 ;;
		*) echo -e "$(ColorRed 'Такого пункта меню не существует')" ; press_any_key ; menu ;;
    esac
}

menu
