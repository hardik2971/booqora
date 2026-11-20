import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { features, featureHref } from "@/content/features";
import { industries } from "@/content/industries";
import type { Faq } from "@/content/features";
import { Reveal } from "@/components/motion";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { Eyebrow, GhostButton, Logo, PrimaryButton } from "@/components/ui-kit";
import { absoluteUrl, site } from "@/lib/site";
import { cn } from "@/lib/utils";

export function JsonLd({ data }: { data: object | object[] }) {
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, "\\u003c") }} />;
}

export function breadcrumbLd(items: { name: string; path: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => ({ "@type": "ListItem", position: i + 1, name: it.name, item: absoluteUrl(it.path) })),
  };
}

export function faqLd(faqs: Faq[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((f) => ({ "@type": "Question", name: f.q, acceptedAnswer: { "@type": "Answer", text: f.a } })),
  };
}

export function Breadcrumbs({ items }: { items: { name: string; path: string }[] }) {
  return (
    <nav aria-label="Breadcrumb" className="text-sm">
      <ol className="flex flex-wrap items-center gap-1 text-white/60">
        {items.map((it, i) => (
          <li key={it.path} className="flex items-center gap-1">
            {i > 0 && <ChevronRight className="size-3.5" aria-hidden />}
            {i === items.length - 1 ? (
              <span className="text-white/90" aria-current="page">
                {it.name}
              </span>
            ) : (
              <Link href={it.path} className="hover:text-white">
                {it.name}
              </Link>
            )}
          </li>
        ))}
      </ol>
    </nav>
  );
}

/** Dark aurora hero used at the top of every page (the header sits on top of it). */
export function AuroraHero({ children, className, bottomFade = true }: { children: React.ReactNode; className?: string; bottomFade?: boolean }) {
  return (
    <section className={cn("relative isolate overflow-hidden bg-aurora pt-32 text-white sm:pt-36", className)}>
      <div className="bg-dots-light mask-fade absolute inset-0 -z-10" aria-hidden />
      <div className="absolute -top-40 left-1/2 -z-10 size-[44rem] -translate-x-1/2 animate-spin-slow rounded-full border border-dashed border-lavender/15" aria-hidden />
      <div className="absolute top-24 -left-24 -z-10 size-72 rounded-full bg-violet-bright/40 blur-[100px]" aria-hidden />
      <div className="absolute top-10 -right-20 -z-10 size-80 rounded-full bg-rose/20 blur-[110px]" aria-hidden />
      <Sparkles />
      {children}
      {bottomFade && <div className="pointer-events-none absolute inset-x-0 bottom-0 h-24 bg-gradient-to-b from-transparent to-white" aria-hidden />}
    </section>
  );
}

function Sparkles() {
  const pts = [
    [8, 22, 0], [92, 30, 1.2], [78, 12, 2.1], [18, 70, 0.6], [60, 8, 1.6], [96, 64, 2.6],
  ];
  return (
    <>
      {pts.map(([x, y, d], i) => (
        <span
          key={i}
          className="absolute -z-10 size-3 animate-pulse"
          style={{ left: `${x}%`, top: `${y}%`, animationDelay: `${d}s`, animationDuration: "3s" }}
          aria-hidden
        >
          <span className="absolute top-1/2 left-0 h-px w-full -translate-y-1/2 bg-white shadow-[0_0_8px_#fff]" />
          <span className="absolute top-0 left-1/2 h-full w-px -translate-x-1/2 bg-white shadow-[0_0_8px_#fff]" />
        </span>
      ))}
    </>
  );
}

export function FaqSection({ faqs, title = "Frequently asked questions", className }: { faqs: Faq[]; title?: string; className?: string }) {
  return (
    <section className={cn("py-24", className)} aria-labelledby="faq-title">
      <JsonLd data={faqLd(faqs)} />
      <div className="container-x grid gap-12 lg:grid-cols-[0.8fr_1.2fr]">
        <Reveal>
          <Eyebrow>FAQ</Eyebrow>
          <h2 id="faq-title" className="mt-5 text-4xl font-extrabold text-ink">
            {title}
          </h2>
          <p className="mt-4 text-lg text-ink-soft">
            Can&apos;t find what you&apos;re looking for?{" "}
            <Link href="/contact" className="font-semibold text-violet underline decoration-lavender underline-offset-4">
              Contact us
            </Link>
            .
          </p>
        </Reveal>
        <Reveal delay={0.1}>
          <Accordion className="rounded-3xl bg-white p-2 shadow-[0_30px_70px_-40px_rgba(28,9,56,0.4)] ring-1 ring-line">
            {faqs.map((f, i) => (
              <AccordionItem key={i} value={`f${i}`} className="border-line px-5 last:border-b-0">
                <AccordionTrigger className="py-5 text-left text-[1.05rem] font-bold text-ink hover:text-violet hover:no-underline">{f.q}</AccordionTrigger>
                <AccordionContent className="pb-5 text-[1rem] leading-7 text-ink-soft">{f.a}</AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </Reveal>
      </div>
    </section>
  );
}

export function CtaBand({ title = "Ready to make renting", accent = "beautifully simple?", lead }: { title?: string; accent?: string; lead?: string }) {
  return (
    <section className="px-4 pb-24 sm:px-6 lg:px-8">
      <Reveal className="relative isolate mx-auto max-w-7xl overflow-hidden rounded-[2.5rem] bg-aurora px-6 py-16 text-center text-white sm:px-12 sm:py-20">
        <div className="bg-dots-light mask-fade absolute inset-0 -z-10" aria-hidden />
        <div className="absolute -bottom-40 left-1/2 -z-10 size-[36rem] -translate-x-1/2 rounded-full border border-dashed border-lavender/20 animate-spin-slow" aria-hidden />
        <h2 className="mx-auto max-w-3xl text-4xl leading-[1.08] font-extrabold sm:text-5xl">
          {title} <span className="text-gradient-light">{accent}</span>
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-lg text-white/70">
          {lead ?? `Start your ${site.trialDays}-day free trial today. No credit card required — set up your first products in minutes.`}
        </p>
        <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <PrimaryButton href={site.signupUrl} size="lg">
            Start free trial
          </PrimaryButton>
          <GhostButton href="/pricing" size="lg" dark>
            View pricing
          </GhostButton>
        </div>
      </Reveal>
    </section>
  );
}

export function SiteFooter() {
  const year = 2026;
  const cols: { title: string; links: { href: string; label: string }[] }[] = [
    { title: "Product", links: [{ href: "/features", label: "All features" }, ...features.slice(0, 7).map((f) => ({ href: featureHref(f), label: f.name }))] },
    { title: "More features", links: [...features.slice(7).map((f) => ({ href: featureHref(f), label: f.name })), { href: "/pricing", label: "Pricing" }] },
    { title: "Industries", links: [{ href: "/industries", label: "All industries" }, ...industries.map((i) => ({ href: `/industries/${i.slug}`, label: i.name }))] },
    {
      title: "Company",
      links: [
        { href: "/about", label: "About" },
        { href: "/blog", label: "Rental guides" },
        { href: "/contact", label: "Contact" },
        { href: site.privacyUrl, label: "Privacy policy" },
        { href: site.loginUrl, label: "Log in" },
      ],
    },
  ];
  return (
    <footer className="relative overflow-hidden bg-night text-white">
      <div className="bg-dots-light mask-fade absolute inset-0 opacity-50" aria-hidden />
      <div className="container-x relative grid gap-12 py-16 lg:grid-cols-[1.1fr_2.4fr]">
        <div>
          <Logo dark />
          <p className="mt-5 max-w-xs text-white/60">{site.tagline}. Bookings, inventory, payments and your online store — on the web and on your phone.</p>
          <div className="mt-7">
            <PrimaryButton href={site.signupUrl}>Start free trial</PrimaryButton>
          </div>
          <p className="mt-4 text-sm text-white/45">{site.trialDays}-day free trial · No credit card required</p>
        </div>
        <div className="grid grid-cols-2 gap-8 sm:grid-cols-4">
          {cols.map((c) => (
            <div key={c.title}>
              <p className="text-sm font-bold tracking-wider text-lavender uppercase">{c.title}</p>
              <ul className="mt-4 space-y-2.5">
                {c.links.map((l) => (
                  <li key={l.href + l.label}>
                    {l.href.startsWith("http") ? (
                      <a href={l.href} className="text-[0.93rem] text-white/65 transition hover:text-white">
                        {l.label}
                      </a>
                    ) : (
                      <Link href={l.href} className="text-[0.93rem] text-white/65 transition hover:text-white">
                        {l.label}
                      </Link>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
      <div className="relative border-t border-white/10">
        <div className="container-x flex flex-col items-center justify-between gap-3 py-6 text-sm text-white/45 sm:flex-row">
          <p>
            © {year} {site.legalName}. All rights reserved.
          </p>
          <p>
            <a href={`mailto:${site.email}`} className="hover:text-white">
              {site.email}
            </a>
          </p>
        </div>
      </div>
    </footer>
  );
}

/** Shell shown while a param-driven page streams in on client navigation. */
export function HeroFallback() {
  return (
    <section className="relative isolate overflow-hidden bg-aurora pt-36 pb-40 text-white" aria-busy="true">
      <div className="bg-dots-light mask-fade absolute inset-0 -z-10" aria-hidden />
      <div className="container-x">
        <div className="h-4 w-48 animate-pulse rounded-full bg-white/15" />
        <div className="mt-10 h-8 w-32 animate-pulse rounded-full bg-white/10" />
        <div className="mt-6 h-14 w-full max-w-2xl animate-pulse rounded-2xl bg-white/15" />
        <div className="mt-4 h-14 w-2/3 max-w-xl animate-pulse rounded-2xl bg-white/10" />
        <div className="mt-8 h-5 w-full max-w-lg animate-pulse rounded-full bg-white/10" />
      </div>
    </section>
  );
}
