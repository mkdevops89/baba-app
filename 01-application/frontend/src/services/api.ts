export const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080/api";

export function getOrCreateSessionId(): string {
  if (typeof window === "undefined") return "";
  let sessionId = localStorage.getItem("babaAppSessionId");
  if (!sessionId) {
    sessionId = crypto.randomUUID();
    localStorage.setItem("babaAppSessionId", sessionId);
  }
  return sessionId;
}
