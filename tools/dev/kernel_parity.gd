extends SceneTree
## Parity of the C# MacroTerrainKernel with the GDScript kernel: N points per
## seed/region (fixed pseudo-random positions, plus lattice points), both
## include_noise values; prints KERNEL_PARITY {active, points, mismatches,
## max_abs_diff} and the speed of both paths. Exit 1 on any mismatch.
##   [--points=N (200000)] (run with the .NET build after dotnet build)
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")


func _initialize() -> void:
	var points: int = 200000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--points="):
			points = arg.substr(9).to_int()
	var active: bool = Eval.kernel_active()
	var total: int = 0
	var mismatches: int = 0
	var worst: float = 0.0
	var gd_us: float = 0.0
	var cs_us: float = 0.0
	for case: Array in [[184729, Vector2i(0, 0)], [2024, Vector2i(0, 0)], [3628391, Vector2i(3, -2)]]:
		var plan: RefCounted = Gen.build(case[0], case[1])
		var context: Eval.Context = Eval.prepare(plan.get_macro_terrain())
		if not active or context.kernel == null:
			print("KERNEL_PARITY NOT_RUN (C# kernel not active)")
			quit(1)
			return
		var xs := PackedFloat64Array()
		var zs := PackedFloat64Array()
		var state: int = int(case[0])
		for k in range(points):
			state = (state * 6364136223846793005 + 1442695040888963407)
			var a: float = float((state >> 11) & 0xFFFFF) / 1048576.0
			state = (state * 6364136223846793005 + 1442695040888963407)
			var b: float = float((state >> 11) & 0xFFFFF) / 1048576.0
			xs.append(a * 4096.0 if k % 5 != 0 else float(16 * ((k / 5) % 257)))
			zs.append(b * 4096.0 if k % 5 != 0 else float(16 * ((k / 1285) % 257)))
		for noise: bool in [true, false]:
			var t: int = Time.get_ticks_usec()
			var gd := PackedFloat64Array()
			gd.resize(points)
			for k in range(points):
				gd[k] = Eval._sample(context, xs[k], zs[k], noise)
			gd_us += Time.get_ticks_usec() - t
			t = Time.get_ticks_usec()
			var cs := PackedFloat64Array()
			cs.resize(points)
			for k in range(points):
				cs[k] = Eval.sample_prepared(context, xs[k], zs[k], noise)
			cs_us += Time.get_ticks_usec() - t
			for k in range(points):
				total += 1
				if gd[k] != cs[k]:
					mismatches += 1
					worst = maxf(worst, absf(gd[k] - cs[k]))
	print("KERNEL_PARITY ", JSON.stringify({"active": active, "points": total, "mismatches": mismatches, "max_abs_diff": worst, "gdscript_us_per_point": gd_us / total,
		"csharp_us_per_point": cs_us / total}))
	quit(0 if mismatches == 0 else 1)
