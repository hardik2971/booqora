import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Clock, Lightbulb } from "lucide-react";
import { PostCover } from "@/components/art/post-cover";
import { Reveal } from "@/components/motion";
import { Suspense } from "react";
import { AuroraHero, Breadcrumbs, CtaBand, HeroFallback, JsonLd, breadcrumbLd } from "@/components/sections";
import { PrimaryButton } from "@/components/ui-kit";
import { getPost, posts, type Block } from "@/content/posts";
import { absoluteUrl, site } from "@/lib/site";

export function generateStaticParams() {
  return posts.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: PageProps<"/blog/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  const p = getPost(slug);
  if (!p) return {};
  return {
    title: p.title,
    description: p.description,
    keywords: p.keywords,
    alternates: { canonical: `/blog/${p.slug}` },
    openGraph: { type: "article", title: p.title, description: p.description, url: `/blog/${p.slug}`, publishedTime: p.date },
    twitter: { title: p.title, description: p.description },
  };
}

const fmt = (iso: string) => new Date(iso + "T00:00:00Z").toLocaleDateString("en-IN", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });

function renderBlock(b: Block, i: number) {
  switch (b.t) {
    case "h2":
      return <h2 key={i}>{b.c}</h2>;
    case "h3":
      return <h3 key={i}>{b.c}</h3>;
    case "ul":
      return (
        <ul key={i}>
          {b.c.map((x) => (
            <li key={x}>{x}</li>
          ))}
        </ul>
      );
    case "ol":
      return (
        <ol key={i}>
          {b.c.map((x) => (
            <li key={x}>{x}</li>
          ))}
        </ol>
      );
    case "tip":
      return (
        <aside key={i} className="not-prose my-8 flex gap-4 rounded-2xl bg-haze p-5 ring-1 ring-lavender/60">
          <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-violet to-indigo text-white">
            <Lightbulb className="size-5" />
          </span>
          <p className="!mb-0 text-ink">{b.c}</p>
        </aside>
      );
    default:
      return <p key={i}>{b.c}</p>;
  }
}

export default function PostPage({ params }: PageProps<"/blog/[slug]">) {
  return (
    <Suspense fallback={<HeroFallback />}>
      <PostContent params={params} />
    </Suspense>
  );
}

async function PostContent({ params }: { params: PageProps<"/blog/[slug]">["params"] }) {
  const { slug } = await params;
  const p = getPost(slug);
  if (!p) notFound();
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Guides", path: "/blog" },
    { name: p.title, path: `/blog/${p.slug}` },
  ];
  const others = posts.filter((x) => x.slug !== p.slug);
  const articleLd = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: p.title,
    description: p.description,
    datePublished: p.date,
    dateModified: p.date,
    author: { "@type": "Organization", name: site.name, url: site.url },
    publisher: { "@type": "Organization", name: site.name, logo: { "@type": "ImageObject", url: absoluteUrl("/logo-mark.png") } },
    mainEntityOfPage: absoluteUrl(`/blog/${p.slug}`),
    keywords: p.keywords.join(", "),
  };
  return (
    <>
      <JsonLd data={[breadcrumbLd(crumbs), articleLd]} />
      <AuroraHero className="pb-40" bottomFade={false}>
        <div className="container-x max-w-4xl">
          <Reveal>
            <Breadcrumbs items={crumbs} />
          </Reveal>
          <Reveal delay={0.05}>
            <p className="mt-8 text-sm font-bold tracking-[0.14em] text-lavender uppercase">{p.category}</p>
          </Reveal>
          <Reveal delay={0.1}>
            <h1 className="mt-4 text-[2.2rem] leading-[1.08] font-extrabold tracking-[-0.025em] sm:text-5xl">{p.title}</h1>
          </Reveal>
          <Reveal delay={0.16}>
            <p className="mt-6 flex flex-wrap items-center gap-x-4 gap-y-1 text-white/65">
              <span>By the Booqora team</span>
              <span className="flex items-center gap-1.5">
                <Clock className="size-4" /> {p.readMinutes} min read
              </span>
              <time dateTime={p.date}>{fmt(p.date)}</time>
            </p>
          </Reveal>
        </div>
      </AuroraHero>
      <article className="container-x relative -mt-28 max-w-4xl pb-20">
        <Reveal>
          <PostCover art={p.art} className="aspect-[16/7] rounded-[2rem] shadow-[0_40px_90px_-40px_rgba(28,9,56,0.6)]" large />
        </Reveal>
        <div className="prose-booqora mx-auto mt-14 max-w-3xl">
          <p className="!text-xl !leading-9 text-ink">{p.description}</p>
          {p.body.map(renderBlock)}
        </div>
        <div className="mx-auto mt-14 max-w-3xl rounded-[2rem] bg-aurora p-8 text-white sm:p-10">
          <p className="font-display text-2xl font-extrabold">Run your rental business on Booqora</p>
          <p className="mt-2 text-white/70">Online bookings, inventory, payments and invoices in one place. Free for {site.trialDays} days, no credit card required.</p>
          <div className="mt-6">
            <PrimaryButton href={site.signupUrl}>Start free trial</PrimaryButton>
          </div>
        </div>
        <div className="mx-auto mt-14 max-w-3xl">
          <p className="text-sm font-bold tracking-[0.14em] text-mute uppercase">Keep reading</p>
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            {others.map((o) => (
              <Link key={o.slug} href={`/blog/${o.slug}`} className="group overflow-hidden rounded-2xl bg-white ring-1 ring-line card-lift">
                <PostCover art={o.art} className="aspect-[16/7]" />
                <p className="p-5 font-bold text-ink group-hover:text-violet">{o.title}</p>
              </Link>
            ))}
          </div>
          <Link href="/blog" className="mt-8 inline-flex items-center gap-2 font-semibold text-violet">
            <ArrowLeft className="size-4" /> All guides
          </Link>
        </div>
      </article>
      <CtaBand />
    </>
  );
}
