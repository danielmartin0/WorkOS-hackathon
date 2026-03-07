local merge = require("lib").merge

data:extend({
	{
		type = "item",
		name = "hackium",
		icons = {
			{
				icon = "__space-age__/graphics/icons/bioflux.png",
				icon_size = 64,
				tint = { r = 0.35, g = 0.9, b = 1, a = 1 },
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
				icon = "__space-age__/graphics/icons/bioflux.png",
				icon_size = 64,
				tint = { r = 0.35, g = 0.9, b = 1, a = 1 },
			},
		},
		minable = {
			mining_time = 1,
			result = "hackium",
		},
		autoplace = "nil",
		map_color = { r = 0.45, g = 0.9, b = 1 },
	}),
})
