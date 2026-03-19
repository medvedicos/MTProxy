# MTProxy

Установка MTProto прокси для Telegram одной командой. Docker-контейнер с поддержкой Fake TLS.

## Установка

```bash
curl -sL https://raw.githubusercontent.com/medvedicos/MTProxy/main/install.sh | sudo bash
```

## Что делает скрипт

- Устанавливает Docker (если не установлен)
- Генерирует секрет с Fake TLS (маскировка трафика под обычный HTTPS к ya.ru)
- Находит свободный порт (443 → 8443 → 8444 → 8445)
- Запускает официальный контейнер `telegrammessenger/proxy`
- Выводит готовую ссылку `tg://proxy?...` для подключения
- Сохраняет конфигурацию в `~/mtproto_config.txt`

## Требования

- Ubuntu 20.04 / 22.04 / 24.04
- Минимум 512 MB RAM, 5 GB диск
- Root-доступ

## Управление

```bash
# Статус
sudo docker ps

# Логи
sudo docker logs mtproto-proxy

# Перезапуск
sudo docker restart mtproto-proxy

# Остановка
sudo docker stop mtproto-proxy

# Удаление
sudo docker rm -f mtproto-proxy
```

## Подключение

После установки скрипт выведет ссылку вида:

```
tg://proxy?server=IP&port=PORT&secret=SECRET
```

Откройте её на устройстве с Telegram — прокси подключится автоматически. Или добавьте вручную: **Настройки → Данные и память → Прокси → Добавить прокси**.
