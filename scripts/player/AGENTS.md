# Player — stable API and presentation

- BicycleController, camera and controls are stable. A change needs a reproducible measured defect, an explicitly scoped player task and a separate approved plan with player/physics/camera regression evidence.
- Preserve public `telemetry_updated(speed_kmh, cadence_pct, is_coasting)` and `bell_rung` signals, existing public properties, query/recovery contracts and pitch raycasting.
- Player owns kinematics. World consumers observe public telemetry/queries and interact through collision; they do not command internal motion or mutate controller internals.
- Keep the physical CharacterBody3D root world-upright (`Basis.Y = (0, 1, 0)`). Visual lean, dive and pitch remain decoupled in VisualsRoot. Approved player refinements preserve these boundaries.
- Camera, scene exports, input maps and resources outside this directory are also protected by root instructions. A scene/project-setting edit cannot bypass the player gate. Do not alter raycasts or camera to hide world defects.
