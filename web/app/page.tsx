import type { GreetingResponse } from "@shared/types";

// Hello-world som beviser delt type-kontrakt med serveren.
const greeting: GreetingResponse = {
  message: "Hello from huginn web",
};

export default function Home() {
  return (
    <main style={{ padding: "2rem", fontFamily: "system-ui" }}>
      <h1>{greeting.message}</h1>
    </main>
  );
}
