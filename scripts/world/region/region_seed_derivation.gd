class_name RegionSeedDerivation
extends RefCounted

## Versioned seed derivation for the single registered R0 purpose.
const ALGORITHM_TAG := "slow_cycle.seed/1"
const PURPOSE_REGION_SEED := "region_seed"
const PURPOSE_MACRO_STRUCTURE := "macro_structure"
const PURPOSE_MACRO_NOISE := "macro_noise"


static func macro_structure_seed_preimage(region_seed_value: int) -> String:
	return _preimage(PURPOSE_MACRO_STRUCTURE, PackedInt64Array([region_seed_value]))


static func macro_structure_seed(region_seed_value: int) -> int:
	return _seed_from_preimage(macro_structure_seed_preimage(region_seed_value))


static func macro_noise_seed_preimage(region_seed_value: int) -> String:
	return _preimage(PURPOSE_MACRO_NOISE, PackedInt64Array([region_seed_value]))


static func macro_noise_seed(region_seed_value: int) -> int:
	return _seed_from_preimage(macro_noise_seed_preimage(region_seed_value))


static func region_seed_preimage(world_seed: int, region_coordinate: Vector2i) -> String:
	return _preimage(PURPOSE_REGION_SEED,
		PackedInt64Array([world_seed, int(region_coordinate.x), int(region_coordinate.y)]))


static func region_seed(world_seed: int, region_coordinate: Vector2i) -> int:
	return _seed_from_preimage(region_seed_preimage(world_seed, region_coordinate))


static func _preimage(purpose: String, values: PackedInt64Array) -> String:
	var text: String = ALGORITHM_TAG + "\npurpose=" + purpose + "\ncount=" + str(values.size()) + "\n"
	for i in range(values.size()):
		text += "v" + str(i) + "=" + str(values[i]) + "\n"
	return text


static func _seed_from_preimage(text: String) -> int:
	var digest: PackedByteArray = text.sha256_buffer()
	var result: int = int(digest[0] & 0x7F)
	for i in range(1, 8):
		result = (result << 8) | int(digest[i])
	return result
