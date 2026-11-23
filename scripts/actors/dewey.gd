# Dewey, the gas-station attendant: stands by the road and cheers the
# Sheriff on as he passes. Never blocks anything.
extends CharacterBody2D

var line := ""
var done := false
var cheer_t := 0
var player: Player
@onready var bubble: Node2D = $Bubble


var line_id := ""


func setup(p: Player, text: String, id := "") -> void:
	player = p
	line = text
	line_id = id


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + 1400.0 * delta, 500.0)
	move_and_slide()
	cheer_t = maxi(cheer_t - 1, 0)
	if not done and player and absf(player.global_position.x - global_position.x) < 170.0:
		done = true
		cheer_t = 150
		bubble.show_text(Names.fmt(line), 150, line_id)
	$Sprite.facing = -1 if player and player.global_position.x < global_position.x else 1
	$Sprite.play_anim("victory" if cheer_t > 0 else "idle")
