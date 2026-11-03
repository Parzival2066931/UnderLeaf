extends Button
class_name RecipeSlot
@export var basic_recipe_style: StyleBoxTexture
@export var craftable_recipe_style: StyleBoxTexture


var recipe: CraftRecipe

func setup(craft_recipe: CraftRecipe) -> void:
	recipe = craft_recipe
	icon = recipe.result.texture

func set_craftable(available: bool) -> void:
	var style := basic_recipe_style
	if available:
		style = craftable_recipe_style

	for state in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		add_theme_stylebox_override(state, style)
