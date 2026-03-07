import { Rcon } from "rcon-client"

const rcon = await Rcon.connect({
  host: "localhost",
  port: 27015,
  password: "mysecretpassword",
})

const response = await rcon.send(
  '/silent-command rendering.draw_sprite({sprite = "file/image.png",render_layer = "object",surface = "nauvis",target = { x = 0, y = 10 }})',
)
console.log("Response:", response)

await rcon.end()
