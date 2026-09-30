extends SceneTree

const MountainMassifFieldClass = preload("res://scripts/world/mountain_massif_field.gd")

func _init() -> void:
	print("\n========================================================")
	print("🧪 TESTING MOUNTAIN MASSIF FIELD (LAYER 0)")
	print("========================================================\n")

	var field_a = MountainMassifFieldClass.new(184729)
	var field_b = MountainMassifFieldClass.new(184729)
	var field_diff = MountainMassifFieldClass.new(99999)

	# 1. Test Determinism: field_a and field_b must produce identical values
	var max_diff: float = 0.0
	for ix in range(-20, 21):
		for iz in range(-50, 0):
			var x: float = float(ix) * 25.0
			var z: float = float(iz) * 50.0
			var ha: float = field_a.get_elevation(x, z)
			var hb: float = field_b.get_elevation(x, z)
			assert(is_finite(ha), "Non-finite elevation in field_a")
			assert(is_finite(hb), "Non-finite elevation in field_b")
			var d: float = absf(ha - hb)
			if d > max_diff:
				max_diff = d
	assert(max_diff < 0.000001, "Determinism failed: field_a != field_b")
	print("  [DETERMINISM PASS] Identical values across instances (max delta = %.8f)" % max_diff)

	# 2. Test Seed Diversity: field_a and field_diff must produce different values
	var diff_count: int = 0
	for ix in range(-5, 6):
		for iz in range(-10, 0):
			var x: float = float(ix) * 50.0
			var z: float = float(iz) * 100.0
			var ha: float = field_a.get_elevation(x, z)
			var hd: float = field_diff.get_elevation(x, z)
			if absf(ha - hd) > 1.0:
				diff_count += 1
	assert(diff_count > 40, "Seed diversity failed: field_diff is too similar to field_a")
	print("  [SEED DIVERSITY PASS] Different seeds produce distinct topography (%d points differ by > 1m)" % diff_count)

	# 3. Test Gradient & Contour Orthogonality: contour vector . gradient vector == 0
	var max_ortho_err: float = 0.0
	for ix in range(-10, 11):
		for iz in range(-25, 0):
			var x: float = float(ix) * 35.0
			var z: float = float(iz) * 60.0
			var grad: Vector2 = field_a.get_gradient(x, z)
			var contour: Vector2 = field_a.get_contour_direction(x, z)
			var dot_prod: float = absf(grad.normalized().dot(contour))
			if dot_prod > max_ortho_err:
				max_ortho_err = dot_prod
	assert(max_ortho_err < 0.001, "Orthogonality failed: contour . grad != 0")
	print("  [ORTHOGONALITY PASS] Contour tangents strictly orthogonal to gradient (max dot = %.8f)" % max_ortho_err)

	# 4. Test Gradient Finite Difference Consistency
	var max_grad_err: float = 0.0
	for ix in range(-5, 6):
		for iz in range(-15, 0):
			var x: float = float(ix) * 40.0
			var z: float = float(iz) * 70.0
			var grad: Vector2 = field_a.get_gradient(x, z, 0.5)
			# Numerical check with smaller step
			var h_xp = field_a.get_elevation(x + 0.1, z)
			var h_xm = field_a.get_elevation(x - 0.1, z)
			var num_gx = (h_xp - h_xm) / 0.2
			var err_x = absf(grad.x - num_gx)
			if err_x > max_grad_err:
				max_grad_err = err_x
	assert(max_grad_err < 0.25, "Gradient consistency failed")
	print("  [GRADIENT CONSISTENCY PASS] Analytical gradient matches finite differences (max err = %.4f)" % max_grad_err)

	# 5. Test Fall Line Steepness
	for iz in range(-20, 0):
		var z: float = float(iz) * 100.0
		var steepness: float = field_a.get_steepness_deg(0.0, z)
		assert(steepness >= 0.0 and steepness < 85.0, "Unrealistic mountain steepness: %.1f deg" % steepness)

	print("\n✅ ALL MOUNTAIN MASSIF FIELD CONTRACTS SATISFIED!\n")
	quit(0)
