import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { site } from "@/lib/site";

export function Logo({ dark = false, className }: { dark?: boolean; className?: string }) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <Image src="/logo-mark.png" alt="" width={36} height={36} className="size-9" priority />
      <span className={cn("font-display text-[1.35rem] font-extrabold tracking-tight", dark ? "text-white" : "text-ink")}>Booqora</span>
    </span>
  );
}

type BtnProps = { href: string; children: React.ReactNode; className?: string; size?: "md" | "lg"; external?: boolean };

const base =
  "group inline-flex items-center justify-center gap-2 rounded-full font-semibold transition-all duration-300 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-lavender/60 whitespace-nowrap";
const sizes = { md: "h-11 px-5 text-[0.95rem]", lg: "h-13 px-7 text-base" };

function BtnLink({ href, external, className, children }: { href: string; external?: boolean; className: string; children: React.ReactNode }) {
  if (external || href.startsWith("http")) {
    return (
      <a href={href} className={className}>
        {children}
      </a>
    );
  }
  return (
    <Link href={href} className={className}>
      {children}
    </Link>
  );
}

export function PrimaryButton({ href, children, className, size = "md", external }: BtnProps) {
  return (
    <BtnLink
      href={href}
      external={external}
      className={cn(base, sizes[size], "btn-shine text-white shadow-[0_14px_30px_-12px_rgba(100,49,221,0.75)] hover:-translate-y-0.5 hover:shadow-[0_20px_40px_-14px_rgba(100,49,221,0.9)]", className)}
    >
      {children}
      <ArrowRight className="size-4 transition-transform duration-300 group-hover:translate-x-1" aria-hidden />
    </BtnLink>
  );
}

export function GhostButton({ href, children, className, size = "md", external, dark = false }: BtnProps & { dark?: boolean }) {
  return (
    <BtnLink
      href={href}
      external={external}
      className={cn(
        base,
        sizes[size],
        dark ? "glass text-white hover:bg-white/15" : "bg-white text-ink ring-1 ring-line hover:ring-lavender hover:-translate-y-0.5 shadow-sm",
        className,
      )}
    >
      {children}
    </BtnLink>
  );
}

export const TrialCta = ({ className, size = "lg" }: { className?: string; size?: "md" | "lg" }) => (
  <PrimaryButton href={site.signupUrl} size={size} className={className}>
    Start free trial
  </PrimaryButton>
);

export function Eyebrow({ children, dark = false, className }: { children: React.ReactNode; dark?: boolean; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[0.78rem] font-bold tracking-[0.14em] uppercase",
        dark ? "glass text-[#E9DEFF]" : "bg-haze text-violet ring-1 ring-lavender/50",
        className,
      )}
    >
      <span className="size-1.5 rounded-full bg-gradient-to-br from-lavender to-rose shadow-[0_0_10px_#f472b6]" aria-hidden />
      {children}
    </span>
  );
}

export function SectionHeading({
  eyebrow,
  title,
  accent,
  lead,
  dark = false,
  align = "center",
  className,
  as: H = "h2",
}: {
  eyebrow?: string;
  title: string;
  accent?: string;
  lead?: string;
  dark?: boolean;
  align?: "center" | "left";
  className?: string;
  as?: "h1" | "h2";
}) {
  return (
    <div className={cn("max-w-3xl", align === "center" && "mx-auto text-center", className)}>
      {eyebrow && <Eyebrow dark={dark}>{eyebrow}</Eyebrow>}
      <H className={cn("mt-5 text-[2.1rem] leading-[1.08] font-extrabold sm:text-5xl", dark ? "text-white" : "text-ink")}>
        {title} {accent && <span className={dark ? "text-gradient-light" : "text-gradient"}>{accent}</span>}
      </H>
      {lead && <p className={cn("mt-5 text-lg leading-8", dark ? "text-white/70" : "text-ink-soft")}>{lead}</p>}
    </div>
  );
}

/** Desktop browser window around a real Booqora screenshot. */
export function BrowserFrame({
  src,
  alt,
  className,
  priority = false,
  url = "booqora-platform.web.app",
  sizes = "(min-width: 1024px) 760px, 100vw",
}: {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
  url?: string;
  sizes?: string;
}) {
  return (
    <div className={cn("overflow-hidden rounded-2xl bg-white shadow-[0_50px_100px_-30px_rgba(28,9,56,0.55),0_0_0_1px_rgba(28,9,56,0.06)]", className)}>
      <div className="flex items-center gap-2 border-b border-line bg-mist px-4 py-2.5">
        <span className="size-2.5 rounded-full bg-[#ff6b6b]" />
        <span className="size-2.5 rounded-full bg-[#fbbf24]" />
        <span className="size-2.5 rounded-full bg-[#34d399]" />
        <span className="ml-3 hidden flex-1 truncate rounded-md bg-white px-3 py-1 text-center text-[0.7rem] text-mute ring-1 ring-line sm:block">{url}</span>
      </div>
      <Image src={src} alt={alt} width={1920} height={1144} sizes={sizes} priority={priority} className="block h-auto w-full" />
    </div>
  );
}

/** Phone bezel around a real mobile app screenshot. */
export function PhoneFrame({ src, alt, className, priority = false }: { src: string; alt: string; className?: string; priority?: boolean }) {
  return (
    <div className={cn("relative rounded-[2.6rem] bg-gradient-to-br from-[#3a2a5e] via-[#120a24] to-[#0b0617] p-2.5 shadow-[0_40px_80px_-24px_rgba(28,9,56,0.7),0_0_0_1px_rgba(255,255,255,0.08)_inset]", className)}>
      <div className="relative overflow-hidden rounded-[2.1rem] bg-white">
        <div className="absolute top-2.5 left-1/2 z-10 h-5 w-20 -translate-x-1/2 rounded-full bg-[#05020c]" aria-hidden />
        <Image src={src} alt={alt} width={720} height={1600} sizes="300px" priority={priority} className="block h-auto w-full" />
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-white/20 via-transparent to-transparent" aria-hidden />
      </div>
    </div>
  );
}

/** Small floating UI chip used around product shots. */
export function Chip({ icon, label, sub, tone = "violet", className }: { icon: React.ReactNode; label: string; sub?: string; tone?: "violet" | "green" | "amber" | "pink" | "blue"; className?: string }) {
  const tones = {
    violet: "bg-haze text-violet",
    green: "bg-[#e7f7ed] text-[#16a34a]",
    amber: "bg-[#fef3e2] text-[#d97706]",
    pink: "bg-[#fde7f3] text-[#db2777]",
    blue: "bg-[#e8f0fe] text-[#2563eb]",
  };
  return (
    <div className={cn("flex items-center gap-3 rounded-2xl bg-white/95 py-2.5 pr-4 pl-2.5 shadow-[0_24px_50px_-18px_rgba(28,9,56,0.55)] ring-1 ring-white backdrop-blur", className)}>
      <span className={cn("grid size-9 shrink-0 place-items-center rounded-xl [&_svg]:size-[18px]", tones[tone])}>{icon}</span>
      <span className="leading-tight">
        <span className="block text-[0.82rem] font-bold whitespace-nowrap text-ink">{label}</span>
        {sub && <span className="block text-[0.72rem] whitespace-nowrap text-mute">{sub}</span>}
      </span>
    </div>
  );
}

export function IntegrationTile({ name, color, className }: { name: string; color: string; className?: string }) {
  const initials = name
    .replace(/\..*$/, "")
    .split(/\s+/)
    .map((w) => w[0])
    .join("")
    .slice(0, 2);
  return (
    <span className={cn("grid size-12 shrink-0 place-items-center rounded-2xl font-display text-lg font-extrabold text-white shadow-md", className)} style={{ background: `linear-gradient(140deg, ${color}, ${color}cc)` }} aria-hidden>
      {initials}
    </span>
  );
}

