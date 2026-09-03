"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import CategoryBar from "./CategoryBar";
import { API_URL, getOrCreateSessionId } from "../services/api";

export default function Navbar() {
  const router = useRouter();
  const [search, setSearch] = useState("");
  const [cartCount, setCartCount] = useState(0);

  useEffect(() => {
    const refreshCart = async () => {
      try {
        const sessionId = getOrCreateSessionId();
        const response = await fetch(`${API_URL}/cart?sessionId=${encodeURIComponent(sessionId)}`);
        if (!response.ok) return;
        const items = await response.json();
        setCartCount(items.reduce((total: number, item: { quantity: number }) => total + item.quantity, 0));
      } catch (error) {
        console.error("Unable to refresh cart count", error);
      }
    };

    refreshCart();
    window.addEventListener("baba-cart-updated", refreshCart);
    return () => window.removeEventListener("baba-cart-updated", refreshCart);
  }, []);

  const submitSearch = (event: FormEvent) => {
    event.preventDefault();
    const query = search.trim();
    router.push(query ? `/home?search=${encodeURIComponent(query)}` : "/home");
  };

  return (
    <header style={{ position: "sticky", top: 0, zIndex: 50 }}>
      <div style={{ background: "#131921", color: "white", minHeight: 64, display: "flex", alignItems: "center", gap: "1rem", padding: ".55rem 1.5rem" }}>
        <Link href="/home" style={{ color: "white", textDecoration: "none", fontWeight: 800, fontSize: "1.55rem", letterSpacing: "-1px" }}>
          Baba<span style={{ color: "#ff9900" }}>App</span>
        </Link>

        <div style={{ display: "flex", flexDirection: "column", fontSize: ".75rem", minWidth: 105 }}>
          <span style={{ color: "#ccc" }}>Deliver to</span>
          <strong>📍 United States</strong>
        </div>

        <form onSubmit={submitSearch} style={{ display: "flex", flex: 1, height: 42, minWidth: 200 }}>
          <span style={{ background: "#f3f3f3", color: "#555", padding: "0 .75rem", display: "grid", placeItems: "center", borderRadius: "5px 0 0 5px", fontSize: ".8rem" }}>All</span>
          <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search Baba App" style={{ flex: 1, border: 0, outline: 0, padding: "0 .8rem", fontSize: "1rem" }} />
          <button type="submit" style={{ width: 56, border: 0, background: "#febd69", borderRadius: "0 5px 5px 0", cursor: "pointer", fontSize: "1.25rem" }}>⌕</button>
        </form>

        <Link href="/login" style={navLinkStyle}><small>Hello, Sign in</small><strong>Account & Lists</strong></Link>
        <div style={navLinkStyle}><small>Returns</small><strong>& Orders</strong></div>
        <Link href="/cart" style={{ ...navLinkStyle, position: "relative", fontSize: "1rem" }}>
          <span style={{ fontSize: "1.65rem" }}>🛒</span>
          <span style={{ position: "absolute", top: -6, left: 20, color: "#ff9900", fontWeight: 800 }}>{cartCount}</span>
          <strong>Cart</strong>
        </Link>
      </div>
      <CategoryBar />
    </header>
  );
}

const navLinkStyle: React.CSSProperties = {
  color: "white", textDecoration: "none", display: "flex", flexDirection: "column", whiteSpace: "nowrap", fontSize: ".8rem"
};
