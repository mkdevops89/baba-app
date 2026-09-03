"use client";

import { useRouter } from "next/navigation";

const categories = [
  "All",
  "Today's Deals",
  "Customer Service",
  "Registry",
  "Gift Cards",
  "Sell",
  "Electronics",
  "Computers",
  "Home",
  "Clothing",
  "Sports",
  "Books",
];

export default function CategoryBar() {
  const router = useRouter();

  const handleCategory = (category: string) => {
    if (category === "All" || ["Today's Deals", "Customer Service", "Registry", "Gift Cards", "Sell"].includes(category)) {
      router.push("/home");
      return;
    }
    router.push(`/home?search=${encodeURIComponent(category)}`);
  };

  return (
    <div style={{
      display: "flex", alignItems: "center", gap: "0.35rem", overflowX: "auto",
      whiteSpace: "nowrap", background: "#232f3e", color: "white", padding: "0.45rem 1rem",
      fontSize: "0.88rem"
    }}>
      {categories.map((category, index) => (
        <button
          key={category}
          onClick={() => handleCategory(category)}
          style={{
            background: "transparent", border: index === 0 ? "1px solid transparent" : "1px solid transparent",
            color: "white", padding: "0.35rem 0.55rem", cursor: "pointer", fontWeight: index === 0 ? 700 : 500
          }}
          onMouseEnter={(e) => (e.currentTarget.style.borderColor = "white")}
          onMouseLeave={(e) => (e.currentTarget.style.borderColor = "transparent")}
        >
          {index === 0 ? "☰ All" : category}
        </button>
      ))}
    </div>
  );
}
