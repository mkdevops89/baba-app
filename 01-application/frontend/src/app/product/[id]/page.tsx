"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import Navbar from "../../../components/Navbar";
import { API_URL, getOrCreateSessionId } from "../../../services/api";

interface Product { id: number; name: string; description: string; price: number; imageUrl?: string; category: string; }

export default function ProductDetail() {
  const params = useParams<{ id: string }>();
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);

  useEffect(() => {
    fetch(`${API_URL}/products/${params.id}`)
      .then((response) => response.ok ? response.json() : Promise.reject(response.status))
      .then(setProduct).catch(() => setProduct(null)).finally(() => setLoading(false));
  }, [params.id]);

  const addToCart = async () => {
    if (!product) return;
    setAdding(true);
    try {
      const response = await fetch(`${API_URL}/cart/add`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ productId: product.id, quantity: 1, sessionId: getOrCreateSessionId() }) });
      if (response.ok) window.dispatchEvent(new Event("baba-cart-updated"));
    } finally { setAdding(false); }
  };

  if (loading) return <main><Navbar /><div style={{ padding: "3rem" }}>Loading product...</div></main>;
  if (!product) return <main><Navbar /><div style={{ padding: "3rem" }}><h1>Product not found</h1><Link href="/home">Return to Baba App</Link></div></main>;

  return (
    <main style={{ minHeight: "100vh", background: "white" }}>
      <Navbar />
      <div style={{ maxWidth: 1350, margin: "0 auto", padding: "1.25rem" }}>
        <div style={{ fontSize: ".8rem", color: "#565959", marginBottom: "1.25rem" }}><Link href="/home">Home</Link> › {product.category} › {product.name}</div>
        <div style={{ display: "grid", gridTemplateColumns: "minmax(280px, 1.2fr) minmax(300px, 1fr) minmax(260px, .65fr)", gap: "2rem", alignItems: "start" }}>
          <div style={{ height: 520, display: "grid", placeItems: "center", background: "#fafafa" }}><img src={product.imageUrl || "/images/default.jpg"} alt={product.name} style={{ maxWidth: "92%", maxHeight: "92%", objectFit: "contain" }} /></div>
          <section>
            <h1 style={{ fontSize: "2rem", lineHeight: 1.2, marginTop: 0 }}>{product.name}</h1>
            <div style={{ color: "#007185" }}>Visit the {product.category} Store</div>
            <div style={{ padding: ".8rem 0", borderBottom: "1px solid #ddd" }}>★★★★☆ <span style={{ color: "#007185" }}>1,234 ratings</span></div>
            <div style={{ fontSize: "2rem", marginTop: "1rem" }}>${Number(product.price).toFixed(2)}</div>
            <div style={{ color: "#565959", fontSize: ".9rem" }}>List Price: <span style={{ textDecoration: "line-through" }}>${(Number(product.price) * 1.2).toFixed(2)}</span></div>
            <h3>About this item</h3>
            <ul style={{ lineHeight: 1.7 }}><li>{product.description}</li><li>Designed for dependable everyday use.</li><li>Backed by Baba App customer support.</li><li>Eligible for standard returns.</li></ul>
          </section>
          <aside style={{ border: "1px solid #d5d9d9", borderRadius: 10, padding: "1.25rem", boxShadow: "0 1px 2px rgba(0,0,0,.08)" }}>
            <div style={{ fontSize: "1.65rem", marginBottom: ".75rem" }}>${Number(product.price).toFixed(2)}</div>
            <p><strong>FREE delivery</strong> within 2–3 days</p><p style={{ color: "#007600", fontSize: "1.15rem" }}>In Stock</p>
            <button onClick={addToCart} disabled={adding} style={{ width: "100%", border: "1px solid #fcd200", background: "#ffd814", borderRadius: 999, padding: ".7rem", cursor: "pointer" }}>{adding ? "Adding..." : "Add to Cart"}</button>
            <button style={{ width: "100%", border: "1px solid #ff8f00", background: "#ffa41c", borderRadius: 999, padding: ".7rem", cursor: "pointer", marginTop: ".6rem" }}>Buy Now</button>
            <div style={{ borderTop: "1px solid #eee", marginTop: "1rem", paddingTop: "1rem", fontSize: ".8rem", color: "#565959" }}>Ships from <strong>Baba App</strong><br />Sold by <strong>Baba App</strong></div>
          </aside>
        </div>
      </div>
    </main>
  );
}
