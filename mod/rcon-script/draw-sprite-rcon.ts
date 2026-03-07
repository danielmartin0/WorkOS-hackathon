import { Rcon } from "rcon-client"

const rcon = await Rcon.connect({
  host: "localhost",
  port: 27015,
  password: "mysecretpassword",
})

const response = await rcon.send(
  'rendering.draw_sprite({sprite = "file/sprite.png",render_layer = "object",surface = "nauvis",target = { x = 0, y = 10 }})',
)
console.log("Response:", response)

await rcon.end()
