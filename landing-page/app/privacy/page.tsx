export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-black text-white px-6 py-24">
      <div className="max-w-3xl mx-auto space-y-8">
        <header className="space-y-3">
          <p className="text-sm text-zinc-400">Rouse Alarm</p>
          <h1 className="text-3xl font-bold">Privacy Policy</h1>
          <p className="text-sm text-zinc-400">Effective date: 2026-01-22</p>
        </header>

        <section className="space-y-4 text-zinc-200">
          <p>
            This policy describes how Rouse Alarm processes data when you use the app and website.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">Data We Process</h2>
          <ul className="list-disc pl-6 text-zinc-200 space-y-2">
            <li>Voice transcripts you speak during wake-up sessions.</li>
            <li>Alarm preferences and onboarding inputs (name, goal, schedule).</li>
            <li>Technical logs for reliability and safety.</li>
          </ul>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">Third-Party Processing</h2>
          <p className="text-zinc-200">
            Voice transcripts and prompts are sent to OpenAI for reasoning and to ElevenLabs for
            voice synthesis. These providers process data to return AI responses and audio.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">Retention</h2>
          <p className="text-zinc-200">
            We retain minimal data needed to operate the service and improve quality. You can
            delete local app data in Settings.
          </p>
        </section>

        <section className="space-y-3">
          <h2 className="text-xl font-semibold">Your Choices</h2>
          <p className="text-zinc-200">
            You can reset local data and revoke permissions at any time in Settings or iOS System
            Settings.
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
