import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Talking Alarm | The only alarm that actually wakes you up",
  description: "Built for heavy sleepers. An AI alarm that talks back and forces you to stay awake.",
};

export const viewport = {
  themeColor: "#000000",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark scroll-smooth">
      <body className={`${inter.variable} antialiased bg-black text-white min-h-screen`}>
        {children}
      </body>
    </html>
  );
}
