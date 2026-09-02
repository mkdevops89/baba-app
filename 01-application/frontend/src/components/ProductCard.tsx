import Image from "next/image";

interface ProductProps {
    title: string;
    price: number;
    image: string;
    category: string;
}

export default function ProductCard({ title, price, image, category }: ProductProps) {
    return (
        <div className="glass-panel" style={{
            padding: '1.5rem',
            display: 'flex',
            flexDirection: 'column',
            height: '100%',
            backgroundColor: 'white',
            zIndex: 1,
            position: 'relative'
        }}>
            <h3 style={{ fontSize: '1.2rem', marginBottom: '1rem' }}>{title}</h3>

            <div style={{ flex: 1, display: 'flex', justifyContent: 'center', alignItems: 'center', marginBottom: '1rem', background: '#f8f8f8', minHeight: '200px' }}>
                {/* Render the actual product image */}
                <img
                    src={image}
                    alt={title}
                    style={{ maxHeight: '100%', maxWidth: '100%', objectFit: 'contain' }}
                />
            </div>

            <div style={{ marginBottom: '0.5rem' }}>
                <span style={{ fontSize: '0.8rem', color: '#007185' }}>{category}</span>
            </div>

            <div style={{ fontSize: '1.3rem', fontWeight: 'bold', display: 'flex', alignItems: 'start' }}>
                <span style={{ fontSize: '0.8rem', marginTop: '4px' }}>$</span>
                {price}
            </div>

            <div style={{ marginTop: '0.5rem', color: '#565959', fontSize: '0.9rem' }}>
                Fast Delivery
            </div>

            <button className="btn-primary" style={{ marginTop: '1rem', width: '100%' }}>
                Add to Cart
            </button>
        </div>
    );
}
