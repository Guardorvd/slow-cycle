# Project Slow Cycle — Atomic Backlog

## Завершённые спринты

### Спринт 1: Базовая физика и Кокпит (`COMPLETED [x]`)
- `[x] [FEAT-001]` Project Init & Graphics Baseline (`project.godot`, `forest_env.tres`)
- `[x] [FEAT-002]` Bicycle Kinematics & Banking Controller (`scripts/player/bicycle_controller.gd`)
- `[x] [FEAT-003]` First-Person Cockpit & Stabilized Camera (`scenes/player/bicycle.tscn`, `scripts/camera/bike_camera.gd`)
- `[x] [FEAT-004]` Forest Sandbox Test Track (`scenes/test/sandbox.tscn`, Low-Poly деревья, HUD)
- `[x] [FEAT-007.1]` Procedural Audio: Bell Chime & Freewheel Ratchet (`scripts/audio/bike_audio_manager.gd`)

### Спринт 2A: Бесконечная гравийная дорога (`COMPLETED [x]`)
- `[x] [FEAT-005.1]` RoadPathData & Детерминированный генератор ритма с валидатором (`scripts/world/road_path_data.gd`, `scripts/world/road_math.gd`, `scripts/world/road_logic.gd`)
- `[x] [FEAT-005.2]` Chunk Road Geometry & Двухслойная физика (`scripts/world/road_chunk.gd`, `assets/materials/gravel_road.tres`, `assets/shaders/gravel_road.gdshader`)
- `[x] [FEAT-005.3]` Дистанционный стример чанков и shared-ресурсы (`scripts/world/chunk_streamer.gd`, `scripts/world/world_manager.gd`)
- `[x] [FEAT-005.4]` Chunk-Local MultiMesh Foliage (`scripts/world/chunk_foliage.gd`)
- `[x] [FEAT-005.5]` Двухслойное трение и Decoupled Recovery (R) (`scripts/player/bicycle_controller.gd`, `scripts/ui/screen_fader.gd`)
- `[x] [FEAT-005.6]` Developer Debug HUD (F3) (`scripts/ui/debug_hud.gd`, `scenes/ui/debug_hud.tscn`)
- `[x] [SG-001/002/003]` Stability Gate 2A: Real Mesh Seam Tests (0.000m), True Tangent Slopes, Curve Group Continuity, Foliage Height Alignment (`scripts/test/test_diagnostics.gd`, `scripts/world/road_logic.gd`, `scripts/world/chunk_foliage.gd`)

### Спринт 2B: 15 Минут Езды & Тюнинг Комфорта (`COMPLETED [x]`)
- `[x] [FEAT-006.1]` 15-Minute Continuous Ride Soak Test & Rolling Buffer (`scripts/test/test_soak_run.gd`, `scripts/world/road_path_data.gd`, `scripts/world/chunk_streamer.gd`)
- `[x] [FEAT-006.2]` Speed-Sensitive Steering & Weighted Bicycle Dynamics (`scripts/player/bicycle_controller.gd`)
- `[x] [FEAT-006.3]` Horizon Fog & Zero Pop-In Blending (`scenes/environment/forest_env.tres`, `scripts/world/chunk_streamer.gd`)

---

## 🏃 Текущий спринт: Спринт 3A (Тактильность, Звук Ветра и Геймпад)

### `[ ] [FEAT-007.1]` Аналоговое управление геймпадом (Gamepads & Haptics)
- **Goal**: Полная поддержка контроллеров Xbox, DualSense, Switch Pro.
- **Do**: Настройка осей курков (RT/LT) для аналогового газа/тормоза, аналоговый стик с мягкой экспоненциальной чувствительностью, вибрация при выезде на траву.
- **Files**: `project.godot`, `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-007.2]` Процедурный свист ветра от скорости
- **Goal**: Добавить динамический шум ветра, отражающий скорость движения.
- **Do**: В `scripts/audio/bike_audio_manager.gd` синтезировать розовый шум с полосовым фильтром, громкость и частота среза которого управляются сигналом скорости.
- **Files**: `scripts/audio/bike_audio_manager.gd`.

### `[ ] [FEAT-007.3]` Шуршание колес по гравию и траве
- **Goal**: Процедурный звук трения покрышек о гравийную дорогу и мягкий шорох травы на обочине.
- **Files**: `scripts/audio/bike_audio_manager.gd`.

### `[ ] [FEAT-007.4]` Меню настроек комфорта (FOV, Bob, Lean)
- **Goal**: Окно настроек для чувствительных к укачиванию игроков.
- **Do**: Слайдеры регулировки угла обзора (FOV 70–100), интенсивности покачивания камеры (Head Bob 0–100%) и наклона горизонта (Horizon Lean 0–100%).
- **Files**: `scripts/camera/bike_camera.gd`, `scenes/ui/comfort_menu.tscn`.

---

## 📅 Будущий спринт: Спринт 3B (Динамическая Атмосфера и Суточный Цикл)

### `[ ] [FEAT-008.1]` Плавная смена времени суток
- **Goal**: Медленный суточный цикл без резких рывков (рассвет $\rightarrow$ день $\rightarrow$ закат $\rightarrow$ сумерки).
- **Do**: Вращение источника солнца `DirectionalLight3D`, плавный переход градиентов неба и рассеянного освещения.
- **Files**: `scripts/world/day_night_cycle.gd`, `scenes/environment/forest_env.tres`.

### `[ ] [FEAT-008.2]` Лесные атмосферные частицы
- **Goal**: Частицы пыльцы/пылинок в солнечных лучах днем и светлячки в сумерках.
- **Do**: Привязанный к камере `GPUParticles3D` с легким дрейфом в воздухе.
- **Files**: `scenes/environment/ambient_particles.tscn`.

### `[ ] [FEAT-008.3]` Фара велосипеда в сумерках
- **Goal**: Теплый световой луч от фонарика на руле для вечерних поездок.
- **Files**: `scenes/player/bicycle.tscn`.

---

## 📅 Будущий спринт: Спринт 4A (Биомы и Разнообразие Маршрута)

### `[ ] [FEAT-009.1]` Система макро-биомов
- **Goal**: Переключение типа окружения вдоль одной дороги: Лес $\rightarrow$ Открытые цветущие поля $\rightarrow$ Прибрежные скалы.
- **Do**: Модификация генератора растительности и палитры шейдера земли в зависимости от глобального расстояния.
- **Files**: `scripts/world/biome_manager.gd`, `scripts/world/chunk_foliage.gd`.

### `[ ] [FEAT-009.2]` Бесшовный Cross-Fade переход биомов
- **Goal**: Плавное смешивание плотности и типов деревьев на протяжении 200 метров границы биомов.
- **Files**: `scripts/world/road_chunk.gd`.

---

## 📅 Будущий спринт: Спринт 4B (Полировка, Фоторежим и Релиз)

### `[ ] [FEAT-010.1]` Медитативный Фоторежим
- **Goal**: Возможность сделать красивый снимок любимого пейзажа.
- **Do**: Клавиша `P`, скрытие интерфейса, свободный полет камеры, регулировка угла и глубины резкости, кнопка сохранения скриншота.
- **Files**: `scripts/camera/photo_mode.gd`.

### `[ ] [FEAT-010.2]` Меню паузы и выбор сида
- **Goal**: Минималистичное меню по `Esc`: выбор сида мира, регуляторы громкости, выход.
- **Files**: `scenes/ui/pause_menu.tscn`.

### `[ ] [FEAT-010.3]` Standalone Windows сборка (.exe)
- **Goal**: Готовый дистрибутив для игры без необходимости открывать Godot Editor.
- **Do**: Настройка профилей экспорта Windows Desktop (x86_64), иконка, оптимизация размера ассетов.
