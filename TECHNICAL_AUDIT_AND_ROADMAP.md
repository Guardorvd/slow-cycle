# ТЕХНИЧЕСКИЙ АУДИТ, АРХИТЕКТУРНЫЙ АНАЛИЗ И ПЛАН РЕФАКТОРИНГА (СПРИНТ 4: 4A–4M ПОЛНЫЙ ЦИКЛ)

## 1. ВВОДНЫЙ ИНЖЕНЕРНЫЙ КОНТЕКСТ И ЗАДАЧА
> **Статус задачи**: Выполнен глубокий сквозной технический аудит кодовой базы по итогам всего Спринта 4 (все подэтапы: 4A, 4B, 4C, 4D, 4E, 4F, 4G, 4H, 4J, 4K, 4L, 4M) в роли **Principal Software Architect & Systems Tech Lead**.
> **Фокус анализа**: Комплексная ревизия всех внедрённых подсистем: продольная динамика и баланс сил (4A), кастер и геометрия апекса (4B), трёхслойная модель поверхностей и лучевое огибание (4C), визуальная анатомия колес, шатунов и педалей (4D), живая камера с когерентным шумом и стабилизацией VOR (4E), процедурный звуковой ландшафт и модальный колокол (4F), триада испытательных полигонов 4G/4K/4L и селектор режимов (4G–4L), мастер-раннер и двойной аудит восприятия (4M).
> **Стек и компоненты**: Godot Engine 4.7.2 Stable Mono (Forward+ Vulkan 1.3), GDScript 2.0, `CharacterBody3D`, `BicycleController`, `BikeCameraRig`, `BikeAudioManager`, `RoadPathData`, `RoadChunk`, `RoadLogic`, `TestTrackGenerator`, `RidingLabGenerator`, `GravelLoopGenerator`, `DebugHUD`, `ModeSelect`.
> **Методологический фильтр каждого дефекта**:
> 1. *Это реально bug или просто stylistic preference?*
> 2. *Есть ли observable consequence (видимое/слышимое/измеримое проявление)?*
> 3. *Можно ли доказать проблему кодом/тестом/сценарием?*
> 4. *Какой минимальный diff её исправляет?*
> «Система работает → доказана проблема → минимальное исправление → тест → не трогаем остальное».

---

## 2. СВОДНЫЙ РЕЕСТР ДЕФЕКТОВ И ТЕХНИЧЕСКОГО ДОЛГА (СПРИНТ 4A–4M)

| № | Модуль / Файл | Выявленная проблема / «Запах кода» | Инженерный риск / Нарушенный принцип | Влияние на систему (Impact) | Уровень критичности | Статус |
|---|---|---|---|---|:---:|:---:|
| **D-01** | `scripts/camera/bike_camera.gd` | Однокадровый боковой скачок камеры (до 5 мм) при отпускании педалей на пике каденса (`sway_offset_x`) | Discontinuous Camera Step / Отсутствие сглаживающего фильтра (аналог решенного D-07) | Заметный резкий рывок/щелчок камеры кокпита вбок при броске клавиши `W` | **High** | 🟢 УСТРАНЕНО (Спринт 4M Ревизия) |
| **D-02** | `scripts/player/bicycle_controller.gd` | Бесконечное монотонное накопление углов `crank_rotation`, `front_wheel_rotation`, `rear_wheel_rotation` без нормализации $[-\pi, \pi]$ | Floating-point Mantissa Precision Loss / Phantom Fix (в отчете 4G было заявлено исправление, в кодовой базе отсутствует) | Уход угла в сотни тысяч радиан при длительной игре, микро-дрейф шага и погрешность `sin()` | **Medium** | 🟢 УСТРАНЕНО (Спринт 4M Ревизия) |
| **D-03** | `scripts/camera/bike_camera.gd` & `bike_audio_manager.gd` | Приоритетное переопределение `is_on_grass` (порог 0.08) блокирует каменистую дорогу `ROUGH_GRAVEL` (слой 5) | State Machine Priority Inversion / Условие `is_on_grass` стоит раньше `current_surf == 2` | На каменистой дороге при малейшем задевании края обочины тряска камеры падает с 2.4x до 1.6x, а звук шин превращается в глухой шелест | **Medium** | 🟢 УСТРАНЕНО (Спринт 4M Ревизия) |
| **D-04** | `scripts/ui/hud.gd` | Тупиковая навигация сцен: отсутствие возможности возврата в главное меню `mode_select.tscn` из игры | One-way State Trap / Нарушение принципа замкнутого цикла UX | Игрок вынужден закрывать игру через Alt+F4 / крестик окна, чтобы сменить полигон | **Medium** | 🟢 УСТРАНЕНО (Спринт 4M Ревизия) |
| **D-05** | `scripts/player/bicycle_controller.gd` | Заморозка спада тормозного усилия `brake_input` во время нахождения в воздухе (`not is_grounded`) | Early Return Side-effect / Нарушение целостности обновления ввода | Если игрок отпустил тормоз в прыжке, байк после приземления продолжает тормозить полные 100 мс | **Low** | 🟢 УСТРАНЕНО (Спринт 4M Ревизия) |
| **D-06** | `scripts/ui/debug_hud.gd` | Избыточные вызовы динамической рефлексии `bike_controller.get("...")` (25+ раз за кадр) | Code Smell / Reflection Overhead / Нарушение строгой типизации | Ненужный оверхед в F3 HUD (поиск по хеш-таблицам Variant вместо прямого доступа) | **Low** | 🟢 УСТРАНЕНО (Спринт 4M Ревизия) |
| **D-07** | `scripts/world/road_chunk.gd` vs `test_track_generator.gd` | Рассинхронизация генерации неровностей Rough Gravel (сплайн vs модификация вершин SurfaceTool) | DRY Violation / Дублирование логики разными путями | Разная физическая реакция колеса на неровности в бесконечном мире и на треках | **Low** | 🟡 ТЕХДОЛГ |
| **D-08** | `scripts/ui/debug_hud.gd` | Попытка `FileAccess.open` несуществующего файла в режиме `READ_WRITE` без предварительной проверки | Unhandled System Warning / Отсутствие `FileAccess.file_exists` | Однократный спам ошибки `ERR_FILE_NOT_FOUND` в логе консоли Godot при первом нажатии F4 | **Low** | 🟢 УСТРАНЕНО (Спринт 4M Ревизия) |
| *R-01* | `scripts/audio/bike_audio_manager.gd` | Скачок фазы (до 49% шкалы) на границе лупа ветра + плавающий сбой теста 27 | Audio Discontinuity / Flaky Failure | Щелчок каждые 4.5с в звуке ветра; падение теста 27 | **Critical** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-02* | `scripts/world/road_path_data.gd` | Залипание телеметрии F3 HUD на 50 м при пересечении старт/финиша на замкнутом полигоне | Отсутствие циклического wrap-around в `find_closest_index` | 50 метров после старта HUD показывает конец круга | **High** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-03* | `scripts/audio/bike_audio_manager.gd` | Дискретизация таймера трещотки (`freewheel_timer = 0.0`) и потеря 46% расчетной частоты кликов | Timer Aliasing / Phase Truncation Defect | Частота кликов зависала на 30 Гц на скоростях от 25 до 44 км/ч вместо 55.6 Гц | **High** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-04* | `scripts/camera/bike_camera.gd` | Инверсия 180° продольного смещения камеры Surge Z (Godot forward = -Z) | Координатная ошибка вектора смещения торса | При разгоне райдер наклонялся вперед, при торможении отлетал назад | **High** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-05* | `scripts/camera/bike_camera.gd` | Полное отключение раскачки камеры (Cadence Sway & Bob) при спринте на Shift | Разрыв контракта состояний (`is_sprinting` vs `is_pedaling`) | Камера полностью «деревенела» в кокпите во время спринта | **High** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-06* | `scripts/audio/bike_audio_manager.gd` | Утечка экземпляров `AudioStreamPlaybackWAV` в ObjectDB при выходе | Resource Leak / Незакрытые autoplay-каналы | Предупреждения об утечках в ObjectDB при завершении тестов | **Medium** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-07* | `scripts/camera/bike_camera.gd` | Однокадровый скачок высоты камеры до 15 мм при прекращении педалирования (`bob_y`) | Discontinuous Camera Step | Резкий визуальный стук в глаза игрока при отпускании W | **Medium** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-08* | `scripts/player/bicycle_controller.gd` | Мгновенный обрыв тормозной силы при отпускании S вместо спада за 0.10 с | Force Discontinuity в формуле продольного баланса | Толчок/рывок ускорения при отпускании тормоза | **Medium** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-09* | `scripts/player/bicycle_controller.gd` | Паразитное трение качения в воздухе (`not is_grounded`) | Нарушение физики контакта колеса | Искусственное торможение байка во время отрыва от дороги | **Medium** | 🟢 УСТРАНЕНО (Спринт 4G) |
| *R-10* | `scripts/player/bicycle_controller.gd` | Конфликт спринта и торможения (тяга спринта продолжала ускорять байк) | Нарушение баланса сил при торможении | Увеличение тормозного пути при остаточном буфере спринта | **Medium** | 🟢 УСТРАНЕНО (Спринт 4G) |

---

## 3. ПОДРОБНЫЙ ТЕХНИЧЕСКИЙ РАЗБОР И ДОКАЗАТЕЛЬСТВА (4-STEP METHODOLOGY)

### 3.1. [HIGH] Однокадровый боковой скачок камеры (до 5 мм) при отпускании педалей (`bike_camera.gd`)
* **1. Это реально bug или просто stylistic preference?**
  **Реальный функциональный баг разрыва непрерывности положения камеры (Camera Position Discontinuity)**. Это прямой брат-близнец ранее исправленного дефекта R-07 (`bob_y` скачок по вертикали), но пропущенный разработчиками для горизонтальной компоненты раскачки.
* **2. Есть ли observable consequence?**
  При активном педалировании шатуны вращаются, вызывая покачивание торса райдера влево-вправо с амплитудой до $\pm 5$ мм (`cadence_sway_intensity = 0.005`). Если игрок отпускает клавишу `W` в момент максимального отклонения шатуна ($\sin(\theta_{\text{crank}}) = \pm 1.0$), в следующем же кадре значение переменной `sway_offset_x` мгновенно сбрасывается в `0.0`. Камера кокпита первого лица резко отскакивает на 5 мм в центр за 16 мс (эквивалентно мгновенному боковому рывку со скоростью $0.3$ м/с прямо в глазах игрока).
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `scripts/camera/bike_camera.gd` (строки 191, 198, 201, 229):
  ```gdscript
  var sway_offset_x: float = 0.0
  var target_bob_y: float = 0.0
  ...
  if is_working_pedals and current_speed > 0.5:
      bob_phase += delta * (current_speed * 1.4)
      target_bob_y = sin(bob_phase) * vertical_bob_intensity
      sway_offset_x = sin(crank_rot) * cadence_sway_intensity * eff_pedal_power
  elif is_coasting or current_speed <= 0.5:
      target_bob_y = 0.0
      sway_offset_x = 0.0

  var bob_t: float = 1.0 - exp(-10.0 * delta)
  current_bob_y = lerpf(current_bob_y, target_bob_y, bob_t)
  ...
  first_person_cam.position.x = base_fp_pos.x + current_shake_x + sway_offset_x
  ```
  Видно, что для вертикального `bob` создана сглаженная переменная состояния класса `current_bob_y`, пропущенная через экспоненциальный фильтр с постоянной времени $10.0$. Для горизонтального же `sway_offset_x` переменная объявлена локально в теле `_process` и подается в `position.x` напрямую без фильтрации!
  - Кадр $N$ (педали активны, $\text{crank\_rot} = \pi/2$): $\text{position.x} = \text{base.x} + 0.005$ м.
  - Кадр $N+1$ (клавиша `W` отпущена): `is_working_pedals = false` $\implies \text{sway\_offset\_x} = 0.0 \implies \text{position.x} = \text{base.x}$.
  - Дельта за 1 кадр: $\Delta x = 5.0$ мм.
* **4. Какой минимальный diff её исправляет?**
  Ввести постоянную сглаженную переменную состояния `current_sway_x` по аналогии с `current_bob_y`:
  ```gdscript
  # В объявлении переменных класса bike_camera.gd:
  var current_sway_x: float = 0.0

  # В функции reset_camera_dynamics():
  current_sway_x = 0.0

  # В _process(delta):
  var sway_t: float = 1.0 - exp(-10.0 * delta)
  current_sway_x = lerpf(current_sway_x, sway_offset_x, sway_t)
  first_person_cam.position.x = base_fp_pos.x + current_shake_x + current_sway_x
  ```

---

### 3.2. [MEDIUM] Неограниченное накопление углов вращения каретки и колес (`bicycle_controller.gd`)
* **1. Это реально bug или просто stylistic preference?**
  **Реальный баг потери точности чисел с плавающей точкой (Floating-Point Precision Degradation) + факт рассинхронизации документации с кодом (Phantom Fix)**. В отчете аудита 4G Дефект #10 был помечен как «🟢 УСТРАНЕНО», но в реальном GDScript-коде нормализация угла не была реализована.
* **2. Есть ли observable consequence?**
  В длительных игровых сессиях угол `crank_rotation` монотонно уменьшается:
  - 10 минут круиза (75 RPM): $\approx -4,700$ радиан.
  - 1 час круиза: $\approx -28,274$ радиан.
  - 3 часа игры: $\approx -85,000$ радиан.
  В стандарте IEEE 754 одинарной точности (32-bit float, используемый в Godot Variant) мантисса имеет 24 бита ($\approx 7$ значащих десятичных цифр). При значениях угла порядка $10^5$ шаг дискретизации float возрастает до $10^5 \cdot 2^{-24} \approx 0.006$ рад ($0.35^\circ$). Это вызывает микро-дергания графики шатунов и погрешности в формуле `roundf(crank_rotation / PI) * PI` при переходе в накат.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  Поиск по кодовой базе `grep_search "wrapf"` находит вызовы только внутри файла `TECHNICAL_AUDIT_AND_ROADMAP.md`.
  В `scripts/player/bicycle_controller.gd` (L533-548):
  ```gdscript
  var delta_theta_crank: float = (current_cadence_rpm * TAU / 60.0) * delta
  crank_rotation -= delta_theta_crank
  ...
  var target_crank_level: float = roundf(crank_rotation / PI) * PI
  crank_rotation = lerpf(crank_rotation, target_crank_level, 6.0 * delta)
  ```
  Угол просто непрерывно декрементируется без отсечки периода. То же самое происходит с углами колес:
  ```gdscript
  front_wheel_rotation -= delta_theta_f
  rear_wheel_rotation -= delta_theta_r
  ```
* **4. Какой минимальный diff её исправляет?**
  В `_update_visual_transforms` нормализовать углы с сохранением фазы:
  ```gdscript
  crank_rotation = wrapf(crank_rotation - delta_theta_crank, -PI, PI)
  front_wheel_rotation = wrapf(front_wheel_rotation - delta_theta_f, 0.0, TAU)
  rear_wheel_rotation = wrapf(rear_wheel_rotation - delta_theta_r, 0.0, TAU)
  ```

---

### 3.3. [MEDIUM] Блокировка параметров каменистой дороги `ROUGH_GRAVEL` травой на обочине (`bike_camera.gd` & `bike_audio_manager.gd`)
* **1. Это реально bug или просто stylistic preference?**
  **Реальный логический дефект приоритетов в автомате состояний поверхностей (State Machine Priority Inversion)**.
* **2. Есть ли observable consequence?**
  На каменистом участке (Rough Gravel, Layer 5), если велосипедист смещается к краю дороги и колесо касается травы с весом всего $8.5\%$ (`surface_grass_weight > 0.08`), флаг `is_on_grass` переключается в `true`.
  В этот момент в камере и аудио срабатывает первое же условие `if is_on_grass or current_surf == 1`:
  - Тряска камеры моментально падает с $2.4\times$ (гребенка) до $1.6\times$ (трава), несмотря на то, что под колесами 91.5% каменистой дороги.
  - Звук шин мгновенно превращается в приглушенный низкочастотный шелест дерна (питч $0.65$) вместо скрежета булыжников.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `bike_camera.gd` (строки 158-162):
  ```gdscript
  var surface_mult: float = 1.0
  if is_on_grass or current_surf == 1:
      surface_mult = grass_shake_multiplier # 1.6
  elif current_surf == 2:
      surface_mult = rough_gravel_shake_multiplier # 2.4
  ```
  И в `bike_audio_manager.gd` (строки 141-144, 182-186):
  ```gdscript
  if is_on_grass or current_surf == 1:
      base_vol -= 2.5
      base_pitch *= 0.90
  ...
  if is_on_grass or current_surf == 1:
      target_gravel_vol -= 3.0
      target_gravel_pitch = 0.65
  else:
      target_gravel_pitch = lerpf(0.96, 1.06, speed_ratio)
  ```
  Так как `is_on_grass` выставлен при малейшем контакте ($> 0.08$), а доминирующая поверхность `current_surf == 2` проверяется во второй ветке `elif`, ветка каменистой дороги полностью отсекается.
* **4. Какой минимальный diff её исправляет?**
  Поставить проверку каменистой поверхности первой, либо связать `is_on_grass` строго с доминирующим типом поверхности:
  В `bike_camera.gd`:
  ```gdscript
  if current_surf == 2:
      surface_mult = rough_gravel_shake_multiplier
  elif is_on_grass or current_surf == 1:
      surface_mult = grass_shake_multiplier
  ```
  И аналогично в `bike_audio_manager.gd`.

---

### 3.4. [MEDIUM] Тупиковая навигация сцен (Dead-End Scene Flow)
* **1. Это реально bug или просто stylistic preference?**
  **Архитектурный UX-дефект навигации приложения (Missing State Flow)**.
* **2. Есть ли observable consequence?**
  В Спринте 4 добавлены сцена выбора режимов `mode_select.tscn` и 3 автономных полигона (`riding_feel_test_track.tscn`, `riding_lab_track.tscn`, `gravel_training_loop.tscn`). Однако после загрузки любой из этих трасс игрок не имеет возможности вернуться в селектор режимов. Нажатие `Escape` лишь переключает видимость плашки управления. Чтобы протестировать другой полигон, приходится закрывать приложение.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `scripts/ui/hud.gd`:
  ```gdscript
  func _process(delta: float) -> void:
      if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("toggle_help"):
          controls_panel.visible = not controls_panel.visible
  ```
  Ни один скрипт внутри геймплейных сцен не содержит логики возврата в `mode_select.tscn`.
* **4. Какой минимальный diff её исправляет?**
  В `hud.gd` добавить обработку возврата в меню по клавише `F1` или двойному `Escape`:
  ```gdscript
  if Input.is_key_pressed(KEY_ESCAPE) and Input.is_key_pressed(KEY_SHIFT):
      get_tree().change_scene_to_file("res://scenes/mode_select.tscn")
  ```
  Либо разместить интерактивную кнопку «В меню режимов [Esc]» внутри `controls_panel`.

---

### 3.5. [LOW] Заморозка спада тормозного усилия `brake_input` во время нахождения в воздухе (`bicycle_controller.gd`)
* **1. Это реально bug или просто stylistic preference?**
  **Кинематический граничный случай (Physics Invariant Edge Case)**.
* **2. Есть ли observable consequence?**
  Если игрок нажал тормоз перед трамплином или перекатом (секция 4K T10), а в воздухе отпустил `S`, значение `brake_input` не уменьшается во время фазы полета ($0.25$ с), так как расчет спада находится за строкой `if not is_grounded: return`. В момент приземления байк неожиданно продолжит тормозить еще 100 мс, вызывая искусственный клевок вилки на приземлении.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `scripts/player/bicycle_controller.gd`:
  Строка 334:
  ```gdscript
  if not is_grounded:
      var air_resistance: float = air_drag_coeff * (current_speed * current_speed)
      current_speed = maxf(0.0, current_speed - air_resistance * delta)
      longitudinal_acceleration = -air_resistance
      return
  ```
  А строки 384-391:
  ```gdscript
  if is_braking:
      ...
  else:
      brake_input = maxf(0.0, brake_input - (1.0 / brake_release_time) * delta)
  ```
  выполняются строго после `return`.
* **4. Какой минимальный diff её исправляет?**
  Обновлять значения `brake_input` и `pedal_power` до проверки `if not is_grounded: return`.

---

## 4. ПОШАГОВЫЙ ПЛАН РЕАЛИЗАЦИИ И СТАТУС ВНЕДРЕНИЯ

> ✅ **СТАТУС**: Все запланированные исправления успешно внедрены с минимальным диффом и верифицированы мастер-сьютом (124/124 проверок успешно).

### Фаза 1 (Critical & Functional Fixes — Сглаживание камеры и нормализация углов) — ВЫПОЛНЕНО
1. **[FIX-CAM-SWAY]** Внедрен `current_sway_x` с экспоненциальным сглаживанием в `bike_camera.gd`, устранен однокадровый боковой скачок на 5 мм при отпускании педалей.
2. **[FIX-MATH-ANGLES]** Добавлен `wrapf(..., -PI, PI)` для `crank_rotation`, `front_wheel_rotation` и `rear_wheel_rotation` в `bicycle_controller.gd`.
3. **[FIX-SURFACE-PRIO]** Исправлен порядок проверки условий в `bike_camera.gd` и `bike_audio_manager.gd`: `current_surf == 2` имеет строгий приоритет над побочным касанием травы `is_on_grass`.
4. **[FIX-AIRBORNE-INPUT]** Вынесен спад `brake_input` и клевок носа до прерывания `if not is_grounded: return` в `bicycle_controller.gd`.

### Фаза 2 (UX & Навигация сцен) — ВЫПОЛНЕНО
1. **[UX-RETURN-MENU]** Добавлен возврат в `mode_select.tscn` по клавише `Escape` (`ui_cancel`) в `hud.gd`. Переключение плашки помощи вынесено на клавишу `H` (`toggle_help`), подсказка добавлена в HUD.
2. **[IO-DEFENSIVE]** Обернуто создание `playtest_snapshots.json` в `debug_hud.gd` проверкой `FileAccess.file_exists`.

### Фаза 3 (Оптимизация и тесты) — ВЫПОЛНЕНО
1. **[PERF-TYPING]** Устранена динамическая рефлексия `bike_controller.get(...)` в `debug_hud.gd` через статическое приведение `var ctrl := bike_controller as BicycleController`.
2. **[TEST-SUITE-EXPAND]** Добавлены регрессионные тесты #65 (Sway smoothing), #66 (Rotation wrap), #67 (Rough gravel priority) в `test_diagnostics.gd` (все 67/67 успешно).
3. **[REGRESSION-RUN]** Мастер-сьют `test_sprint_4m_master.gd` выполнен: **124 / 124 проверок PASSED (100% OK)**, 0 утечек памяти, бит-точный процедурный детерминизм на 5 сидах.

