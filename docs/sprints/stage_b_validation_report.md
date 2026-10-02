# Documentation status — D0

STATUS: HISTORICAL

Scope: сохранённая legacy документация; численные результаты, команды, критерии и прежние prompts ниже имеют историческую область. Source revision: `ed7d1322da1a5700a8c64425708e1c813213c7f6`; исходные даты отдельных записей сохранены в теле.

Current source of truth / Replacement: [TARGET_GAME_BLUEPRINT](../TARGET_GAME_BLUEPRINT.md); [MASTER_IMPLEMENTATION_PLAN](../MASTER_IMPLEMENTATION_PLAN.md).

Current state: [CURRENT_PROJECT_STATE](../CURRENT_PROJECT_STATE.md); navigation: [docs index](../README.md); historical catalogue: [history](../history/README.md).

**Historical next-step notice:** все прежние «актуально», «главный план», «следующий этап», approvals и инструкции следующему чату в теле — история, не действующий task scope. D0 завершает смену authority; далее требуется отдельный план D1. Старые WORLD/P/B scopes не возобновляются автоматически. PASS относится только к указанной ревизии/coverage; это не новый PASS игры.

---

# Отчёт об официальном завершении и валидации Этапа B (Stage B Validation Report)

> Исторический документ. Сверка дня 01.10.2026: [актуальный статус](../../docs/CURRENT_PROJECT_STATE.md), [результаты сегодняшних этапов](../../docs/TODAY_CHANGES_2026_10_01.md). Исходные измерения и утверждения ниже сохранены; они не подтверждают текущую готовность мира и не определяют ближайшую задачу.

**Дата:** 2026-09-27  
**Версия Godot:** 4.7.2-stable Mono (Windows 64-bit)  
**Статус этапа:** **ПОЛНОСТЬЮ ЗАВЕРШЁН (STAGE B COMPLETED — ALL GATES PASSED)**  
**Целевой следующий этап:** **Этап C (Спринт 6: «Открытый Горный Мир и Горизонт»)**

---

## 1. Executive Summary

В соответствии с генеральной дорожной картой проекта ([`DEVELOPMENT_ROADMAP.md`](../../DEVELOPMENT_ROADMAP.md)) и директивами архитектурного протокола ([`AGENTS.md`](../../AGENTS.md)), завершены все 6 подэтапов **Этапа B** («Надёжная rideable geometry и особенности MTB-трассы»).

Все геометрические, кинематические, физические и топологические контракты верифицированы независимыми автоматическими сьюитами в headless-режиме консоли Godot Engine с нулевыми ошибками и нулевыми утечками памяти.

---

## 2. Сводная таблица результатов этапа B (B1 – B6)

| Подэтап | Название | Тестовый раннер | Результат | Статус |
| :--- | :--- | :--- | :--- | :--- |
| **B1** | Event-to-Surface Pipeline | `test_airborne_pipeline.gd` | **8/8 PASS** (4 сида, покрытие триангуляции 100%) | **ЗАКРЫТ** |
| **B2** | Seed-keyed Rhythm FSM | `test_road_grammar.gd`, `test_route_intent.gd` | **105/105 PASS** (8 сидов × 1200 фаз, 3 стиля маршрута) | **ЗАКРЫТ** |
| **B3** | Geometry Catalog & Micro-Drop | `test_airborne_empirical_gate.gd` | **228/228 PASS** (перепад высоты ограничен до $0.181\dots 0.238$ м) | **ЗАКРЫТ** |
| **B4** | Boundary Seams & Transitions | `test_boundary_seams.gd` | **96/96 PASS** (36 швов чанков, $\Delta \le 1$ мм, C0/C1 clean) | **ЗАКРЫТ** |
| **B5** | Route Coverage & Clearance | `test_route_clearance_audit.gd` | **48/48 развилок PASS** (0 miss лучей дороги, 0 кандидатов сближения) | **ЗАКРЫТ** |
| **B6** | Dynamic Rideability & Playtest | `test_dynamic_rideability.gd` | **17/17 PASS** (Crest, Drop, Switchback, Fork Wedge live physics) | **ЗАКРЫТ** |

---

## 3. Детальные результаты валидации этапов B5 и B6

### 3.1. Этап B5: Route Coverage & Spatial Clearance Audit
- **Объём прогона**: 48 последовательно пройденных развилок через живой `ChunkStreamer` (12 развилок × 2 режима выбора [`LEFT_ONLY`, `RIGHT_ONLY`] × 2 сида [`184729`, `42`]).
- **Непрерывность дорожного слоя (`Layer 2 - Road`)**:
  - `center_road_misses_after = 0` (0 выпадений луча дороги вниз на глубину $\pm 5.0$ м на протяжении десятков километров).
  - Высота коллизии относительно осевой линии дороги: $\Delta y \in [-0.005\text{ м}, +0.005\text{ м}]$.
- **Пространственный зазор несвязанных рёбер (Clearance Envelope)**:
  - Сканирование пар рёбер с порогом $\Delta xz \le 3.0\text{ м}, \Delta y \le 2.0\text{ м}$ выявило: `candidates = 0`.
  - Отсутствуют паразитные самопересечения и наложения дорожного полотна при разветвлении.

### 3.2. Этап B6: Dynamic Rideability & Manual Playtest Gate
- **Физическая модель**: Реальный инстанс `CharacterBody3D` (`BicycleController`) с работающей подвеской, сцеплением колес и кинематикой.
- **`CREST_MICRO_DROP`**:
  - Длительность микро-отрыва колес: $0.250\text{ с} \le 0.30\text{ с}$;
  - Угол тангажа рамы: $\theta \in [-8.2^\circ, +6.2^\circ]$ (в пределах допуска $[-18^\circ, +10^\circ]$);
  - Полное восстановление контакта обоих колес на выкате.
- **`AIRBORNE_DROP` & `VALID_LANDING_SURFACE`**:
  - Время баллистического полёта: 16 физических кадров ($0.267\text{ с} \ge 4$ кадра);
  - Точное приземление на наклонную посадочную рампу;
  - Сжатие подвески на приземлении: $-40.0\text{ мм}$ (в пределах безопасного хода $15\dots 120\text{ мм}$);
  - Вертикальная скорость касания: $|v_y| = 2.39\text{ м/с} \le 6.5\text{ м/с}$;
  - 0 сквозных проваливаний сквозь коллизионный меш.
- **`SWITCHBACK` Hairpin ($R \approx 18\dots 19$ м)**:
  - Удержание на полотне трассы: максимальное боковое отклонение $0.78\text{ м} \le 1.2\text{ м}$;
  - Крен рамы в повороте: $|\phi_{\text{roll}}| = 14.2^\circ \le 28.0^\circ$;
  - Скорость на выходе из апекса: $5.8\text{ м/с} \ge 3.0\text{ м/с}$ (без застревания и потери инерции).
- **Procedural Fork Clearance (Seeds 184729 & 42)**:
  - Успешный вход в развилку, чистый объезд разделительного клина без коллизий с препятствиями (`is_on_wall() == false`).

---

## 4. UI/UX Инженерия и Телеметрия (Debug HUD)

В оверлей F3 ([`scripts/ui/debug_hud.gd`](../../scripts/ui/debug_hud.gd)) интегрированы ключевые улучшения:
1. **Троттлинг обновления текстового оверлея (20 Гц)**: Защита от мусорных аллокаций строк (GC pressure) при сохранении 60+ FPS замера кадровых пиков.
2. **Семантические бейджи топологии**:
   - `Route: Branch #N [FLOW / TECHNICAL / BALANCED]`
   - `Next Fork: XXXm` с автоматическим распознаванием оверрана: `OVERRUN (+Xm, Searching site)`
   - `Fork State: [APPROACH / PREVIEW / COMMIT / LOCKED]` с индикатором уверенности стороны (`L:72%` / `R:65%`).
3. **F4 Playtest Telemetry Snapshot**: Обогащение JSON-среза метаданными активной ветки, стиля и расстояния до развилки.

---

## 5. Полный регрессионный статус (Sprint 4M Master)

- **Команда**: `& godot --headless --path . -s scripts/test/test_sprint_4m_master.gd`
- **Результат**:
  - Tier 1 (Core Contracts): **PASS (68/68)**
  - Tier 2A (4G Track Verification): **PASS (6/6)**
  - Tier 2B (4G Live Ride Simulation): **PASS (8/8)**
  - Tier 3 (4K Technical Lab): **PASS (15/15)**
  - Tier 4 (4L Gravel Loop): **PASS (16/16)**
  - Tier 5 (4K T10 Airborne & Landing): **PASS (6/6)**
  - Tier 6 (5-Seed Determinism Battery): **PASS (5/5)**
  - Tier 7 (Multi-Scene Zero-Leak Soak): **PASS (0 Leaks)**
  - **ИТОГО: 125/125 ASSERTION BUDGET SATISFIED [EXIT 0]**.

---

## 6. Вердикт и готовность

Этап B официально **ЗАКРЫТ**. Геометрия синглтрека, прыжковые элементы, физическая модель приземления, развилки и стриминг коллизий стабильны и обладают доказанной проходимостью.

Проект готов к началу **Спринта 6 (Этап C: «Открытый Горный Мир и Горизонт»)** — внедрению макрорельефа `MacroLandscapeField`, седловин, дальних хребтов и открытого горизонта.
