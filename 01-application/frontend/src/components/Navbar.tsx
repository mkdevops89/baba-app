import Link from 'next/link';

export default function Navbar() {
    return (
        <nav style={{ backgroundColor: 'var(--secondary)', color: 'white', padding: '0.5rem 0' }}>
            <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: '60px' }}>

                {/* Logo */}
                <Link href="/" style={{ fontSize: '1.5rem', fontWeight: 'bold', color: 'white', textDecoration: 'none', marginRight: '2rem' }}>
                    Baba<span style={{ color: 'var(--primary)' }}>App</span>
                </Link>

                {/* Search Bar */}
                <div style={{ flex: 1, display: 'flex', maxWidth: '800px' }}>
                    <input
                        type="text"
                        placeholder="Search Baba App"
                        style={{
                            width: '100%',
                            padding: '0.6rem',
                            borderRadius: '4px 0 0 4px',
                            border: 'none',
                            outline: 'none'
                        }}
                    />
                    <button style={{
                        backgroundColor: 'var(--primary)',
                        border: 'none',
                        borderRadius: '0 4px 4px 0',
                        padding: '0 1rem',
                        fontWeight: 'bold'
                    }}>
                        Search
                    </button>
                </div>

                {/* Actions */}
                <div style={{ display: 'flex', gap: '1.5rem', marginLeft: '2rem' }}>
                    <Link href="/login" style={{ color: 'white', display: 'flex', flexDirection: 'column', fontSize: '0.8rem' }}>
                        <span>Hello, Sign in</span>
                        <span style={{ fontWeight: 'bold', fontSize: '0.9rem' }}>Account & Lists</span>
                    </Link>

                    <Link href="/orders" style={{ color: 'white', display: 'flex', flexDirection: 'column', fontSize: '0.8rem' }}>
                        <span>Returns</span>
                        <span style={{ fontWeight: 'bold', fontSize: '0.9rem' }}>& Orders</span>
                    </Link>

                    <Link href="/cart" style={{ color: 'white', display: 'flex', alignItems: 'end' }}>
                        <span style={{ fontSize: '1.2rem', fontWeight: 'bold' }}>🛒 Cart</span>
                    </Link>
                </div>

            </div>

            {/* Sub-nav */}
            <div style={{ backgroundColor: 'var(--secondary-light)', padding: '0.5rem 0', marginTop: '0.5rem' }}>
                <div className="container" style={{ display: 'flex', gap: '1rem', fontSize: '0.9rem' }}>
                    <Link href="#" style={{ color: 'white' }}>All</Link>
                    <Link href="#" style={{ color: 'white' }}>Today's Deals</Link>
                    <Link href="#" style={{ color: 'white' }}>Customer Service</Link>
                    <Link href="#" style={{ color: 'white' }}>Registry</Link>
                    <Link href="#" style={{ color: 'white' }}>Gift Cards</Link>
                    <Link href="#" style={{ color: 'white' }}>Sell</Link>
                </div>
            </div>
        </nav>
    );
}
