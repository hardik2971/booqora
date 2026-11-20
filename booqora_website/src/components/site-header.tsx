"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "motion/react";
import { ArrowRight, BookOpen, ChevronDown, Info, Mail, Menu, Smartphone, X } from "lucide-react";
import { features, featureHref } from "@/content/features";
import { industries, industryPhoto } from "@/content/industries";
import Image from "next/image";
import { Logo, PrimaryButton } from "@/components/ui-kit";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";

type MenuKey = "product" | "industries" | "resources" | null;

const resources = [
  { href: "/blog", label: "Rental guides", body: "Practical advice for running a rental business", icon: BookOpen },
  { href: "/about", label: "About Booqora", body: "Why we build rental software", icon: Info },
  { href: "/contact", label: "Contact", body: "Talk to us about your business", icon: Mail },
];

export function SiteHeader() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState<MenuKey>(null);
  const [mobile, setMobile] = useState(false);
  const pathname = usePathname();
  const closeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Close menus after navigation (state adjusted during render, not in an effect).
  const [lastPath, setLastPath] = useState(pathname);
  if (pathname !== lastPath) {
    setLastPath(pathname);
    setOpen(null);
    setMobile(false);
  }

  useEffect(() => {
    document.body.style.overflow = mobile ? "hidden" : "";
  }, [mobile]);

  const solid = scrolled || open !== null;
  const enter = (k: MenuKey) => {
    if (closeTimer.current) clearTimeout(closeTimer.current);
    setOpen(k);
  };
  const leave = () => {
    closeTimer.current = setTimeout(() => setOpen(null), 140);
  };

  const navItem = (k: Exclude<MenuKey, null>, label: string) => (
    <button
      type="button"
      onMouseEnter={() => enter(k)}
      onMouseLeave={leave}
      onFocus={() => enter(k)}
      onClick={() => setOpen(open === k ? null : k)}
      aria-expanded={open === k}
      className={cn("inline-flex items-center gap-1 rounded-full px-3.5 py-2 text-[0.94rem] font-semibold transition-colors", solid ? "text-ink hover:bg-haze" : "text-white/90 hover:bg-white/10")}
    >
      {label}
      <ChevronDown className={cn("size-4 transition-transform duration-300", open === k && "rotate-180")} aria-hidden />
    </button>
  );

  const plainLink = (href: string, label: string) => (
    <Link
      href={href}
      className={cn("rounded-full px-3.5 py-2 text-[0.94rem] font-semibold transition-colors", solid ? "text-ink hover:bg-haze" : "text-white/90 hover:bg-white/10", pathname === href && (solid ? "text-violet" : "text-white"))}
    >
      {label}
    </Link>
  );

  return (
    <header className="fixed inset-x-0 top-0 z-50">
      <div
        className={cn(
          "transition-all duration-500",
          solid ? "bg-white/85 shadow-[0_10px_40px_-20px_rgba(28,9,56,0.35)] backdrop-blur-xl" : "bg-transparent",
        )}
      >
        <nav className="container-x flex h-[4.5rem] items-center justify-between gap-6" aria-label="Main">
          <Link href="/" aria-label="Booqora home" className="shrink-0">
            <Logo dark={!solid} />
          </Link>

          <div className="hidden items-center gap-1 lg:flex">
            {navItem("product", "Product")}
            {navItem("industries", "Industries")}
            {plainLink("/pricing", "Pricing")}
            {plainLink("/integrations", "Integrations")}
            {navItem("resources", "Resources")}
          </div>

          <div className="hidden items-center gap-2 lg:flex">
            <a href={site.loginUrl} className={cn("rounded-full px-4 py-2 text-[0.94rem] font-semibold transition-colors", solid ? "text-ink hover:bg-haze" : "text-white hover:bg-white/10")}>
              Log in
            </a>
            <PrimaryButton href={site.signupUrl}>Start free trial</PrimaryButton>
          </div>

          <button
            type="button"
            onClick={() => setMobile(true)}
            className={cn("grid size-11 place-items-center rounded-full lg:hidden", solid ? "text-ink hover:bg-haze" : "text-white hover:bg-white/10")}
            aria-label="Open menu"
          >
            <Menu className="size-6" />
          </button>
        </nav>

        <AnimatePresence>
          {open && (
            <motion.div
              key={open}
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
              onMouseEnter={() => enter(open)}
              onMouseLeave={leave}
              className="hidden border-t border-line lg:block"
            >
              <div className="container-x py-7">
                {open === "product" && <ProductMenu />}
                {open === "industries" && <IndustriesMenu />}
                {open === "resources" && (
                  <div className="grid grid-cols-3 gap-3">
                    {resources.map((r) => (
                      <Link key={r.href} href={r.href} className="group flex gap-4 rounded-2xl p-4 transition hover:bg-mist">
                        <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-haze text-violet">
                          <r.icon className="size-5" />
                        </span>
                        <span>
                          <span className="block font-bold text-ink group-hover:text-violet">{r.label}</span>
                          <span className="block text-sm text-mute">{r.body}</span>
                        </span>
                      </Link>
                    ))}
                  </div>
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <AnimatePresence>{mobile && <MobileMenu onClose={() => setMobile(false)} />}</AnimatePresence>
    </header>
  );
}

function ProductMenu() {
  return (
    <div className="grid grid-cols-[1fr_300px] gap-8">
      <div className="grid grid-cols-3 gap-1.5">
        {features.map((f) => (
          <Link key={f.slug} href={featureHref(f)} className="group flex gap-3.5 rounded-2xl p-3 transition hover:bg-mist">
            <span className={cn("grid size-10 shrink-0 place-items-center rounded-xl bg-gradient-to-br text-white shadow-md", f.tint)}>
              <f.icon className="size-[18px]" />
            </span>
            <span>
              <span className="block text-[0.95rem] font-bold text-ink group-hover:text-violet">{f.name}</span>
              <span className="line-clamp-2 block text-[0.82rem] leading-5 text-mute">{f.short}</span>
            </span>
          </Link>
        ))}
      </div>
      <div className="relative overflow-hidden rounded-3xl bg-aurora p-6 text-white">
        <div className="bg-dots-light absolute inset-0 opacity-60" aria-hidden />
        <Link href="/mobile-app" className="group relative block">
          <Smartphone className="size-8 text-lavender" />
          <p className="mt-4 font-display text-xl font-extrabold">Booqora in your pocket</p>
          <p className="mt-2 text-sm text-white/70">Bookings, payments, barcode scanning and invoices on Android and iOS.</p>
          <span className="mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-lavender">
            Explore the app <ArrowRight className="size-4 transition group-hover:translate-x-1" />
          </span>
        </Link>
        <Link href="/features" className="relative mt-6 block border-t border-white/15 pt-4 text-sm font-semibold text-white/80 hover:text-white">
          See all features →
        </Link>
      </div>
    </div>
  );
}

function IndustriesMenu() {
  return (
    <div className="grid grid-cols-3 gap-3">
      {industries.map((i) => (
        <Link key={i.slug} href={`/industries/${i.slug}`} className="group flex items-center gap-4 rounded-2xl p-3 transition hover:bg-mist">
          <span className="relative size-14 shrink-0 overflow-hidden rounded-2xl bg-haze">
            <Image src={industryPhoto(i.slug)} alt="" fill sizes="56px" className="object-cover transition duration-500 group-hover:scale-110" />
          </span>
          <span>
            <span className="block font-bold text-ink group-hover:text-violet">{i.name}</span>
            <span className="block text-[0.82rem] text-mute">{i.short}</span>
          </span>
        </Link>
      ))}
    </div>
  );
}

function MobileMenu({ onClose }: { onClose: () => void }) {
  const [section, setSection] = useState<string | null>("product");
  const group = (key: string, label: string, children: React.ReactNode) => (
    <div className="border-b border-line">
      <button type="button" onClick={() => setSection(section === key ? null : key)} className="flex w-full items-center justify-between py-4 text-lg font-bold text-ink" aria-expanded={section === key}>
        {label}
        <ChevronDown className={cn("size-5 transition-transform", section === key && "rotate-180")} />
      </button>
      <AnimatePresence initial={false}>
        {section === key && (
          <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden">
            <div className="pb-4">{children}</div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-50 lg:hidden">
      <div className="absolute inset-0 bg-night/50 backdrop-blur-sm" onClick={onClose} aria-hidden />
      <motion.div
        initial={{ x: "100%" }}
        animate={{ x: 0 }}
        exit={{ x: "100%" }}
        transition={{ type: "spring", damping: 30, stiffness: 260 }}
        className="absolute inset-y-0 right-0 flex w-full max-w-sm flex-col bg-white"
        role="dialog"
        aria-modal="true"
        aria-label="Menu"
      >
        <div className="flex h-[4.5rem] items-center justify-between px-5">
          <Logo />
          <button type="button" onClick={onClose} className="grid size-11 place-items-center rounded-full text-ink hover:bg-haze" aria-label="Close menu">
            <X className="size-6" />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-5">
          {group(
            "product",
            "Product",
            <div className="grid gap-1">
              {features.map((f) => (
                <Link key={f.slug} href={featureHref(f)} className="flex items-center gap-3 rounded-xl p-2 hover:bg-mist">
                  <span className={cn("grid size-8 place-items-center rounded-lg bg-gradient-to-br text-white", f.tint)}>
                    <f.icon className="size-4" />
                  </span>
                  <span className="font-semibold text-ink">{f.name}</span>
                </Link>
              ))}
              <Link href="/features" className="p-2 text-sm font-bold text-violet">
                See all features →
              </Link>
            </div>,
          )}
          {group(
            "industries",
            "Industries",
            <div className="grid gap-1">
              {industries.map((i) => (
                <Link key={i.slug} href={`/industries/${i.slug}`} className="flex items-center gap-3 rounded-xl p-2 hover:bg-mist">
                  <Image src={industryPhoto(i.slug)} alt="" width={32} height={32} className="size-8 rounded-lg object-cover" />
                  <span className="font-semibold text-ink">{i.name}</span>
                </Link>
              ))}
            </div>,
          )}
          <Link href="/pricing" className="block border-b border-line py-4 text-lg font-bold text-ink">
            Pricing
          </Link>
          <Link href="/integrations" className="block border-b border-line py-4 text-lg font-bold text-ink">
            Integrations
          </Link>
          {group(
            "resources",
            "Resources",
            <div className="grid gap-1">
              {resources.map((r) => (
                <Link key={r.href} href={r.href} className="rounded-xl p-2 font-semibold text-ink hover:bg-mist">
                  {r.label}
                </Link>
              ))}
            </div>,
          )}
        </div>
        <div className="grid gap-3 border-t border-line p-5">
          <a href={site.loginUrl} className="flex h-12 items-center justify-center rounded-full font-semibold text-ink ring-1 ring-line">
            Log in
          </a>
          <PrimaryButton href={site.signupUrl} className="h-12">
            Start free trial
          </PrimaryButton>
        </div>
      </motion.div>
    </motion.div>
  );
}
