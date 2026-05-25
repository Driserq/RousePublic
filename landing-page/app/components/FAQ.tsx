"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Plus, Minus } from "lucide-react";

const faqs = [
  {
    q: "Is this meant for heavy sleepers?",
    a: "Yes—designed specifically for those needing 45-60min ramps to wake up fully.",
  },
  {
    q: "Can it run for up to an hour?",
    a: "It escalates gradually until it verifies you are awake, capable of running a full hour sequence.",
  },
  {
    q: "Do you store photos or audio?",
    a: "Privacy-first: everything is processed locally on your device. No cloud storage.",
  },
  {
    q: "What if I’m offline?",
    a: "The core alarm functionality works offline; AI features enhance the experience when online.",
  },
  {
    q: "What permissions do you need?",
    a: "Microphone (for voice checks), Camera (for photo proof), and Notifications (for the alarm itself).",
  },
];

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  return (
    <section className="py-24 px-6 bg-surface-dark">
      <div className="max-w-3xl mx-auto">
        <h2 className="text-3xl md:text-5xl font-bold mb-12 text-center">
          Got questions?
        </h2>

        <div className="space-y-4">
          {faqs.map((item, i) => (
            <div
              key={i}
              className="border border-white/10 rounded-xl bg-black overflow-hidden"
            >
              <button
                onClick={() => setOpenIndex(openIndex === i ? null : i)}
                className="flex items-center justify-between w-full p-6 text-left hover:bg-white/5 transition-colors"
              >
                <span className="text-lg font-medium text-white">{item.q}</span>
                {openIndex === i ? (
                  <Minus className="w-5 h-5 text-neon-primary" />
                ) : (
                  <Plus className="w-5 h-5 text-zinc-500" />
                )}
              </button>

              <AnimatePresence>
                {openIndex === i && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: "auto", opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.3, ease: "easeInOut" }}
                  >
                    <div className="p-6 pt-0 text-zinc-400 leading-relaxed border-t border-white/5">
                      {item.a}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
