# Subtree Shader Applicator

`SubtreeShaderApplicator` is a helper node for pushing one material setup through an entire scene branch.

Feel free to donate to my [Paypal]( https://www.paypal.com/donate/?business=WK8M59YJRAYAJ&no_recurring=0&currency_code=USD) if you like what I make :)

Licensed under MIT so feel free to use it however you like. 

My only ask is if you come up with a better solution to a shortcoming of this plugin, make an issue or a PR with your updates :) happy coding!


## What it does

- For 2D, it assigns the same `Material` resource to every `CanvasItem` in the target subtree.
- For 3D, it can assign `material_override`, `material_overlay`, and/or a shared `next_pass` to every `GeometryInstance3D` in the target subtree.
- If `target_root_path` is empty, it targets this helper node's children.

## What it does not do

- It does not combine a 2D subtree into one draw pass. If you need a single combined 2D shader pass, use Godot's `CanvasGroup`.
- It does not automatically watch runtime-spawned children. Call `refresh_subtree()` after adding nodes dynamically.
- A 3D `next_pass` is only preserved non-destructively for nodes that already have `material_override` or for `MeshInstance3D` surface materials. Other `GeometryInstance3D` types should prefer `material_overlay`.

## Usage

1. Enable the plugin in `Project > Project Settings > Plugins`.
2. Add a `SubtreeShaderApplicator` node to your scene.
3. Leave `target_root_path` empty to target this node's children, or point it at any other subtree root.
4. Set `canvas_item_material` for 2D, `geometry_material_override` for 3D replacement, `geometry_material_overlay` for 3D layering on top of the original material, or `geometry_material_next_pass` to append a 3D next pass without editing the original mesh materials.
5. The helper reacts to those fields automatically. Assigning a material applies it to the subtree, and clearing the field restores the cached original state for that effect type.
6. Leave `apply_on_ready` enabled if you want the configured materials to be re-applied automatically when the scene enters the tree at runtime.
7. Add any nodes to `exceptions` that should be excluded from material application. Excepted nodes and their entire subtrees are skipped, and their original materials are left untouched.

## Outline workflow

- For a character made of many `MeshInstance3D` parts, prefer `geometry_material_overlay` first. Godot renders overlays on top of the current material for the whole geometry, which is usually the cleanest non-destructive path for shield, hit-flash, and outline-style effects.
- Use `geometry_material_next_pass` when you specifically want a real extra material pass instead of an overlay. The addon duplicates the active material chain at the node level so the imported mesh materials are not modified.

## Exceptions

The `exceptions` array lets you exclude specific nodes from material application without removing them from the subtree.

- Any node listed in `exceptions`, along with its entire child hierarchy, is skipped when syncing materials.
- Excepted nodes have their original materials preserved (or restored if the exception is added after materials were already applied).
- Changes to the `exceptions` list take effect immediately — adding a node to exceptions restores its original materials, and removing it causes the shader to be applied on the next sync.
- Node paths in `exceptions` are resolved relative to the `SubtreeShaderApplicator` node, the same as `target_root_path`.

## Global shader parameters

- If every affected node uses the same `ShaderMaterial` resource through this addon, editing that shared resource changes every node at once.
- From code, call `set_canvas_shader_parameter()`, `set_geometry_overlay_shader_parameter()`, `set_geometry_next_pass_shader_parameter()`, or `set_all_assigned_shader_parameters()` on the helper node.
- If you need scene-wide uniforms shared across multiple different materials, use `ShaderGlobalsOverride` or the `RenderingServer.global_shader_parameter_*` API with `global uniform` shader parameters.
