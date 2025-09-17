<div align="center">

![Ruby](https://img.shields.io/badge/Ruby-3.2.2-red)
![Rails](https://img.shields.io/badge/Rails-7.2.2-brightgreen)
[![CI](https://github.com/AndPewka/rails-project-66/actions/workflows/ci.yml/badge.svg)](https://github.com/AndPewka/rails-project-66/actions)

# Github Quality (Hexlet Project 66)
</div>

> Учебное Rails-приложение: интеграция с **GitHub**, добавление репозиториев, запуск проверок кода (**RuboCop**, **ESLint**) с отчётами и вебхуками.  
> Используются: **OmniAuth GitHub**, **Octokit**, **dry-container**, **AASM**, **Bootstrap 5**, **Sentry**, CI на **GitHub Actions**, деплой на **Render**.

---

## 🚀 Демо
`https://rails-project-64-pmc8.onrender.com/`

---

## ✨ Функционал
- Вход через **GitHub OAuth** (OmniAuth), сохранение токена пользователя.
- Модель **User**: `email*`, `nickname`, `token`.
- Модель **Repository**: `name`, `github_id`, `full_name`, `language`, `clone_url`, `ssh_url`, `user_id`.
- Проверки репозитория (**Repository::Check**) на конкретном коммите `commit_id`:
  - **RuboCop** (Ruby), **ESLint** (JS); запуск внешних процессов через `Open3`.
  - Состояния (AASM): `queued` → `running` → `passed` / `failed`.
  - Просмотр списка проверок и деталей отчёта.
- **Webhooks**: `POST /api/checks` — автоматический запуск проверки по push.
- DI через **dry-container** + застабы клиентов (Octokit, линтеры) в тестах.
- Интерфейс на **Bootstrap 5** (только стандартные компоненты).

---

## 🛠 Стек
| Слой | Выбор |
|---|---|
| Backend | Ruby **3.2.2**, Rails **7.2.2** |
| DB (prod) | PostgreSQL (Render free) |
| DB (dev/test) | SQLite3 |
| Auth | OmniAuth GitHub |
| GitHub API | Octokit |
| Проверки | RuboCop, ESLint (`--no-eslintrc`, свой конфиг проекта) |
| FSM | AASM |
| DI | dry-container |
| Ошибки | Sentry |
| CSS | Bootstrap 5 |
| CI/CD | GitHub Actions → Render |

---

## ⚡ Быстрый старт локально
Требования: Ruby 3.2.2, Node ≥ 18, Yarn/npm, SQLite3

```bash
git clone https://github.com/AndPewka/rails-project-66.git
cd rails-project-66

bundle install
yarn install --frozen-lockfile

cp .env.example .env
# Заполните переменные (см. ниже)

bundle exec rails db:setup
bundle exec rails assets:precompile

bundle exec rails s
# → http://localhost:3000
