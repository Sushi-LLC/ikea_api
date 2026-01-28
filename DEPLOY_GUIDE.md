IKEYA Deployment Guide

Документ описывает, как проверять и настраивать продакшен-инфраструктуру для Rails API (`/api`), админки (`/admin`) и Swagger-документации (`/api-docs`).

---

## 1. Получение доступа

1. Подключитесь к серверу и перейдите в директорию развёртывания:
```bash
ssh root@45.135.234.22
cd ~/apps/ikea_front
```
2. Базовые команды:
- `docker compose up -d --build`
- `docker compose down`
- `docker ps`
- `docker logs -f ikea-api` (или `ikea-front`)

---

## 2. Nginx Proxy Manager (NPM)

Панель: `http://45.135.234.22:81` (логин `admin@example.com`, пароль `changeme`).

### Proxy Host
1. Нажмите **Add Proxy Host**.
2. Domain Names: `45.135.234.22` (или ваш домен).
3. Scheme: `http`.
4. Forward Hostname: `ikea-front`.
5. Forward Port: `3000`.
6. Включите Websocket Support.

### Custom Locations для backend-путей
| Location | Scheme | Forward Hostname | Forward Port | Назначение |
| --- | --- | --- | --- | --- |
| `/api` | `http` | `172.17.0.1` | `3001` | Rails API |
| `/admin` | `http` | `172.17.0.1` | `3001` | Trestle админка |
| `/api-docs` | `http` | `172.17.0.1` | `3001` | Swagger UI |
| `/assets` | `http` | `172.17.0.1` | `3001` | статика Trestle |
| `/images` | `http` | `172.17.0.1` | `3001` | изображения товаров |

> Хост `172.17.0.1` — адрес Docker-хоста. Puma должна прослушивать `0.0.0.0` или `tcp://0.0.0.0:3001`.

---

## 3. Rails production

### Production конфиг
1. Разрешите входящий хост:
```ruby
config.hosts << "45.135.234.22"
```
2. Укажите, что SSL терминируется прокси:
```ruby
config.assume_ssl = true
```
3. Убедитесь, что `config.public-file-server.enabled = true` — админские ассеты должны отдаваться Rails.

### Puma (config/puma.rb)
`bind ENV.fetch("PUMA_BIND", "tcp://0.0.0.0:3001")`

Или установите `PUMA_BIND=tcp://0.0.0.0:3001` перед запуском (`docker-compose`, systemd, Capistrano).

### Важные маршруты
- `/api` — namespace `api/v1`.
- `/admin` — Trestle через `config/initializers/trestle.rb`.
- `/api-docs` — `Rswag::Api` и `Rswag::Ui`.

Проверьте, что `/assets` и `/images` доступны, иначе NPM не сможет отдавать файлы.

---

## 4. Проверка

1. `curl -I https://45.135.234.22/api/up` — проверка API.
2. Протестируйте `https://45.135.234.22/admin`.
3. Откройте `https://45.135.234.22/api-docs`.
4. В логах Rails проверьте `Host` и `X-Forwarded-Proto`.

---

## 5. Обслуживание

### Очистка диска
- `docker system prune -a -f`
- `journalctl --vacuum-time=3d`

### UFW
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 81/tcp
ufw enable
```

---

## 6. CI/CD

1. Пуш в `main` запускает GitHub Actions.
2. Файлы синхронизируются в `/home/deploy/apps/ikea_front`.
3. Workflow создаёт сеть (`ikea-network`) и запускает `docker compose up -d --build`.

Секреты — через GitHub Secrets.
