class_name DamageFeedbackDefinition
extends Resource
## Single authored source for accepted-hit presentation and bounded motion.
@export var player_knockback := Vector2(230, -145)
@export var player_knockback_seconds := 0.18
@export var enemy_knockback_speed := 135.0
@export var enemy_knockback_seconds := 0.12
@export var hurt_seconds := 0.32
@export var return_transition_seconds := 0.24
@export var flash_seconds := 0.65
@export var flash_frequency := 14.0
## Presentation clocks are real seconds, independent of air aiming slow time.
@export var hit_hold_seconds := 0.045
@export var hazard_impact_seconds := 0.12
@export var hazard_conceal_seconds := 0.16
@export var hazard_reveal_seconds := 0.22
@export var death_body_seconds := 0.78
@export var death_conceal_seconds := 0.32
@export var death_reveal_seconds := 0.26
@export var impact_shake := 2.5
@export var death_shake := 4.0
## Local accepted-kill body/chip hold only; never changes global time or Actor.
@export var plains_kill_hold_seconds := 0.0
