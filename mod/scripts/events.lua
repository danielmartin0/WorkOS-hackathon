script.on_event(defines.events.on_chunk_generated, function(event)
	local surface = event.surface
	if not (surface and surface.valid) then
		return
	end

	if surface.name ~= "nauvis" then
		return
	end

	if storage.hackium_patch_generated then
		return
	end

	local area = event.area
	if area.left_top.x > 0 or area.right_bottom.x < 0 or area.left_top.y > 0 or area.right_bottom.y < 0 then
		return
	end

	for x = -8, 8, 2 do
		for y = -8, 8, 2 do
			surface.create_entity({
				name = "hackium",
				position = { x, y },
				amount = 3000,
			})
		end
	end

	storage.hackium_patch_generated = true
end)
