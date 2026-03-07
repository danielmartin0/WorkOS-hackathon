import "dotenv/config";
import { createServer } from "./server.js";

const port = Number(process.env.AGENT_PORT ?? "5051");
const app = createServer();

app.listen(port, "127.0.0.1", () => {
  // eslint-disable-next-line no-console
  console.log(`Agent sidecar listening on http://127.0.0.1:${port}`);
});
