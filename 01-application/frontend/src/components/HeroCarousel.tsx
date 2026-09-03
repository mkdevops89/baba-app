"use client";

import { useEffect, useState } from "react";

const slides = [
  {
    image: "https://images.pexels.com/photos/459653/pexels-photo-459653.jpeg?auto=compress&cs=tinysrgb&w=1600",
    title: "Upgrade Your Tech",
    subtitle: "Discover devices and accessories for work, play, and everything in between.",
  },
  {
    image: "https://images.pexels.com/photos/2526878/pexels-photo-2526878.jpeg?auto=compress&cs=tinysrgb&w=1600",
    title: "Move More",
    subtitle: "Gear up for your next run, workout, or weekend adventure.",
  },
  {
    image: "https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=1600",
    title: "Upgrade Your Kitchen",
    subtitle: "Smart everyday essentials for better meals at home.",
  },
];

export default function HeroCarousel() {
  const [current, setCurrent] = useState(0);

  useEffect(() => {
    const timer = window.setInterval(() => setCurrent((value) => (value + 1) % slides.length), 5000);
    return () => window.clearInterval(timer);
  }, []);

  const slide = slides[current];

  return (
    <section style={{ position: "relative", height: "clamp(280px, 36vw, 500px)", overflow: "hidden", background: "#111827" }}>
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: `linear-gradient(to bottom, rgba(0,0,0,.15) 35%, rgba(234,237,237,.98) 100%), url(${slide.image})`,
        backgroundSize: "cover", backgroundPosition: "center", transition: "background-image .4s ease"
      }} />
      <div style={{ position: "absolute", left: "7%", top: "18%", color: "white", maxWidth: "560px", textShadow: "0 2px 8px rgba(0,0,0,.65)" }}>
        <h1 style={{ fontSize: "clamp(2rem, 4vw, 3.8rem)", margin: 0, fontWeight: 800 }}>{slide.title}</h1>
        <p style={{ fontSize: "clamp(1rem, 1.6vw, 1.35rem)", marginTop: ".75rem", lineHeight: 1.5 }}>{slide.subtitle}</p>
      </div>
      <button aria-label="Previous slide" onClick={() => setCurrent((current - 1 + slides.length) % slides.length)} style={arrowStyle("left")}>‹</button>
      <button aria-label="Next slide" onClick={() => setCurrent((current + 1) % slides.length)} style={arrowStyle("right")}>›</button>
      <div style={{ position: "absolute", bottom: "2rem", left: "50%", transform: "translateX(-50%)", display: "flex", gap: ".5rem" }}>
        {slides.map((_, index) => <span key={index} style={{ width: 10, height: 10, borderRadius: "50%", background: current === index ? "#ff9900" : "rgba(255,255,255,.75)" }} />)}
      </div>
    </section>
  );
}

function arrowStyle(side: "left" | "right"): React.CSSProperties {
  return {
    position: "absolute", [side]: "1rem", top: "45%", transform: "translateY(-50%)",
    width: 46, height: 64, border: "1px solid rgba(255,255,255,.7)", borderRadius: 6,
    background: "rgba(0,0,0,.14)", color: "white", fontSize: "2.6rem", cursor: "pointer",
  };
}
