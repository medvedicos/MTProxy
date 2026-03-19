#!/bin/bash

# Цвета для красивого вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Параметры по умолчанию
CONTAINER_NAME="mtproto-proxy"
PORT="443"
FAKE_DOMAIN="ya.ru"
SECRET=""
TAG=""

# Разбор аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            FAKE_DOMAIN="$2"
            shift 2
            ;;
        -s|--secret)
            SECRET="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Использование: $0 [опции]"
            echo ""
            echo "Опции:"
            echo "  -d, --domain ДОМЕН    Домен для Fake TLS маскировки (по умолчанию: ya.ru)"
            echo "  -s, --secret СЕКРЕТ   Свой секретный ключ (32 hex-символа, без префикса ee)"
            echo "  -t, --tag ТЕГ         Тег продвигаемого канала (получить у @MTProxybot)"
            echo "  -p, --port ПОРТ       Порт для прокси (по умолчанию: 443)"
            echo "  -h, --help            Показать эту справку"
            echo ""
            echo "Примеры:"
            echo "  $0"
            echo "  $0 -d google.com"
            echo "  $0 -d google.com -s 0123456789abcdef0123456789abcdef -t abc123"
            exit 0
            ;;
        *)
            echo -e "${RED}Неизвестная опция: $1${NC}"
            echo "Используйте -h для справки"
            exit 1
            ;;
    esac
done

echo -e "🚀 Запуск MTProto прокси с Fake TLS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📌 Используем домен: ${BLUE}${FAKE_DOMAIN}${NC}"

# Проверяем наличие Docker, устанавливаем если нет
if ! command -v docker &> /dev/null; then
    echo -e "📦 Docker не найден, устанавливаем..."
    sudo apt update && sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    echo -e "${GREEN}✅ Docker установлен${NC}"
fi

# Генерируем или используем переданный секрет
if [ -n "$SECRET" ]; then
    # Пользователь передал свой секрет — добавляем префикс ee + hex домена
    echo -e "🔑 Используем пользовательский секрет"
    DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps | tr -d '\n')
    SECRET="ee${DOMAIN_HEX}${SECRET}"
    echo -e "   Секрет: ${YELLOW}${SECRET}${NC}"
else
    # Генерируем автоматически
    echo -n -e "🔑 Генерация Fake TLS секрета... "
    DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps | tr -d '\n')
    echo -e "\n   hex домена: ${DOMAIN_HEX}"

    DOMAIN_LEN=${#DOMAIN_HEX}
    NEEDED=$((30 - DOMAIN_LEN))
    RANDOM_HEX=$(openssl rand -hex 15 | cut -c1-$NEEDED)

    SECRET="ee${DOMAIN_HEX}${RANDOM_HEX}"

    echo -e "   Случайное дополнение: ${RANDOM_HEX}"
    echo -e "   Секрет: ${YELLOW}${SECRET}${NC}"
    echo "   Длина: ${#SECRET} символов"
fi

# Проверяем, свободен ли порт
echo -n -e "🔍 Проверка порта ${PORT}... "
if ss -tuln | grep -q ":${PORT} "; then
    echo -e "${YELLOW}порт занят${NC}"
    for alt_port in 8443 8444 8445; do
        if ! ss -tuln | grep -q ":${alt_port} "; then
            PORT=$alt_port
            echo "   Используем порт: ${PORT}"
            break
        fi
    done
else
    echo -e "${GREEN}свободен${NC}"
fi

# Останавливаем старый контейнер, если есть
echo -n -e "🛑 Остановка старого контейнера... "
sudo docker stop ${CONTAINER_NAME} >/dev/null 2>&1
sudo docker rm ${CONTAINER_NAME} >/dev/null 2>&1
echo -e "${GREEN}готово${NC}"

# Формируем команду запуска
echo -n -e "📦 Запуск контейнера... "
DOCKER_ARGS="-d --name ${CONTAINER_NAME} --restart unless-stopped -p ${PORT}:443 -e SECRET=${SECRET}"

if [ -n "$TAG" ]; then
    DOCKER_ARGS="${DOCKER_ARGS} -e TAG=${TAG}"
    echo -e "\n   📢 Тег канала: ${BLUE}${TAG}${NC}"
fi

sudo docker run ${DOCKER_ARGS} telegrammessenger/proxy > /dev/null 2>&1

# Проверяем результат
sleep 3
if sudo docker ps | grep -q ${CONTAINER_NAME}; then
    SERVER_IP=$(curl -s ifconfig.me)

    echo -e "${GREEN}✅ УСПЕШНО${NC}"
    echo ""
    echo "📊 ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Сервер: ${SERVER_IP}"
    echo "🔌 Порт: ${PORT}"
    echo "🔑 Секрет: ${SECRET}"
    echo "🌐 Fake TLS домен: ${FAKE_DOMAIN}"
    [ -n "$TAG" ] && echo "📢 Тег канала: ${TAG}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "🔗 Ссылка для Telegram (нажмите для автоподключения):"
    echo -e "${GREEN}tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Сохраняем конфигурацию
    cat > ~/mtproto_config.txt << EOF
SERVER=${SERVER_IP}
PORT=${PORT}
SECRET=${SECRET}
DOMAIN=${FAKE_DOMAIN}
TAG=${TAG}
LINK=tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}
EOF
    echo "✅ Конфигурация сохранена в ~/mtproto_config.txt"

    # Показываем последние логи
    echo ""
    echo "📋 Логи контейнера:"
    sudo docker logs --tail 5 ${CONTAINER_NAME}
else
    echo -e "${RED}❌ ОШИБКА${NC}"
    sudo docker logs ${CONTAINER_NAME}
fi
