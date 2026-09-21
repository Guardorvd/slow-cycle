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

### Спринт 3C: Калибровка ощущения езды (Ride Feel Calibration) (`COMPLETED [x]`)
- `[x] [FEAT-006.11]` **Визуальная анатомия руля и переднего колеса в кокпите**:
  - Четко читаемый визуальный поворот руля и переднего колеса из камеры 1-го лица в откалиброванных диапазонах: $22.0^\circ$ (низкая скорость), $16.0^\circ$ (крейсерская $25\text{ км/ч}$), $12.0^\circ$ (скоростная $40+\text{ км/ч}$).
  - Строгий `clamp` с усилением `visual_steer_gain = 3.5` для отзывчивого подруливания.
  - Железное согласование знаков ввода: $A \rightarrow$ yaw влево, bank влево, руль влево, переднее колесо влево; $D \rightarrow$ всё вправо.
  - Сохранение независимой оси вращения ступицы колеса (`FrontAxle` $\rightarrow$ `FrontWheel`).
  - Абсолютная сохранность стабильной физической траектории (`yaw_turn_rate`, Аккерман, наклон рамы и генерация дороги не затрагивались).
- `[x] [FEAT-006.12]` **Калибровка мускульного разгона и инерции педалей**:
  - Снижение избыточного ускорения электробайка ($3.5\text{ м/с}^2$) до естественного мускульного усилия: `pedal_acceleration = 1.3 m/s²`, `pedal_attack_time = 0.50 s`.
  - Измеренная динамика: разгон $0 \rightarrow 20\text{ км/ч}$ за $5.57\text{ с}$ (целевой коридор $4.8–6.5\text{ с}$), выход на крейсерские $25\text{ км/ч}$ за $7.55\text{ с}$.
  - Проверена устойчивость на подъеме $+2.5^\circ$ (стабильная скорость $16.8\text{ км/ч}$) и накат со спуска $-2.0^\circ$ ($18.1\text{ км/ч}$).
- `[x] [FEAT-006.13]` **Акустический комфорт ветра**:
  - Убран штормовой шум ветра; порог появления сдвинут на $18\text{–}20\text{ км/ч}$ ($5.0\text{ м/с}$), на прогулочных скоростях слышны только природа, шелест гравия и трещотка.
  - Плавный экспоненциальный fade-in: легкий ветерок на $25\text{ км/ч}$ ($-39\text{–}-41\text{ dB}$), заметный встречный воздух на $30\text{ км/ч}$ ($-33\text{ dB}$), комфортный пик на $43\text{ км/ч}$ ($-26\text{ dB}$).
  - Смягчение фильтра синтезатора шума ($0.955 / 0.045$) и нормализации: шелест мягкого воздуха вместо воющей бури.
- `[x] [FEAT-006.14]` **Поведенческий регрессионный тест (Behavioral Regression Suite)**:
  - Добавлены тесты 21–24 в `scripts/test/test_diagnostics.gd` (знаки руления, ось ступицы, коридор ускорения, кривая звука). Все 24 системных теста пройдены на 100%.

---

### Спринт 4A: Состояние движения, баланс сил и аркадный разгон (`COMPLETED [x]`)
- `[x] [FEAT-012.1]` **Состояние движения, баланс сил и аркадный разгон (Riding State & Arcade Pedal Burst)**:
  - Формализован непрерывный баланс продольных сил: $\Sigma a = a_{\text{cruise}} + a_{\text{sprint}} + a_{\text{gravity}} - a_{\text{rolling}} - a_{\text{drag}} - a_{\text{brake}}$.
  - Реализован спокойный круиз (`W` / `RT`) с поддержкой `sustain_thrust`: естественный набор скорости и стабильное удержание 25.0 км/ч.
  - Внедрён аркадный спринт (`Shift` / `X`) с механикой убывающей отдачи (Diminishing Returns): от $1.35\text{ м/с}^2$ на низких скоростях до естественного предела каденса на $44\text{ км/ч}$ ($12.2\text{ м/с}$). Буфер `sprint_boost` затухает с темпом $1.1\text{ м/с}^2$, максимальный буфер $3.0\text{ м/с}^2$. На спусках суммируется с силой тяжести до $44\text{ км/ч}$.
  - Плавный аэродинамический накат со скорости 40 км/ч без резких клевков и толчков. Выкат на ровной дороге с 25 км/ч до 0 занимает $32.6\text{ с}$ (норматив $25–35\text{ с}$).
  - Устойчивый круиз на спуске −2° ($19.6\text{ км/ч}$), естественный разгон под уклон −6° ($39.1\text{ км/ч}$), закономерное замедление на подъёме +3° ($8.5\text{ с}$).
  - Разделено управление: спокойный круиз (`W` / `RT`), аркадный спринт педалями (`Shift` / `X`), торможение (`S` / `LT`). Полная аналоговая поддержка курков геймпада через `Input.get_action_strength()`.
  - Стартовое меню выбора режима при запуске игры (`scenes/mode_select.tscn`): 1 — Бесконечная дорога (Zen Ride), 2 — Тестовый трек (Sandbox).
  - Обновлён оверлей подсказок `hud.tscn` (клавиша `H`) и F3 Debug HUD с индикацией режимов (`CRUISE`, `SPRINT`, `COAST`, `BRAKE`) и сил.
  - Поведенческие тесты 31–33 в `test_diagnostics.gd`. Все 33 системных теста пройдены на 100%.

---

### Спринт 4B: Руление, динамика наклона и траектории виражей (`COMPLETED [x]`)
- `[x] [FEAT-012.2]` **Руление, динамика наклона и траектории виражей (Steering, Lean Dynamics & Apex Flow)**:
  - Реализована Steer-First / Lean-Coordinated архитектура: мгновенная отзывчивость рулевой геометрии при входе в дугу с последующим глубоким центробежным креном рамы.
  - Разделены режимы Active Steer (`steer_attack_speed = 5.0`) и Passive Trail Centering (`steer_centering_min/max = 8.0..16.0` в зависимости от скорости) — исключено ощущение «ватного руля» и сопротивления игроку.
  - Строгое знаковое боковое ускорение $a_{\text{lat\_signed}} = v \cdot \omega_{\text{yaw}}$ гарантирует идеальное согласование направления крена: A/StickLeft -> крен влево, D/StickRight -> крен вправо.
  - Интеграция сопротивления сноса $a_{\text{scrub}}$ напрямую в непрерывный баланс продольных сил $\Sigma a_{\text{long}}$ вместо дискретного срезания скорости.
  - Натурная физика Apex Flow: при входе в поворот радиусом 25 м на 22 км/ч ($a_{\text{lat}} \le 1.8\text{ м/с}^2$) потеря скорости строго равна 0; при агрессивном входе на 38 км/ч ($a_{\text{lat}} = 3.96\text{ м/с}^2$) шины скрабят избыточную энергию с замедлением $a_{\text{scrub}} \approx 0.48\text{ м/с}^2$.
  - Высокоскоростной лимит радиуса на 40 км/ч ($R = 25.8\text{ м} \ge 25.0\text{ м}$, $a_{\text{lat}} = 4.79\text{ м/с}^2 \le 5.2\text{ м/с}^2$) гарантирует устойчивость шасси без ножевых срывов.
  - Обновлён F3 Debug HUD: отображение перегрузки, сопротивления сноса шин и статуса `[FLOW]` / `[SCRUB]`.
  - Поведенческие контракты: тесты 34, 35, 36 добавлены в `test_diagnostics.gd`. Все 36 тестов пройдены на 100%.

---

### TASK: [FEAT-012.3] Sprint 4C: Реакция на рельеф и типы поверхностей (Terrain, Crest/Dip & Surface Dynamics) (`COMPLETED [x]`)
**Goal**: Плавный и устойчивый контакт колес с дорогой на резких перегибах (гребни холмов и ямы), разделение свойств покрытий (гравий vs трава vs неровный грунт).
**Realized**:
- В `scripts/player/bicycle_controller.gd`:
  - Расширена модель поверхностей `enum SurfaceType { GRAVEL, GRASS, ROUGH_GRAVEL }` с раздельной калибровкой сопротивления качению ($0.125$, $0.450$, $0.220$).
  - Строгая выпуклая нормализация весов поверхностей ($\sum w_i \equiv 1.0, w_i \ge 0$), полностью исключающая отрицательный вес гравия.
  - Двухзонный опрос RayCast: физический контакт ограничен порогом `max_ground_contact_distance = 0.68` (запас отбоя 18 см), исключая эффект «магнита к земле» при реальном полете, при этом лучи $1.6\text{ м}$ используются для упреждающего сопровождения ориентации рамы (lookahead).
  - Разделена валидация `front_contact_valid` и `rear_contact_valid` с трёхуровневым расчётом тангажа (секущая при двух лучах, локальная нормаль при одном луче, плавное затухание в свободном полете), ликвидирован сброс тангажа в 0° на гребне.
  - Канал шероховатости `terrain_roughness` ($0.0 \dots 1.0$) измеряет скалярное отклонение нормали от сглаженной нормали склона `smoothed_surface_normal` (на ровных склонах шероховатость не растёт, на кочках честно детектируется).
  - Микро-подвеска рамы (`VisualsRoot.position.y = 0.34 + suspension_compression`, ход $\pm 4\text{ см}$).
- В `scenes/player/bicycle.tscn`: глубина лучей увеличена до $1.6\text{ м}$, маска лучей дополнена слоем 5 (`mask = 22`).
- В `scripts/test/test_track_generator.gd`: секции J, K, S4 размечены метаданными `surface_type = "rough_gravel"` и группой `surface_rough_gravel`.
- В `scripts/ui/debug_hud.gd`: телеметрия отображает тип поверхности, процент шероховатости и ход подвески (`Surface: ROUGH_GRAVEL | Rough: 76% | Susp: -8mm`).
- Поведенческие контракты: тесты 37, 38, 39, 40 добавлены в `test_diagnostics.gd`. Все 40 тестов пройдены на 100%. Тест живой симуляции полигона `test_track_ride.gd` успешно верифицирует секцию J (Rough Gravel washboard).
**Files**: `scripts/player/bicycle_controller.gd`, `scenes/player/bicycle.tscn`, `scripts/test/test_track_generator.gd`, `scripts/ui/debug_hud.gd`, `scripts/test/test_track_ride.gd`, `scripts/test/test_diagnostics.gd`.

---

### TASK: [FEAT-012.4] Sprint 4D: Слой визуального представления велосипеда (Bicycle Visual Presentation Layer) (`COMPLETED [x]`)
**Goal**: Чистое разделение физического корня (`CharacterBody3D`) и слоя визуального представления (`VisualsRoot`), устранение стробоскопического эффекта спиц, анимированная каретка и педали, пороговый юз заднего колеса.
**Realized**:
- В `scenes/player/bicycle.tscn`:
  - Добавлены 4-лучевые спицы `Mesh_SpokeBar` и втулки `Mesh_WheelHub` для переднего и заднего колес. Расчет числа спиц по Найквисту ($v_{\text{Nyquist}} = 57.7\text{ км/ч} > 44\text{ км/ч}$) гарантирует отсутствие стробоскопического реверса (Wagon-Wheel Aliasing) при 60 FPS.
  - Кинематическая компенсация `FrontAxle`: обратный наклон оси ($-14^\circ \approx -0.24\text{ рад}$) компенсирует рейк вилки ($+14^\circ \approx +0.24\text{ рад}$), колесо вращается вокруг локального X без прецессии и биения.
  - Кареточный узел `Visuals/Crankset`: ось каретки `BottomBracket`, шатуны `LeftCrank` и `RightCrank`, платформы педалей `LeftPedal` и `RightPedal`.
  - Подключены экспортные ссылки в корне сцены: `crankset_pivot`, `left_pedal`, `right_pedal`.
- В `scripts/player/bicycle_controller.gd`:
  - Вращение каретки от скорости и каденса ($75\text{ RPM}$ на круизе $25\text{ км/ч}$, с повышением до $1.3\times$ на спринте).
  - Плавное горизонтирование шатунов при накате (`is_coasting`).
  - Контр-вращение платформ педалей (`-crank_rotation`), сохраняющее их строго горизонтальными.
  - Пороговый Brake Skid заднего колеса (`smoothstep(0.65, 1.0, brake_input)`): отсутствие проскальзывания при легком торможении ($\le 60\%$), прогрессивная блокировка до $10\%$ скорости при экстренном зажатии тормоза ($100\%$).
  - Двухуровневое руление: физический безопасный угол `current_steer` и усиленный эргономичный визуальный угол `visual_steer` (`visual_steer_gain = 3.5`, динамический лимит $22^\circ \dots 12^\circ$).
  - Полная изоляция корня `CharacterBody3D` (крен, тангаж, клевок и подвеска применяются только к `VisualsRoot`).
- В `scripts/ui/debug_hud.gd`: телеметрия дополнена отображением визуального руля, каденса и процента юза шины.
- Поведенческие контракты: тесты 41, 42, 43, 44 добавлены в `test_diagnostics.gd`. Все 44 теста пройдены на 100%.
**Files**: `scenes/player/bicycle.tscn`, `scripts/player/bicycle_controller.gd`, `scripts/ui/debug_hud.gd`, `scripts/test/test_diagnostics.gd`.

---

## 🚴 Следующий спринт: Спринт 4E (Живая камера как сенсор движения)

### TASK: [FEAT-012.5] Sprint 4E: Живая камера как сенсор движения (Camera Riding Feel & Coherent Noise)
**Goal**: Камера передает скорость, ускорение, торможение и микро-рельеф без тошноты и резких рывков.
**Do**:
- В `scripts/camera/bike_camera.gd`:
  - Генерация связного микро-шума дороги через `FastNoiseLite` с масштабированием по скорости и шероховатости покрытия.
  - Плавный продольный сдвиг камеры при ускорении и деликатный клевок при резком торможении.
  - Сохранение динамического Speed FOV и стабилизации горизонта.
**Do not**: Не допускать резкой хаотичной тряски и заваливания горизонта более чем на 35%.
**Acceptance Criteria**:
- При разгоне камера мягко дышит скоростью, на гравии чувствуется деликатная вибрация дороги, при торможении есть естественный упругий клевок.
**Files**: `scripts/camera/bike_camera.gd`.

---

### TASK: [FEAT-012.6] Sprint 4F: Звуковой ландшафт движения (Riding Audio & Texture Modulation)
**Goal**: Натуральный процедурный звук: отчетливая трещотка свободного хода, аэродинамический свист ветра и шорох шин.
**Do**:
- В `scripts/audio/bike_audio_manager.gd`:
  - Трещотка втулки при свободном ходе с динамической частотой кликов от скорости.
  - Свист ветра с аэродинамическим частотным фильтром.
  - Модуляция шороха гравия и глухого баса травы по шероховатости и боковому сбросу скорости.
**Do not**: Не допускать щелчков на швах звуковых петель.
**Acceptance Criteria**:
- При отпускании газа приятно стрекочет трещотка втулки, на скорости шелестит ветер, на траве звук шин бархатисто глушится.
**Files**: `scripts/audio/bike_audio_manager.gd`, `default_bus_layout.tres`.

---

### TASK: [FEAT-012.7] Sprint 4G: Тестовый полигон, селектор режимов и калибровка (Test Track, Mode Switcher & Calibration Gate) (`COMPLETED [x]`)
**Goal**: Создать выделенную тестовую сцену с 18 секциями (12 изолированных A–L + 6 композитных стресс-секций S1–S6), удобный выбор режима при старте игры и детерминированную верификацию.
**Realized**:
- Реализована детерминированная замкнутая сцена `scenes/test/riding_feel_test_track.tscn` (~2.8 км, 56 чанков, 1401 сэмпл):
  - Точное аналитическое замыкание шва: $\Delta p = 0.000\text{ мм}$, $\Delta \theta = 0.00000000\text{ рад}$, $\Delta Y = 0.000\text{ мм}$ (абсолютная $C^1$-непрерывность).
  - 12 изолированных секций A–L: Flat Start, Climb $+4.5^\circ$, Downhill $-5.0^\circ$, Sharp Crest $+6^\circ \to -6^\circ$, Sharp Dip $-6^\circ \to +6^\circ$, Constant Arc $R=35\text{м}$, Sharp Corner $R=25\text{м}$, S-Chicanes $R=30\text{м}$, Fast Sweeper $R=65\text{м}$, Rough Gravel (микро-кочки), Rough Downhill $-4^\circ$, Grass Verge Exit (Layer 3).
  - 6 композитных стресс-секций S1–S6: Downhill $\to$ Sweeper, Apex Flow с гоночными щитами дистанции, Crest $\to$ Dip $\to$ Turn, Rough Downhill $\to$ S-Turns, Sweeper $\to$ Heavy Brake, Grass in Corner Return to Start.
  - 18 придорожных стел с 3D-табличками (`Label3D`) и 5 гоночных щитов зоны апекса (`[100m]`, `[50m]`, `[BRAKE ZONE]`, `[APEX]`, `[SPRINT]`).
  - Поддержка возврата на дорогу (клавиша `R` через `request_bike_recovery`).
  - Вывод текущей секции и параметров в Debug HUD (F3).
  - Селектор режимов: кнопка «2. Тестовый полигон» в `mode_select.gd` загружает тестовый трек.
  - Автоматизированный верификатор `test_track_verification.gd` и тест живой симуляции `test_track_ride.gd` пройдены на 100%.
**Files**: `scenes/test/riding_feel_test_track.tscn` (NEW), `scripts/test/test_track_generator.gd` (NEW), `scripts/test/test_track_verification.gd` (NEW), `scripts/test/test_track_ride.gd` (NEW), `scripts/ui/mode_select.gd`, `scenes/mode_select.tscn`, `scripts/ui/debug_hud.gd`.


---

## 🌅 Спринт 5: Атмосфера, Суточный Цикл и Фара

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
**Do not**: Не внедрять сложный UI до Спринта 6; только чистый стейт-контроллер.
**Acceptance Criteria**:
- При переходе в `PAUSED` мир замирает; при `resume_game` движение продолжается без рывков.
**Files**: `scripts/core/game_state.gd` (NEW), `project.godot`.

---

## 🎨 Спринт 6: Визуальная Полировка, UI и Меню

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

## ☁️ Спринт 7: Steam Build и Интеграция (отдельный этап)

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
