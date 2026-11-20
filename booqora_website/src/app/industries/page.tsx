import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { Reveal, Stagger, StaggerItem } from "@/components/motion";
import { AuroraHero, Breadcrumbs, CtaBand, JsonLd, breadcrumbLd } from "@/components/sections";
import { Eyebrow, PrimaryButton } from "@/components/ui-kit";
import { industries, industryPhoto } from "@/content/industries";
import { site } from "@/lib/site";

const description =
  "Booqora rental software for camera and AV rental, party and event rental, bike and scooter rental, tool and equipment hire, sports and outdoor gear and furniture rental.";

export const metadata: Metadata = {
  title: "Rental Software by Industry",
  description,
  alternates: { canonical: "/industries" },
  openGraph: { title: "Rental Software by Industry | Booqora", description, url: "/industries" },
};

export default function IndustriesPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Industries", path: "/industries" },
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
            <Eyebrow dark>Industries</Eyebrow>
          </Reveal>
          <Reveal delay={0.1}>
            <h1 className="mx-auto mt-6 max-w-4xl text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
              Whatever you rent, <span className="text-gradient-light">Booqora fits</span>
            </h1>
          </Reveal>
          <Reveal delay={0.16}>
            <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-white/75">
              From a single camera kit to a warehouse of event furniture — Booqora adapts to how your business rents, prices and delivers.
            </p>
          </Reveal>
          <Reveal delay={0.22} className="mt-9 flex justify-center">
            <PrimaryButton href={site.signupUrl} size="lg">
              Start free trial
            </PrimaryButton>
          </Reveal>
        </div>
      </AuroraHero>

      <section className="py-20">
        <div className="container-x">
          <Stagger className="grid gap-6 md:grid-cols-2">
            {industries.map((ind) => (
              <StaggerItem key={ind.slug}>
                <Link href={`/industries/${ind.slug}`} className="group relative flex h-full flex-col overflow-hidden rounded-[2rem] bg-white ring-1 ring-line card-lift sm:flex-row">
                  <div className="relative min-h-52 overflow-hidden bg-mist sm:w-60 sm:shrink-0">
                    <Image
                      src={industryPhoto(ind.slug)}
                      alt={ind.photoAlt}
                      fill
                      sizes="(min-width: 640px) 240px, 100vw"
                      className="object-cover transition duration-700 group-hover:scale-105"
                    />
                  </div>
                  <div className="flex flex-1 flex-col p-7">
                    <h2 className="text-2xl font-extrabold text-ink group-hover:text-violet">{ind.name}</h2>
                    <p className="mt-2 text-ink-soft">{ind.lead}</p>
                    <span className="mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-violet">
                      {ind.seoTitle} <ArrowRight className="size-4 transition group-hover:translate-x-1" />
                    </span>
                  </div>
                </Link>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </section>
      <CtaBand />
    </>
  );
}
