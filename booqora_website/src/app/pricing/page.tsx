import type { Metadata } from "next";
import { Check, Minus } from "lucide-react";
import { Reveal, Stagger, StaggerItem } from "@/components/motion";
import { PricingTable } from "@/components/pricing-table";
import { AuroraHero, Breadcrumbs, CtaBand, FaqSection, JsonLd, breadcrumbLd } from "@/components/sections";
import { Eyebrow, SectionHeading } from "@/components/ui-kit";
import { pricingFaqs } from "@/content/catalog";
import { site } from "@/lib/site";

const description =
  "Simple, transparent pricing for Booqora rental software. Plans from ₹1,499 per month with a 14-day free trial, no credit card required. Save 20% with yearly billing.";

export const metadata: Metadata = {
  title: "Pricing — Rental Software Plans",
  description,
  alternates: { canonical: "/pricing" },
  openGraph: { title: "Booqora Pricing — Rental Software Plans", description, url: "/pricing" },
};

const included = [
  "Online store & booking page",
  "Mobile app for Android & iOS",
  "Orders, inventory & customers",
  "Quotes, contracts & invoices",
  "Razorpay, Stripe & PayPal",
  "Barcode scanning",
  "Rental calendar",
  "Bora assistant",
];

const compare: { label: string; values: [boolean | string, boolean | string, boolean | string] }[] = [
  { label: "Team members", values: ["3", "10", "25"] },
  { label: "Orders, inventory & customers", values: [true, true, true] },
  { label: "Online store with your branding", values: [true, true, true] },
  { label: "Quotes, contracts & invoices", values: [true, true, true] },
  { label: "Online payments", values: [true, true, true] },
  { label: "Mobile app", values: [true, true, true] },
  { label: "Pricing structures & custom fields", values: [false, true, true] },
  { label: "Multiple locations", values: [false, true, true] },
  { label: "Reports & app integrations", values: [false, true, true] },
  { label: "Security controls (2FA, IP allow-lists, SSO)", values: [false, false, true] },
  { label: "Advanced permissions", values: [false, false, true] },
  { label: "Support", values: ["Email", "Priority", "Dedicated onboarding"] },
];

export default function PricingPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Pricing", path: "/pricing" },
  ];
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-40">
        <div className="container-x relative">
          <div className="text-center">
            <Reveal className="flex justify-center">
              <Breadcrumbs items={crumbs} />
            </Reveal>
            <Reveal delay={0.05} className="mt-8">
              <Eyebrow dark>Pricing</Eyebrow>
            </Reveal>
            <Reveal delay={0.1}>
              <h1 className="mx-auto mt-6 max-w-4xl text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
                Simple pricing that <span className="text-gradient-light">grows with you</span>
              </h1>
            </Reveal>
            <Reveal delay={0.16}>
              <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-white/75">
                Start with a {site.trialDays}-day free trial — no credit card required. No setup fees, no transaction fees from Booqora.
              </p>
            </Reveal>
          </div>
          <div className="mt-14">
            <PricingTable />
          </div>
        </div>
      </AuroraHero>

      <section className="py-20" aria-labelledby="inc-title">
        <div className="container-x">
          <Reveal>
            <SectionHeading eyebrow="Every plan" title="Included in" accent="every plan" />
          </Reveal>
          <Stagger className="mx-auto mt-12 grid max-w-5xl grid-cols-2 gap-3 md:grid-cols-4">
            {included.map((i) => (
              <StaggerItem key={i}>
                <div className="flex h-full items-center gap-3 rounded-2xl bg-white p-4 ring-1 ring-line">
                  <span className="grid size-8 shrink-0 place-items-center rounded-full bg-gradient-to-br from-violet to-indigo text-white">
                    <Check className="size-4" />
                  </span>
                  <span className="text-[0.95rem] font-semibold text-ink">{i}</span>
                </div>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </section>

      <section className="bg-mist py-20" aria-labelledby="cmp-title">
        <div className="container-x max-w-5xl">
          <Reveal>
            <SectionHeading eyebrow="Compare" title="Compare" accent="plans" />
          </Reveal>
          <Reveal delay={0.1} className="mt-12 overflow-x-auto rounded-[1.75rem] bg-white ring-1 ring-line">
            <table className="w-full min-w-[640px] text-left">
              <caption className="sr-only">Booqora plan comparison</caption>
              <thead>
                <tr className="border-b border-line">
                  <th scope="col" className="p-5 text-sm font-bold text-mute">
                    Feature
                  </th>
                  {["Starter", "Pro", "Business"].map((p) => (
                    <th key={p} scope="col" className="p-5 text-center font-display text-lg font-extrabold text-ink">
                      {p}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {compare.map((row) => (
                  <tr key={row.label} className="border-b border-line last:border-0 hover:bg-mist/60">
                    <th scope="row" className="p-5 text-[0.95rem] font-semibold text-ink">
                      {row.label}
                    </th>
                    {row.values.map((v, i) => (
                      <td key={i} className="p-5 text-center text-[0.95rem] text-ink-soft">
                        {v === true ? (
                          <Check className="mx-auto size-5 text-violet" aria-label="Included" />
                        ) : v === false ? (
                          <Minus className="mx-auto size-5 text-line" aria-label="Not included" />
                        ) : (
                          <span className="font-semibold text-ink">{v}</span>
                        )}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </Reveal>
        </div>
      </section>

      <FaqSection faqs={pricingFaqs} title="Pricing questions" />
      <CtaBand />
    </>
  );
}
