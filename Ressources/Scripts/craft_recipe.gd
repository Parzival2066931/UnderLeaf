extends Resource
class_name CraftRecipe

@export var result: ItemData
@export_range(1, 999, 1) var result_quantity: int = 1

@export var ingredients: Array[RecipeIngredient] = []
