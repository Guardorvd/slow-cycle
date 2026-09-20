# Project Slow Cycle — Atomic Backlog

## Завершённые спринты

### Спринт 1: Базовая физика и Кокпит (`COMPLETED [x]`)
- `[x] [FEAT-001]` Project Init & Graphics Baseline (`project.godot`, `forest_env.tres`)
- `[x] [FEAT-002]` Bicycle Kinematics & Banking Controller (`scripts/player/bicycle_controller.gd`)
- `[x] [FEAT-003]` First-Person Cockpit & Stabilized Camera (`scenes/player/bicycle.tscn`, `scripts/camera/bike_camera.gd`)
- `[x] [FEAT-004]` Forest Sandbox Test Track (`scenes/test/sandbox.tscn`, Low-Poly деревья, HUD)
- `[x] [FEAT-005.0]` Procedural Audio: Bell Chime & Freewheel Ratchet (`scripts/audio/bike_audio_manager.gd`)

### Спринт 2A: Бесконечная гравийная дорога (`COMPLETED [x]`)
- `[x] [FEAT-005.1]` RoadPathData & Детерминированный генератор ритма с валидатором (`scripts/world/road_path_data.gd`, `scripts/world/road_math.gd`, `scripts/world/road_logic.gd`)
- `[x] [FEAT-005.2]` Chunk Road Geometry & Двухслойная физика (`scripts/world/road_chunk.gd`, `assets/materials/gravel_road.tres`, `assets/shaders/gravel_road.gdshader`)
- `[x] [FEAT-005.3]` Дистанционный стример чанков и shared-ресурсы (`scripts/world/chunk_streamer.gd`, `scripts/world/world_manager.gd`)
- `[x] [FEAT-005.4]` Chunk-Local MultiMesh Foliage (`scripts/world/chunk_foliage.gd`)
- `[x] [FEAT-005.5]` Двухслойное трение и Decoupled Recovery (R) (`scripts/player/bicycle_controller.gd`, `scripts/ui/screen_fader.gd`)
- `[x] [FEAT-005.6]` Developer Debug HUD (F3) (`scripts/ui/debug_hud.gd`, `scenes/ui/debug_hud.tscn`)
- `[x] [SG-001/002/003]` Stability Gate 2A: Real Mesh Seam Tests, True Tangent Slopes, Foliage Height Alignment

### Спринт 2B: 15 Минут Езды & Тюнинг Комфорта (`COMPLETED [x]`)
- `[x] [FEAT-006.1]` 15-Minute Continuous Ride Soak Test & Rolling Buffer (`scripts/test/test_soak_run.gd`, `scripts/world/road_path_data.gd`, `scripts/world/chunk_streamer.gd`)
- `[x] [FEAT-006.2]` Speed-Sensitive Steering & Weighted Bicycle Dynamics (`scripts/player/bicycle_controller.gd`)
- `[x] [FEAT-006.3]` Horizon Fog & Zero Pop-In Blending (`scenes/environment/forest_env.tres`, `scripts/world/chunk_streamer.gd`)

### Спринт 2C: Cleanup Gate (`COMPLETED [x]`)
- `[x] [FIX-001]` Удаление рудиментарной переменной `current_gear` и 4-го аргумента сигнала (`scripts/player/bicycle_controller.gd`, `scripts/ui/hud.gd`)
- `[x] [FIX-002]` Замена fallback noise на строгий `assert(noise != null)` (`scripts/world/road_chunk.gd`)
- `[x] [FIX-003]` Точная посадка листвы и деревьев через noise в реальных координатах спавна $(X, Z)$ (`scripts/world/chunk_foliage.gd`)
- `[x] [FIX-004]` Актуализация статусов [RESOLVED in 2B/2C] в документации аудита (`TECHNICAL_AUDIT_AND_ROADMAP.md`)

---

## 🚴 Следующий спринт: Спринт 3A (Динамика Велосипеда и Lean-to-Steer ★ КЛЮЧЕВОЙ)

### `[ ] [FEAT-006.4]` Калибровка наката и сопротивлений
- **Goal**: На пологом спуске −2° велосипед катит без педалей, не замедляясь. На ровном — медленно останавливается.
- **Do**: Изменить 3 `@export` значения: `road_rolling_resistance` 0.35 → 0.08, `grass_rolling_resistance` 1.35 → 0.45, `air_drag_coeff` 0.015 → 0.018. Калибровать в Inspector.
- **Do NOT**: Менять структуру `_calculate_forward_dynamics`. Только константы.
- **Acceptance**: Спуск −2° при 20 км/ч: скорость стабильна. Ровная: 20 → 0 за ~15 сек. Трава: ощутимое замедление.
- **Files**: `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-006.5]` Отзывчивый уклон (Asymmetric Pitch Response)
- **Goal**: Велосипед мгновенно «чувствует» начало горки, а не реагирует с задержкой 0.5 сек.
- **Do**: Асимметричный lerp в `_calculate_ground_and_slope()`: `pitch_smoothness = 14` при нарастании уклона, `= 7` при выравнивании.
- **Acceptance**: Въезд на −5° спуск — гравитация подхватывает в первые 0.3 сек.
- **Files**: `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-006.6]` Lean-to-Steer (наклон → руль следует)
- **Goal**: Поворот начинается с наклона тела/рамы, руль доворачивает вслед — как в жизни.
- **Do**: Переработать `_calculate_steering_and_banking()`: Input → target_lean → current_bank (lerp, ~0.25 сек) → current_steer = f(current_bank, speed) (руль следует, ~0.1 сек задержка) → Ackermann yaw rate. Speed-sensitive steering возникает автоматически.
- **Do NOT**: Менять Ackermann-формулу, визуальные трансформы, API/сигналы.
- **Acceptance**: Визуально: рама наклоняется первой, руль догоняет. Ощущается как наклон тела, а не «выкрутил руль».
- **Files**: `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-006.7]` Прогрессивное торможение
- **Goal**: Тормоз нарастает плавно (0 → max за 0.3 сек), а не бьёт мгновенно с первого кадра.
- **Do**: Новая переменная `brake_input` (0→1 за 0.3 сек). Квадратичная кривая усилия. Визуальный pitch forward (+1.7° при полном торможении).
- **Acceptance**: Нажал S на 30 км/ч — сначала мягко, потом сильно. Нос чуть наклоняется вперёд.
- **Files**: `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-006.8]` Инерция педалирования
- **Goal**: Разгон нарастающий, не мгновенный. Ощущение «ноги включились».
- **Do**: Новая переменная `pedal_power` (0→1 за 0.4 сек). `effective_accel = pedal_acceleration * pedal_power`.
- **Acceptance**: С места (0 км/ч) — разгон нарастающий. Отпустил педали — мгновенный переход в накат.
- **Files**: `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-006.9]` Потеря скорости в поворотах (Cornering Scrub)
- **Goal**: На гравии крутые повороты сбрасывают скорость.
- **Do**: `speed -= abs(yaw_turn_rate) * 0.15 * current_speed * delta` после drag-вычислений.
- **Acceptance**: Seed `20202` (извилистый): серия виражей — скорость заметно падает. На прямых — нет.
- **Files**: `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-006.10]` Грунтовая микро-тряска камеры
- **Goal**: Тонкая вибрация камеры от скорости и покрытия, усиливающая ощущение езды.
- **Do**: Perlin-based micro-shake в `bike_camera.gd`, пропорциональный скорости. Удвоенная интенсивность на траве.
- **Do NOT**: Делать тряску заметной. Это подсознательный эффект.
- **Files**: `scripts/camera/bike_camera.gd`.

---

## 🎧 Спринт 3B: Геймпад, Звуковой Ландшафт и Камера

### `[ ] [FEAT-007.1a]` Gamepad Input Mapping
- **Goal**: 8BitDo / Xbox контроллер работает из коробки.
- **Do**: В `project.godot`: RT (ось 5) = газ, LT (ось 4) = тормоз, Left Stick X = руление с экспоненциальной кривой `pow(input, 1.5)`, dead zone 0.15. A = звонок, B = recovery, Y = камера. В `_handle_input()`: определять аналоговое значение осей.
- **Do NOT**: Менять биндинги клавиатуры.
- **Files**: `project.godot`, `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-007.1b]` Gamepad Haptic Feedback
- **Goal**: Тактильная обратная связь при смене покрытия и торможении.
- **Do**: Вибрация при выезде на траву (короткий бумп), лёгкая постоянная тряска на обочине, ощутимый стоп при резком торможении.
- **Files**: `scripts/player/bicycle_controller.gd`.

### `[ ] [FEAT-007.2]` Звуковой ландшафт движения (ветер + шины)
- **Goal**: Ощущение скорости через звук.
- **Do**: В `bike_audio_manager.gd`: ветер (розовый шум, bandpass 200-2000 Hz, громкость от скорости) через уже объявленный `wind_player`. Шины (зернистый noise, тембр меняется на траве) через новый `gravel_player`. Всё процедурное.
- **Files**: `scripts/audio/bike_audio_manager.gd`.

### `[ ] [FEAT-007.3]` Speed FOV (камера скорости)
- **Goal**: Подсознательное ощущение скорости через расширение поля зрения.
- **Do**: В `bike_camera.gd`: плавное расширение FOV от 78° до 82° на максимальной скорости.
- **Files**: `scripts/camera/bike_camera.gd`.

---

## 🌅 Спринт 4A: Атмосфера и Суточный Цикл

### `[ ] [FEAT-008.1]` Суточный цикл с горячими клавишами
- **Goal**: Плавная смена времени суток. Клавиши `1`-`4` для мгновенного переключения.
- **Do**: Новый скрипт `day_night_cycle.gd`: 4 пресета (Утро/День/Вечер/Ночь), автоцикл 32 мин, crossfade 3 сек. Управление DirectionalLight3D, ProceduralSkyMaterial, Environment fog/ambient.
- **Files**: `scripts/world/day_night_cycle.gd` (NEW), `project.godot`, `scenes/main.tscn`.

### `[ ] [FEAT-008.2]` Атмосферные частицы
- **Goal**: Пыльца днём, искры вечером, светлячки ночью.
- **Do**: `GPUParticles3D` привязанный к камере, spawn rate и цвет управляются из `day_night_cycle.gd`.
- **Files**: `scenes/environment/ambient_particles.tscn` (NEW), `scripts/world/day_night_cycle.gd`.

### `[ ] [FEAT-008.3]` Фара велосипеда
- **Goal**: Тёплый свет от фонарика на руле в сумерках и ночью.
- **Do**: `SpotLight3D` как дочерний нод ForkAndHandlebar. Энергия и цвет управляются из `day_night_cycle.gd`.
- **Files**: `scenes/player/bicycle.tscn`, `scripts/world/day_night_cycle.gd`.

### `[ ] [INFRA-001]` AudioBus routing
- **Goal**: Основа для настроек громкости в меню.
- **Do**: `default_bus_layout.tres`: Master → SFX → Ambient → Music. Присвоить каждому AudioStreamPlayer3D bus.
- **Files**: `default_bus_layout.tres` (NEW), `scripts/audio/bike_audio_manager.gd`.

### `[ ] [INFRA-002]` Game State Machine (скелет)
- **Goal**: Фундамент для паузы и фоторежима.
- **Do**: Autoload `game_state.gd`: enum `{RIDING, PAUSED, PHOTO_MODE}`, сигнал `state_changed`.
- **Files**: `scripts/core/game_state.gd` (NEW), `project.godot`.

---

## 🎨 Спринт 4B: Визуальная Полировка, UI и Меню

### `[ ] [OPT-001]` LOD для MultiMesh растительности
- **Goal**: FPS ≥ 60 при 400+ чанков.
- **Do**: `visibility_range_begin/end` на MultiMeshInstance3D. Деревья >150м → billboard. `fade_mode = TRANS`.
- **Files**: `scripts/world/chunk_foliage.gd`, `scripts/world/chunk_streamer.gd`.

### `[ ] [VISUAL-001]` Дальний рельеф (Far Terrain Silhouettes)
- **Goal**: За полосой террейна — не пустота, а мягкие силуэты холмов.
- **Do**: Low-poly mesh холмов за 20м полосой, без коллизий, уходящий в туман.
- **Files**: `scripts/world/road_chunk.gd`.

### `[ ] [VISUAL-002]` Мокрый гравий (Wetness Shader)
- **Goal**: Утром — мокрый блестящий гравий, днём — сухой.
- **Do**: Uniform `wetness` в `gravel_road.gdshader`, управляемый из `day_night_cycle.gd`.
- **Files**: `assets/shaders/gravel_road.gdshader`, `scripts/world/day_night_cycle.gd`.

### `[ ] [VISUAL-003]` Модель велосипеда v2
- **Goal**: Велосипед выглядит достойно для скриншотов.
- **Do**: Спицы, цепь, педали (animated по `pedal_power`), metallic paint на раме.
- **Files**: `scenes/player/bicycle.tscn`.

### `[ ] [VISUAL-004]` Деревья v2
- **Goal**: Красивые деревья вблизи и издалека.
- **Do**: 5 ярусов у сосны, объёмная крона берёзы (icosphere), вариация цвета через `MultiMesh.use_colors`.
- **Files**: `scripts/world/world_manager.gd`.

### `[ ] [FEAT-010.1]` Медитативный Фоторежим
- **Goal**: Красивые скриншоты пейзажей.
- **Do**: Клавиша `P`, скрытие HUD, свободная орбитальная камера, DoF slider, F12 = сохранение скриншота.
- **Files**: `scripts/camera/photo_mode.gd` (NEW), `scripts/core/game_state.gd`.

### `[ ] [FEAT-010.2]` Меню паузы
- **Goal**: `Esc` → полупрозрачная пауза с настройками.
- **Do**: Overlay с кнопками: Продолжить / Настройки / Фоторежим / Выход в меню.
- **Files**: `scenes/ui/pause_menu.tscn` (NEW), `scripts/ui/pause_menu.gd` (NEW).

### `[ ] [FEAT-007.4]` Настройки комфорта и графики
- **Goal**: Индивидуальная настройка для чувствительных к укачиванию игроков.
- **Do**: Вкладка в паузе: FOV (65°-100°), Head Bob (0%-100%), Horizon Lean (0%-100%), громкость (Master/SFX/Ambient), графика (MSAA, SSAO).
- **Files**: `scenes/ui/pause_menu.tscn`, `scripts/ui/settings_manager.gd` (NEW).

### `[ ] [FEAT-010.3]` Главное меню (Title Screen)
- **Goal**: При запуске — красивый минималистичный экран.
- **Do**: Фоновая камера над дорогой. «Начать поездку» / «Выбрать маршрут» (seed) / «Настройки» / «Выход».
- **Files**: `scenes/ui/main_menu.tscn` (NEW), `scripts/ui/main_menu.gd` (NEW), `project.godot`.

### `[ ] [FEAT-010.4]` Persistence (сохранение настроек)
- **Goal**: Настройки запоминаются между сессиями.
- **Do**: `ConfigFile` → `user://settings.cfg`. Сохранение FOV, bob, lean, volume, graphics, last seed, time-of-day.
- **Files**: `scripts/ui/settings_manager.gd`.

---

## ☁️ Будущее: Steam Build и Интеграция (отдельный этап)

### `[ ] [FEAT-011.1]` Export и Standalone Build
- **Goal**: `SlowCycle.exe` запускается без Godot Editor.
- **Files**: `export_presets.cfg` (NEW), `project.godot`.

### `[ ] [FEAT-011.2]` Steam Integration
- **Goal**: Steam overlay, скриншоты через F12.
- **Files**: `scripts/core/steam_integration.gd` (NEW, опционально).

### `[ ] [FEAT-011.3]` Финальный QA Pass
- **Goal**: Полный прогон тестов + ручное тестирование.
- **Files**: `scripts/test/`.

---

## 🌍 Пост-релиз: Биомы и Разнообразие (если потребуется)

### `[ ] [FEAT-009.1]` Система макро-биомов
- **Goal**: Лес → Открытые поля → Прибрежные скалы.
- **Files**: `scripts/world/biome_manager.gd` (NEW), `scripts/world/chunk_foliage.gd`.

### `[ ] [FEAT-009.2]` Бесшовный Cross-Fade переход биомов
- **Goal**: Плавный переход за 200м.
- **Files**: `scripts/world/road_chunk.gd`.
