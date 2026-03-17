@tool
extends Node

class_name SubtreeShaderApplicator

const META_ORIGINAL_CANVAS_MATERIAL := "_subtree_shader_applicator_original_canvas_material"
const META_ORIGINAL_MATERIAL_OVERRIDE := "_subtree_shader_applicator_original_material_override"
const META_ORIGINAL_MATERIAL_OVERLAY := "_subtree_shader_applicator_original_material_overlay"
const META_ORIGINAL_SURFACE_OVERRIDES := "_subtree_shader_applicator_original_surface_overrides"

var _target_root_path: NodePath
var _canvas_item_material: Material
var _geometry_material_override: Material
var _geometry_material_overlay: Material
var _geometry_material_next_pass: Material
var _include_internal_children := false
var _apply_on_ready := true
var _apply_in_editor := true
var _exceptions: Array[NodePath] = []
var _sync_queued := false
var _last_target_root: Node

## The root node of the subtree to apply materials to. If left empty, this node itself is used as the root and materials are applied to all of its children.
@export_node_path("Node") var target_root_path: NodePath:
	set(value):
		if _target_root_path == value:
			return
		_target_root_path = value
		_queue_sync()
	get:
		return _target_root_path

@export_category("2D")
## Material applied to all [CanvasItem] nodes in the subtree. Replaces the [member CanvasItem.material] property on each matching node.
@export var canvas_item_material: Material:
	set(value):
		if _canvas_item_material == value:
			return
		_canvas_item_material = value
		_queue_sync()
	get:
		return _canvas_item_material

@export_category("3D")
## Material applied as [member GeometryInstance3D.material_override] on all [GeometryInstance3D] nodes in the subtree. Overrides all surface materials entirely.
@export var geometry_material_override: Material:
	set(value):
		if _geometry_material_override == value:
			return
		_geometry_material_override = value
		_queue_sync()
	get:
		return _geometry_material_override

## Material applied as [member GeometryInstance3D.material_overlay] on all [GeometryInstance3D] nodes in the subtree. Rendered on top of the existing surface materials.
@export var geometry_material_overlay: Material:
	set(value):
		if _geometry_material_overlay == value:
			return
		_geometry_material_overlay = value
		_queue_sync()
	get:
		return _geometry_material_overlay

## Material appended as the [member Material.next_pass] on all [GeometryInstance3D] nodes in the subtree. Chained after the existing material's last pass, leaving original materials intact.
@export var geometry_material_next_pass: Material:
	set(value):
		if _geometry_material_next_pass == value:
			return
		_geometry_material_next_pass = value
		_queue_sync()
	get:
		return _geometry_material_next_pass

@export_category("Behavior")
## When enabled, Godot's internal child nodes (e.g. collision shapes, skeletons) are included in the subtree traversal in addition to user-created children.
@export var include_internal_children := false:
	set(value):
		if _include_internal_children == value:
			return
		_include_internal_children = value
		_queue_sync()
	get:
		return _include_internal_children

## When enabled, materials are applied to the subtree automatically when the scene is ready. Disable if you want to control when materials are applied via [method refresh_subtree] instead.
@export var apply_on_ready := true:
	set(value):
		_apply_on_ready = value
	get:
		return _apply_on_ready

## When enabled, materials are applied while editing in the Godot editor, giving a live preview. Disable to only apply materials at runtime.
@export var apply_in_editor := true:
	set(value):
		if _apply_in_editor == value:
			return
		_apply_in_editor = value
		_queue_sync()
	get:
		return _apply_in_editor

## Nodes to exclude from material application. Any node listed here (and its entire subtree) will be skipped, and its original materials will be preserved. Changes to this list take effect immediately.
@export var exceptions: Array[NodePath] = []:
	set(value):
		_exceptions = value
		_queue_sync()
	get:
		return _exceptions


func _ready() -> void:
	if apply_on_ready:
		_queue_sync()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var target_root := _resolve_target_root()

	if not target_root_path.is_empty() and target_root == null:
		warnings.append("The selected subtree node could not be found. Set a valid target_root_path.")
	elif target_root == null:
		warnings.append("Add children under this node or set target_root_path to define the subtree.")
	elif target_root.get_child_count(include_internal_children) == 0:
		warnings.append("The selected subtree node has no children to affect.")

	return warnings


func refresh_subtree() -> void:
	_queue_sync()


func apply_to_target() -> void:
	refresh_subtree()


func set_all_assigned_shader_parameters(parameter_name: StringName, value: Variant) -> void:
	_set_shader_parameter_on_material(canvas_item_material, parameter_name, value)
	_set_shader_parameter_on_material(geometry_material_override, parameter_name, value)
	_set_shader_parameter_on_material(geometry_material_overlay, parameter_name, value)
	_set_shader_parameter_on_material(geometry_material_next_pass, parameter_name, value)


func set_canvas_shader_parameter(parameter_name: StringName, value: Variant) -> void:
	_set_shader_parameter_on_material(canvas_item_material, parameter_name, value)


func set_geometry_override_shader_parameter(parameter_name: StringName, value: Variant) -> void:
	_set_shader_parameter_on_material(geometry_material_override, parameter_name, value)


func set_geometry_overlay_shader_parameter(parameter_name: StringName, value: Variant) -> void:
	_set_shader_parameter_on_material(geometry_material_overlay, parameter_name, value)


func set_geometry_next_pass_shader_parameter(parameter_name: StringName, value: Variant) -> void:
	_set_shader_parameter_on_material(geometry_material_next_pass, parameter_name, value)


func clear_cached_state() -> void:
	var target_root := _resolve_target_root()
	if target_root == null:
		return

	_clear_cached_state_in_branch(target_root)


func _queue_sync() -> void:
	update_configuration_warnings()

	if not is_inside_tree():
		return

	if _sync_queued:
		return

	_sync_queued = true
	call_deferred("_sync_to_target")


func _sync_to_target() -> void:
	_sync_queued = false

	var target_root := _resolve_target_root()

	if not _should_apply_now():
		_restore_previous_target_if_needed(null)
		return

	_restore_previous_target_if_needed(target_root)

	if target_root == null:
		return

	_sync_branch(target_root)
	_last_target_root = target_root


func _restore_previous_target_if_needed(current_target: Node) -> void:
	if _last_target_root == null:
		return

	if not is_instance_valid(_last_target_root):
		_last_target_root = null
		return

	if _last_target_root == current_target:
		return

	_restore_branch(_last_target_root)
	_last_target_root = null


func _sync_branch(node: Node) -> void:
	if node != self:
		if _is_excepted(node):
			_restore_node(node)
			return
		_sync_node(node)

	for child in node.get_children(include_internal_children):
		_sync_branch(child)


func _restore_branch(node: Node) -> void:
	if node != self:
		_restore_node(node)

	for child in node.get_children(include_internal_children):
		_restore_branch(child)


func _sync_node(node: Node) -> void:
	if node is CanvasItem:
		_sync_canvas_item(node as CanvasItem)

	if node is GeometryInstance3D:
		_sync_geometry_instance(node as GeometryInstance3D)


func _restore_node(node: Node) -> void:
	if node is CanvasItem:
		_restore_canvas_item(node as CanvasItem)

	if node is GeometryInstance3D:
		_restore_geometry_instance(node as GeometryInstance3D)


func _sync_canvas_item(canvas_item: CanvasItem) -> void:
	_cache_original_canvas_material(canvas_item)

	if canvas_item_material != null:
		canvas_item.material = canvas_item_material
	else:
		_restore_canvas_item(canvas_item)


func _restore_canvas_item(canvas_item: CanvasItem) -> void:
	if canvas_item.has_meta(META_ORIGINAL_CANVAS_MATERIAL):
		canvas_item.material = canvas_item.get_meta(META_ORIGINAL_CANVAS_MATERIAL) as Material


func _sync_geometry_instance(geometry_instance: GeometryInstance3D) -> void:
	_cache_original_geometry_state(geometry_instance)
	_restore_geometry_instance(geometry_instance)

	if geometry_material_override != null:
		geometry_instance.material_override = geometry_material_override

	if geometry_material_overlay != null:
		geometry_instance.material_overlay = geometry_material_overlay

	if geometry_material_next_pass != null:
		_apply_geometry_next_pass(geometry_instance)


func _restore_geometry_instance(geometry_instance: GeometryInstance3D) -> void:
	if geometry_instance.has_meta(META_ORIGINAL_MATERIAL_OVERRIDE):
		geometry_instance.material_override = geometry_instance.get_meta(META_ORIGINAL_MATERIAL_OVERRIDE) as Material

	if geometry_instance.has_meta(META_ORIGINAL_MATERIAL_OVERLAY):
		geometry_instance.material_overlay = geometry_instance.get_meta(META_ORIGINAL_MATERIAL_OVERLAY) as Material

	if geometry_instance is MeshInstance3D and geometry_instance.has_meta(META_ORIGINAL_SURFACE_OVERRIDES):
		var mesh_instance := geometry_instance as MeshInstance3D
		var original_overrides: Array = geometry_instance.get_meta(META_ORIGINAL_SURFACE_OVERRIDES) as Array
		var surface_count := mesh_instance.get_surface_override_material_count()
		for surface in surface_count:
			var original_override: Material = null
			if surface < original_overrides.size():
				original_override = original_overrides[surface] as Material
			mesh_instance.set_surface_override_material(surface, original_override)


func _apply_geometry_next_pass(geometry_instance: GeometryInstance3D) -> void:
	if geometry_instance.material_override != null:
		geometry_instance.material_override = _duplicate_material_with_next_pass(geometry_instance.material_override)
		return

	if geometry_instance is MeshInstance3D:
		_apply_geometry_next_pass_to_mesh_instance(geometry_instance as MeshInstance3D)


func _apply_geometry_next_pass_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	var surface_count := mesh_instance.get_surface_override_material_count()
	for surface in surface_count:
		var base_material := _get_mesh_surface_source_material(mesh_instance, surface)
		if base_material == null:
			continue

		mesh_instance.set_surface_override_material(surface, _duplicate_material_with_next_pass(base_material))


func _cache_original_canvas_material(canvas_item: CanvasItem) -> void:
	if not canvas_item.has_meta(META_ORIGINAL_CANVAS_MATERIAL):
		canvas_item.set_meta(META_ORIGINAL_CANVAS_MATERIAL, canvas_item.material)


func _cache_original_geometry_state(geometry_instance: GeometryInstance3D) -> void:
	if not geometry_instance.has_meta(META_ORIGINAL_MATERIAL_OVERRIDE):
		geometry_instance.set_meta(META_ORIGINAL_MATERIAL_OVERRIDE, geometry_instance.material_override)

	if not geometry_instance.has_meta(META_ORIGINAL_MATERIAL_OVERLAY):
		geometry_instance.set_meta(META_ORIGINAL_MATERIAL_OVERLAY, geometry_instance.material_overlay)

	if geometry_instance is MeshInstance3D:
		_cache_original_surface_overrides(geometry_instance as MeshInstance3D)


func _cache_original_surface_overrides(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.has_meta(META_ORIGINAL_SURFACE_OVERRIDES):
		return

	var original_overrides: Array[Material] = []
	var surface_count := mesh_instance.get_surface_override_material_count()
	for surface in surface_count:
		original_overrides.append(mesh_instance.get_surface_override_material(surface))

	mesh_instance.set_meta(META_ORIGINAL_SURFACE_OVERRIDES, original_overrides)


func _clear_cached_state_in_branch(node: Node) -> void:
	if node != self and node is CanvasItem:
		(node as CanvasItem).remove_meta(META_ORIGINAL_CANVAS_MATERIAL)

	if node != self and node is GeometryInstance3D:
		var geometry_instance := node as GeometryInstance3D
		geometry_instance.remove_meta(META_ORIGINAL_MATERIAL_OVERRIDE)
		geometry_instance.remove_meta(META_ORIGINAL_MATERIAL_OVERLAY)
		geometry_instance.remove_meta(META_ORIGINAL_SURFACE_OVERRIDES)

	for child in node.get_children(include_internal_children):
		_clear_cached_state_in_branch(child)


func _get_mesh_surface_source_material(mesh_instance: MeshInstance3D, surface: int) -> Material:
	var source_override: Material = mesh_instance.get_surface_override_material(surface)
	if source_override != null:
		return source_override

	return mesh_instance.mesh.surface_get_material(surface)


func _duplicate_material_with_next_pass(base_material: Material) -> Material:
	var duplicated_material := base_material.duplicate() as Material
	if duplicated_material == null:
		return base_material

	duplicated_material.resource_local_to_scene = true

	var last_pass := duplicated_material
	while last_pass.next_pass != null:
		last_pass = last_pass.next_pass

	last_pass.next_pass = geometry_material_next_pass
	return duplicated_material


func _set_shader_parameter_on_material(material: Material, parameter_name: StringName, value: Variant) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(parameter_name, value)


func _is_excepted(node: Node) -> bool:
	for exception_path in _exceptions:
		if exception_path.is_empty():
			continue
		var exception_node := get_node_or_null(exception_path)
		if exception_node == node:
			return true
	return false


func _resolve_target_root() -> Node:
	if not target_root_path.is_empty():
		return get_node_or_null(target_root_path)

	if get_child_count(include_internal_children) > 0:
		return self

	return null


func _should_apply_now() -> bool:
	return not Engine.is_editor_hint() or apply_in_editor
