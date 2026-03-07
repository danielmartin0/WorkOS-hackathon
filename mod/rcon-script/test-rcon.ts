import { Rcon } from "rcon-client"

const commandToRun = process.argv.slice(2).join(" ").trim()

if (!commandToRun) {
  console.error('Usage: tsx test-rcon.ts "<factorio-command>"')
  process.exit(1)
}

const rconHost = process.env.RCON_HOST ?? "127.0.0.1"
const rconPort = Number(process.env.RCON_PORT ?? "27015")
const rconPassword = process.env.RCON_PASSWORD ?? "mysecretpassword"

const rcon = await Rcon.connect({
  host: rconHost,
  port: rconPort,
  password: rconPassword,
})

// Send the very first command first, then execute passed CLI command
await rcon.send('/silent-command game.print("Hello from Claude!")')
const response = await rcon.send(commandToRun)
console.log("Response:", response)

await rcon.end()
