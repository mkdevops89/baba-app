"use client";

import { useEffect, useState } from 'react';
import Navbar from '../../components/Navbar';
import Hero from '../../components/Hero';
import ProductCard from '../../components/ProductCard';

interface Product {
  id: number;
  name: string;
  price: number;
  category: string;
  imageUrl?: string;
}

export default function Home() {
  const [products, setProducts] = useState<Product[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080/api';
    fetch(`${apiUrl}/products`)
      .then(res => {
        if (!res.ok) throw new Error(`API returned ${res.status}`);
        return res.json();
      })
      .then(data => setProducts(data))
      .catch(err => {
        console.error("Failed to fetch products:", err);
        setError("Unable to load products. Confirm the backend is running on port 8080.");
      });
  }, []);

  return (
    <main style={{ minHeight: '100vh', paddingBottom: '2rem' }}>
      <Navbar />
      <Hero />

      <div className="container" style={{ position: 'relative', zIndex: 10 }}>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
          gap: '1.5rem',
          padding: '1rem'
        }}>
          {error ? (
            <p className="text-center p-10">{error}</p>
          ) : products.length === 0 ? (
            <p className="text-center p-10">Loading products from Baba App API...</p>
          ) : (
            products.map(product => (
              <ProductCard
                key={product.id}
                title={product.name}
                price={product.price}
                category={product.category}
                image={product.imageUrl || "/images/default.jpg"}
              />
            ))
          )}
        </div>
      </div>
    </main>
  );
}
