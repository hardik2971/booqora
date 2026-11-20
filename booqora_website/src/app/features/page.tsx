import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { Reveal, Stagger, StaggerItem, TiltIn } from "@/components/motion";
import { AuroraHero, Breadcrumbs, CtaBand, JsonLd, breadcrumbLd } from "@/components/sections";
import { BrowserFrame, Eyebrow, PrimaryButton, SectionHeading } from "@/components/ui-kit";
import { features, featureHref } from "@/content/features";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";

const description =
  "Explore every Booqora feature: online booking website, rental inventory and availability, orders, calendar, payments with Razorpay, Stripe and PayPal, quotes, contracts and invoices, customers, reports, barcode scanning and the mobile app.";

export const metadata: Metadata = {
  title: "Rental Software Features",
  description,
  alternates: { canonical: "/features" },
  openGraph: { title: "Rental Software Features | Booqora", description, url: "/features" },
};

const groups = [
  { title: "Take bookings", lead: "Fill your calendar from the counter, the phone and the web.", slugs: ["online-booking", "order-management", "rental-calendar"] },
  { title: "Manage your gear", lead: "Know what you own, where it is and when it's free.", slugs: ["inventory-management", "barcode-scanning", "mobile-app"] },
  { title: "Get paid & stay organised", lead: "Professional paperwork and payments without the admin.", slugs: ["payments", "documents", "customer-management"] },
  { title: "Grow with confidence", lead: "Insights, integrations and tools for growing teams.", slugs: ["reports", "integrations", "team-and-security", "bora-assistant"] },
];

export default function FeaturesPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Features", path: "/features" },
  ];
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-28">
        <div className="container-x text-center">
          <Reveal className="flex justify-center">
            <Breadcrumbs items={crumbs} />
          </Reveal>
          <Reveal delay={0.05} className="mt-8">
            <Eyebrow dark>Features</Eyebrow>
          </Reveal>
          <Reveal delay={0.1}>
            <h1 className="mx-auto mt-6 max-w-4xl text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
              Every tool a rental business needs. <span className="text-gradient-light">None it doesn&apos;t.</span>
            </h1>
          </Reveal>
          <Reveal delay={0.16}>
            <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-white/75">
              Booqora brings bookings, inventory, payments, documents and your online store together — so the whole business runs from one place, on the web and on your phone.
            </p>
          </Reveal>
          <Reveal delay={0.22} className="mt-9 flex justify-center">
            <PrimaryButton href={site.signupUrl} size="lg">
              Start free trial
            </PrimaryButton>
          </Reveal>
        </div>
        <div className="container-x relative mt-16 max-w-5xl">
          <TiltIn>
            <BrowserFrame src="/shots/orders.webp" alt="Booqora orders list with statuses, payment status and live availability" priority />
          </TiltIn>
        </div>
      </AuroraHero>

      {groups.map((g, gi) => (
        <section key={g.title} className={cn("py-20", gi % 2 === 0 ? "bg-white" : "bg-mist")} aria-labelledby={`g${gi}`}>
          <div className="container-x">
            <Reveal>
              <SectionHeading align="left" eyebrow={`0${gi + 1}`} title={g.title} lead={g.lead} />
            </Reveal>
            <Stagger className={cn("mt-12 grid gap-5 sm:grid-cols-2", g.slugs.length === 4 ? "lg:grid-cols-4" : "lg:grid-cols-3")}>
              {g.slugs.map((slug) => {
                const f = features.find((x) => x.slug === slug)!;
                return (
                  <StaggerItem key={slug}>
                    <Link href={featureHref(f)} className="group relative flex h-full flex-col overflow-hidden rounded-[1.75rem] bg-white p-7 ring-1 ring-line card-lift">
                      <div className={cn("absolute -top-20 -right-20 size-48 rounded-full bg-gradient-to-br opacity-0 blur-2xl transition duration-500 group-hover:opacity-30", f.tint)} aria-hidden />
                      <span className={cn("relative grid size-14 place-items-center rounded-2xl bg-gradient-to-br text-white shadow-lg transition duration-500 group-hover:scale-110 group-hover:-rotate-6", f.tint)}>
                        <f.icon className="size-7" />
                      </span>
                      <h3 className="relative mt-6 text-xl font-extrabold text-ink group-hover:text-violet">{f.name}</h3>
                      <p className="relative mt-2 flex-1 leading-7 text-ink-soft">{f.short}</p>
                      <span className="relative mt-6 inline-flex items-center gap-1.5 text-sm font-bold text-violet">
                        Explore <ArrowRight className="size-4 transition group-hover:translate-x-1" />
                      </span>
                    </Link>
                  </StaggerItem>
                );
              })}
            </Stagger>
          </div>
        </section>
      ))}

      <div className="bg-mist pt-4">
        <CtaBand title="All of this, from" accent="₹1,499 a month" lead={`Every plan includes the online store, mobile app, documents and payments. Try it free for ${site.trialDays} days.`} />
      </div>
    </>
  );
}
