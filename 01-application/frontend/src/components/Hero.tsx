export default function Hero() {
    return (
        <div style={{
            position: 'relative',
            height: '400px',
            background: 'linear-gradient(to bottom, #d6e6f5, #eaeded)',
            marginBottom: '-150px'
        }}>
            <div className="container">
                {/* Placeholder for a carousel image */}
                <div style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    height: '100%',
                    fontSize: '2rem',
                    color: '#333'
                }}>
                    {/* Hero Banner Content can go here */}
                </div>
            </div>
            <div style={{
                position: 'absolute',
                bottom: 0,
                width: '100%',
                height: '100px',
                background: 'linear-gradient(to bottom, transparent, #eaeded)'
            }}></div>
        </div>
    );
}
