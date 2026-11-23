# A thrown rock (by the Sheriff or Earl) or a popgun cork (the deputy).
# Flies with simple gravity; the level decides what it hits.
class_name Projectile
extends Node2D

enum Kind { PLAYER_ROCK, EARL_ROCK, CORK }

var kind := Kind.PLAYER_ROCK
var velocity := Vector2.ZERO
var gravity := 900.0
var level: Node
var _spin := 0.0
var _age := 0
var egg := false             # Earl's eggs (Chicken Run) instead of rocks


func setup(k: int, at: Vector2, vel: Vector2, l: Node) -> void:
	kind = k
	position = at
	velocity = vel
	level = l
	gravity = 0.0 if k == Kind.CORK else 900.0


func _physics_process(delta: float) -> void:
	_age += 1
	velocity.y += gravity * delta
	position += velocity * delta
	_spin += 0.35 * signf(velocity.x)
	if level.projectile_step(self):
		queue_free()
		return
	# hit the ground or a wall
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position
	q.collision_mask = 1
	if not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty():
		level.projectile_landed(self)
		queue_free()
	elif _age > 300 or global_position.y > 600:
		queue_free()
	queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(4, 4), Vector2(8, 8))


func _draw() -> void:
	if egg:
		draw_set_transform(Vector2.ZERO, _spin * 0.5, Vector2.ONE)
		draw_rect(Rect2(-3, -4, 6, 8), Color("24140e"))
		draw_rect(Rect2(-4, -3, 8, 6), Color("24140e"))
		draw_rect(Rect2(-2, -3, 4, 6), Color("fff6e4"))
		draw_rect(Rect2(-3, -2, 6, 4), Color("fff6e4"))
		draw_rect(Rect2(-2, -2, 1, 2), Color("ffffff"))
		return
	var tex := SpriteLib.prop("cork" if kind == Kind.CORK else "rock")
	draw_set_transform(Vector2.ZERO, _spin if kind != Kind.CORK else 0.0, Vector2.ONE)
	draw_texture(tex, -tex.get_size() / 2.0)
