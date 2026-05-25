export default function TermsPage() {
  return (
    <main className="min-h-screen bg-black text-white px-6 py-24">
      <div className="max-w-3xl mx-auto space-y-8">
        <header className="space-y-3">
          <p className="text-sm text-zinc-400">Rouse Alarm</p>
          <h1 className="text-3xl font-bold">Terms of Service (EULA)</h1>
          <p className="text-sm text-zinc-400">Effective date: 2026-01-22</p>
        </header>

        <section className="space-y-4 text-zinc-200">
          <p>
            By downloading or using Rouse Alarm, you agree to these Terms. If you do not agree, do
            not use the app.
          </p>
          <p>
            Rouse Alarm provides AI-generated wake-up coaching and motivational content. The app
            does not provide medical, health, or safety advice.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">AI Liability & User Responsibility</h2>
          <ul className="list-disc pl-6 text-zinc-200 space-y-2">
            <li>AI outputs are generated content and may be inaccurate or incomplete.</li>
            <li>You are responsible for how you use AI-generated content.</li>
            <li>Do not rely on the app for medical, legal, or emergency decisions.</li>
          </ul>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">License</h2>
          <p className="text-zinc-200">
            We grant you a limited, non-transferable, revocable license to use the app for personal
            use only.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">Termination</h2>
          <p className="text-zinc-200">
            We may suspend or terminate access if you violate these Terms. You may stop using the
            app at any time.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">Contact</h2>
          <p className="text-zinc-200">
            Questions? Email <a className="underline" href="mailto:kuba@kubaszewczyk.me">kuba@kubaszewczyk.me</a>.
          </p>
        </section>
      </div>
    </main>
  );
}
