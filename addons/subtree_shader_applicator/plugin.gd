@tool
extends EditorPlugin

const TYPE_NAME := "SubtreeShaderApplicator"
const BASE_TYPE := "Node"
const SCRIPT := preload("subtree_shader_applicator.gd")
const ICON := preload("icon.svg")


func _enter_tree() -> void:
	add_custom_type(TYPE_NAME, BASE_TYPE, SCRIPT, ICON)


func _exit_tree() -> void:
	remove_custom_type(TYPE_NAME)
