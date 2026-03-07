local merge = require("lib").merge

local hackium_tint = { r = 0.35, g = 0.9, b = 1, a = 1 }

data:extend({
	{
		type = "item",
		name = "hackium",
		icons = {
			{
				icon = "__base__/graphics/icons/iron-plate.png",
				icon_size = 64,
				tint = hackium_tint,
			},
		},
		subgroup = "raw-resource",
		order = "g[hackium]",
		stack_size = 50,
	},

	merge(data.raw.resource["iron-ore"], {
		name = "hackium",
		icons = {
			{
				icon = "__base__/graphics/icons/iron-plate.png",
				icon_size = 64,
				tint = hackium_tint,
			},
		},
		minable = {
			mining_time = 1,
			result = "hackium",
		},
		autoplace = "nil",
		map_color = { r = 0.45, g = 0.9, b = 1 },
		stages = {
			sheet = {
				filename = "__base__/graphics/entity/iron-ore/iron-ore.png",
				priority = "extra-high",
				size = 128,
				frame_count = 8,
				variation_count = 8,
				scale = 0.5,
				tint = hackium_tint,
			},
		},
		mining_visualisation_tint = hackium_tint,
	}),
})
