# AmneziaWG — обфусцированный WireGuard как fallback

Этот каталог — **опциональный** компонент. Поднимать только если основной XRay/Reality-канал не подходит (например, нужен UDP-протокол с поддержкой клиентов AmneziaVPN).

Используется контейнер [awg-easy](https://github.com/w1k1n9cc/awg-easy) — форк wg-easy с поддержкой обфускации AmneziaWG (параметры Jc/Jmin/Jmax/S1/S2/H1–H4 генерируются автоматически).

## Установка

Сначала разверните основной стек (см. корневой `README.md`), затем:

```bash
sudo bash amneziawg/setup-awg.sh
```

Скрипт:

1. Выставит `ALLOW_AMNEZIAWG=true` в корневом `.env` и откроет UDP-порт в UFW.
2. Сгенерирует `amneziawg/.env` (пароль админ-панели, публичный IP, порт).
3. Запустит контейнер `awg-easy`.
4. Распечатает учётные данные и команду для SSH-туннеля к админ-UI.

## Доступ к админ-панели

Веб-интерфейс намеренно слушает только `127.0.0.1`. Открываем SSH-туннель:

```bash
ssh -L 51821:127.0.0.1:51821 user@<VPS_IP>
```

И открываем `http://127.0.0.1:51821/` в браузере.

## Клиенты

Клиенты AmneziaVPN (Android/iOS/desktop) или любые WireGuard-совместимые с поддержкой AmneziaWG-параметров.

## Удалить

```bash
cd amneziawg && sudo docker compose down
sudo sed -i 's|^ALLOW_AMNEZIAWG=.*|ALLOW_AMNEZIAWG=false|' ../.env
sudo bash ../ufw/rules.sh
```
