import type { Metadata } from 'next';
import './globals.css';
export const metadata:Metadata={title:'NFCnect — Loyalty Studio',description:'Secure membership accounts, shared points and verified rewards for local businesses.'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
