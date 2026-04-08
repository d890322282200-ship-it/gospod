# Self-hosted AI coding assistant + n8n GitHub automation (Ubuntu 24.04, headless)

Ниже — готовый минимально-безопасный набор для запуска **бесплатного** self-hosted стека:
- локальный LLM через **Ollama** (только `127.0.0.1:11434`),
- CLI-агент для правок кода через **aider**,
- оркестрация GitHub Issue → ветка → коммит → PR через **n8n** (Docker Compose),
- доступ из VS Code/Continue или Antigravity по **SSH tunnel** без GUI на сервере.

> По умолчанию выбран подход: **n8n в Docker Compose**, а `git`/`aider` запускаются в отдельном shell step внутри n8n-контейнера (с примонтированными директориями и установленными утилитами). Это лучше по изоляции и повторяемости, чем “всё на хосте”, и проще бэкапить/обновлять.

---

## 1) Архитектура (кратко)

1. `ollama` как systemd-сервис на хосте, bind `127.0.0.1:11434`.
2. `aider` в Python venv (`/opt/aider-venv`) + wrapper `aider-ollama`.
3. `n8n` в Docker Compose (`n8n/docker-compose.yml`) с volume для данных.
4. n8n workflow получает Issue (manual trigger / webhook), готовит branch, вызывает `aider`, гоняет тесты, push и открывает PR через GitHub API.
5. Все репозитории для автоправок в `/srv/ai/repos`.
6. Секреты (`GITHUB_TOKEN` и т.п.) в env-файле (не коммитить реальные токены).
7. Внешний доступ к Ollama только через `ssh -L 11434:127.0.0.1:11434`.
8. Для слабого сервера: swap + маленькая модель (1–2GB class).
9. Для будущего GPU-сервера: ставим NVIDIA драйвер, переключаем модель на более сильную code model.

---

## 2) Структура проекта

```text
.
├── README.md
├── config/
│   └── example.env
├── scripts/
│   ├── 00_base.sh
│   ├── 01_swap_optional.sh
│   ├── 02_install_ollama.sh
│   ├── 03_pull_models.sh
│   ├── 04_install_aider.sh
│   └── 10_gpu_setup_future.sh
└── n8n/
    ├── docker-compose.yml
    └── workflows/
        └── github_issue_to_pr.json
```

---

## 3) Быстрый старт

### 3.1 Клонирование и env

```bash
git clone <this-repo-url> ai-stack
cd ai-stack
cp config/example.env .env
# Отредактируй .env: GITHUB_TOKEN, REPO_URL, OWNER, REPO_NAME и т.д.
```

### 3.2 База + (опц.) swap + Ollama + модели + aider

```bash
sudo bash scripts/00_base.sh
# На 2GB RAM рекомендуется:
sudo bash scripts/01_swap_optional.sh
sudo bash scripts/02_install_ollama.sh
sudo --preserve-env=SMALL_MODEL,MAIN_MODEL bash scripts/03_pull_models.sh
sudo bash scripts/04_install_aider.sh
```

Проверки:

```bash
systemctl status ollama --no-pager
curl -fsS http://127.0.0.1:11434/api/tags | jq .
aider-ollama --version
```

### 3.3 Поднять n8n (Docker Compose)

```bash
cd n8n
cp ../.env ./.env
docker compose up -d

docker compose ps
docker compose logs -f n8n
```

Открыть UI n8n через SSH-туннель:

```bash
ssh -L 5678:127.0.0.1:5678 aiops@<server_ip>
# Затем локально: http://127.0.0.1:5678
```

Импортируй workflow из `n8n/workflows/github_issue_to_pr.json`.

---

## 4) Подключение Continue (VS Code) через SSH tunnel

На локальной машине:

```bash
ssh -N -L 11434:127.0.0.1:11434 aiops@<server_ip>
```

Пример провайдера в Continue (локально в VS Code settings):

```json
{
  "models": [
    {
      "title": "Ollama-Remote-Coder",
      "provider": "ollama",
      "model": "qwen2.5-coder:1.5b",
      "apiBase": "http://127.0.0.1:11434"
    }
  ]
}
```

Проверка:

```bash
curl -fsS http://127.0.0.1:11434/api/tags
```

---

## 5) n8n workflow: GitHub issue → PR

Ожидаемый flow:

1. Trigger (Manual / Webhook / Cron).
2. GitHub API: получить issue body/title.
3. `Execute Command`: clone repo в `/srv/ai/repos/...`.
4. Создать ветку `BRANCH_PREFIX/issue-<id>-<timestamp>`.
5. Вызвать `aider-ollama` с промптом из issue.
6. Запустить тесты (`TEST_CMD`, например `pytest -q` или `npm test -- --ci`).
7. Commit + push.
8. GitHub API: создать PR.

Секреты в n8n credentials/env: `GITHUB_TOKEN`.

---

## 6) Безопасность

- Ollama слушает только localhost (`127.0.0.1:11434`).
- Доступ к модели снаружи — только через SSH tunnel.
- `GITHUB_TOKEN` должен иметь минимальные права: `repo` (или granular permissions на конкретный репозиторий).
- Не хранить реальные секреты в git.

### Опционально: reverse proxy + auth (не default)

Если нужен доступ без SSH tunnel:
- ставь Nginx/Caddy перед Ollama,
- включай Basic Auth + IP allowlist + TLS,
- ограничивай rate limit.

Но рекомендуемый default для headless сервера: **SSH tunnel only**.

---

## 7) Как запускать это на слабом сервере 2GB RAM

1. Включи swap: `sudo bash scripts/01_swap_optional.sh`.
2. Используй только маленькую модель, например:
   - `qwen2.5-coder:1.5b` (приоритет),
   - альтернатива: `deepseek-coder:1.3b` (если доступна в Ollama library).
3. В `.env`:
   - `MODEL=qwen2.5-coder:1.5b`
   - уменьшай параллелизм в n8n и тестах.
4. Ожидай высокую latency (ответ может занимать десятки секунд/минуты).
5. Не держи одновременно тяжёлые CI-джобы и генерацию кода.

---

## 8) Как перейти на новый сервер с GPU 22GB

1. Выполни: `sudo bash scripts/10_gpu_setup_future.sh`.
2. Проверь:

```bash
nvidia-smi
```

3. Подтяни более сильную модель:

```bash
export MAIN_MODEL="qwen2.5-coder:14b"
sudo --preserve-env=SMALL_MODEL,MAIN_MODEL bash scripts/03_pull_models.sh
```

4. Переключи `.env`:

```env
MODEL=qwen2.5-coder:14b
```

5. Перезапусти n8n (если нужно):

```bash
cd n8n && docker compose restart
```

Рекомендованные модели для 22GB VRAM:
- `qwen2.5-coder:14b` (практичный баланс качества/скорости),
- `qwen2.5-coder:32b` (лучше качество, но может требовать квант и аккуратные лимиты RAM/VRAM).

Проверка, что Ollama использует GPU:
- во время инференса смотри `nvidia-smi` (должен расти memory usage/process),
- в `journalctl -u ollama -f` проверь логи загрузки backend.

---

## 9) Troubleshooting

### Ollama не стартует

```bash
systemctl status ollama --no-pager
journalctl -u ollama -n 100 --no-pager
```

Проверь override:

```bash
systemctl cat ollama
```

### Порт 11434 недоступен

```bash
ss -ltnp | grep 11434 || true
curl -v http://127.0.0.1:11434/api/version
```

### n8n не видит git/aider

- В compose уже ставятся `git`, `python3-venv`, `pipx`, `jq`, `curl`.
- Проверка внутри контейнера:

```bash
cd n8n
docker compose exec n8n bash -lc 'git --version && python3 --version && aider --version || true'
```

### PR не создаётся

Проверь права токена и API endpoint:

```bash
curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user
```

---

## 10) Рекомендуемый порядок выполнения на чистом сервере

```bash
sudo bash scripts/00_base.sh
sudo bash scripts/01_swap_optional.sh
sudo bash scripts/02_install_ollama.sh
sudo --preserve-env=SMALL_MODEL,MAIN_MODEL bash scripts/03_pull_models.sh
sudo bash scripts/04_install_aider.sh

cp config/example.env .env
# edit .env
cd n8n && cp ../.env ./.env && docker compose up -d
```

Готово: дальше импорт workflow и запуск manual trigger в n8n.
