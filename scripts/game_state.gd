extends Node

enum State {
	START = 0,             # Initial: Talk to Old Man
	CHICKEN_QUEST = 1,     # Old Man asked to find chicken
	LANTERN_FOUND = 2,     # Player got the lantern from chicken
	CAVE_QUEST = 3,        # Old Man sent player to cave
	CAVE_NOTE_FOUND = 4,   # Player read note in cave: "GO BACK TO THE OLD MAN"
	GAME_OVER = 5          # Final joke: $5 taken, "TAKE YOUR MONEY NOOB!"
}

var current_state: State = State.START
var has_lantern: bool = false

signal state_changed(new_state: State)
signal objective_updated(text: String)

func set_state(new_state: State) -> void:
	if current_state != new_state:
		current_state = new_state
		state_changed.emit(new_state)
		
		match new_state:
			State.START:
				update_objective("Talk to the Old Man.")
			State.CHICKEN_QUEST:
				update_objective("🐔 FIND THE CHICKEN")
			State.LANTERN_FOUND:
				has_lantern = true
				update_objective("🔙 RETURN TO THE OLD MAN")
			State.CAVE_QUEST:
				update_objective("ENTER THE CAVE")
			State.CAVE_NOTE_FOUND:
				update_objective("🔙 GO BACK TO THE OLD MAN")
			State.GAME_OVER:
				update_objective("Quest Complete!")

func update_objective(text: String) -> void:
	objective_updated.emit(text)

func reset() -> void:
	current_state = State.START
	has_lantern = false
