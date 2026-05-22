# myVSP — личный VPN на XRay (VLESS + Reality) c 3X-UI

Развёртывание персонального VPN-сервера на чистой Ubuntu-VPS в три команды.

- **Основной протокол:** XRay-core, VLESS + Reality — трафик маскируется под легитимный HTTPS к чужому SNI (`www.microsoft.com` по умолчанию). Устойчив к DPI; домен и сертификат **не требуются**.
- **Панель управления:** [3X-UI](https://github.com/MHSanaei/3x-ui) (Docker, host networking).
- **Опциональный fallback:** [AmneziaWG](amneziawg/README.md) — обфусцированный WireGuard.

## Требования

- VPS с Ubuntu **22.04 LTS или 24.04 LTS**, root/sudo.
- Открытый порт SSH (по умолчанию 22) для управления.
- Свободный TCP/443 на сервере (его займёт XRay/Reality).

## Быстрый старт

```bash
git clone <repo-url> /opt/myvsp
cd /opt/myvsp

sudo bash scripts/install.sh        # ставит Docker, UFW, fail2ban, BBR
sudo bash scripts/setup-3xui.sh     # поднимает 3X-UI и печатает учётку (один раз)
```

После завершения скрипт выведет URL панели, логин и пароль, а также сохранит их в `db/CREDENTIALS.txt` (chmod 600, добавлен в `.gitignore`).

## Первый вход в панель

1. Откройте напечатанный URL — `http://<IP>:<PANEL_PORT><PANEL_PATH>/` (со слэшем в конце).
2. Войдите.
3. **Сразу смените пароль через UI** (Settings → Security).

## Создание первого инбаунда VLESS + Reality

В панели: **Inbounds → Add Inbound**.

| Поле                 | Значение                                    |
|----------------------|---------------------------------------------|
| Remark               | любое имя, напр. `home-reality`             |
| Protocol             | `vless`                                     |
| Listening IP         | пусто (= `0.0.0.0`)                         |
| Port                 | `443`                                       |
| Security             | `reality`                                   |
| Dest                 | `www.microsoft.com:443`                     |
| Server Names         | `www.microsoft.com`                         |
| Private / Public key | нажать **Get New Cert** (3X-UI создаст X25519) |
| Short ID             | оставить дефолт (или сгенерировать)         |
| Client               | добавить клиента, скопировать UUID          |

После сохранения нажмите **QR Code** возле клиента и отсканируйте его клиентом:

- iOS / Android: **v2RayTun**, **Hiddify**, **Streisand**, **NekoBox**.
- Windows / macOS / Linux: **Hiddify Next**, **NekoRay**, **v2rayN**.

## Проверка работы

```bash
# Контейнер
docker ps                                       # 3x-ui должен быть Up
docker compose logs --tail=50 3x-ui

# Файрвол и ядро
sudo ufw status verbose                         # default deny in; allow 22, 443, 2053
sysctl net.ipv4.tcp_congestion_control          # bbr
sysctl net.ipv4.ip_forward                      # 1

# Панель локально
curl -sI "http://127.0.0.1:${PANEL_PORT}${PANEL_PATH}/" | head -1   # 200 OK

# XRay-конфиг (после создания инбаунда)
docker exec 3x-ui xray -test -config /etc/x-ui/bin/config.json     # Configuration OK
ss -tlnp | grep :443                            # xray слушает 443

# Reality SNI достижим с VPS
curl -sI https://www.microsoft.com | head -1    # HTTP/2 200

# Из подключённого клиента
curl ifconfig.io                                # должен вернуть IP вашего VPS
```

## Безопасность — что сделать после установки

1. **Сменить пароль панели** через UI (не оставлять автогенерированный надолго).
2. **Отключить парольный SSH** (только ключи):
   ```bash
   sudo bash scripts/harden-ssh.sh
   ```
   Скрипт потребует подтверждения. Не запускайте, пока не убедились, что SSH-ключ работает.
3. **Ограничить доступ к панели по IP** (если у вас статический IP админа):
   ```bash
   sudo ufw delete allow 2053/tcp
   sudo ufw allow from <YOUR_ADMIN_IP> to any port 2053 proto tcp
   ```
4. Резервные копии:
   ```bash
   sudo tar czf myvsp-backup-$(date +%F).tgz db/ .env
   ```

## AmneziaWG (опционально)

См. [amneziawg/README.md](amneziawg/README.md).

```bash
sudo bash amneziawg/setup-awg.sh
```

## Troubleshooting

**Панель не открывается**
- Проверьте `PANEL_PATH` со слэшем в начале: URL должен быть `http://<IP>:2053/<PATH>/`.
- `curl -v http://127.0.0.1:2053/<PATH>/` с самого VPS — что отвечает?
- `docker compose logs 3x-ui`.

**Клиент не подключается через Reality**
- `docker exec 3x-ui xray -test -config /etc/x-ui/bin/config.json` — конфиг валиден?
- `ss -tlnp | grep :443` — XRay слушает 443? Если порт занят чем-то ещё — `sudo fuser 443/tcp`.
- SNI достижим с VPS? `openssl s_client -connect www.microsoft.com:443 -servername www.microsoft.com </dev/null`
- В клиенте: `Public key` и `Short ID` совпадают с панелью, время на устройстве синхронизировано.

**После `ufw enable` потеряли SSH**
- Скрипты всегда добавляют SSH-правило до включения UFW. Если это всё-таки случилось — войдите через консоль провайдера и выполните `ufw allow 22/tcp && ufw reload`.

**BBR не включился**
- `sudo modprobe tcp_bbr && sudo sysctl --system`
- На совсем старых ядрах (<4.9) BBR недоступен; на Ubuntu 22.04/24.04 он есть всегда.

## Файлы и каталоги

```
myVSP/
├── docker-compose.yml          # 3X-UI (network_mode: host)
├── .env.example                # шаблон настроек
├── scripts/
│   ├── install.sh              # bootstrap VPS
│   ├── setup-3xui.sh           # поднимает панель, генерирует учётку
│   ├── harden-ssh.sh           # отключает парольный SSH (опционально)
│   ├── uninstall.sh            # снос
│   └── lib/common.sh           # хелперы
├── sysctl/99-vpn-tuning.conf   # BBR, ip_forward, лимиты
├── ufw/rules.sh                # настройка файрвола
├── fail2ban/jail.local         # sshd jail
└── amneziawg/                  # опциональный fallback
```

## Удаление

```bash
sudo bash scripts/uninstall.sh
```

## Дальнейшее усиление (за рамки MVP)

- Reverse-proxy (Caddy / Nginx) перед панелью с TLS.
- Telegram-бот 3X-UI для уведомлений и бэкапов.
- Резервные копии в S3/Backblaze по расписанию.
- Мультихоп / несколько нод с балансировкой.

## Лицензия

Личное использование. Стек состоит из открытых компонентов под их собственными лицензиями (XRay-core — MPL-2.0, 3X-UI — GPL-3.0, awg-easy — MIT).
