import { handleRequest } from "./app";

const port = Number(process.env.PORT ?? 3001);

Bun.serve({
  port,
  fetch: handleRequest,
});

console.log(`server listening on :${port}`);
