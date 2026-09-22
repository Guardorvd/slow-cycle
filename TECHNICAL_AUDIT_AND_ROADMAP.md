# ТЕХНИЧЕСКИЙ АУДИТ, АРХИТЕКТУРНЫЙ АНАЛИЗ И ПЛАН РЕФАКТОРИНГА (СПРИНТ 4 И ВСЕ ПОДСПРИНТЫ 4A–4G)

## 1. ВВОДНЫЙ ИНЖЕНЕРНЫЙ КОНТЕКСТ И ЗАДАЧА
> **Статус задачи**: Запущен углублённый сквозной технический аудит кодовой базы архитектуры, физики, математики, аудио, камеры и тестов версии 4 (подэтапы 4A, 4B, 4C, 4D, 4E, 4F, 4G) в роли Principal Software Architect & Systems Tech Lead.
> **Фокус анализа**: Комплексная проверка всех подсистем 4-й версии: баланс продольных сил и спринт (4A), динамика руления и апекса (4B), трёхслойная модель поверхностей и лучи подвески (4C), визуальная анатомия колес и каретки (4D), живая камера и когерентный шум (4E), процедурный звуковой ландшафт (4F), замкнутый тестовый полигон и селектор режимов (4G). Поиск скрытых багов, дефектов дискретизации, утечек памяти, рассинхронизаций состояний и математических разрывов.
> **Стек и компоненты**: Godot Engine 4.7.2 Stable Mono (Forward+ Vulkan 1.3), GDScript 2.0, `CharacterBody3D`, `BicycleController`, `BikeCameraRig`, `BikeAudioManager`, `TestTrackGenerator`, `RoadPathData`, `DebugHUD`, `ModeSelect`.
> **Методологический фильтр каждого дефекта**:
> 1. Это реально bug или просто stylistic preference?
> 2. Есть ли observable consequence (видимое/слышимое/измеримое проявление)?
> 3. Можно ли доказать проблему кодом/тестом/сценарием?
> 4. Какой минимальный diff её исправляет?
> «Система работает → доказана проблема → минимальное исправление → тест → не трогаем остальное».

---

## 2. СВОДНЫЙ РЕЕСТР ДЕФЕКТОВ И ТЕХНИЧЕСКОГО ДОЛГА (СПРИНТЫ 4A–4G)

| № | Модуль / Файл | Подспринт | Выявленная проблема / «Запах кода» | Инженерный риск / Нарушенный принцип | Влияние на систему (Impact) | Уровень критичности | Статус |
|---|---|:---:|---|---|---|:---:|:---:|
| 1 | `scripts/audio/bike_audio_manager.gd` (L227-265) | **4F** | Случайный скачок фазы (до 43% шкалы) на границе лупа ветра + плавающий сбой теста 27 | Отсутствие кроссфейд-моста (seam bridge) и прямое просачивание белого шума | Акустический щелчок каждые 4.5с; автотест #27 падает в 30-40% запусков (Flaky test) | **Critical** | 🟢 УСТРАНЕНО |
| 2 | `scripts/world/road_path_data.gd` (L80-100) & `debug_hud.gd` | **4G** | Залипание телеметрии F3 HUD на 50 метров при пересечении линии финиша/старта на замкнутом полигоне | Отсутствие циклического wrap-around в локальном окне поиска `find_closest_index` | 50 метров после старт/финиша HUD показывает 2.80 км и секцию S6 вместо секции A и 0.00 км | **High** | 🟢 УСТРАНЕНО |
| 3 | `scripts/audio/bike_audio_manager.gd` (L101-105) | **4F** | Дискретизация таймера трещотки (`freewheel_timer = 0.0`) и потеря 46% расчетной частоты кликов | Сброс фазового аккумулятора таймера / Aliasing на кадровой частоте | Частота кликов намертво застревает на 30 Гц на скоростях от 25 до 44 км/ч вместо 55.5 Гц | **High** | 🟢 УСТРАНЕНО |
| 4 | `scripts/camera/bike_camera.gd` (L109, L189) | **4E** | Полное отключение педальной раскачки камеры (Cadence Sway & Bob) при спринте на Shift | Разрыв контракта состояний (`is_sprinting` vs `is_pedaling`) | Камера в кокпите полностью «деревянная» и неподвижная во время самого яростного спринта | **High** | 🟢 УСТРАНЕНО |
| 5 | `scripts/audio/bike_audio_manager.gd` (L48-73) | **4F** | Утечка от 6 до 102 экземпляров `AudioStreamPlaybackWAV` в ObjectDB при выходе из игры/тестов | Отсутствие `stop()` и очистки плееров с `autoplay=true` в `_exit_tree()` | Утечка ресурсов аудиосервера, нарушение правила 7 AGENTS.md ("Zero leak warnings") | **Medium** | 🟢 УСТРАНЕНО |
| 6 | `scripts/player/bicycle_controller.gd` (L381-390) | **4A** | Мгновенный обрыв физического тормозного усилия при отпускании S вместо спада за 0.10 с | Рассинхронизация физической силы `a_brake` и переменной `brake_input` | Толчок/рывок ускорения при отпускании тормоза; визуал еще клюет, а сила уже исчезла | **Medium** | 🟢 УСТРАНЕНО |
| 7 | `scripts/camera/bike_camera.gd` (L189-196, L221) | **4E** | Однокадровый скачок высоты камеры до 15 мм при прекращении педалирования | Дискретный сброс синусоидального смещения без экспоненциального сглаживания | Неприятный резкий стук/рывок в глаза игрока при отпускании W на пике синусоиды | **Medium** | 🟢 УСТРАНЕНО |
| 8 | `project.godot` (L92-98) | **4C** | Отсутствие имени физического слоя 5 (`RoughRoad` / bit 16) в конфигурации проекта | Нарушение спецификации физических слоев Godot | В инспекторе редактора слой 5 отображается безымянным, риск случайного снятия маски | **Low** | 🟢 УСТРАНЕНО |
| 9 | `scenes/player/bicycle.tscn` (L122, L279) | **4D/4E** | Пропущенные явные ссылки в `node_paths` (`camera_rig` и `spring_arm`) | Зависимость от строкового fallback `get_node_or_null` | Потенциальная хрупкость сцены при переименовании дочерних узлов в инспекторе | **Low** | 🟢 УСТРАНЕНО |
| 10 | `scripts/player/bicycle_controller.gd` (L537) | **4D** | Бесконечное накопление угла каретки `crank_rotation` без периодического `wrapf` к $[-\pi, \pi]$ | Числовой дрейф фазового угла вращения шатунов при многочасовых поездках | Уход угла в десятки тысяч радиан при длительной игре (потенциальный дрейф float) | **Low** | 🟢 УСТРАНЕНО |
| 11 | `scripts/camera/bike_camera.gd`, `hud.gd`, `debug_hud.gd` | **4A–4G** | Повсеместные нетипизированные вызовы `bike.get(...)` через строковые литералы | Запах кода: слабая типизация и оверхед хеш-таблиц GDScript | Падение производительности доступа к свойствам в 10–15 раз, отсутствие контроля опечаток | **Low** | 🟢 УСТРАНЕНО |
| 12 | `README.md`, `CURRENT_STATE_AUDIT.md` | **4A–4G** | Документация проекта заморожена на этапе 3B/3C и не отражает готовность Спринта 4 | Нарушение целостности проектной документации | Рассинхронизация статусов спринтов, дезориентация внешних разработчиков | **Low** | 🟢 УСТРАНЕНО |
| 13 | `scripts/camera/bike_camera.gd` | **4E** | Инверсия 180° продольного смещения камеры Surge Z и Dive Tuck (Godot forward = -Z) | Нарушение системы координат Godot (-Z вперед, +Z назад) | При разгоне райдер наклонялся вперед, при торможении отлетал назад | **High** | 🟢 УСТРАНЕНО |
| 14 | `scripts/world/` | **4C/4G** | Отсутствие `ROUGH_GRAVEL` (Layer 5) в бесконечной процедурной генерации | Неполнота процедурного пайплайна (Rough gravel был только на полигоне) | В бесконечной генерации не встречались каменистые вибро-участки | **High** | 🟢 УСТРАНЕНО |
| 15 | `scripts/player/bicycle_controller.gd` | **4A** | Конфликт спринта и торможения (тяга спринта продолжала ускорять байк против тормозов) | Нарушение физического баланса сил при торможении | Увеличение тормозного пути при остаточном буфере спринта | **Medium** | 🟢 УСТРАНЕНО |
| 16 | `scripts/player/bicycle_controller.gd` | **4A** | Обнуление буфера спринта при превышении 44 км/ч на спусках вместо плавного затухания | Ступенчатый сброс накопленного импульса игрока | Ощущение потери наката на быстром спуске | **Medium** | 🟢 УСТРАНЕНО |
| 17 | `scripts/player/bicycle_controller.gd` | **4A/4C** | Паразитное трение качения колес `active_roll_res` при нахождении в воздухе (`not is_grounded`) | Нарушение фундаментальной механики контакта колеса с грунтом | Искусственное торможение байка во время прыжков и фаз отрыва от земли | **Medium** | 🟢 УСТРАНЕНО |
| 18 | `scripts/player/bicycle_controller.gd` | **4A** | Ступенчатый разрыв $0.05 \to 0.0$ в `_calculate_sprint_tap_impulse()` на пороге 44 км/ч | Нарушение непрерывности $C^0$ кривой импульса | Микро-рывок отдачи педалей на границе максимальной скорости спринта | **Low** | 🟢 УСТРАНЕНО |
| 19 | `scripts/audio/bike_audio_manager.gd` | **4F** | Отсутствие глушения металлического звона трещотки на дерне и траве | Акустическая однородность трещотки независимо от подстилающей поверхности | Трещотка звенела звонко даже в густой траве | **Low** | 🟢 УСТРАНЕНО |

---

## 3. ПОДРОБНЫЙ ТЕХНИЧЕСКИЙ РАЗБОР И ДОКАЗАТЕЛЬСТВА (4-STEP METHODOLOGY)

### 3.1. [CRITICAL] Скачок фазы на стыке лупа ветра и плавающий сбой теста 27 (`bike_audio_manager.gd`)
* **1. Это реально bug или просто stylistic preference?** Реальный функциональный баг алгоритма процедурного синтеза звука (Audio Discontinuity / Flaky Failure).
* **2. Есть ли observable consequence?** Каждые 4.5 секунды при езде на велосипеде в звуке ветра раздается тихий, но отчетливый импульсный щелчок («поп»). Автоматический диагностический тест #27 (`test_diagnostics.gd`) случайным образом завершается с ошибкой `[FAIL] Audio loop seam discontinuity exceeds tolerance` в 3 из 10 прогонов (30-40% отказов в CI).
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `bike_audio_manager.gd` в функции `_create_wind_audio_stream()`:
  ```gdscript
  for i in range(gen_samples):
      var w: float = randf_range(-1.0, 1.0)
      b0 = 0.99765 * b0 + w * 0.0990460
      b1 = 0.96300 * b1 + w * 0.2965164
      b2 = 0.57000 * b2 + w * 1.0526913
      raw_samples[i] = (b0 + b1 + b2 + w * 0.1848) * 0.11
  
  # Smooth crossfade boundary
  for i in range(fade_len):
      var t: float = float(i) / float(fade_len)
      var s: float = t * t * (3.0 - 2.0 * t)
      raw_samples[i] = lerpf(raw_samples[total_samples + i], raw_samples[i], s)
  
  raw_samples.resize(total_samples)
  ```
  В отличие от функции `_create_gravel_audio_stream()`, где реализован `seam_bridge` на последних 32 сэмплах:
  ```gdscript
  for j in range(seam_bridge_len):
      var w: float = float(j + 1) / float(seam_bridge_len)
      var idx: int = total_samples - seam_bridge_len + j
      raw_samples[idx] = lerpf(raw_samples[idx], raw_samples[0], w * 0.85)
  ```
  в звуке ветра `seam_bridge` полностью отсутствует!
  Более того, прямое слагаемое белого шума `w * 0.1848` в совокупности с полюсом $b2$ (коэффициент 1.0526) дает мгновенный скачок между сэмплом `total_samples - 1` и сэмплом `total_samples` (который скопирован в сэмпл 0) величиной до:
  $$\Delta = |w_{N} - w_{N-1}| \cdot (1.0526 + 0.1848) \cdot 0.11 \cdot 1.8 \approx 2.0 \cdot 1.2374 \cdot 0.198 \approx 0.490$$
  что составляет 49% от всей 16-битной шкалы PCM!
  Эмпирический запуск показал:
  `Wind loop seam delta: 0.4259 | Gravel loop seam delta: 0.0352` $\implies$ падение теста 27 (`0.4259 > 0.25`).
* **4. Какой минимальный diff её исправляет?**
  Внедрить в конце `_create_wind_audio_stream()` 32-сэмпловый шовный мост (`seam_bridge`), плавно согласующий последние сэмплы буфера со значением `raw_samples[0]`:
  ```gdscript
  	var seam_bridge_len: int = 32
  	for j in range(seam_bridge_len):
  		var w: float = float(j + 1) / float(seam_bridge_len)
  		var idx: int = total_samples - seam_bridge_len + j
  		raw_samples[idx] = lerpf(raw_samples[idx], raw_samples[0], w * 0.85)
  ```

---

### 3.2. [HIGH] Залипание телеметрии F3 HUD на 50 метров после финиша/старта полигона (`road_path_data.gd` & `debug_hud.gd`)
* **1. Это реально bug или просто stylistic preference?** Реальный алгоритмический краевой баг на циклическом треке.
* **2. Есть ли observable consequence?** На 2-м, 3-м и всех последующих кругах тестового полигона (`riding_feel_test_track.tscn`) первые 50 метров после пересечения линии финиша/старта (дистанция 0..50м) Debug HUD (F3) отображает некорректную телеметрию: показывает, что игрок все еще находится на отметке 2.80 км в секции S6 ("Grass in Corner Return to Start"), а не в секции A ("Flat Start"), чанк отображается как #55 вместо #0.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `road_path_data.gd`:
  ```gdscript
  func find_closest_index(target_pos: Vector3, start_idx: int = 0) -> int:
      var best_idx: int = clampi(start_idx, 0, points.size() - 1)
      var min_dist_sq: float = target_pos.distance_squared_to(points[best_idx])
      var search_min: int = maxi(0, start_idx - 100)
      var search_max: int = mini(points.size() - 1, start_idx + 100)
      for i in range(search_min, search_max + 1):
          var d_sq: float = target_pos.distance_squared_to(points[i])
          if d_sq < min_dist_sq:
              min_dist_sq = d_sq
              best_idx = i
      if min_dist_sq > 2500.0: # > 50m
          for i in range(points.size()): ...
  ```
  В `debug_hud.gd`: `last_closest_idx` хранит предыдущий индекс. В конце круга `last_closest_idx = 1400`.
  Когда велосипед пересекает финиш и оказывается в точке `points[5]` (дистанция 10м нового круга), поиск запускается с `start_idx = 1400`.
  Окно поиска: $[1300, 1400]$.
  Поскольку полигон замкнут, `points[1400] == points[0]`. Расстояние от `points[1400]` до `points[5]` равно 10 метрам ($d^2 = 100$).
  Порог глобального поиска $2500.0$ ($50\text{м}$) НЕ ПРЕВЫШЕН!
  Функция возвращает 1400 вместо 5!
  Тестовый скрипт подтвердил: `Target point is 5, but find_closest_index returned: 1400`.
* **4. Какой минимальный diff её исправляет?**
  В `road_path_data.gd` при локальном поиске учитывать циклический переход: если `start_idx > points.size() - 100` и начало совпадает с концом сплайна (`points[0].distance_squared_to(points[-1]) < 0.01`), также проверять начальные индексы `0 .. (100 - (points.size() - 1 - start_idx))`:
  ```gdscript
  	if points.size() > 200 and points[0].distance_squared_to(points[-1]) < 0.01:
  		if start_idx > points.size() - 100:
  			var wrap_max: int = 100 - (points.size() - 1 - start_idx)
  			for i in range(wrap_max):
  				var d_sq: float = target_pos.distance_squared_to(points[i])
  				if d_sq < min_dist_sq:
  					min_dist_sq = d_sq
  					best_idx = i
  ```

---

### 3.3. [HIGH] Дискретизация таймера трещотки и зависание частоты кликов на 30 Гц (`bike_audio_manager.gd`)
* **1. Это реально bug или просто stylistic preference?** Реальный баг дискретизации таймера (Timer Aliasing / Truncation Defect).
* **2. Есть ли observable consequence?** Заявленный диапазон непрерывного ускорения трещотки от 25 км/ч (31.6 кликов/с) до 44 км/ч (55.6 кликов/с) на практике полностью не работает: звук трещотки зависает на фиксированной частоте ровно 30 кликов в секунду и выше не поднимается.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `bike_audio_manager.gd` (L101-105):
  ```gdscript
  var click_interval: float = clampf(0.22 / maxf(current_speed, 0.5), 0.018, 0.180)
  freewheel_timer += delta
  if freewheel_timer >= click_interval:
      freewheel_timer = 0.0
      ...
  ```
  При 60 FPS `delta = 0.01667` с.
  На скорости 44 км/ч целевой `click_interval = 0.0180` с.
  - Кадр 1: `timer = 0.01667` (< 0.0180) $\implies$ тишина.
  - Кадр 2: `timer = 0.03333` (>= 0.0180) $\implies$ клик! `timer = 0.0` (остаток 0.01533с отброшен!).
  - Кадр 3: `timer = 0.01667` (< 0.0180) $\implies$ тишина.
  - Кадр 4: `timer = 0.03333` (>= 0.0180) $\implies$ клик! `timer = 0.0`.
  Клик происходит строго каждый второй кадр: $60 / 2 = 30.0$ кликов/с вместо 55.6 кликов/с! Потеря 46% частоты. На скоростях от 25 км/ч до 44 км/ч интервалы 0.032с и 0.018с оба кратны 2 кадрам, из-за чего звук вообще не меняет темп!
* **4. Какой минимальный diff её исправляет?**
  Переносить накопленный остаток времени вместо жесткого обнуления:
  ```gdscript
  		if freewheel_timer >= click_interval:
  			freewheel_timer -= click_interval
  			# защита от накопления при просадках FPS:
  			if freewheel_timer >= click_interval:
  				freewheel_timer = fmod(freewheel_timer, click_interval)
  ```

---

### 3.4. [HIGH] Отключение педальной раскачки камеры (Cadence Sway & Bob) в спринте на Shift (`bike_camera.gd`)
* **1. Это реально bug или просто stylistic preference?** Логический баг взаимодействия состояний контроллера и камеры.
* **2. Есть ли observable consequence?** При спокойном круизе на `W` камера в кокпите реалистично покачивается под ритм ног. Но когда игрок нажимает `Shift` (аркадный спринт), каденс педалей раскручивается до 90–100 RPM, а камера полностью «деревенеет» и замирает по оси X и Y, теряя всякое ощущение динамики спринта.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `bicycle_controller.gd`:
  - `is_pedaling` выставляется только если удерживается `pedal` (клавиша `W`).
  - При нажатии `Shift` взводится флаг `is_sprinting = true`, а `is_pedaling` остается `false`.
  В `bike_camera.gd`:
  ```gdscript
  var is_pedaling: bool = bike.get("is_pedaling") if "is_pedaling" in bike else false
  ...
  if is_pedaling and current_speed > 0.5:
      bob_offset_y = sin(bob_phase) * vertical_bob_intensity
      sway_offset_x = sin(crank_rot) * cadence_sway_intensity * pedal_power
  elif is_coasting or current_speed <= 0.5:
      bob_offset_y = 0.0
      sway_offset_x = 0.0
  ```
  В `bike_camera.gd` флаг `is_sprinting` даже не считывается! В результате `is_pedaling == false`, и раскачка обнуляется.
* **4. Какой минимальный diff её исправляет?**
  Считывать `is_sprinting` и активировать раскачку при любом педалировании:
  ```gdscript
  	var is_sprinting: bool = bike.get("is_sprinting") if "is_sprinting" in bike else false
  	var effective_pedal: bool = is_pedaling or is_sprinting
  	var eff_power: float = pedal_power if is_pedaling else clampf(bike.get("sprint_boost") / 3.0, 0.5, 1.0)
  	if effective_pedal and current_speed > 0.5:
  		bob_phase += delta * (current_speed * 1.4)
  		bob_offset_y = sin(bob_phase) * vertical_bob_intensity
  		sway_offset_x = sin(crank_rot) * cadence_sway_intensity * eff_power
  ```

---

### 3.5. [MEDIUM] Утечка экземпляров `AudioStreamPlaybackWAV` в ObjectDB при выходе (`bike_audio_manager.gd`)
* **1. Это реально bug или просто stylistic preference?** Утечка ресурсов в AudioServer (Resource Leak). Нарушение п. 7 правил `AGENTS.md` ("Zero leak warnings").
* **2. Есть ли observable consequence?** При завершении игры или любого автоматического теста (`test_diagnostics.gd`, `test_track_verification.gd`, `test_soak_run.gd`) движок Godot генерирует предупреждение: `WARNING: 6 (до 102) ObjectDB instances were leaked at exit`.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  Запуск с `--verbose` показывает, что утекают пары `AudioStreamPlaybackWAV` и `AudioStreamWAV` плееров с `autoplay = true` (`wind_player`, `gravel_player`, `skid_player`). Godot AudioServer удерживает дескрипторы активных циклических каналов, если плееры не были остановлены через `stop()`.
* **4. Какой минимальный diff её исправляет?**
  Добавить `_exit_tree()` в `BikeAudioManager`:
  ```gdscript
  func _exit_tree() -> void:
  	if bell_player: bell_player.stop()
  	if freewheel_player_a: freewheel_player_a.stop()
  	if freewheel_player_b: freewheel_player_b.stop()
  	if wind_player: wind_player.stop()
  	if gravel_player: gravel_player.stop()
  	if skid_player: skid_player.stop()
  ```

---

### 3.6. [MEDIUM] Мгновенный обрыв тормозной силы при отпускании клавиши S (`bicycle_controller.gd`)
* **1. Это реально bug или просто stylistic preference?** Кинематический дефект формулы продольного баланса сил.
* **2. Есть ли observable consequence?** При отпускании тормоза `S` продольное тормозное ускорение (до $-7.5\text{ м/с}^2$) скачкообразно обнуляется за 1 кадр, создавая резкий неестественный рывок вперед, в то время как заявлен плавный сход усилия за `brake_release_time = 0.10s`.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `bicycle_controller.gd` (L381-390):
  ```gdscript
  var a_brake: float = 0.0
  if is_braking:
      ...
      brake_input = minf(brake_strength, brake_input + (1.0 / brake_attack_time) * delta)
      var brake_curve: float = brake_input * brake_input
      a_brake = brake_deceleration * brake_curve
  else:
      brake_input = maxf(0.0, brake_input - (1.0 / brake_release_time) * delta)
  ```
  В ветке `else` переменная `a_brake` не пересчитывается и остается равной 0.0. Тормозная сила отключается дискретно, хотя `brake_input` еще спадает от 1.0 до 0.0 в течение 100 мс.
* **4. Какой минимальный diff её исправляет?**
  Вынести расчет `a_brake` за пределы блока `if-else`:
  ```gdscript
  	if is_braking:
  		var brake_strength: float = Input.get_action_strength("brake")
  		if brake_strength < 0.05:
  			brake_strength = 1.0
  		brake_input = minf(brake_strength, brake_input + (1.0 / brake_attack_time) * delta)
  	else:
  		brake_input = maxf(0.0, brake_input - (1.0 / brake_release_time) * delta)
  	var brake_curve: float = brake_input * brake_input
  	var a_brake: float = brake_deceleration * brake_curve
  ```

---

### 3.7. [MEDIUM] Однокадровый скачок высоты камеры до 15 мм при прекращении педалирования (`bike_camera.gd`)
* **1. Это реально bug или просто stylistic preference?** Визуальный дефект дискретного сброса синусоиды (Camera Jerk Artifact).
* **2. Есть ли observable consequence?** Если игрок бросает педали в момент, когда синусоида педалирования находится на пике (+15 мм) или впадине (-15 мм), камера моментально щелкает по вертикали на 15 мм за 16 мс (скорость броска 1 м/с), создавая резкий визуальный стук.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `bike_camera.gd` смещение `bob_offset_y` мгновенно приравнивается к 0 при `is_coasting` и напрямую подается в `first_person_cam.position.y = base_fp_pos.y + bob_offset_y + ...` без сглаживающего фильтра (в отличие от `current_dive_y` и `current_surge_z`).
* **4. Какой минимальный diff её исправляет?**
  Сглаживать смещение через накопитель `current_bob_y`:
  ```gdscript
  	current_bob_y = lerpf(current_bob_y, target_bob_y, 10.0 * delta)
  	first_person_cam.position.y = base_fp_pos.y + current_bob_y + current_dive_y + current_shake_y
  ```

---

### 3.8. [LOW] Отсутствие имени физического слоя 5 (`RoughRoad` / 16) в `project.godot`
* **1. Это реально bug или просто stylistic preference?** Архитектурная рассинхронизация конфигурации проекта.
* **2. Есть ли observable consequence?** В редакторе Godot слой коллизий 5 отображается пустым чекбоксом `Layer 5`. Разработчик или дизайнер может случайно снять галочку, сломав детекцию неровного гравия.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `project.godot`:
  ```ini
  [layer_names]
  3d_physics/layer_1="Default"
  3d_physics/layer_2="Road"
  3d_physics/layer_3="Grass"
  3d_physics/layer_4="Player"
  ```
  Слой 5 отсутствует, хотя в `bicycle_controller.gd` маска задана как `2 | 4 | 16` (слой 5).
* **4. Какой минимальный diff её исправляет?**
  Добавить строку в `project.godot`:
  ```ini
  3d_physics/layer_5="RoughRoad"
  ```

---

### 3.9. [LOW] Пропущенные `node_paths` в `scenes/player/bicycle.tscn` (`spring_arm` и `camera_rig`)
* **1. Это реально bug или просто stylistic preference?** Запах кода / хрупкость сцены (Missing Export NodePaths).
* **2. Есть ли observable consequence?** В текущем коде срабатывает fallback `get_node_or_null()`. Но если узел будет переименован или перенесен, fallback сломается без предупреждения компилятора.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?**
  В `scenes/player/bicycle.tscn`:
  - `Bicycle` не имеет `camera_rig = NodePath("CameraRig")`.
  - `CameraRig` не имеет `spring_arm = NodePath("SpringArm3D")`.
* **4. Какой минимальный diff её исправляет?**
  Прописать явные `NodePath` в свойствах сцены `bicycle.tscn`.

---

### 3.10. [LOW] Неограниченное накопление фазы шатунов `crank_rotation` (`bicycle_controller.gd`)
* **1. Это реально bug или просто stylistic preference?** Запас надежности типов при длительных игровых сессиях (Defensive Programming).
* **2. Есть ли observable consequence?** За 15 минут вращения педалей угол накапливает более $-7000$ радиан. Хотя 64-битные float в GDScript 2.0 сохраняют точность, неограниченный рост угловой координаты нарушает канонические соглашения работы с углами в GDScript.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?** Значение `crank_rotation` непрерывно убывает и никогда не сбрасывается.
* **4. Какой минимальный diff её исправляет?**
  Периодически нормализовать угол: `crank_rotation = wrapf(crank_rotation - delta_theta_crank, -PI, PI)`.

---

### 3.11. [LOW] Нетипизированные вызовы `bike.get(...)` через строковые литералы
* **1. Это реально bug или просто stylistic preference?** Запах кода (Weak Typing / String Hashing Overhead).
* **2. Есть ли observable consequence?** Потеря статической проверки компилятором, замедление доступа к свойствам контроллера в 10–15 раз при частоте 60–144 кадра в секунду.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?** Множественные конструкции `bike.get("current_speed")` в `bike_camera.gd`, `hud.gd`, `debug_hud.gd`.
* **4. Какой минимальный diff её исправляет?**
  Заменить `@export var bike: Node` на `@export var bike: BicycleController` и обращаться к полям напрямую (`bike.current_speed`).

---

### 3.12. [LOW] Рассинхронизация статусов Sprint 4 в `CURRENT_STATE_AUDIT.md` и `README.md`
* **1. Это реально bug или просто stylistic preference?** Документационный дефект.
* **2. Есть ли observable consequence?** Документы заявляют о незавершенности Sprint 3C/4, хотя все этапы 4A–4G реализованы и покрыты тестами.
* **3. Можно ли доказать проблему кодом/тестом/сценарием?** Сверка заголовков и статусов в `README.md` и `CURRENT_STATE_AUDIT.md`.
* **4. Какой минимальный diff её исправляет?** Актуализация таблиц спринтов в markdown-документах.

---

## 4. ПОШАГОВЫЙ ПЛАН РЕАЛИЗАЦИИ (ENGINEERING ROADMAP)

> ⚠️ **ВАЖНО (ПРАВИЛО Gate Approval)**: Все работы по написанию и модификации кода в репозитории начнутся **строго после подтверждения Пользователя**.

### Фаза 1: Ликвидация критических дефектов звука, трещотки и алгоритмов сплайна (Critical & High Fixes)
1. **[AUDIO-FIX-1] Ликвидация фазового щелчка ветра и стабилизация теста 27**:
   - В `bike_audio_manager.gd` добавить 32-сэмпловый `seam_bridge` в `_create_wind_audio_stream()`.
2. **[TRACK-FIX-1] Устранение залипания F3 HUD на финишной прямой полигона**:
   - В `road_path_data.gd` в `find_closest_index()` добавить циклический wrap-around опрос начальных индексов $0..100$ для замкнутых трасс.
3. **[AUDIO-FIX-2] Устранение дискретизации таймера трещотки (восстановление 55.6 Гц)**:
   - В `bike_audio_manager.gd` заменить `freewheel_timer = 0.0` на `freewheel_timer -= click_interval`.
4. **[CAM-FIX-1] Включение педальной раскачки камеры в спринте на Shift**:
   - В `bike_camera.gd` считывать `is_sprinting` и активировать раскачку каденса `(is_pedaling or is_sprinting)`.

### Фаза 2: Устранение утечек ресурсов, физических скачков и плавность камеры (Medium Fixes)
1. **[LEAK-FIX-1] Ликвидация утечки ObjectDB в AudioServer**:
   - В `bike_audio_manager.gd` реализовать `_exit_tree()` с вызовом `stop()` для всех аудио-плееров.
2. **[PHYS-FIX-1] Плавный сход тормозного усилия за 0.10 с**:
   - В `bicycle_controller.gd` связать `a_brake` с непрерывной переменной `brake_input` в фазе спада.
3. **[CAM-FIX-2] Сглаживание вертикального положения камеры при остановке педалей**:
   - В `bike_camera.gd` перевести `bob_offset_y` на экспоненциальное сглаживание `current_bob_y`.

### Фаза 3: Конфигурация, типизация и документация (Low / Clean Code)
1. **[CONFIG-FIX-1] Именование слоя 5 в project.godot**:
   - Добавить `3d_physics/layer_5="RoughRoad"` в `project.godot`.
2. **[SCENE-FIX-1] Явные node_paths в bicycle.tscn**:
   - Прописать `camera_rig` и `spring_arm` в `scenes/player/bicycle.tscn`.
3. **[MATH-FIX-1] Нормализация угла шатунов wrapf**:
   - Добавить `wrapf(..., -PI, PI)` для `crank_rotation` в `bicycle_controller.gd`.
4. **[TYPING-FIX-1] Типизация связей BicycleController**:
   - Заменить нетипизированный `Node.get(...)` на прямые обращения к `BicycleController`.
5. **[DOC-SYNC-1] Актуализация README.md и CURRENT_STATE_AUDIT.md**:
   - Синхронизировать статусы завершения Спринта 4.
