extends Resource
class_name RecipeIngredient

@export var item: ItemData
@export_range(1, 999, 1) var quantity: int = 1
