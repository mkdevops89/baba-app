"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import Navbar from "../../components/Navbar";
import HeroCarousel from "../../components/HeroCarousel";
import ProductCard from "../../components/ProductCard";
import { API_URL } from "../../services/api";

interface Product { id: number; name: string; description: string; price: number; imageUrl?: string; category: string; }

function Storefront() {
  const params = useSearchParams();
  const search = params.get("search")?.trim() || "";
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    setLoading(true); setError(false);
    const url = search ? `${API_URL}/products/search?q=${encodeURIComponent(search)}` : `${API_URL}/products`;
    fetch(url)
      .then((response) => { if (!response.ok) throw new Error(String(response.status)); return response.json(); })
      .then((data) => setProducts(Array.isArray(data) ? data : []))
      .catch((err) => { console.error(err); setError(true); })
      .finally(() => setLoading(false));
  }, [search]);

  const heading = useMemo(() => search ? `Results for “${search}”` : "Featured products", [search]);

  return (
    <>
      {!search && <HeroCarousel />}
      <section style={{ maxWidth: 1450, margin: search ? "2rem auto" : "-5rem auto 0", position: "relative", zIndex: 10, padding: "0 1rem 3rem" }}>
        <h2 style={{ margin: "0 0 1rem", fontSize: "1.35rem" }}>{heading}</h2>
        {loading && <div style={stateStyle}>Loading products...</div>}
        {error && <div style={stateStyle}>Unable to load products. Confirm the backend is running on port 8080.</div>}
        {!loading && !error && products.length === 0 && <div style={stateStyle}>No products found.</div>}
        {!loading && !error && products.length > 0 && (
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(245px, 1fr))", gap: "1.15rem" }}>
            {products.map((product) => <ProductCard key={product.id} id={product.id} title={product.name} price={Number(product.price)} category={product.category} image={product.imageUrl || "/images/default.jpg"} />)}
          </div>
        )}
      </section>
    </>
  );
}

export default function Home() {
  return <main style={{ minHeight: "100vh", background: "#eaeded" }}><Navbar /><Suspense fallback={<div style={stateStyle}>Loading storefront...</div>}><Storefront /></Suspense></main>;
}

const stateStyle: React.CSSProperties = { background: "white", padding: "2.5rem", textAlign: "center", borderRadius: 4 };
