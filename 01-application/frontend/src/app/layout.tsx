import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Baba App | Cloud-Native Shopping",
  description: "A production-style cloud-native application and DevSecOps reference platform",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  );
}
