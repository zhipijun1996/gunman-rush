class_name StageCompletionRule
extends Resource

# Independent completion policies; stage loaders consume one definition, not type IDs.
enum Goal { DEFEAT_TARGET, REACH_FINISH, CLAIM_AND_REACH, CLAIM, OPEN_ACCESS }
@export var rule_id: StringName
@export var definition_version := 1
@export var goal: Goal = Goal.REACH_FINISH

func is_valid() -> bool:
	return not rule_id.is_empty() and definition_version == 1 and goal in [Goal.DEFEAT_TARGET, Goal.REACH_FINISH, Goal.CLAIM_AND_REACH, Goal.CLAIM, Goal.OPEN_ACCESS]

func evaluate(player_location: Vector2, target_health: HealthState, reward_claimed: bool, finish_x := 980.0) -> bool:
	if not is_valid() or not player_location.is_finite() or not is_finite(finish_x):
		return false
	match goal:
		Goal.OPEN_ACCESS:
			return true
		Goal.DEFEAT_TARGET:
			return target_health != null and target_health.epoch > 0 and target_health.terminal
		Goal.REACH_FINISH:
			return player_location.x > finish_x
		Goal.CLAIM_AND_REACH:
			return reward_claimed and player_location.x > finish_x
		Goal.CLAIM:
			return reward_claimed
	return false

static func builtin(id: StringName) -> StageCompletionRule:
	var goals := {&"ordinary_access": Goal.OPEN_ACCESS, &"defeat_targets": Goal.DEFEAT_TARGET, &"defeat_boss": Goal.DEFEAT_TARGET, &"visit_exit": Goal.REACH_FINISH, &"choose_item": Goal.CLAIM_AND_REACH, &"claim_reward": Goal.CLAIM}
	if not goals.has(id):
		return null
	var component := StageCompletionRule.new()
	component.rule_id = id
	component.goal = goals[id]
	return component
