"use client";

import Link from "next/link";
import { useState } from "react";
import { API_URL, getOrCreateSessionId } from "../services/api";

interface Props {
  id: number;
  title: string;
  price: number;
  image: string;
  category: string;
}

export default function ProductCard({ id, title, price, image, category }: Props) {
  const [loading, setLoading] = useState(false);
  const [added, setAdded] = useState(false);
  const listPrice = price * 1.2;

  const addToCart = async () => {
    setLoading(true);
    setAdded(false);
    try {
      const response = await fetch(`${API_URL}/cart/add`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ productId: id, quantity: 1, sessionId: getOrCreateSessionId() }),
      });
      if (!response.ok) throw new Error(`Cart API returned ${response.status}`);
      window.dispatchEvent(new Event("baba-cart-updated"));
      setAdded(true);
      window.setTimeout(() => setAdded(false), 1200);
    } catch (error) {
      console.error("Unable to add product to cart", error);
    } finally {
      setLoading(false);
    }
  };

  const dollars = Math.floor(price);
  const cents = Math.round((price - dollars) * 100).toString().padStart(2, "0");

  return (
    <article style={{ background: "white", padding: "1rem", display: "flex", flexDirection: "column", minHeight: 500, boxShadow: "0 1px 3px rgba(0,0,0,.08)" }}>
      <Link
        href={`/product/${id}`} style={{ height: 220, width: "100%", display: "flex", alignItems: "center", justifyContent: "center", background: "#f7f7f7", marginBottom: ".85rem", overflow: "hidden", flexShrink: 0}}>
        <img src={image} alt={title} style={{width: "100%", height: "100%", objectFit: "contain", display: "block"}} />
      </Link>
      <Link href={`/product/${id}`} style={{ color: "#0f1111", textDecoration: "none", fontSize: "1.05rem", fontWeight: 650, lineHeight: 1.35, minHeight: "2.8rem", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden", }}>{title}</Link>
      <div style={{ color: "#007185", fontSize: ".85rem", marginTop: ".4rem" }}>★★★★☆ <span style={{ color: "#565959" }}>1,234</span></div>
      <div style={{ marginTop: ".3rem", display: "flex", alignItems: "flex-start" }}><span style={{ fontSize: ".75rem", marginTop: 4 }}>$</span><strong style={{ fontSize: "1.7rem" }}>{dollars}</strong><strong style={{ fontSize: ".78rem", marginTop: 4 }}>{cents}</strong></div>
      <div style={{ fontSize: ".76rem", color: "#565959" }}>List: <span style={{ textDecoration: "line-through" }}>${listPrice.toFixed(2)}</span></div>
      <div style={{ color: "#007185", fontSize: ".75rem", marginTop: ".35rem" }}>{category}</div>
      <p style={{ fontSize: ".8rem", color: "#565959", margin: ".45rem 0 0" }}>Delivery <strong>within 2–3 days</strong></p>
      <button onClick={addToCart} disabled={loading} style={{ marginTop: "auto", background: "#ffd814", border: "1px solid #fcd200", borderRadius: 999, padding: ".55rem 1rem", cursor: loading ? "wait" : "pointer", fontWeight: 500 }}>
        {loading ? "Adding..." : added ? "Added ✓" : "Add to Cart"}
      </button>
    </article>
  );
}
