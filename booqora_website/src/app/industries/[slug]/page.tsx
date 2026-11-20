import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AlertTriangle, ArrowRight, Check } from "lucide-react";
import { Float, Reveal, Stagger, StaggerItem } from "@/components/motion";
import { Suspense } from "react";
import { AuroraHero, Breadcrumbs, CtaBand, FaqSection, HeroFallback, JsonLd, breadcrumbLd } from "@/components/sections";
import { BrowserFrame, Chip, Eyebrow, GhostButton, PhoneFrame, PrimaryButton, SectionHeading } from "@/components/ui-kit";
import { getFeature, featureHref } from "@/content/features";
import { getIndustry, industries, industryPhoto } from "@/content/industries";
import { site } from "@/lib/site";

export function generateStaticParams() {
  return industries.map((i) => ({ slug: i.slug }));
}

export async function generateMetadata({ params }: PageProps<"/industries/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  const ind = getIndustry(slug);
  if (!ind) return {};
  return {
    title: ind.seoTitle,
    description: ind.metaDescription,
    keywords: ind.keywords,
    alternates: { canonical: `/industries/${ind.slug}` },
    openGraph: { title: `${ind.seoTitle} | Booqora`, description: ind.metaDescription, url: `/industries/${ind.slug}` },
    twitter: { title: `${ind.seoTitle} | Booqora`, description: ind.metaDescription },
  };
}

export default function IndustryPage({ params }: PageProps<"/industries/[slug]">) {
  return (
    <Suspense fallback={<HeroFallback />}>
      <IndustryContent params={params} />
    </Suspense>
  );
}

async function IndustryContent({ params }: { params: PageProps<"/industries/[slug]">["params"] }) {
  const { slug } = await params;
  const ind = getIndustry(slug);
  if (!ind) notFound();
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Industries", path: "/industries" },
    { name: ind.name, path: `/industries/${ind.slug}` },
  ];
  const others = industries.filter((i) => i.slug !== ind.slug).slice(0, 3);

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-24">
        <div className="container-x">
          <Reveal>
            <Breadcrumbs items={crumbs} />
          </Reveal>
          <div className="mt-10 grid items-center gap-14 lg:grid-cols-[1.05fr_1fr]">
            <div>
              <Reveal delay={0.05}>
                <Eyebrow dark>{ind.name}</Eyebrow>
              </Reveal>
              <Reveal delay={0.1}>
                <h1 className="mt-6 text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
                  {ind.headline} <span className="text-gradient-light">{ind.headlineAccent}</span>
                </h1>
              </Reveal>
              <Reveal delay={0.16}>
                <p className="mt-6 max-w-xl text-lg leading-8 text-white/75">{ind.lead}</p>
              </Reveal>
              <Reveal delay={0.22} className="mt-9 flex flex-col gap-3 sm:flex-row">
                <PrimaryButton href={site.signupUrl} size="lg">
                  Start free trial
                </PrimaryButton>
                <GhostButton href="/features" size="lg" dark>
                  See all features
                </GhostButton>
              </Reveal>
            </div>
            {/* Industry photo with the Booqora app alongside */}
            <div className="relative mx-auto w-full max-w-xl pb-10 sm:pr-16">
              <div className="absolute inset-[8%] -z-10 rounded-full bg-violet-bright/40 blur-[90px]" aria-hidden />
              <Reveal delay={0.15} className="relative aspect-[4/3] overflow-hidden rounded-[2rem] shadow-[0_50px_100px_-30px_rgba(0,0,0,0.7)] ring-1 ring-white/20">
                <Image src={industryPhoto(ind.slug)} alt={ind.photoAlt} fill priority sizes="(min-width: 1024px) 560px, 100vw" className="object-cover" />
                <div className="absolute inset-0 bg-gradient-to-t from-night/50 via-transparent to-transparent" aria-hidden />
              </Reveal>
              <Float className="absolute right-0 -bottom-2 w-[30%] max-w-[160px]" delay={0.6} distance={8}>
                <PhoneFrame src="/shots/m-inventory.webp" alt="Booqora mobile inventory" />
              </Float>
              <Float className="absolute -bottom-1 left-4 sm:-left-6" delay={0.9} distance={7}>
                <Chip icon={<Check />} tone="green" label="Live availability" sub="Synced on web & mobile" />
              </Float>
            </div>
          </div>
        </div>
      </AuroraHero>

      <section className="py-16" aria-label="What you rent">
        <div className="container-x">
          <Reveal>
            <p className="text-center text-sm font-bold tracking-[0.16em] text-mute uppercase">Perfect for renting</p>
          </Reveal>
          <Stagger className="mt-6 flex flex-wrap justify-center gap-3">
            {ind.examples.map((e) => (
              <StaggerItem key={e}>
                <span className="inline-flex items-center gap-2 rounded-full bg-white px-5 py-2.5 font-semibold text-ink ring-1 ring-line">
                  <span className="size-2 rounded-full bg-gradient-to-br from-violet to-rose" aria-hidden />
                  {e}
                </span>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </section>

      <section className="bg-mist py-24" aria-labelledby="ch-title">
        <div className="container-x">
          <Reveal>
            <SectionHeading eyebrow="The challenge" title={`Running a ${ind.name.toLowerCase()} business`} accent="is hard work" />
          </Reveal>
          <Stagger className="mt-14 grid gap-5 md:grid-cols-3">
            {ind.challenges.map((c) => (
              <StaggerItem key={c.title}>
                <div className="h-full rounded-[1.75rem] bg-white p-7 ring-1 ring-line">
                  <span className="grid size-12 place-items-center rounded-2xl bg-[#fef3e2] text-[#d97706]">
                    <AlertTriangle className="size-6" />
                  </span>
                  <h3 className="mt-5 text-xl font-extrabold text-ink">{c.title}</h3>
                  <p className="mt-2 leading-7 text-ink-soft">{c.body}</p>
                </div>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </section>

      <section className="py-24" aria-labelledby="help-title">
        <div className="container-x grid items-center gap-14 lg:grid-cols-2">
          <div>
            <Reveal>
              <SectionHeading align="left" eyebrow="How Booqora helps" title="Built around the way" accent="you work" />
            </Reveal>
            <div className="mt-10 space-y-4">
              {ind.howItHelps.map((h, i) => {
                const feat = getFeature(h.feature);
                return (
                  <Reveal key={h.title} delay={i * 0.06}>
                    <Link href={feat ? featureHref(feat) : "/features"} className="group flex gap-4 rounded-2xl p-4 ring-1 ring-transparent transition hover:bg-mist hover:ring-line">
                      <span className="mt-0.5 grid size-10 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-violet to-indigo text-white shadow-md">
                        <Check className="size-5" />
                      </span>
                      <span>
                        <span className="block text-lg font-extrabold text-ink group-hover:text-violet">{h.title}</span>
                        <span className="mt-1 block leading-7 text-ink-soft">{h.body}</span>
                        {feat && (
                          <span className="mt-2 inline-flex items-center gap-1 text-sm font-bold text-violet">
                            {feat.name} <ArrowRight className="size-3.5 transition group-hover:translate-x-1" />
                          </span>
                        )}
                      </span>
                    </Link>
                  </Reveal>
                );
              })}
            </div>
          </div>
          <Reveal delay={0.1} className="relative">
            <div className="absolute inset-8 -z-10 rounded-[3rem] bg-gradient-to-br from-lavender/60 via-haze to-[#fde7f3] blur-2xl" aria-hidden />
            <BrowserFrame src="/shots/product.webp" alt={`Tracking ${ind.name.toLowerCase()} inventory in Booqora`} />
            <Float className="absolute -bottom-10 -left-4 w-[30%] max-w-[180px]" delay={0.4}>
              <PhoneFrame src="/shots/m-order.webp" alt="Booqora order on mobile" />
            </Float>
          </Reveal>
        </div>
      </section>

      <FaqSection faqs={ind.faqs} title={`${ind.name} software FAQ`} className="bg-mist" />

      <section className="bg-mist pb-20" aria-label="Other industries">
        <div className="container-x">
          <p className="text-center text-sm font-bold tracking-[0.16em] text-mute uppercase">Other industries</p>
          <div className="mt-6 grid gap-4 sm:grid-cols-3">
            {others.map((o) => (
              <Link key={o.slug} href={`/industries/${o.slug}`} className="group flex items-center gap-4 rounded-2xl bg-white p-4 ring-1 ring-line card-lift">
                <span className="relative size-14 shrink-0 overflow-hidden rounded-2xl bg-mist">
                  <Image src={industryPhoto(o.slug)} alt="" fill sizes="56px" className="object-cover transition group-hover:scale-110" />
                </span>
                <span className="font-bold text-ink group-hover:text-violet">{o.name}</span>
              </Link>
            ))}
          </div>
        </div>
      </section>
      <div className="bg-mist">
        <CtaBand title={`Grow your ${ind.name.toLowerCase()}`} accent="business with Booqora" />
      </div>
    </>
  );
}
