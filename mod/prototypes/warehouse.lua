local item_sounds = require("__base__.prototypes.item_sounds")

data:extend({
	{
		type = "container",
		name = "warehouse",
		icons = {
			{ icon = "__WorkOS-hackathon__/other-graphics/icons/container-4-base.png", icon_size = 64 },
		},
		flags = { "placeable-neutral", "player-creation" },
		minable = { mining_time = 1, result = "warehouse" },
		max_health = 1000,
		open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume = 0.43 },
		close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.43 },
		resistances = {
			{
				type = "fire",
				percent = 90,
			},
			{
				type = "impact",
				percent = 60,
			},
		},
		collision_box = {
			{
				-1.8,
				-1.8,
			},
			{
				1.8,
				1.8,
			},
		},
		selection_box = {
			{
				-1.8,
				-1.8,
			},
			{
				1.8,
				1.8,
			},
		},
		inventory_size = 39,
		picture = {
			layers = {
				{
					filename = "__WorkOS-hackathon__/image1.png",
					height = 260,
					scale = 0.5,
					width = 260,
				},
				{
					draw_as_shadow = true,
					filename = "__WorkOS-hackathon__/other-graphics/entity/shadow.png",
					height = 176,
					scale = 0.5,
					shift = {
						0.875,
						0.65625,
					},
					width = 308,
				},
			},
		},
	},
	{
		type = "item",
		name = "warehouse",
		icons = {
			{ icon = "__WorkOS-hackathon__/other-graphics/icons/container-4-base.png", icon_size = 64 },
		},
		subgroup = "storage",
		order = "a[warehouse]",
		stack_size = 10,
		inventory_move_sound = item_sounds.metal_chest_inventory_move,
		pick_sound = item_sounds.metal_chest_inventory_pickup,
		drop_sound = item_sounds.metal_chest_inventory_move,
		place_result = "warehouse",
	},
	{
		type = "recipe",
		name = "warehouse",
		enabled = true,
		ingredients = {},
		results = {
			{ type = "item", name = "warehouse", amount = 1 },
		},
	},
})
