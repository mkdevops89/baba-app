'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
    const router = useRouter();

    const handleLogin = (e: React.FormEvent) => {
        e.preventDefault();
        // Simulate login
        router.push('/home');
    };

    return (
        <div style={{
            minHeight: '100vh',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            paddingTop: '2rem',
            background: 'linear-gradient(to bottom, #f0f2f2, #ffffff)'
        }}>
            {/* Logo */}
            <Link href="/" style={{ marginBottom: '1.5rem', fontSize: '2rem', fontWeight: 'bold', textDecoration: 'none', color: 'black' }}>
                Baba<span style={{ color: 'var(--primary)' }}>App</span>
            </Link>

            {/* Login Card */}
            <div className="glass-panel" style={{
                width: '100%',
                maxWidth: '350px',
                padding: '2rem',
                borderRadius: '8px',
                backgroundColor: 'white'
            }}>
                <h1 style={{ fontSize: '1.8rem', marginBottom: '1.5rem', fontWeight: '500' }}>Sign in</h1>

                <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <div>
                        <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 'bold', marginBottom: '0.3rem' }}>Username</label>
                        <input
                            type="text"
                            style={{
                                width: '100%',
                                padding: '0.6rem',
                                borderRadius: '4px',
                                border: '1px solid #ccc',
                                boxShadow: '0 1px 2px rgba(0,0,0,0.1) inset'
                            }}
                        />
                    </div>

                    <div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                            <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 'bold', marginBottom: '0.3rem' }}>Password</label>
                            <Link href="#" style={{ fontSize: '0.8rem', color: '#007185' }}>Forgot your password?</Link>
                        </div>
                        <input
                            type="password"
                            style={{
                                width: '100%',
                                padding: '0.6rem',
                                borderRadius: '4px',
                                border: '1px solid #ccc',
                                boxShadow: '0 1px 2px rgba(0,0,0,0.1) inset'
                            }}
                        />
                    </div>

                    <button type="submit" className="btn-primary" style={{ marginTop: '0.5rem', fontWeight: '500' }}>
                        Sign in
                    </button>
                </form>

                <div style={{ marginTop: '1.5rem', fontSize: '0.8rem' }}>
                    By continuing, you agree to Baba App's <Link href="#" style={{ color: '#007185' }}>Conditions of Use</Link> and <Link href="#" style={{ color: '#007185' }}>Privacy Notice</Link>.
                </div>
            </div>

            {/* New to Amazon */}
            <div style={{
                marginTop: '1.5rem',
                width: '100%',
                maxWidth: '350px',
                textAlign: 'center',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center'
            }}>
                <div style={{
                    width: '100%',
                    borderBottom: '1px solid #e7e7e7',
                    lineHeight: '0.1em',
                    margin: '10px 0 20px',
                    color: '#767676',
                    fontSize: '0.8rem'
                }}>
                    <span style={{ background: '#f1f1f1', padding: '0 10px', backgroundColor: 'transparent' }}>New to Baba App?</span>
                </div>

                <button style={{
                    width: '100%',
                    padding: '0.5rem',
                    background: '#e7e9ec',
                    border: '1px solid #8d9096',
                    borderRadius: '4px',
                    boxShadow: '0 1px 0 rgba(255,255,255,0.6) inset',
                    fontSize: '0.85rem'
                }}>
                    Create your Baba App account
                </button>
            </div>

        </div>
    );
}
