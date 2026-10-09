import type { HealthResponse, GreetingResponse } from "@shared/types";

export const PRODUCT = "huginn";

// Ren request-handler — testbar uten å starte en server.
export function handleRequest(req: Request): Response {
  const url = new URL(req.url);

  switch (url.pathname) {
    case "/health": {
      const body: HealthResponse = {
        status: "ok",
        ok: true,
        sha: process.env.GIT_SHA ?? "dev",
        product: PRODUCT,
        timestamp: new Date().toISOString(),
      };
      return Response.json(body);
    }
    case "/greeting": {
      const body: GreetingResponse = {
        message: `Hello from ${PRODUCT} server`,
      };
      return Response.json(body);
    }
    default:
      return new Response("Not found", { status: 404 });
  }
}
