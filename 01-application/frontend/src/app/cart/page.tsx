"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import Navbar from "../../components/Navbar";

interface BackendCartItem {
    id: number;
    product: {
        id: number;
        name: string;
        price: number;
        imageUrl?: string;
        category?: string;
    };
    quantity: number;
}

function getOrCreateSessionId(): string {
    let sessionId = localStorage.getItem("babaAppSessionId");
    if (!sessionId) {
        sessionId = crypto.randomUUID();
        localStorage.setItem("babaAppSessionId", sessionId);
    }
    return sessionId;
}

export default function CartPage() {
    const [items, setItems] = useState<BackendCartItem[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080/api";

    // Perform only the API request here. Keeping the request separate from
    // React state updates allows the initial effect to cancel an in-flight
    // request safely if the component unmounts.
    const requestCart = useCallback(
        async (signal?: AbortSignal): Promise<BackendCartItem[]> => {
            const sessionId = getOrCreateSessionId();

            const response = await fetch(
                `${apiUrl}/cart?sessionId=${encodeURIComponent(sessionId)}`,
                { signal },
            );

            if (!response.ok) {
                throw new Error(`Cart API returned ${response.status}`);
            }

            return response.json() as Promise<BackendCartItem[]>;
        },
        [apiUrl],
    );

    // Update the cart state and notify other components, such as the navbar,
    // whenever fresh cart data has been retrieved successfully.
    const publishCart = useCallback((cartItems: BackendCartItem[]) => {
        setItems(cartItems);
        window.dispatchEvent(new Event("baba-cart-updated"));
    }, []);

    // Refresh the cart after user-initiated mutations. In this path, showing
    // the loading state immediately is intentional because it follows a click.
    const fetchCart = useCallback(async () => {
        setLoading(true);
        setError(null);

        try {
            const cartItems = await requestCart();
            publishCart(cartItems);
        } catch (err) {
            console.error("Failed to load cart:", err);
            setError("Unable to load your cart.");
        } finally {
            setLoading(false);
        }
    }, [publishCart, requestCart]);

    useEffect(() => {
        // Abort the initial request when the component unmounts or apiUrl
        // changes. This prevents stale requests from updating React state.
        const abortController = new AbortController();

        const loadInitialCart = async () => {
            try {
                const cartItems = await requestCart(abortController.signal);

                if (!abortController.signal.aborted) {
                    publishCart(cartItems);
                }
            } catch (err) {
                // AbortError is expected during cleanup and should not be
                // displayed to the user as an application failure.
                if (abortController.signal.aborted) {
                    return;
                }

                console.error("Failed to load cart:", err);
                setError("Unable to load your cart.");
            } finally {
                if (!abortController.signal.aborted) {
                    setLoading(false);
                }
            }
        };

        void loadInitialCart();

        return () => {
            abortController.abort();
        };
    }, [publishCart, requestCart]);

    const updateQuantity = async (productId: number, quantity: number) => {
        const sessionId = getOrCreateSessionId();
        const response = await fetch(`${apiUrl}/cart/add`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ productId, quantity, sessionId }),
        });

        if (!response.ok) {
            setError("Unable to update your cart.");
            return;
        }

        await fetchCart();
    };

    const totalItems = items.reduce((total, item) => total + item.quantity, 0);
    const subtotal = items.reduce((total, item) => total + item.product.price * item.quantity, 0);

    return (
        <main style={{ minHeight: "100vh", background: "#f3f4f6", paddingBottom: "3rem" }}>
            <Navbar />
            <div className="container" style={{ paddingTop: "2rem" }}>
                <div style={{ background: "white", borderRadius: "8px", padding: "1.5rem" }}>
                    <h1 style={{ fontSize: "1.8rem", marginBottom: "1rem" }}>Your Baba App Cart</h1>

                    {loading && <p>Loading your cart...</p>}
                    {error && <p style={{ color: "#b12704" }}>{error}</p>}

                    {!loading && !error && items.length === 0 && (
                        <div style={{ padding: "2rem 0" }}>
                            <p style={{ marginBottom: "1rem" }}>Your cart is empty.</p>
                            <Link href="/home" style={{ color: "#007185" }}>Continue shopping</Link>
                        </div>
                    )}

                    {items.map(item => (
                        <div key={item.id} style={{ display: "flex", gap: "1rem", padding: "1rem 0", borderBottom: "1px solid #ddd", alignItems: "center" }}>
                            <img
                                src={item.product.imageUrl || "/images/default.jpg"}
                                alt={item.product.name}
                                style={{ width: "100px", height: "100px", objectFit: "contain" }}
                            />
                            <div style={{ flex: 1 }}>
                                <h2 style={{ fontSize: "1.05rem", fontWeight: "bold" }}>{item.product.name}</h2>
                                <p style={{ color: "#565959", marginTop: "0.25rem" }}>{item.product.category}</p>
                                <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", marginTop: "0.75rem" }}>
                                    <button onClick={() => updateQuantity(item.product.id, -1)}>-</button>
                                    <span>Qty: {item.quantity}</span>
                                    <button onClick={() => updateQuantity(item.product.id, 1)}>+</button>
                                    <button onClick={() => updateQuantity(item.product.id, -item.quantity)} style={{ marginLeft: "0.5rem", color: "#b12704" }}>
                                        Remove
                                    </button>
                                </div>
                            </div>
                            <strong>${item.product.price.toFixed(2)}</strong>
                        </div>
                    ))}

                    {!loading && items.length > 0 && (
                        <div style={{ textAlign: "right", marginTop: "1.5rem", fontSize: "1.15rem" }}>
                            Subtotal ({totalItems} items): <strong>${subtotal.toFixed(2)}</strong>
                        </div>
                    )}
                </div>
            </div>
        </main>
    );
}
