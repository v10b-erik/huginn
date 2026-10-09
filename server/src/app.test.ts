import { describe, expect, test } from "bun:test";
import type { HealthResponse } from "@shared/types";
import { handleRequest } from "./app";

describe("handleRequest", () => {
  test("/health returns ok with shared type shape", async () => {
    const res = handleRequest(new Request("http://localhost/health"));
    expect(res.status).toBe(200);
    const body = (await res.json()) as HealthResponse;
    expect(body.status).toBe("ok");
    expect(Date.parse(body.timestamp)).not.toBeNaN();
  });

  test("unknown path returns 404", () => {
    const res = handleRequest(new Request("http://localhost/nope"));
    expect(res.status).toBe(404);
  });
});
