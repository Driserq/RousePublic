"use client";

import { motion } from "framer-motion";
import ZenRing from "@/app/components/ZenRing";
import { ArrowRight } from "lucide-react";

export default function Hero() {
  return (
    <section className="relative flex flex-col items-center justify-center min-h-[90vh] w-full overflow-hidden pt-20">
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[80vw] h-[80vw] bg-neon-primary/10 blur-[120px] rounded-full pointer-events-none" />

      {/* Main Visual: Zen Ring */}
      <div className="relative w-full max-w-[600px] aspect-square mb-[-60px] md:mb-[-100px] z-10">
        {/* Updated color to match the "Lavender/Periwinkle" from screenshot */}
        <ZenRing className="w-full h-full" color="#8e94ff" />
        
        {/* Center Text "ALARM IN" */}
        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
          <span className="text-neon-primary/70 text-sm md:text-base font-medium tracking-[0.2em] animate-pulse">
            ALARM IN
          </span>
          <span className="text-white text-4xl md:text-6xl font-bold tracking-tighter mt-2 text-glow-white">
            07:00
          </span>
          <span className="text-white/50 text-sm mt-1">
            AM
          </span>
        </div>
      </div>

      {/* Copy Stack */}
      <div className="relative z-20 flex flex-col items-center text-center px-6 max-w-4xl mx-auto -mt-10 md:-mt-20">
        <motion.h1 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="text-4xl md:text-7xl font-bold tracking-tight text-white mb-6 leading-[1.1]"
        >
          The only alarm you can rely on to <span className="text-transparent bg-clip-text bg-gradient-to-r from-neon-primary to-white text-glow-primary">drag you out of bed.</span>
        </motion.h1>

        <motion.p 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="text-lg md:text-2xl text-zinc-400 max-w-2xl mb-10 font-light"
        >
          Built for the heaviest sleepers—especially if you need an hour-long runway to fully wake up.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.5, delay: 0.6 }}
          className="flex flex-col items-center gap-4 w-full"
        >
          <a
            href="#early-access"
            className="group relative inline-flex items-center justify-center px-8 py-4 text-lg font-bold text-white transition-all duration-200 bg-surface-card border border-surface-card-border rounded-full hover:bg-surface-card-border hover:scale-105 shadow-neon-primary focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-neon-primary focus:ring-offset-black"
          >
            <span className="mr-2">Get early access</span>
            <ArrowRight className="w-5 h-5 transition-transform group-hover:translate-x-1" />
            
            {/* Button Glow */}
            <div className="absolute inset-0 rounded-full bg-neon-primary blur-md -z-10 opacity-30 group-hover:opacity-60 transition-opacity" />
          </a>
          
          <p className="text-xs text-zinc-600 uppercase tracking-widest">
            No spam. Unsubscribe anytime.
          </p>
        </motion.div>
      </div>
    </section>
  );
}
