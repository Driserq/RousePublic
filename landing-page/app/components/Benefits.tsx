"use client";

import { motion } from "framer-motion";

export default function Benefits() {
  const benefits = [
    "Actually gets you out of bed—even on low willpower days.",
    "Replaces chaos with a reliable wake-up ramp you can count on.",
    "Cuts ‘snooze spirals’ by escalating until you prove you’re up.",
    "Builds consistency for heavy sleepers who need time to switch on.",
  ];

  return (
    <section className="py-24 px-6 relative overflow-hidden">
      {/* Background elements */}
      <div className="absolute top-0 right-0 w-[500px] h-[500px] bg-neon-primary/5 rounded-full blur-[120px] pointer-events-none" />

      <div className="max-w-5xl mx-auto">
        <h2 className="text-3xl md:text-5xl font-bold mb-16 text-center md:text-left">
          Why it changes everything
        </h2>

        <div className="space-y-8">
          {benefits.map((benefit, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, x: -20 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1 }}
              className="group relative"
            >
              <div className="relative z-10 p-6 md:p-8 bg-surface-card rounded-xl border-l-4 border-neon-primary overflow-hidden hover:bg-surface-card-border transition-colors">
                <p className="text-xl md:text-2xl font-medium text-white group-hover:text-neon-secondary transition-colors">
                  {benefit}
                </p>
                
                {/* Glow effect on hover */}
                <div className="absolute inset-0 bg-gradient-to-r from-neon-primary/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none" />
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
