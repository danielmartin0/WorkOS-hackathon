local REMOTE_INTERFACE_NAME = "workos_hackathon"
local REMOTE_FUNCTION_NAME = "draw_nauvis_sprite"

script.on_event(defines.events.on_player_joined_game, function()
	if not remote.interfaces[REMOTE_INTERFACE_NAME] then
		remote.add_interface(REMOTE_INTERFACE_NAME, {
			[REMOTE_FUNCTION_NAME] = function()
				rendering.draw_sprite({
					sprite = "file/image.png",
					render_layer = "object",
					surface = "nauvis",
					target = { x = 0, y = 10 }
				})
			end
		})
	end
end)

