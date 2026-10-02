# 🚲 Slow Cycle

STATUS: CURRENT

Slow Cycle — процедурное велосипедное путешествие по красивым неизвестным природным регионам: удовольствие от езды, свобода направления, исследование и созерцание. **WORLD FIRST → ROUTE SECOND → ROAD THIRD.**

## Статус

D0 — Documentation Authority Reset завершён; [план и отчёт](docs/plans/completed/D0.md). Код игры не менялся. Существующий runtime по-прежнему road-first: дорожная геометрия, развилки, придорожные полосы/декор. Полный region-first pipeline, off-road world surface, river/landmark gameplay ещё не реализованы. Предыдущая общая runtime acceptance INCOMPLETE; D0 её не закрывает.

Новая цель — [Target Blueprint](docs/TARGET_GAME_BLUEPRINT.md), порядок migration — [Master Plan](docs/MASTER_IMPLEMENTATION_PLAN.md). Код/старые тесты задают safe migration, а не новую product architecture. Следующая допустимая работа — подготовка D1 с отдельным plan/approval; она сейчас не начата.

## Документация

| Источник | Назначение |
|---|---|
| [docs index](docs/README.md) | Единая authority map и порядок чтения |
| [Blueprint](docs/TARGET_GAME_BLUEPRINT.md) / [Master](docs/MASTER_IMPLEMENTATION_PLAN.md) | Продукт / стратегия и фазы |
| [Target architecture](docs/TARGET_ARCHITECTURE.md) / [migration matrix](docs/LEGACY_MIGRATION_MATRIX.md) | Будущие owners / KEEP, ADAPT, REPLACE и retirement gates |
| [Current state](docs/CURRENT_PROJECT_STATE.md) / [ARCHITECTURE](ARCHITECTURE.md) | Факты/limitations / as-is runtime |
| [Test strategy](docs/TEST_STRATEGY.md) | Evidence и future authority map, без D0 suite reclassification |
| [AGENTS](AGENTS.md) / [plan slot](implementation_plan.md) | Рабочие ограничения / один approved task |
| [Vision summary](VISION.md) | Краткое производное Blueprint |
| [Audit](docs/DOCUMENTATION_AUDIT.md) / [history](docs/history/README.md) | Статусы, конфликты, сохранённая техника и reports |

Исторические спринты и прежняя README navigation сохранены в [snapshot](docs/history/README_PRE_D0.md). Их числа/PASS не являются сегодняшним подтверждением всех маршрутов или готовности нового slice.

## 🚀 Как запустить игру

1. Открой **Godot 4** со своего ярлыка на Рабочем столе.
2. Нажми **«Импорт» (Import)** $\rightarrow$ выбери папку проекта (содержащую файл `project.godot`).
3. Нажми **«Импортировать и редактировать» (Import & Edit)**.
4. Нажми клавишу **F5** (или значок ▶️ Play в правом верхнем углу).

### Управление в игре:
- **`W` / `↑`** или **Геймпад `RT`** — Спокойный круиз (мускульный набор и автоматическое удержание 25 км/ч).
- **`Shift`** или **Геймпад `X`** — Аркадный спринт педалями (ритмичное ускорение до 44 км/ч с убывающей отдачей).
- **Отпустить `W` / `Shift`** — Свободный накат под горку (разгон силой тяжести со стрёкотом трещотки).
- **`A` / `D` / `←` / `→`** или **Левый стик** — Отзывчивое руление с упругим наклоном байка в вираж и авто-возвратом трейла.
- **`S` / `↓`** или **Геймпад `LT`** — Прогрессивный тормоз с визуальным клевком вилки.
- **`Пробел`** или **Геймпад `A`** — Велосипедный звоночек на руле 🔔.
- **`V`** или **Геймпад `Y`** — Переключить вид (1-е лицо от руля / 3-е лицо со спины).
- **`R`** или **Геймпад `Back` / `Select`** — Мягкое возвращение на центр дороги с затемнением экрана.
- **`H`** — Скрыть / показать панель подсказок управления внизу экрана.
- **`F3`** — Включение / выключение оверлея телеметрии разработчика.
- **`F4`** — Сохранение мгновенного снапшота телеметрии заезда в `user://playtest_snapshots.json`.
- **Аргумент командной строки**: `--seed=XXXXX` для запуска с произвольным сидом генерации.
