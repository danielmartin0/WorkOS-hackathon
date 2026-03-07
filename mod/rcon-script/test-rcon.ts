import { Rcon } from "rcon-client"

const commandToRun = process.argv.slice(2).join(" ").trim()

if (!commandToRun) {
  console.error('Usage: tsx test-rcon.ts "<factorio-command>"')
  process.exit(1)
}

const rcon = await Rcon.connect({
  host: "localhost",
  port: 27015,
  password: "mysecretpassword",
})

// Send the very first command first, then execute passed CLI command
await rcon.send('/silent-command game.print("Hello from AdaL!")')
const response = await rcon.send(commandToRun)
console.log("Response:", response)

await rcon.end()
