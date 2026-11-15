extends Node2D

signal died(loser_id: int)
signal low_health(pid: int)

const FLOOR_Y: float = 560.0
const SCREEN_MIN_X: float = 35.0
const SCREEN_MAX_X: float = 1117.0

const BASE_GRAVITY: float = 1450.0
const BASE_MOVE_SPEED: float = 320.0
const BASE_JUMP_FORCE: float = -600.0

const PUNCH_DAMAGE: int = 8
const PUNCH_COOLDOWN: float = 0.3
const PUNCH_RANGE: float = 72.0

const KICK_DAMAGE: int = 14
const KICK_COOLDOWN: float = 0.5
const KICK_RANGE: float = 90.0

var player_id: int = 1
var body_color: Color = Color(0.2, 0.55, 1.0)
var keys: Dictionary = {}
var opponent: Node2D = null

var max_health: int = 100
var health: int = 100
var active: bool = true
var low_health_triggered: bool = false

var move_speed: float = BASE_MOVE_SPEED
var jump_force: float = BASE_JUMP_FORCE
var damage_multiplier: float = 1.0

var velocity: Vector2 = Vector2.ZERO
var knockback_vx: float = 0.0
var facing: int = 1
var on_ground: bool = true

var punch_timer: float = 0.0
var kick_timer: float = 0.0
var attack_visual_timer: float = 0.0
var hit_flash_timer: float = 0.0

var prev_key_state: Dictionary = {}

var body_rect: ColorRect
var eye_rect: ColorRect
var attack_rect: ColorRect
var boost_rect: ColorRect


func _ready() -> void:
	_build_visuals()
	_update_visual_facing()


func setup(pid: int, start_pos: Vector2, start_facing: int, color_val: Color, control_keys: Dictionary) -> void:
	player_id = pid
	position = start_pos
	facing = start_facing
	body_color = color_val
	keys = control_keys.duplicate()
	if body_rect != null:
		body_rect.color = body_color
	_update_visual_facing()
	_sync_prev_keys()


func reset_fighter(start_pos: Vector2, start_facing: int) -> void:
	position = start_pos
	facing = start_facing
	health = max_health
	active = true
	low_health_triggered = false
	move_speed = BASE_MOVE_SPEED
	jump_force = BASE_JUMP_FORCE
	damage_multiplier = 1.0
	velocity = Vector2.ZERO
	knockback_vx = 0.0
	on_ground = position.y >= FLOOR_Y
	punch_timer = 0.0
	kick_timer = 0.0
	attack_visual_timer = 0.0
	hit_flash_timer = 0.0
	if body_rect != null:
		body_rect.color = body_color
	if attack_rect != null:
		attack_rect.visible = false
	if boost_rect != null:
		boost_rect.visible = false
	_update_visual_facing()
	_sync_prev_keys()


func _build_visuals() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	# Glow border shown when fighter receives a buff
	boost_rect = ColorRect.new()
	boost_rect.size = Vector2(58, 88)
	boost_rect.position = Vector2(-29, -84)
	boost_rect.color = Color(1.0, 0.85, 0.2, 0.9)
	boost_rect.visible = false
	add_child(boost_rect)

	# Main character block (feet at y = 0)
	body_rect = ColorRect.new()
	body_rect.size = Vector2(50, 80)
	body_rect.position = Vector2(-25, -80)
	body_rect.color = body_color
	add_child(body_rect)

	# Eye / visor block to show facing direction
	eye_rect = ColorRect.new()
	eye_rect.size = Vector2(14, 10)
	eye_rect.position = Vector2(8, -68)
	eye_rect.color = Color(0.95, 0.98, 1.0)
	add_child(eye_rect)

	# Punch / kick visual box
	attack_rect = ColorRect.new()
	attack_rect.size = Vector2(36, 16)
	attack_rect.position = Vector2(25, -54)
	attack_rect.color = Color(1.0, 0.92, 0.35)
	attack_rect.visible = false
	add_child(attack_rect)


func _process(delta: float) -> void:
	if keys.is_empty():
		return

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0 and body_rect != null:
			body_rect.color = body_color

	if attack_visual_timer > 0.0:
		attack_visual_timer -= delta
		if attack_visual_timer <= 0.0 and attack_rect != null:
			attack_rect.visible = false

	if not active:
		_sync_prev_keys()
		return

	if punch_timer > 0.0:
		punch_timer -= delta
	if kick_timer > 0.0:
		kick_timer -= delta

	# Horizontal movement
	var move_dir: float = 0.0
	if _is_key_down("left"):
		move_dir -= 1.0
	if _is_key_down("right"):
		move_dir += 1.0

	if move_dir != 0.0:
		facing = int(sign(move_dir))
		_update_visual_facing()

	velocity.x = move_dir * move_speed + knockback_vx
	knockback_vx = move_toward(knockback_vx, 0.0, 1400.0 * delta)

	# Jump
	if on_ground and _is_key_just_pressed("jump"):
		velocity.y = jump_force
		on_ground = false

	# Gravity
	velocity.y += BASE_GRAVITY * delta
	position += velocity * delta

	# Floor collision
	if position.y >= FLOOR_Y:
		position.y = FLOOR_Y
		velocity.y = 0.0
		on_ground = true

	# Screen bounds
	position.x = clamp(position.x, SCREEN_MIN_X, SCREEN_MAX_X)

	# Attacks
	if _is_key_just_pressed("punch") and punch_timer <= 0.0:
		_perform_attack(PUNCH_DAMAGE, PUNCH_RANGE, 260.0, -120.0, false)
		punch_timer = PUNCH_COOLDOWN
	elif _is_key_just_pressed("kick") and kick_timer <= 0.0:
		_perform_attack(KICK_DAMAGE, KICK_RANGE, 380.0, -180.0, true)
		kick_timer = KICK_COOLDOWN

	_sync_prev_keys()


func _perform_attack(base_damage: int, attack_range: float, kb_x: float, kb_y: float, is_kick: bool) -> void:
	if attack_rect != null:
		if is_kick:
			attack_rect.size = Vector2(44, 20)
			attack_rect.color = Color(1.0, 0.65, 0.2)
			attack_rect.position = Vector2(24, -32) if facing > 0 else Vector2(-68, -32)
		else:
			attack_rect.size = Vector2(34, 14)
			attack_rect.color = Color(1.0, 0.95, 0.4)
			attack_rect.position = Vector2(24, -56) if facing > 0 else Vector2(-58, -56)
		attack_rect.visible = true
		attack_visual_timer = 0.12

	if opponent == null or not is_instance_valid(opponent):
		return

	var dx: float = opponent.position.x - position.x
	var dy: float = abs(opponent.position.y - position.y)
	var in_front: bool = (facing > 0 and dx >= -12.0 and dx <= attack_range) or (facing < 0 and dx <= 12.0 and dx >= -attack_range)

	if in_front and dy <= 75.0:
		var final_damage: int = int(round(float(base_damage) * damage_multiplier))
		if opponent.has_method("take_damage"):
			opponent.take_damage(final_damage, Vector2(float(facing) * kb_x, kb_y))


func take_damage(amount: int, knockback: Vector2) -> void:
	if health <= 0:
		return

	health = max(0, health - amount)
	knockback_vx = knockback.x
	velocity.y = min(velocity.y, knockback.y)
	on_ground = false

	if body_rect != null:
		body_rect.color = Color.WHITE
		hit_flash_timer = 0.1

	if health <= 0:
		died.emit(player_id)
		return

	if health <= 30 and not low_health_triggered:
		low_health_triggered = true
		low_health.emit(player_id)


func apply_reward(reward_type: String) -> String:
	if boost_rect != null and reward_type != "heal":
		boost_rect.visible = true

	match reward_type:
		"heal":
			health = min(max_health, health + 30)
			return "+30 HEALTH"
		"damage":
			damage_multiplier = 1.5
			return "1.5x DAMAGE"
		"speed":
			move_speed = BASE_MOVE_SPEED * 1.35
			return "SPEED BOOST"
		"jump":
			jump_force = BASE_JUMP_FORCE * 1.25
			return "HIGHER JUMP"
	return "NO REWARD"


func _update_visual_facing() -> void:
	if eye_rect == null:
		return
	if facing >= 0:
		eye_rect.position = Vector2(8, -68)
	else:
		eye_rect.position = Vector2(-22, -68)


func _is_key_down(action: String) -> bool:
	if not keys.has(action):
		return false
	return Input.is_physical_key_pressed(keys[action])


func _is_key_just_pressed(action: String) -> bool:
	if not keys.has(action):
		return false
	var code: int = keys[action]
	var currently_down: bool = Input.is_physical_key_pressed(code)
	var was_down: bool = prev_key_state.get(action, false)
	return currently_down and not was_down


func _sync_prev_keys() -> void:
	for action in keys.keys():
		prev_key_state[action] = Input.is_physical_key_pressed(keys[action])
