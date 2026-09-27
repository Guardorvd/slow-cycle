# Slow Cycle — Road & World Generation Specification (v5.2.0)

## 1. Концепция: Естественный MTB-Рельеф и Контролируемый Отрыв Колес

В отличие от ранних версий спецификации, где дорога рассматривалась как непрерывно приклеенная к колесам плоскость, архитектура **v5.1.0 (Спринт 5: Горный мир)** основывается на ключевом правиле:

> [!IMPORTANT]
> **Главный инвариант:**  
> **Запрещено не отрывание колёс. Запрещено неконтролируемое / непреднамеренное отрывание колёс.**  
> В реальном MTB-катании колеса постоянно разгружаются на гребнях холмов, корни и уступы дают микро-дропы, а намеренные прыжки со скатом приземления создают ощущение полета и высоты. Задача генератора — создавать безопасную геометрию под существующую физику велосипеда.

---

## 2. Структура Данных: `RoadPathData`

Центральным источником правды для дороги является расширенная структура `RoadPathData`:

```gdscript
class_name RoadPathData
extends RefCounted

var points: PackedVector3Array                 # Опорные точки осевой линии
var tangents: PackedVector3Array               # Нормализованные касательные (векторы курса)
var normals: PackedVector3Array                # Ортонормальные нормали поверхности
var binormals: PackedVector3Array              # Бинормали (векторы поперечной оси)
var cumulative_distances: PackedFloat32Array   # Дистанция s вдоль дуги (для точного Recovery и стриминга)
var slopes: PackedFloat32Array                 # Геометрический уклон в градусах: rad_to_deg(asin(tangent.y))
var curvatures: PackedFloat32Array             # Кривизна kappa = 1 / Radius
var segment_types: PackedInt32Array            # Тип драматургического сегмента
var surface_contact_states: PackedByteArray    # Режим контакта SurfaceContactMode (GROUNDED, MICRO_DROP, AIRBORNE, LANDING)
var banking_angles: PackedFloat32Array         # Поперечный крен полотна в виражах (градусы)
var sight_distances: PackedFloat32Array        # Дистанция открытой видимости вперед (метры)
var branch_id: int = 0                         # Идентификатор ветви в графе развилок
```

---

## 3. Машинный Контракт Геометрии (`RoadGenerationContract` v5.1.0)

Класс `RoadGenerationContract` формализует физические и математические границы:

| Параметр | Символ / Имя | Пределы | Назначение |
|---|---|---|---|
| **Уклон спуска** | `MAX_GRADE_DOWNHILL` | $-14.0^\circ$ | Максимальный гравитационный разгон (без выхода на закритические скорости) |
| **Крейсерский спуск** | `CRUISE_GRADE` | $-6.0^\circ$ | Равновесный накат со стрекотом трещотки на 25–30 км/ч |
| **Уклон подъема** | `MAX_GRADE_UPHILL` | $+5.0^\circ$ | Физический предел мускульного педалирования |
| **Производная уклона** | `MAX_GRADE_CHANGE_PER_METER`| $1.2^\circ/\text{м}$ | Скорость изменения уклона по длине дуги: $\|\Delta \text{slope}\| / \Delta s$ |
| **Минимальный радиус** | `MIN_RADIUS` | $18.0\text{ м}$ | Предел устойчивости шасси в шпильках серпантина |
| **Максимальная кривизна**| `MAX_CURVATURE` | $0.0556\text{ м}^{-1}$ | $1 / 18.0\text{ м}$ |
| **Производная кривизны**| `MAX_CURVATURE_CHANGE_PER_METER`| $0.003\text{ м}^{-2}$| Скорость нарастания кривизны: $\|\Delta \kappa\| / \Delta s$ (клотоидный переход) |
| **Шаг дискретизации** | `NOMINAL_SAMPLE_SPACING` | $2.0\text{ м}$ | Базовое расстояние между сэмплами |
| **Предельный шаг** | `MAX_SAMPLE_SPACING` | $2.5\text{ м}$ | Лимит, превышение которого считается разрывом сэмплов (`ERR_SAMPLE_GAP`) |
| **Стык координат ($C^0$)**| `MAX_SEAM_POS_ERROR` | $0.001\text{ м}$ | 1 мм (абсолютное исключение щелей и стуков trimesh коллизии) |
| **Стык курса ($C^1$)** | `MAX_SEAM_TANGENT_ANGLE_DEG` | $0.2^\circ$ | Предел углового излома направления между чанками |
| **Стык уклона** | `MAX_SEAM_SLOPE_DELTA_DEG` | $0.1^\circ$ | Предел вертикального скачка |
| **Ширина singletrack** | `ROAD_STANDARD_WIDTH` | $1.8\text{ м}$ | Узкое основное полотно; технические плечи могут сужаться до 1.35м |
| **Ширина узла развилки** | `ROAD_FORK_EXPANDED_WIDTH` | $3.6\text{ м}$ | Плавное расширение последних 25м подхода к разветвлению |
| **Поперечный крен** | `MAX_BANKING_ANGLE_DEG` | $\pm 8.0^\circ$ | Визуальный контруклон |

---

## 3.1. Runtime-модель развилок (v5.2.0)

- `RoadGraph` хранит runtime-узел развилки и два исходящих ребра с постоянными `branch_index`: `0 = LEFT`, `1 = RIGHT`. На ребре лежит построенный `RoadPathData`; его `branch_id` определяет маршрут, включаемый после выбора.
- `ForkDecisionModel` сравнивает игрока с фактическими осевыми линиями обеих ветвей. Аналитическая Y-модель остаётся для unit-тестов без геометрии.
- Seed назначает веткам разные роли `FLOW` и `TECHNICAL`. Flow открывается дугами/роллерами и спокойным спуском; technical получает шпильку и контролируемый прыжковый профиль с посадкой. Обе роли используют существующую grammar и validator.
- Перед каждой развилкой создаётся `BRAKING_ZONE` с минимум 45м видимости. Последние 25м расширяются smoothstep от 1.8 до 3.6м; стык внутренних кромок плеч проверяется отдельно.
- Fork spacing пока остаётся дистанционным планировщиком с seed-зависимым разбросом. Макрорельеф и поиск площадки развилки по форме склона в эту итерацию не входят.

Это цельный runtime-срез, но ещё не финальная генерация MTB-мира: нет макромодели горы/долин, merge-узлов и оценки маршрута целиком.

## 3.2. Seeded Macro Elevation Profile (P1.0)

`MountainProfile` (`scripts/world/mountain_profile.gd`) — чистая математическая модель высоты вдоль дистанции маршрута. Инициализируется явными `world_seed`, `route_identity` и стартовой высотой; `sample_at(s)` возвращает elevation, grade, производную grade, классификацию `RIDGE / BENCH / VALLEY` и индекс 300-метрового отчётного интервала.

Профиль строится как вертикальная скорость `dh/ds` по arc length — сумма базового спуска `-0.09` и трёх синусоид с амплитудами `0.020 / 0.013 / 0.007`, длинами волн `1800 / 600 / 300` м и фазами от стабильного ключа `(version, seed, route_identity, harmonic_index)`. Высота — точный интеграл той же функции, grade вычисляется как `asin(dh/ds)`, производная grade — аналитически. Поэтому высота, grade и производная grade гладкие, включая границы отчётных интервалов. Запросы независимы, O(1) по времени и памяти; результат не зависит от порядка sampling. Теоретический grade диапазон приблизительно `-7.47°…-2.87°`, остаётся внутри RoadGenerationContract. Средний перепад — около 90 м/км; на 12 км ожидаемый drop ограничен примерно 1065–1095 м, seed-батарея измерила 1070–1090 м.

Ограничение P1.0 снято интеграцией P1.1 ниже: профиль теперь влияет на дорожную ось и дальнюю поверхность terrain. Сам по себе этот bounded overlay ещё не является route planner и не задаёт разные макровысотные бюджеты альтернативам.

## 3.3. Macro Profile Runtime Integration (P1.1)

`RoadLogic` добавляет к локальной геометрии ограниченную макропоправку `0.35 × (profile_elevation - mean_descent_backbone)`. Средний descent backbone уже присутствует в локальных фазах; добавочная bounded составляющая вводит длинноволновый рельеф и сохраняет grammar-generated локальные повороты, уклоны и контактные события. После поправки пересчитываются sample arc distances, `slopes`, `tangents`, `normals` и binormals до валидации/построения mesh/collision. Fallback получает ту же поправку. Первый tangent каждого fork arm сохраняет касательную узла.

Обе fork arms разделяют одну profile instance и root seed. Левая arm использует накопленную дистанцию родительского пути; у дочерней arm profile origin равен общей fork distance плюс `0.9m` (половина nominal 1.8m полотна), потому что branch centerline начинает от внутренней кромки и её локальная дистанция обнуляется. Так начальные внутренние кромки сохраняют watertight apex, а профиль далее следует фактической branch distance. `RoadPathData.macro_elevation_offsets` хранится параллельно sample arrays и копируется/обрезается вместе с ними.

`TerrainCarver` теперь задаёт дальние точки относительно высоты дорожной оси: абсолютная высота центра пути плюс боковая разность существующей macro/detail noise. Поэтому полосы рельефа поднимаются/опускаются с дорогой; боковой профиль, классификация и noise сохраняются. Тестовая интеграция подтверждает точное совпадение row кромки terrain с краями singletrack и корректный пересчёт far row.

Предел: blend `0.35` намеренно консервативен, чтобы additive grade не вытолкнул существующие технические фазы за contract envelope. У разных ветвей общая macro-высота; различия локальной геометрии остаются в `RoadGrammar`. Планирование отдельного высотного профиля/бюджета для каждой альтернативы — следующий этап route intent.

## 3.4. Deterministic Branch Route Intent (P2.0)

После выбора ветки `RoadGrammar.set_route_style` теперь задаёт девять authored 50m фаз. FLOW следует последовательности плавных cruise/recovery отрезков с двумя crest/micro-drop событиями и одним fast descent; его первые 450m не содержат switchback или AIRBORNE контактов. TECHNICAL строит две braking→switchback→recovery связки с противоположным направлением поворота, затем micro-drop и recovery. После authored opening обе ветви возвращаются в существующий seeded weighted FSM. BALANCED и общие envelope/validator параметры не менялись.

Production `RoadLogic` seed-батарея (4 world seed × 2 style seed × 2 стиля, повтор каждого входа) подтвердила signature distinction и детерминизм. Максимальная измеренная кривизна FLOW составила 0.00166m⁻¹, TECHNICAL — 0.05263m⁻¹ при контрактном максимуме 0.05556m⁻¹; максимальный sample gap — 2.022m при лимите 2.5m. Все chunks валидны.

Историческое ограничение airborne из первых прогонов устранено в REVIEW-FIX-01: убран лишний вертикальный offset поверх нисходящей касательной, а длина хорды в AIRBORNE удерживается внутри контракта. Валидатор и пределы `RoadAirborneContract` не ослаблялись. Генерируемый AIRBORNE с посадкой прошёл validator по четырём seeds; метрики и harness приведены в `TEST_PLAN.md`.

## 3.5. Fork-site endpoint preflight (P2.1a)

`ForkSitePlanner` — чистый evaluator уже сгенерированной точки-кандидата, подключённый в `ChunkStreamer._is_safe_fork_site()` до fork approach generation. После seeded минимального расстояния streamer проверяет доступный endpoint; отказ не вызывает `prepare_fork_approach`, widening или graph/branch/mesh mutation. Обычная генерация добавляет очередной chunk, после чего следующий доступный endpoint может быть оценён тем же способом. Planner не потребляет RNG.

В текущем срезе проверяются последние 25 м centerline: согласованность размеров массивов, конечность sample values, sample spacing до `MAX_SAMPLE_SPACING`, ширина не уже `ROAD_STANDARD_WIDTH`, grade и curvature по действующему `RoadGenerationContract`, только `GROUNDED` contact state и валидность предыдущего chunk. Terrain проверяется ровно существующим `TerrainCarver.evaluate_profile()` на обеих сторонах endpoint; `danger_left/right` откладывает площадку. Минимальная видимость берётся из реального `RoadGrammar` braking-phase spec и сравнивается с `TURN_SIGHT_DISTANCE_40KMH`.

Результат хранится в `ChunkStreamer.last_fork_site_evaluation`: `eligible`, стабильный список `reason_codes` и измеренные метрики. Это диагностическое состояние, а не постоянный пользовательский лог.

**Граница доказательства:** это фильтр одного уже сгенерированного endpoint, не построитель полной сети. P2.1c ниже добавляет preview только двух fork arms; P2.1d добавляет измерение pacing, но не ранжирует несколько prospective corridors и не проверяет полную сеть. P2.1b предоставляет RouteIntent/RoutePlan как измеримый data contract. FEAT-014.4 означает локальную carving/terrain полосу вокруг дороги; макро-ландшафт, открытая гора и horizon остаются будущим этапом C.

## 3.8. Парный fork-arm preview (P2.1c)

Перед созданием graph fork streamer предсказывает обе стороны через production-функцию `ForkArmGeometry.build`. Эта же функция затем добавляет точки в настоящий `RoadPathData`, так что preview не содержит второй приближённой формулы centerline. `ForkCorridorPreviewPlanner` проверяет 26 samples/примерно 50 м на arm, ширину, конечность, шаг, grade/curvature contract, C0/C1 стык в apex, минимальный разнос рукавов и danger flags `TerrainCarver` на обоих боках. FLOW/TECHNICAL назначаются тем же локальным deterministic seed, что и реальный fork.

Если пара отклонена, graph node, child branch и mesh ещё не созданы; streamer продолжает обычную дорогу и повторяет попытку позже. Поля `last_fork_site_evaluation` и `last_fork_corridor_preview` сохраняют диагностику без шумных постоянных логов. Preview не проверяет последующие FSM chunks, соседство с несвязанными далёкими рёбрами или rider feel; эти ограничения остаются для полной route/network проверки и ручной поездки.

## 3.9. Fork pacing и candidate trace (P2.1d)

`ForkPacingPlanner` размечает каждый реальный candidate endpoint после schedule threshold: `wait`, `defer` или `accept`; пишет целевую и измеренную дистанцию, delay, ordinal и band. Первая развилка отделена от следующих; для следующих диагностический band 550–900 м заимствован из draft P0.3, не стал новым gameplay ограничением. При четырёх отказах или delay >200 м ставится `pacing_overrun`, но поиск продолжает требовать site + paired preview safety. `ChunkStreamer.fork_pacing_trace` держит последние 64 записи с seed/branch/fork identity и причиной отказа.

Штатный seed schedule сохранён. В свежих четырёх controlled default traces (2 seed × LEFT/RIGHT) target был 591.0–820.7 м, materialized leg — 600.3–851.1 м, overshoot — 9.3–33.3 м. Это небольшой sample, не rider guarantee. Искусственная 100m stress schedule попала в 314.6–317.6 м delay, потому что проверка endpoint ограничена примерно 350m ahead horizon; это видно в trace и не относится к нормальному default spacing. Никаких изменений интервалов или safety bounds P2.1d не вводит.

## 3.6. REVIEW-FIX-01 generation/runtime corrections

RoadGraph pruning вызывается при выгрузке branch: удаляются только node IDs строго до самой старой ещё используемой `graph_entry_node_id` / `graph_fork_node_id`. Удаление очищает incoming/outgoing adjacency у обоих концов инцидентных edges и продвигает root к старейшему оставшемуся node. На 500 chunks × 3 seeds soak граф держался в наблюдаемом диапазоне 2–5 nodes / 0–3 edges.

Foliage RNG использует положительный 63-bit hash от branch-stable route seed и arc-length границ chunk interval, квантованных до миллиметра. Выделенный global chunk ID и порядок материализации не участвуют. Теоретические hash collisions возможны; расширение с 31 до 63 бит делает их пренебрежимо редкими для текущего размера активного окна.

`RoadValidityValidator` возвращает invalid report для пустых/структурно несогласованных путей и неверных индексов; сегменты с `BRAKING_ZONE` проверяются по реальной crest visibility. AIRBORNE distance/height остаются ограничены прежними 6.0m/1.20m contract значениями. Surface material blend использует bounded exponential interpolation, сохраняя нормализованные веса и исходную скорость сглаживания при малом delta.

## 3.7. RouteIntent / RoutePlan contract (P2.1b)

`RoadGrammar.build_route_intent()` без изменения очереди или RNG экспортирует `RouteIntent`: world/style seeds, route/branch identity, global start distance, запланированные фазы и действующие для каждой фазы ограничения grade, speed, length, radius, visibility, contact и banking. `RoutePlan.from_road_path()` сохраняет фактические глобальные интервалы, диапазон grade, кривизну, максимальный sample gap, contact counts и segment event counts; для полноты нужны также источник и сводка `telemetry_updated`.

На production opening длиной примерно 450m по 16 профилям (4 world seeds × 2 style salts × FLOW/TECHNICAL) FLOW содержал две crest/micro-drop фазы, без switchback; TECHNICAL — две подготовка→switchback→recovery связки и отдельные recovery. FLOW max curvature измерена 0.00101–0.00166m⁻¹, TECHNICAL — 0.05118–0.05263m⁻¹; sample gap обеих стилей 2.015–2.022m. Диапазоны grade: FLOW −8.24°…+0.98°, TECHNICAL −7.48°…+0.95°. Это starting baseline текущей генерации, а не утверждённые субъективные цели качества.

Автоматический path-follower proxy на одном seed для каждого стиля записал сигналы контроллера, но поддерживал продвижение по линии минимум 7m/s; сигнал велосипеда показал среднюю скорость около 9.5km/h и нулевой cadence. Это не согласованный свободный заезд и не годится для выбора style targets. До оценки trade-offs нужен более достоверный ручной ride/telemetry review. P2.1b ничего не меняет в текущей генерации; `ChunkStreamer` ещё не использует RoutePlan для выбора fork.

## 4. Контракт Прыжков и Посадок (`RoadAirborneContract`)

### 4.1. Режимы контакта (`SurfaceContactMode`)
1. `GROUNDED (0)`: Непрерывный контакт с поверхностью.
2. `MICRO_DROP (1)`: Кратковременная разгрузка подвески над гребнем или уступом ($h \le 0.35$ м, $L \le 2.0$ м, время в воздухе $\le 0.25$ с).
3. `AIRBORNE (2)`: Спроектированный полет велосипеда ($h \le 1.20$ м, свободный пролет $L \le 6.0$ м).
4. `LANDING (3)`: Выделенный наклонный стол приземления с плавным схождением нормалей.

### 4.2. Цепочка переходов конечного автомата (FSM)
Строго разрешены только валидные цепочки:
$$\text{GROUNDED} \longleftrightarrow \text{MICRO_DROP}$$
$$\text{GROUNDED} \longrightarrow \text{AIRBORNE} \longrightarrow \text{LANDING} \longrightarrow \text{GROUNDED}$$

Любой несанкционированный переход (например, `AIRBORNE` напрямую в `GROUNDED` без стола приземления) бракуется валидатором как `INVALID_UNCONTROLLED_GAP`.

### 4.3. Требования к зоне приземления (`LANDING`)
- **Уклон посадочного ската**: согласован с нисходящим углом баллистической траектории с допуском не более $\pm 4.0^\circ$. Плоские удары («flat landing») запрещены.
- **Кривизна**: на посадочном столе радиус строго $R \ge 50.0$ м (посадка только по прямой, никаких шпилек в момент касания!).
- **Поперечный крен**: бэнкинг $\le 2.0^\circ$.
- **Зона стабилизации (`RECOVERY`)**: не менее $15.0$ метров прямого участка после посадки перед началом нового виража.

---

## 5. Дифференцированная Дистанция Видимости (Sight Distance)

Вместо единого скаляра контролируются три раздельных канала:
1. `TURN_SIGHT_DISTANCE`: Дистанция до апекса виража.
   $$S_{\text{turn}} \ge \frac{v^2}{2 \cdot a_{\text{brake\_comfort}}} + v \cdot t_{\text{react}} \quad (\ge 45.0\text{ м при } 40\text{ км/ч})$$
2. `DROP_SIGHT_DISTANCE`: Дистанция видимости кромки уступа с зоны заезда `APPROACH` ($\ge 35.0$ м при 40 км/ч).
3. `LANDING_SIGHT_DISTANCE`: Прямая видимость ската приземления и направления выката из точки отрыва. «Слепые дропы в туман» запрещены.

---

## 6. Алгоритмический Валидатор (`RoadValidityValidator`)

Чистый `RefCounted` инспектор трассы:
* Метод `validate_segment(path_data, s_idx, e_idx) -> ValidityReport`:
  - Проверяет $C^0/C^1$ сплошность, шаг сэмплирования, уклоны, радиусы, производные по $\Delta s$, FSM-переходы и комбинационные риски (Interaction Limits).
  - Классифицирует сегмент: `VALID_GROUNDED`, `VALID_MICRO_DROP`, `VALID_AIRBORNE`, `VALID_LANDING`, `INVALID_GEOMETRY`, `INVALID_UNCONTROLLED_GAP`.
* Метод `validate_seam(path_a, idx_a, path_b, idx_b) -> ValidityReport`:
  - Проверяет стыковку между смежными чанками или ветвями развилки ($\Delta p < 1$ мм, $\Delta \theta < 0.2^\circ$).
* Метод `calculate_sight_distance_at(path_data, sample_idx, sight_type) -> float`:
  - Трассирует прямую видимость с учетом выпуклых гребней рельефа.
* **Производительность**: проверка 100 чанков (2500 сэмплов, 5.0 км) занимает $\approx 7.6$ мс (то есть **0.076 мс на чанк** при лимите 1.0 мс).

## 7. Stage B1 — доказательство event-to-surface

`scripts/test/test_mtb_event_pipeline.gd` использует production `RoadLogic` для
создания запрошенного AIRBORNE_DROP и следующей recovery-фазы, а затем передаёт
тот же `RoadPathData` в production `RoadChunk.prepare_geometry_data()`. На seed
`184729`, `42`, `7319`, `900001` event проходит validator, содержит AIRBORNE,
LANDING и grounded RECOVERY, создаёт road mesh vertices и road collision faces.
Середина каждого сегмента полёта/посадки лежит на дорожных collision faces.

Это доказывает связность геометрического pipeline до mesh/collision данных, но
ещё не runtime physics query по зарегистрированному в сцене collider и не
устойчивость реального велосипеда при посадке. Эти gates остаются в частях B3 и
B5 соответственно; ограничения `RoadAirborneContract` не менялись.
