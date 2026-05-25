"use client";

import { Mic, Shield, Camera, Volume2, Clock } from "lucide-react";
import { motion } from "framer-motion";

export default function Features() {
  const features = [
    {
      title: "Hour-long wake runway",
      desc: "Gentle → firm → relentless. A progression that respects your sleep inertia.",
      icon: <Clock className="w-6 h-6 text-neon-primary" />,
    },
    {
      title: "AI voice that talks back",
      desc: "It’s not just noise. It asks questions, demands answers, and wakes your brain.",
      icon: <Mic className="w-6 h-6 text-neon-secondary" />,
    },
    {
      title: "Voice check verification",
      desc: "You have to speak clearly to prove you're awake. Mumbling won't cut it.",
      icon: <Volume2 className="w-6 h-6 text-neon-green" />,
    },
    {
      title: "Awake Zone photo proof",
      desc: "Scan your bathroom sink or coffee maker to finally turn it off.",
      icon: <Camera className="w-6 h-6 text-neon-primary" />,
    },
    {
      title: "Privacy-first design",
      desc: "All processing happens locally or securely. No audio is ever stored.",
      icon: <Shield className="w-6 h-6 text-white" />,
    },
  ];

  return (
    <section className="py-24 px-6 bg-black">
      <div className="max-w-7xl mx-auto">
        <h2 className="text-3xl md:text-5xl font-bold mb-16 text-center">
          How it works
        </h2>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
              className="p-8 rounded-2xl bg-surface-card backdrop-blur-md border border-white/5 hover:border-white/10 transition-all hover:bg-white/5 group"
            >
              <div className="mb-6 p-3 rounded-lg bg-white/5 w-fit group-hover:scale-110 transition-transform duration-300">
                {f.icon}
              </div>
              <h3 className="text-xl font-bold mb-3 text-white">{f.title}</h3>
              <p className="text-zinc-400 leading-relaxed">{f.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
