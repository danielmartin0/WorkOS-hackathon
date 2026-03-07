local merge = require("lib").merge

data:extend({
	{
		type = "item",
		name = "hackium",
		icon = "__base__/graphics/icons/iron-ore.png",
		subgroup = "raw-resource",
		order = "g[hackium]",
		stack_size = 50,
	},

	merge(data.raw.resource["iron-ore"], {
		name = "hackium",
		icon = "__base__/graphics/icons/iron-ore.png",
		minable = {
			mining_time = 1,
			result = "hackium",
		},
		autoplace = "nil",
		map_color = { r = 0.45, g = 0.9, b = 1 },
	}),
})
