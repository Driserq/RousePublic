"use client";

import Hero from "@/app/components/Hero";
import WhosItFor from "@/app/components/WhosItFor";
import Features from "@/app/components/Features";
import Benefits from "@/app/components/Benefits";
import FAQ from "@/app/components/FAQ";
import Footer from "@/app/components/Footer";

export default function Home() {
  return (
    <main className="flex flex-col min-h-screen bg-black selection:bg-neon-primary selection:text-white">
      {/* Sticky Nav */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-black/50 backdrop-blur-xl border-b border-white/5 h-16 flex items-center px-6">
        <div className="max-w-7xl w-full mx-auto flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-full bg-neon-primary shadow-neon-primary animate-pulse" />
            <span className="font-bold text-white tracking-wider">ROUSE</span>
          </div>
          
          <div className="flex items-center gap-6 text-sm font-medium">
            <a href="#features" className="text-zinc-400 hover:text-white transition-colors hidden sm:block">
              How it works
            </a>
            <a href="#early-access" className="px-4 py-2 rounded-full bg-surface-card hover:bg-surface-card-border text-white transition-colors border border-surface-card-border">
              Early Access
            </a>
          </div>
        </div>
      </nav>

      <Hero />
      <div id="features">
          <WhosItFor />
          <Features />
      </div>
      <Benefits />
      <FAQ />
      <div id="early-access">
          <Footer />
      </div>
    </main>
  );
}
