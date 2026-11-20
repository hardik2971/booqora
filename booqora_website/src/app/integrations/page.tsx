import type { Metadata } from "next";
import { Plug } from "lucide-react";
import { Float, Reveal, Stagger, StaggerItem, TiltIn } from "@/components/motion";
import { AuroraHero, Breadcrumbs, CtaBand, JsonLd, breadcrumbLd } from "@/components/sections";
import { BrowserFrame, Eyebrow, IntegrationTile, PrimaryButton, SectionHeading } from "@/components/ui-kit";
import { integrations } from "@/content/catalog";
import { site } from "@/lib/site";

const description =
  "Connect Booqora rental software with Razorpay, Stripe, PayPal, Google Analytics, Meta Pixel, Mailchimp, WhatsApp Business, QuickBooks, Xero, Tally, Shiprocket, Google Calendar, Slack, Zapier and more.";

export const metadata: Metadata = {
  title: "Integrations — Payments, Accounting, Marketing & More",
  description,
  alternates: { canonical: "/integrations" },
  openGraph: { title: "Booqora Integrations", description, url: "/integrations" },
};

export default function IntegrationsPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Integrations", path: "/integrations" },
  ];
  const categories = Array.from(new Set(integrations.map((i) => i.category)));
  const orbit = integrations.slice(0, 10);
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-24">
        <div className="container-x grid items-center gap-14 lg:grid-cols-2">
          <div>
            <Reveal>
              <Breadcrumbs items={crumbs} />
            </Reveal>
            <Reveal delay={0.05} className="mt-8">
              <Eyebrow dark>Integrations</Eyebrow>
            </Reveal>
            <Reveal delay={0.1}>
              <h1 className="mt-6 text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
                Connect the tools <span className="text-gradient-light">you already love</span>
              </h1>
            </Reveal>
            <Reveal delay={0.16}>
              <p className="mt-6 max-w-xl text-lg leading-8 text-white/75">
                Install apps from the Booqora app store in a few clicks — payments, analytics, marketing, accounting, fulfilment and communication.
              </p>
            </Reveal>
            <Reveal delay={0.22} className="mt-9">
              <PrimaryButton href={site.signupUrl} size="lg">
                Start free trial
              </PrimaryButton>
            </Reveal>
          </div>
          {/* Orbit illustration */}
          <div className="relative mx-auto aspect-square w-full max-w-[28rem]" aria-hidden>
            <div className="absolute inset-[4%] animate-spin-slow rounded-full border border-dashed border-lavender/30" />
            <div className="absolute inset-[22%] rounded-full border border-white/10" />
            <div className="absolute inset-[36%] grid place-items-center rounded-full bg-gradient-to-br from-violet-bright to-indigo shadow-[0_0_80px_rgba(123,63,242,0.8)]">
              <Plug className="size-12 text-white" />
            </div>
            {orbit.map((it, i) => {
              const a = (i / orbit.length) * Math.PI * 2 - Math.PI / 2;
              const r = i % 2 ? 44 : 31;
              return (
                <div key={it.id} className="absolute" style={{ left: `${50 + Math.cos(a) * r}%`, top: `${50 + Math.sin(a) * r}%`, transform: "translate(-50%, -50%)" }}>
                  <Float delay={i * 0.15} distance={7} duration={5 + (i % 4)}>
                    <IntegrationTile name={it.name} color={it.color} className="ring-2 ring-white/20" />
                  </Float>
                </div>
              );
            })}
          </div>
        </div>
      </AuroraHero>

      <section className="py-20" aria-labelledby="all-int">
        <div className="container-x">
          <Reveal>
            <SectionHeading eyebrow={`${integrations.length} apps`} title="Browse the" accent="app store" lead={categories.join(" · ")} />
          </Reveal>
          <Stagger className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {integrations.map((it) => (
              <StaggerItem key={it.id}>
                <div className="flex h-full flex-col rounded-[1.5rem] bg-white p-6 ring-1 ring-line card-lift">
                  <div className="flex items-start justify-between gap-2">
                    <IntegrationTile name={it.name} color={it.color} />
                    <span className="rounded-full bg-haze px-2.5 py-1 text-[0.7rem] font-bold text-violet">{it.category}</span>
                  </div>
                  <h3 className="mt-5 flex flex-wrap items-center gap-2 text-lg font-extrabold text-ink">
                    {it.name}
                    {it.builtIn && <span className="rounded-full bg-[#e7f7ed] px-2 py-0.5 text-[0.7rem] font-bold text-[#16a34a]">Built in</span>}
                    {it.beta && <span className="rounded-full bg-[#fef3e2] px-2 py-0.5 text-[0.7rem] font-bold text-[#d97706]">Beta</span>}
                  </h3>
                  <p className="mt-1 flex-1 text-[0.95rem] text-ink-soft">{it.short}</p>
                  <p className="mt-3 text-xs font-semibold text-mute">{it.pricing}</p>
                </div>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </section>

      <section className="py-24">
        <div className="container-x grid items-center gap-12 lg:grid-cols-2">
          <Reveal>
            <SectionHeading align="left" eyebrow="App store" title="Install in" accent="a few clicks" lead="Open Apps inside Booqora, pick an integration, paste your ID or key and you're connected. Payment secrets stay on the server." />
          </Reveal>
          <Reveal delay={0.1}>
            <TiltIn>
              <BrowserFrame src="/shots/apps.webp" alt="The Booqora app store with integrations for analytics, marketing and payments" />
            </TiltIn>
          </Reveal>
        </div>
      </section>
      <CtaBand />
    </>
  );
}
