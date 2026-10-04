class_name MacroTerrainPlan
extends RefCounted

## Schema state only: R0 carries no macro-terrain data.
const STATE_DEFERRED_R1 := "DEFERRED_R1"


func get_state() -> String:
	return STATE_DEFERRED_R1
