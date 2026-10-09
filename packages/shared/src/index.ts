// Delte API-kontrakter mellom server og web. Én kilde til sannhet —
// endrer du serverens respons, endrer du typen her først.

export interface HealthResponse {
  status: "ok";
  /** Deploy-motoren (tillitskjernen) krever ok, og db når produktet har database. */
  ok: true;
  db?: boolean;
  /** GIT_SHA fra miljøet — motoren sjekker at det er den nye koden som svarer. */
  sha: string;
  product: string;
  timestamp: string;
}

export interface GreetingResponse {
  message: string;
}
