import { Rcon } from "rcon-client"

const rconHost = process.env.RCON_HOST ?? "127.0.0.1"
const rconPort = Number(process.env.RCON_PORT ?? "27015")
const rconPassword = process.env.RCON_PASSWORD ?? "mysecretpassword"

const rcon = await Rcon.connect({
  host: rconHost,
  port: rconPort,
  password: rconPassword,
})

const response = await rcon.send(
  '/silent-command remote.call("workos_hackathon", "draw_nauvis_sprite")',
)
console.log("Response:", response)

await rcon.end()
