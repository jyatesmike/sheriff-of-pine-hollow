# Animation poses for the humanoid rig. pose(anim, i) returns the pose for
# frame i. Vector2(x, y) for limbs = (angle at hip/shoulder, knee/elbow bend).
# The row order and frame counts must match data/sprites.json.
extends RefCounted

const ANIMS := [
	["idle", 4], ["run", 8], ["jump", 1], ["fall", 1], ["land", 2], ["skid", 2],
	["throw", 4], ["hurt", 2], ["victory", 6], ["slide", 3], ["tiphat", 4],
	["taunt", 4], ["stunned", 2], ["cuffed", 2], ["aim", 3], ["fumble", 4],
	["climb", 4], ["climb_idle", 1],
]


static func pose(anim: String, i: int, ch: Dictionary) -> Dictionary:
	match anim:
		"idle":
			return {
				"bob": [0, 0, 1, 1][i], "lean": 0.02,
				"leg_b": Vector2(-0.07, 0.02), "leg_f": Vector2(0.09, 0.03),
				"arm_b": Vector2(-0.12, 0.2), "arm_f": Vector2(0.08 + 0.03 * [0, 0, 1, 1][i], 0.25),
				"blink": i == 3,
			}
		"run":
			var t := i / 8.0 * TAU
			return {
				"lean": 0.2, "bob": roundf(1.2 * absf(sin(t))) - 1.0,
				"leg_f": Vector2(0.75 * sin(t), 0.2 + 1.25 * maxf(0.0, cos(t))),
				"leg_b": Vector2(0.75 * sin(t + PI), 0.2 + 1.25 * maxf(0.0, cos(t + PI))),
				"arm_f": Vector2(-0.85 * sin(t), 1.35),
				"arm_b": Vector2(0.85 * sin(t), 1.35),
			}
		"jump":
			return {
				"hip_y": 36.0, "lean": 0.1,
				"leg_f": Vector2(1.0, 1.6), "leg_b": Vector2(-0.15, 0.9),
				"arm_f": Vector2(2.4, 0.4), "arm_b": Vector2(-2.0, -0.4), "mouth": "smile",
			}
		"fall":
			return {
				"hip_y": 34.0, "lean": 0.0,
				"leg_f": Vector2(0.35, 0.5), "leg_b": Vector2(-0.25, 0.3),
				"arm_f": Vector2(1.9, 0.4), "arm_b": Vector2(-1.9, -0.3),
			}
		"land":
			return [
				{"lean": 0.3, "leg_f": Vector2(0.95, 1.6), "leg_b": Vector2(0.35, 1.4),
				 "arm_f": Vector2(0.7, 0.6), "arm_b": Vector2(-0.4, 0.5)},
				{"lean": 0.15, "leg_f": Vector2(0.5, 0.8), "leg_b": Vector2(0.15, 0.7),
				 "arm_f": Vector2(0.3, 0.4), "arm_b": Vector2(-0.2, 0.4)},
			][i]
		"skid":
			return {
				"lean": -0.22, "leg_f": Vector2(0.75, 0.1), "leg_b": Vector2(-0.25, 0.9),
				"arm_f": Vector2(1.3 + 0.2 * i, 0.2), "arm_b": Vector2(-1.5 - 0.2 * i, 0.3), "mouth": "open",
			}
		"throw":
			var arm: Vector2 = [Vector2(-2.4, 0.8), Vector2(-1.7, 0.5), Vector2(1.6, 0.1), Vector2(0.9, 0.3)][i]
			return {
				"lean": [-0.12, -0.06, 0.25, 0.18][i],
				"leg_f": Vector2(0.45, 0.3), "leg_b": Vector2(-0.35, 0.2),
				"arm_f": arm, "arm_b": Vector2(0.8, 0.6),
				"item": "rock" if i < 2 and ch.get("throws", false) else "",
			}
		"hurt":
			return {
				"hip_y": 36.0 + i, "lean": -0.35,
				"leg_f": Vector2(0.5, 0.4), "leg_b": Vector2(-0.45, 0.3),
				"arm_f": Vector2(1.9 + 0.2 * i, 0.5), "arm_b": Vector2(-2.2, -0.4), "mouth": "open", "blink": i == 1,
			}
		"victory":
			var w := sin(i * PI / 3.0)
			return {
				"bob": [0, -2, -5, -5, -2, 0][i], "lean": 0.0,
				"leg_f": Vector2(0.15, 0.1 + 0.3 * absf(w)), "leg_b": Vector2(-0.15, 0.1 + 0.3 * absf(w)),
				"arm_f": Vector2(2.3 + 0.25 * w, 0.5), "arm_b": Vector2(-2.4 + 0.25 * w, -0.5), "mouth": "open",
			}
		"slide":
			return {
				"hip_x": 27.0, "hip_y": 55.0 - i * 0.5, "lean": -1.15 - 0.05 * i,
				"leg_f": Vector2(1.5, 0.5), "leg_b": Vector2(1.35, 0.15),
				"arm_b": Vector2(-0.9, 0.3), "arm_f": Vector2(0.7, 1.3), "mouth": "smile",
			}
		"tiphat":
			return {
				"lean": 0.0, "leg_b": Vector2(-0.07, 0.02), "leg_f": Vector2(0.09, 0.03),
				"arm_b": Vector2(-0.12, 0.2),
				"arm_f": [Vector2(1.3, 1.0), Vector2(2.2, 1.0), Vector2(2.2, 1.0), Vector2(1.6, 1.0)][i],
				"hat_up": i == 2, "mouth": "smile", "blink": i == 2,
			}
		"taunt":
			return {
				"bob": [0, -1, 0, -1][i], "lean": -0.05,
				"leg_f": Vector2(0.2, 0.1), "leg_b": Vector2(-0.2, 0.1),
				"arm_f": Vector2(2.4 + 0.15 * (i % 2), 1.9), "arm_b": Vector2(-2.3 - 0.15 * (i % 2), -1.9),
				"mouth": "open",
			}
		"stunned":
			return {
				"lean": [-0.12, 0.12][i], "leg_f": Vector2(0.15, 0.2), "leg_b": Vector2(-0.1, 0.25),
				"arm_f": Vector2(0.6, 0.2), "arm_b": Vector2(-0.6, 0.2), "blink": true, "mouth": "open",
			}
		"cuffed":
			return {
				"lean": 0.15, "head_dy": 1.0 + i * 0.0, "bob": i,
				"leg_f": Vector2(0.05, 0.05), "leg_b": Vector2(-0.05, 0.05),
				"arm_f": Vector2(-0.45, 1.5), "arm_b": Vector2(-0.55, 1.6),
			}
		"aim":
			var tremble: float = [0.0, 0.05, -0.05][i]
			return {
				"lean": 0.05, "leg_f": Vector2(0.4, 0.3), "leg_b": Vector2(-0.35, 0.2),
				"arm_f": Vector2(1.0 if i == 0 else 1.5 + tremble, 0.05), "arm_b": Vector2(1.3, 0.35),
				"item": "popgun",
			}
		"fumble":
			return {
				"lean": 0.1, "head_dy": 1.0, "leg_f": Vector2(0.1, 0.1), "leg_b": Vector2(-0.1, 0.1),
				"arm_f": Vector2(0.3 + 0.2 * (i % 2), 1.5), "arm_b": Vector2(-0.2 - 0.2 * ((i + 1) % 2), 1.6),
				"item": "popgun" if i < 2 else "", "cork": false, "mouth": "open" if i % 2 else "",
			}
		"climb", "climb_idle":
			# hand over hand up a ladder (or hanging from a zip line)
			var k := i % 2
			return {
				"hip_y": 44.0, "lean": 0.0,
				"leg_f": Vector2(0.6 if k == 0 else 0.15, 1.1 if k == 0 else 0.3),
				"leg_b": Vector2(0.15 if k == 0 else 0.6, 0.3 if k == 0 else 1.1),
				"arm_f": Vector2(2.95 if k == 0 else 2.6, 0.15),
				"arm_b": Vector2(-2.6 if k == 0 else -2.95, -0.15),
			}
	return {}
