class_name Interact
extends Node3D
## Allgemeines benutzbares Objekt: Text und Aktion werden von außen gesetzt.

var label := ""
var reach := 3.6
var action: Callable
var condition: Callable
var label_fn: Callable


func _ready() -> void:
	add_to_group("interact")


func usable() -> bool:
	return not condition.is_valid() or condition.call()


func prompt() -> String:
	return label_fn.call() if label_fn.is_valid() else label


func interact() -> void:
	if action.is_valid():
		action.call()
