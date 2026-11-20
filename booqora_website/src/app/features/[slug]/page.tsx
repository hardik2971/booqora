import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowRight, Check, CheckCircle2, Sparkles } from "lucide-react";
import { Float, Parallax, Reveal, Stagger, StaggerItem, TiltIn } from "@/components/motion";
import { Suspense } from "react";
import { AuroraHero, Breadcrumbs, CtaBand, FaqSection, HeroFallback, JsonLd, breadcrumbLd } from "@/components/sections";
import { BrowserFrame, Chip, Eyebrow, GhostButton, PrimaryButton, SectionHeading } from "@/components/ui-kit";
import { featureHref, featurePages, getFeature } from "@/content/features";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";

export function generateStaticParams() {
  return featurePages.map((f) => ({ slug: f.slug }));
}

export async function generateMetadata({ params }: PageProps<"/features/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  const f = getFeature(slug);
  if (!f) return {};
  return {
    title: f.seoTitle,
    description: f.metaDescription,
    keywords: f.keywords,
    alternates: { canonical: `/features/${f.slug}` },
    openGraph: { title: `${f.seoTitle} | Booqora`, description: f.metaDescription, url: `/features/${f.slug}`, type: "website" },
    twitter: { title: `${f.seoTitle} | Booqora`, description: f.metaDescription },
  };
}

export default function FeaturePage({ params }: PageProps<"/features/[slug]">) {
  return (
    <Suspense fallback={<HeroFallback />}>
      <FeatureContent params={params} />
    </Suspense>
  );
}

async function FeatureContent({ params }: { params: PageProps<"/features/[slug]">["params"] }) {
  const { slug } = await params;
  const f = getFeature(slug);
  if (!f || f.href) notFound();
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Features", path: "/features" },
    { name: f.name, path: `/features/${f.slug}` },
  ];
  const related = f.related.map(getFeature).filter((x): x is NonNullable<typeof x> => Boolean(x));

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-24">
        <div className="container-x">
          <Reveal>
            <Breadcrumbs items={crumbs} />
          </Reveal>
          <div className="mt-10 grid items-center gap-14 lg:grid-cols-[1fr_1.15fr]">
            <div>
              <Reveal delay={0.05}>
                <Eyebrow dark>
                  <f.icon className="size-3.5" aria-hidden /> {f.eyebrow}
                </Eyebrow>
              </Reveal>
              <Reveal delay={0.1}>
                <h1 className="mt-6 text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
                  {f.headline} <span className="text-gradient-light">{f.headlineAccent}</span>
                </h1>
              </Reveal>
              <Reveal delay={0.16}>
                <p className="mt-6 max-w-xl text-lg leading-8 text-white/75">{f.lead}</p>
              </Reveal>
              <Reveal delay={0.22} className="mt-9 flex flex-col gap-3 sm:flex-row">
                <PrimaryButton href={site.signupUrl} size="lg">
                  Start free trial
                </PrimaryButton>
                <GhostButton href="/pricing" size="lg" dark>
                  See pricing
                </GhostButton>
              </Reveal>
            </div>
            <div className="relative">
              <div className="absolute inset-[10%] -z-10 rounded-full bg-violet-bright/50 blur-[90px]" aria-hidden />
              <TiltIn>
                <BrowserFrame src={`/shots/${f.shot}.webp`} alt={`${f.name} in Booqora`} priority />
              </TiltIn>
              {f.highlights[0] && (
                <Float className="absolute -bottom-7 -left-3 sm:-left-8" delay={0.6} distance={9}>
                  <Chip icon={<CheckCircle2 />} tone="green" label={f.highlights[0].title} sub="Included in every plan" />
                </Float>
              )}
              {f.highlights[1] && (
                <Float className="absolute -top-7 right-4 hidden sm:block" delay={0.9} distance={8}>
                  <Chip icon={<Sparkles />} tone="violet" label={f.highlights[1].title} sub="Web & mobile" />
                </Float>
              )}
            </div>
          </div>
        </div>
      </AuroraHero>

      {f.highlights.length > 0 && (
        <section className="py-24" aria-labelledby="hl-title">
          <div className="container-x">
            <Reveal>
              <SectionHeading eyebrow="Highlights" title={`What you get with ${f.name.toLowerCase()}`} />
            </Reveal>
            <Stagger className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {f.highlights.map((h, i) => (
                <StaggerItem key={h.title}>
                  <div className="group relative h-full overflow-hidden rounded-[1.75rem] bg-white p-7 ring-1 ring-line card-lift">
                    <span className="absolute -top-6 -right-4 font-display text-8xl font-extrabold text-haze transition group-hover:text-lavender/40" aria-hidden>
                      {String(i + 1).padStart(2, "0")}
                    </span>
                    <span className={cn("relative grid size-12 place-items-center rounded-2xl bg-gradient-to-br text-white shadow-lg", f.tint)}>
                      <Check className="size-6" />
                    </span>
                    <h3 className="relative mt-6 text-xl font-extrabold text-ink">{h.title}</h3>
                    <p className="relative mt-2 leading-7 text-ink-soft">{h.body}</p>
                  </div>
                </StaggerItem>
              ))}
            </Stagger>
          </div>
        </section>
      )}

      {f.sections.map((s, i) => (
        <section key={s.title} className={cn("overflow-x-clip py-20", i % 2 === 0 ? "bg-mist" : "bg-white")}>
          <div className="container-x grid items-center gap-12 lg:grid-cols-2 lg:gap-20">
            <Reveal className={cn(i % 2 === 1 && "lg:order-2")}>
              <h2 className="text-3xl leading-tight font-extrabold text-ink sm:text-[2.5rem]">{s.title}</h2>
              <p className="mt-5 text-lg leading-8 text-ink-soft">{s.body}</p>
              <ul className="mt-7 space-y-3.5">
                {s.bullets.map((b) => (
                  <li key={b} className="flex gap-3 text-ink">
                    <span className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-gradient-to-br from-violet to-indigo text-white">
                      <Check className="size-3.5" />
                    </span>
                    {b}
                  </li>
                ))}
              </ul>
            </Reveal>
            <div className={cn("relative", i % 2 === 1 && "lg:order-1")}>
              <div className="absolute inset-8 -z-10 rounded-[3rem] bg-gradient-to-br from-lavender/60 via-haze to-[#fde7f3] blur-2xl" aria-hidden />
              {s.shot ? (
                <Parallax offset={24}>
                  <BrowserFrame src={`/shots/${s.shot}.webp`} alt={`${s.title} — Booqora`} />
                </Parallax>
              ) : (
                <IllustratedCard title={s.title} bullets={s.bullets} tint={f.tint} />
              )}
            </div>
          </div>
        </section>
      ))}

      {related.length > 0 && (
        <section className="py-24" aria-labelledby="rel-title">
          <div className="container-x">
            <Reveal>
              <SectionHeading eyebrow="Works together" title="Better together with" accent="these features" />
            </Reveal>
            <Stagger className="mt-12 grid gap-5 md:grid-cols-3">
              {related.map((r) => (
                <StaggerItem key={r.slug}>
                  <Link href={featureHref(r)} className="group flex h-full flex-col rounded-[1.75rem] bg-white p-7 ring-1 ring-line card-lift">
                    <span className={cn("grid size-12 place-items-center rounded-2xl bg-gradient-to-br text-white shadow-lg", r.tint)}>
                      <r.icon className="size-6" />
                    </span>
                    <h3 className="mt-5 text-xl font-extrabold text-ink group-hover:text-violet">{r.name}</h3>
                    <p className="mt-2 flex-1 text-ink-soft">{r.short}</p>
                    <span className="mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-violet">
                      Learn more <ArrowRight className="size-4 transition group-hover:translate-x-1" />
                    </span>
                  </Link>
                </StaggerItem>
              ))}
            </Stagger>
          </div>
        </section>
      )}

      {f.faqs.length > 0 && <FaqSection faqs={f.faqs} title={`${f.name}: common questions`} className="bg-mist" />}
      <div className={f.faqs.length ? "bg-mist" : ""}>
        <CtaBand />
      </div>
    </>
  );
}

/** Decorative “UI card” illustration for sections without a screenshot. */
function IllustratedCard({ title, bullets, tint }: { title: string; bullets: string[]; tint: string }) {
  return (
    <div className="relative mx-auto max-w-md">
      <div className="relative overflow-hidden rounded-[2rem] bg-white p-7 shadow-[0_40px_80px_-30px_rgba(28,9,56,0.45)] ring-1 ring-line">
        <div className={cn("absolute -top-16 -right-16 size-48 rounded-full bg-gradient-to-br opacity-20 blur-2xl", tint)} aria-hidden />
        <p className="text-xs font-bold tracking-[0.14em] text-violet uppercase">Booqora</p>
        <p className="mt-2 font-display text-xl font-extrabold text-ink">{title}</p>
        <ul className="mt-6 space-y-3">
          {bullets.map((b, i) => (
            <li key={b} className="flex items-center gap-3 rounded-2xl bg-mist p-3.5 ring-1 ring-line">
              <span className={cn("grid size-9 shrink-0 place-items-center rounded-xl bg-gradient-to-br text-white", tint)}>
                <Check className="size-4" />
              </span>
              <span className="text-[0.95rem] font-semibold text-ink">{b}</span>
              <span className="ml-auto h-2 w-10 rounded-full bg-line" style={{ width: `${28 + ((i * 17) % 30)}px` }} aria-hidden />
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
