"use client";

import { motion } from "framer-motion";
import Image from "next/image";

export default function WhosItFor() {
  const points = [
    "Normal alarms don’t touch you.",
    "You can snooze for 45–60 minutes like it’s a sport.",
    "You need a slow ramp + escalating pressure—not one loud beep.",
  ];

  return (
    <section className="relative py-32 px-6 overflow-hidden">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-20">
          <h2 className="text-3xl md:text-5xl font-bold mb-4">
            The Talking Alarm is for you if…
          </h2>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          {/* Points Left (Desktop) / Top (Mobile) */}
          <div className="flex flex-col gap-6 order-2 lg:order-1">
            {points.map((point, i) => (
              <motion.div
                key={i}
                initial={{ opacity: 0, x: -50 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.5, delay: i * 0.2 }}
                className="group relative p-6 rounded-2xl bg-surface-card border border-white/10 hover:border-neon-blue/50 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className="w-2 h-12 bg-neon-primary rounded-full shadow-neon-primary" />
                  <p className="text-xl md:text-2xl font-light text-zinc-200">
                    {point}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>

          {/* Mockup Right (Desktop) / Bottom (Mobile) */}
          <motion.div
            initial={{ opacity: 0, rotateY: 30, scale: 0.8, x: 50 }}
            whileInView={{ opacity: 1, rotateY: 0, scale: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ 
                duration: 0.8, 
                type: "spring",
                bounce: 0.4 
            }}
            className="relative order-1 lg:order-2 h-[600px] w-full flex items-center justify-center perspective-1000"
          >
            {/* Phone Container with 3D tilt */}
            <motion.div 
              className="relative w-auto h-[600px] aspect-[9/19.5]" // Adjust aspect ratio to standard phone or auto
              whileHover={{ scale: 1.05, rotateY: -5, rotateX: 5 }}
              transition={{ type: "spring", stiffness: 400, damping: 10 }}
              style={{
                filter: "drop-shadow(0px 20px 40px rgba(0,0,0,0.5))"
              }}
            >
                {/* The actual image - No borders, no rounded cropping, just the pure PNG */}
                 <Image 
                    src="/rouse-mockup.png" 
                    fill 
                    alt="Rouse App Screenshot" 
                    className="object-contain" // Changed to contain to respect the png boundaries
                    sizes="(max-width: 768px) 100vw, 400px"
                    priority
                 />
                
                {/* "Pop" Glow Effect behind the phone */}
                <motion.div 
                    animate={{ 
                        opacity: [0.3, 0.6, 0.3],
                        scale: [0.8, 1.0, 0.8]
                    }}
                    transition={{ 
                        duration: 4, 
                        repeat: Infinity,
                        ease: "easeInOut"
                    }}
                    className="absolute inset-0 bg-neon-primary/30 blur-3xl -z-10 rounded-full" 
                />
            </motion.div>
            
            {/* Background Ambient Glow */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[600px] bg-neon-primary/10 blur-[120px] -z-20 rounded-full" />
          </motion.div>
        </div>
      </div>
    </section>
  );
}
