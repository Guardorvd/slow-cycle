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

### Спринт 3A: Доведение ощущения велосипеда до финального Playable Feel (`COMPLETED [x]`)
- `[x] [FEAT-006.4]` **Калибровка наката под Target Feel**: `road_rolling_resistance = 0.08`, `grass_rolling_resistance = 0.45`, `air_drag_coeff = 0.015`. Равновесная скорость на спуске −2° составляет 18.96 км/ч (окно 17–21 км/ч), свободный выкат с 20 км/ч до 0 за 34.0 с, торможение на траве за 9.6 с.
- `[x] [FEAT-006.5]` **Разделение физического и визуального уклона**: `physics_pitch` мгновенно считывается для гравитации и прижима колес $v_y$; `visual_pitch` асимметрично сглаживается (`attack = 14.0`, `decay = 7.0`) исключительно для визуальной рамы.
- `[x] [FEAT-006.6]` **Hybrid Lean Steering & Turn Radius Limiter**: Сохранение прямого руления на малых скоростях (3 км/ч), плавный кроссовер 3–8 км/ч, ограничение угла руля на 40 км/ч до 2.58° (радиус поворота $R \ge 25.5\text{м}$), центробежный крен рамы. Live-телеметрия в Debug HUD (F3).
- `[x] [FEAT-006.7]` **Progressive Braking & Visual Dive**: Быстрое нарастание тормозного усилия за 0.15 с по квадратичной кривой + визуальный клевок вилки рамы до −1.7° без воздействия на физическую капсулу.
- `[x] [FEAT-006.8]` **Инерция педалирования**: Нарастание тяги за 0.35 с (`pedal_power` от 0 до 1), мгновенный сброс в накат при отпускании педали.
- `[x] [FEAT-006.9]` **Cornering Scrub по боковой перегрузке**: Сброс скорости активируется только при боковом ускорении $a_{\text{lat}} > 1.5\text{ м/с}^2$, мягко гася 1–3 км/ч в глубоких виражах и не трогая прямые.
- `[x] [FEAT-006.10]` **Terrain Micro-Motion в камере**: Деликатный псевдо-шум низкой частоты (8 Гц) микро-амплитуды (0.0018 м) с коэффициентом 1.6× на траве, зависящий от скорости.

### Спринт 3B: Анатомия руления, Звуковой ландшафт, Камера и Геймпад (`COMPLETED [x]`)
- `[x] [FEAT-007.0]` **Анатомия руления и исправление знака крена**: Исправлена полярность крена рамы ($\phi = +\text{atan2}(a_{\text{lat}}, 9.8)$), поворот налево теперь вызывает естественный крен внутрь виража (влево); построена строгая иерархия узлов `SteerPivot` $\rightarrow$ `FrontAxle` (фиксированная компенсация наклона стакана вилки) $\rightarrow$ `FrontWheel` (независимое вращение спиц вокруг горизонтальной оси X); двухслойное руление `visual_steer` с усилением $2.5\times$ и динамическим ограничением до $12.0^\circ$ на крейсерской скорости.
- `[x] [FEAT-007.1a]` **Gamepad Analog Input Mapping**: RT/LT для аналоговой тяги и торможения через `Input.get_action_strength()`, Left Stick X с нелинейной степенной кривой $1.5$ и мёртвой зоной $0.15$, кнопки A (звонок), B (recovery), Y (смена камеры). Клавиатурное управление сохранено без единого изменения.
- `[x] [FEAT-007.1b]` **Gamepad Haptic Vibration Feedback**: Сфокусированный тактильный импульс при съезде на траву ($0.2$ сила, $0.12\text{ с}$) и упругий толчок при экстренном торможении ($0.35$ сила, $0.15\text{ с}$) через `Input.start_joy_vibration`.
- `[x] [FEAT-007.2]` **Процедурный звуковой ландшафт (Ветер + Шуршание гравия)**: Процедурный синтез бесшовного зацикленного розового шума ветра (`wind_player`) и зернистого фактурного шума гравия (`gravel_player`) в `AudioStreamWAV` с `LOOP_FORWARD`. Динамическая модуляция громкости и высоты тона от скорости; при выезде на траву питч шин глушится до $0.65$ (глухой бас грунта).
- `[x] [FEAT-007.3]` **Dynamic Speed FOV**: Динамическое расширение поля зрения камеры 1-го лица от $78.0^\circ$ до $83.0^\circ$ (и 3-го лица от $68.0^\circ$ до $72.0^\circ$) при разгоне до $43.2\text{ км/ч}$ с мягким сглаживанием $3.5$ (без укачивания и эффекта "рыбьего глаза").

---

## 🌅 Следующий спринт: Спринт 4A (Атмосфера, Суточный Цикл и Фара)

### TASK: [FEAT-008.1] Суточный цикл с горячими клавишами (Day/Night Presets)
**Goal**: Смена времени суток с 4 атмосферными пресетами: Утро (золотистый туман), День (яркое солнце), Вечер (закатные лучи), Ночь (лунный свет и звёзды).
**Do**: Создать скрипт `scripts/world/day_night_cycle.gd`:
- Пресеты: `DAWN`, `NOON`, `DUSK`, `NIGHT`.
- Горячие клавиши `1`, `2`, `3`, `4` для мгновенного плавного crossfade (3 секунды) между пресетами.
- Автоматический медленный суточный круг: полный цикл = 32 минуты реального времени.
- Плавная интерполяция параметров: угол солнца `DirectionalLight3D`, цвет света, `sky_top_color`, плотность и цвет тумана `forest_env.tres`.
**Do not**: Не нарушать Zero Pop-In тумана (цвет горизонта неба и цвет дальнего тумана должны всегда строго совпадать!).
**Acceptance Criteria**:
- Нажатие `1`–`4` запускает красивый 3-секундный переход освещения.
- Все тени и туман пересчитываются без графических артефактов.
**Tests**: Тест смены пресетов без просадки FPS.
**Files**: `scripts/world/day_night_cycle.gd` (NEW), `scenes/main.tscn`, `project.godot`.

### TASK: [FEAT-008.2] Атмосферные частицы (Ambient Particles)
**Goal**: Витающие в воздухе частицы, оживляющие пространство вокруг игрока.
**Do**: Создать сцену `scenes/environment/ambient_particles.tscn` с `GPUParticles3D`:
- Привязка к локальной позиции камеры в радиусе 12м.
- Днём: парящие пыльца и пушинки в лучах солнца.
- Вечером: золотистые микро-частицы.
- Ночью: светящиеся зеленоватые светлячки.
- Интенсивность спавна и альфа-канал интерполируются из `day_night_cycle.gd`.
**Do not**: Не перегружать GPU (лимит 250 частиц, простой unshaded биллборд).
**Acceptance Criteria**:
- В свете солнца сквозь сосны видны мягко парящие частицы пыльцы.
**Tests**: Замер FPS: падение производительности не более 0.2 мс на кадр.
**Files**: `scenes/environment/ambient_particles.tscn` (NEW), `scripts/world/day_night_cycle.gd`.

### TASK: [FEAT-008.3] Процедурная фара велосипеда (Dynamic Handlebar Headlight)
**Goal**: Тёплый луч света от фары на руле в сумерках и ночью.
**Do**:
- В `scenes/player/bicycle.tscn` добавить нод `SpotLight3D` как дочерний элемент `Visuals/ForkAndHandlebar`.
- Свет направлен строго по курсу переднего колеса и поворачивает вместе с рулем.
- Параметры: угол конуса 42°, дальность 28м, цвет теплый белый `Color(1.0, 0.96, 0.88)`, мягкое затухание.
- В сумерках и ночью фару плавно включает `day_night_cycle.gd` (fade-in за 2 секунды).
**Do not**: Не включать тень от фары без необходимости (экономия производительности).
**Acceptance Criteria**:
- Ночью фара освещает дорожное полотно на 25м вперед, послушно следуя за поворотом руля.
**Tests**: Ночной заезд с фарой, проверка освещения гравийного шейдера.
**Files**: `scenes/player/bicycle.tscn`, `scripts/world/day_night_cycle.gd`.

### TASK: [INFRA-001] AudioBus Routing & Master Architecture
**Goal**: Чистая маршрутизация аудиопотоков для будущих настроек громкости.
**Do**: Создать `default_bus_layout.tres`:
- Каналы: `Master` → `SFX` (звонок, трещотка), `Ambient` (ветер, гравий, природа), `Music`.
- Назначить шины всем плеерам в `bike_audio_manager.gd`.
**Do not**: Не трогать логику синтеза звуков.
**Acceptance Criteria**:
- Каждый звук играет строго в своей шине; регулировка громкости шины корректно глушит соответствующие звуки.
**Files**: `default_bus_layout.tres` (NEW), `scripts/audio/bike_audio_manager.gd`.

### TASK: [INFRA-002] Game State Machine Autoload
**Goal**: Базовый менеджер состояний игры для паузы и фоторежима.
**Do**: Создать скрипт autoload `scripts/core/game_state.gd`:
- `enum State { RIDING, PAUSED, PHOTO_MODE }`.
- Сигнал `state_changed(old_state, new_state)`.
- Методы: `pause_game()`, `resume_game()`, `enter_photo_mode()`.
- Управление `get_tree().paused`.
**Do not**: Не внедрять сложный UI до Спринта 4B; только чистый стейт-контроллер.
**Acceptance Criteria**:
- При переходе в `PAUSED` мир замирает; при `resume_game` движение продолжается без рывков.
**Files**: `scripts/core/game_state.gd` (NEW), `project.godot`.

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
