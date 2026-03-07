import { Rcon } from "rcon-client"

const rcon = await Rcon.connect({
  host: "localhost",
  port: 27015,
  password: "mysecretpassword",
})

const response = await rcon.send(
  '/silent-command remote.call("workos_hackathon", "draw_nauvis_sprite")',
)
console.log("Response:", response)

await rcon.end()
