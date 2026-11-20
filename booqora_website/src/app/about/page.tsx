import type { Metadata } from "next";
import { Heart, Layers, ShieldCheck, Sparkles } from "lucide-react";
import Image from "next/image";
import { industries, industryPhoto } from "@/content/industries";
import { Reveal, Stagger, StaggerItem } from "@/components/motion";
import { AuroraHero, Breadcrumbs, CtaBand, JsonLd, breadcrumbLd } from "@/components/sections";
import { Eyebrow, SectionHeading } from "@/components/ui-kit";

const description =
  "Booqora builds rental management software for rental businesses — one platform for bookings, inventory, payments, documents and online stores, on the web and on mobile.";

export const metadata: Metadata = {
  title: "About Booqora",
  description,
  alternates: { canonical: "/about" },
  openGraph: { title: "About Booqora", description, url: "/about" },
};

const values = [
  { icon: Sparkles, title: "Beautifully simple", body: "Powerful software doesn't have to be complicated. Every screen is designed to be understood at a glance." },
  { icon: Layers, title: "One source of truth", body: "Bookings, stock, payments and documents belong together. Booqora keeps them connected so nothing slips through." },
  { icon: ShieldCheck, title: "Trustworthy by design", body: "Your data is encrypted in transit, card details never touch our servers and payment status is verified server-side." },
  { icon: Heart, title: "Built with rental businesses", body: "Late returns, deposits, shortages and maintenance aren't edge cases for us — they're the job." },
];

export default function AboutPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "About", path: "/about" },
  ];
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-28">
        <div className="container-x relative text-center">
          <Reveal className="flex justify-center">
            <Breadcrumbs items={crumbs} />
          </Reveal>
          <Reveal delay={0.05} className="mt-8">
            <Eyebrow dark>About us</Eyebrow>
          </Reveal>
          <Reveal delay={0.1}>
            <h1 className="mx-auto mt-6 max-w-4xl text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
              We make renting <span className="text-gradient-light">beautifully simple</span>
            </h1>
          </Reveal>
          <Reveal delay={0.16}>
            <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-white/75">
              Rental businesses keep cameras rolling, events running and people moving. Booqora exists to give them software as good as the service they provide.
            </p>
          </Reveal>
        </div>
      </AuroraHero>

      <section className="py-24">
        <div className="container-x grid items-center gap-16 lg:grid-cols-2">
          <Reveal className="prose-booqora">
            <Eyebrow>Our story</Eyebrow>
            <h2 className="!mt-6">Why we built Booqora</h2>
            <p>
              Most rental businesses start with a spreadsheet, a diary and a phone full of WhatsApp messages. It works — until it doesn&apos;t. A late return clashes with a new booking,
              a deposit is forgotten, or an invoice takes an evening to type up.
            </p>
            <p>
              Booqora brings everything into one place: an online store that takes bookings 24/7, inventory that knows what&apos;s available for any date, orders that price themselves,
              payments that reconcile automatically and documents that look professional — on the web and on your phone.
            </p>
            <p>
              We designed it for rental businesses in India first — with Razorpay UPI payments, rupee pricing and configurable taxes — while working just as well for rental businesses anywhere.
            </p>
          </Reveal>
          <Reveal delay={0.1} className="relative mx-auto grid w-full max-w-lg grid-cols-2 gap-4">
            {industries.map((ind, i) => (
              <div key={ind.slug} className="relative aspect-[4/3] overflow-hidden rounded-3xl shadow-[0_24px_50px_-28px_rgba(28,9,56,0.6)] ring-1 ring-line" style={{ transform: `translateY(${i % 2 ? 24 : 0}px)` }}>
                <Image src={industryPhoto(ind.slug)} alt={ind.photoAlt} fill sizes="260px" className="object-cover" />
                <span className="absolute bottom-2.5 left-2.5 rounded-full bg-white/90 px-3 py-1 text-xs font-bold text-ink backdrop-blur">{ind.name}</span>
              </div>
            ))}
          </Reveal>
        </div>
      </section>

      <section className="bg-mist py-24">
        <div className="container-x">
          <Reveal>
            <SectionHeading eyebrow="What we believe" title="The principles behind" accent="every screen" />
          </Reveal>
          <Stagger className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {values.map((v) => (
              <StaggerItem key={v.title}>
                <div className="h-full rounded-[1.75rem] bg-white p-7 ring-1 ring-line card-lift">
                  <span className="grid size-12 place-items-center rounded-2xl bg-gradient-to-br from-violet to-indigo text-white shadow-lg">
                    <v.icon className="size-6" />
                  </span>
                  <h3 className="mt-5 text-lg font-extrabold text-ink">{v.title}</h3>
                  <p className="mt-2 leading-7 text-ink-soft">{v.body}</p>
                </div>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </section>
      <div className="bg-mist">
        <CtaBand />
      </div>
    </>
  );
}
