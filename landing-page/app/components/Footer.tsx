import { ArrowRight } from "lucide-react";

export default function Footer() {
  return (
    <footer className="bg-black border-t border-white/10 py-16 px-6">
      <div className="max-w-7xl mx-auto flex flex-col items-center text-center">
        
        {/* Final CTA */}
        <div className="w-full max-w-2xl mb-20">
          <h2 className="text-3xl font-bold mb-6 text-white">
            Ready to wake up different?
          </h2>
          <form className="flex flex-col sm:flex-row gap-4">
            <input 
                type="email" 
                placeholder="Enter your email" 
                className="flex-1 px-6 py-4 rounded-full bg-surface-card border border-surface-card-border focus:border-neon-primary focus:outline-none focus:ring-1 focus:ring-neon-primary text-white placeholder:text-zinc-500 transition-all"
            />
            <button className="px-8 py-4 rounded-full bg-neon-primary text-white font-bold hover:bg-white hover:text-black hover:scale-105 transition-all shadow-neon-primary flex items-center justify-center gap-2">
                Get early access
                <ArrowRight className="w-4 h-4" />
            </button>
          </form>
          <p className="mt-4 text-xs text-zinc-600">
            Limited spots for TestFlight beta.
          </p>
        </div>

        {/* Links */}
        <div className="flex flex-wrap justify-center gap-x-8 gap-y-4 text-sm text-zinc-500 mb-8">
          <a href="mailto:kuba@kubaszewczyk.me" className="hover:text-neon-primary transition-colors">Support</a>
          <a href="mailto:kuba@kubaszewczyk.me" className="hover:text-neon-primary transition-colors">Press</a>
          <a href="/terms" className="hover:text-white transition-colors">Terms</a>
          <a href="/privacy" className="hover:text-white transition-colors">Privacy Policy</a>
        </div>

        {/* Copyright */}
        <p className="text-xs text-zinc-700">
          © 2026 Rouse Alarm. All rights reserved.
        </p>
      </div>
    </footer>
  );
}
