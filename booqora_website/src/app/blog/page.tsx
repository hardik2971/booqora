import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, Clock } from "lucide-react";
import { PostCover } from "@/components/art/post-cover";
import { Reveal, Stagger, StaggerItem } from "@/components/motion";
import { AuroraHero, Breadcrumbs, CtaBand, JsonLd, breadcrumbLd } from "@/components/sections";
import { Eyebrow } from "@/components/ui-kit";
import { posts } from "@/content/posts";

const description = "Practical guides for rental business owners: starting a rental business, pricing your rentals, preventing double bookings and more.";

export const metadata: Metadata = {
  title: "Rental Business Guides & Blog",
  description,
  alternates: { canonical: "/blog" },
  openGraph: { title: "Rental Business Guides | Booqora", description, url: "/blog" },
};

const fmt = (iso: string) => new Date(iso + "T00:00:00Z").toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });

export default function BlogPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Guides", path: "/blog" },
  ];
  const [first, ...rest] = posts;
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-20">
        <div className="container-x text-center">
          <Reveal className="flex justify-center">
            <Breadcrumbs items={crumbs} />
          </Reveal>
          <Reveal delay={0.05} className="mt-8">
            <Eyebrow dark>Rental guides</Eyebrow>
          </Reveal>
          <Reveal delay={0.1}>
            <h1 className="mx-auto mt-6 max-w-3xl text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
              Grow a smarter <span className="text-gradient-light">rental business</span>
            </h1>
          </Reveal>
          <Reveal delay={0.16}>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-8 text-white/75">Practical, no-nonsense advice on pricing, operations and growth for rental business owners.</p>
          </Reveal>
        </div>
      </AuroraHero>

      <section className="pb-24">
        <div className="container-x">
          <Reveal>
            <Link href={`/blog/${first.slug}`} className="group grid overflow-hidden rounded-[2rem] bg-white ring-1 ring-line card-lift lg:grid-cols-2">
              <PostCover art={first.art} className="aspect-[16/10] lg:aspect-auto lg:min-h-[22rem]" large />
              <div className="flex flex-col justify-center p-8 sm:p-10">
                <p className="text-xs font-bold tracking-[0.14em] text-violet uppercase">
                  {first.category} · Featured
                </p>
                <h2 className="mt-3 text-3xl leading-tight font-extrabold text-ink group-hover:text-violet">{first.title}</h2>
                <p className="mt-4 leading-7 text-ink-soft">{first.description}</p>
                <p className="mt-6 flex items-center gap-2 text-sm text-mute">
                  <Clock className="size-4" /> {first.readMinutes} min read · {fmt(first.date)}
                </p>
              </div>
            </Link>
          </Reveal>
          <Stagger className="mt-8 grid gap-6 md:grid-cols-2">
            {rest.map((p) => (
              <StaggerItem key={p.slug}>
                <Link href={`/blog/${p.slug}`} className="group flex h-full flex-col overflow-hidden rounded-[2rem] bg-white ring-1 ring-line card-lift">
                  <PostCover art={p.art} className="aspect-[16/9]" />
                  <div className="flex flex-1 flex-col p-7">
                    <p className="text-xs font-bold tracking-[0.14em] text-violet uppercase">{p.category}</p>
                    <h2 className="mt-3 text-2xl leading-snug font-extrabold text-ink group-hover:text-violet">{p.title}</h2>
                    <p className="mt-3 flex-1 leading-7 text-ink-soft">{p.description}</p>
                    <span className="mt-5 flex items-center justify-between text-sm">
                      <span className="text-mute">{p.readMinutes} min read</span>
                      <span className="inline-flex items-center gap-1.5 font-bold text-violet">
                        Read guide <ArrowRight className="size-4 transition group-hover:translate-x-1" />
                      </span>
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
