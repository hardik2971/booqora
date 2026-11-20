import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Check, CreditCard, Globe2, MousePointerClick, PackagePlus, ScanBarcode, ShieldCheck, Smartphone, Zap } from "lucide-react";
import { HeroVisual } from "@/components/home/hero-visual";
import { Float, Parallax, Reveal, Stagger, StaggerItem } from "@/components/motion";
import { AuroraHero, CtaBand, FaqSection } from "@/components/sections";
import { BrowserFrame, Chip, Eyebrow, GhostButton, IntegrationTile, PhoneFrame, PrimaryButton, SectionHeading } from "@/components/ui-kit";
import { homeFaqs, integrations } from "@/content/catalog";
import { features } from "@/content/features";
import { industries, industryPhoto } from "@/content/industries";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";

export default function HomePage() {
  return (
    <>
      <AuroraHero className="pb-28 sm:pb-36">
        <div className="container-x text-center">
          <Reveal>
            <Eyebrow dark>Rental management software</Eyebrow>
          </Reveal>
          <Reveal delay={0.08}>
            <h1 className="mx-auto mt-7 max-w-5xl text-[2.6rem] leading-[1.02] font-extrabold tracking-[-0.035em] sm:text-6xl lg:text-[5.2rem]">
              Rent out more.
              <br />
              <span className="text-gradient-light">Manage less.</span>
            </h1>
          </Reveal>
          <Reveal delay={0.16}>
            <p className="mx-auto mt-7 max-w-2xl text-lg leading-8 text-white/75 sm:text-xl">
              Booqora is the all-in-one rental software for taking online bookings, tracking inventory and availability, collecting payments and sending invoices —
              on the web and on your phone.
            </p>
          </Reveal>
          <Reveal delay={0.24} className="mt-10 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <PrimaryButton href={site.signupUrl} size="lg">
              Start free trial
            </PrimaryButton>
            <GhostButton href="/features" size="lg" dark>
              Explore features
            </GhostButton>
          </Reveal>
          <Reveal delay={0.3}>
            <ul className="mt-7 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 text-sm text-white/60">
              {[`${site.trialDays}-day free trial`, "No credit card required", "Web, Android & iOS"].map((t) => (
                <li key={t} className="flex items-center gap-1.5">
                  <Check className="size-4 text-mint" aria-hidden /> {t}
                </li>
              ))}
            </ul>
          </Reveal>
        </div>
        <HeroVisual />
      </AuroraHero>

      <IndustryMarquee />
      <Bento />
      <HowItWorks />
      <Spotlights />
      <MobileBand />
      <IndustriesGrid />
      <IntegrationsCloud />
      <FaqSection faqs={homeFaqs} className="bg-mist" />
      <div className="bg-mist">
        <CtaBand />
      </div>
    </>
  );
}

function IndustryMarquee() {
  const items = [...industries, ...industries];
  return (
    <section className="relative py-14" aria-label="Industries">
      <p className="text-center text-sm font-bold tracking-[0.16em] text-mute uppercase">Built for every kind of rental business</p>
      <div className="mask-fade-x mt-8 overflow-hidden">
        <div className="flex w-max animate-marquee gap-4 hover:[animation-play-state:paused]">
          {items.map((i, idx) => (
            <Link
              key={idx}
              href={`/industries/${i.slug}`}
              className="flex items-center gap-3 rounded-full bg-white py-2 pr-6 pl-2 ring-1 ring-line transition hover:ring-lavender"
              tabIndex={idx >= industries.length ? -1 : undefined}
              aria-hidden={idx >= industries.length ? true : undefined}
            >
              <span className="size-11 shrink-0 overflow-hidden rounded-full bg-haze">
                <Image src={industryPhoto(i.slug)} alt="" width={44} height={44} className="size-11 rounded-full object-cover" />
              </span>
              <span className="font-semibold whitespace-nowrap text-ink">{i.name}</span>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

function BentoCard({
  href,
  eyebrow,
  title,
  body,
  className,
  children,
}: {
  href: string;
  eyebrow: string;
  title: string;
  body: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <StaggerItem className={className}>
      <Link href={href} className="group relative flex h-full flex-col overflow-hidden rounded-[2rem] bg-white p-7 ring-1 ring-line card-lift">
        <p className="text-xs font-bold tracking-[0.14em] text-violet uppercase">{eyebrow}</p>
        <h3 className="mt-3 text-2xl font-extrabold text-ink">{title}</h3>
        <p className="mt-2 text-ink-soft">{body}</p>
        <div className="relative mt-6 flex-1">{children}</div>
        <span className="mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-violet">
          Learn more <ArrowRight className="size-4 transition group-hover:translate-x-1" />
        </span>
      </Link>
    </StaggerItem>
  );
}

function ShotCrop({ src, alt, position = "top left", className }: { src: string; alt: string; position?: string; className?: string }) {
  return (
    <div className={cn("relative overflow-hidden rounded-2xl bg-mist ring-1 ring-line", className)}>
      <Image src={src} alt={alt} fill sizes="(min-width: 1024px) 600px, 100vw" className="object-cover transition duration-700 group-hover:scale-[1.04]" style={{ objectPosition: position }} />
    </div>
  );
}

function Bento() {
  return (
    <section className="bg-mist py-24" aria-labelledby="bento-title">
      <div className="container-x">
        <Reveal>
          <SectionHeading
            eyebrow="One platform"
            title="Everything your rental business needs,"
            accent="in one place"
            lead="Stop juggling spreadsheets, diaries and chat threads. Booqora connects bookings, stock, payments and paperwork so every part of your business stays in sync."
          />
        </Reveal>
        <Stagger className="mt-16 grid gap-5 md:grid-cols-6">
          <BentoCard
            className="md:col-span-4"
            href="/features/online-booking"
            eyebrow="Online store"
            title="Take bookings 24/7"
            body="A branded booking website with live availability, cart, checkout and online payments."
          >
            <ShotCrop src="/shots/storefront.webp" alt="Booqora online rental store with date picker and products" className="h-64" position="center 30%" />
            <Float className="absolute -right-2 -bottom-4 hidden sm:block" delay={0.4} distance={6}>
              <Chip icon={<Globe2 />} label="New online booking" sub="2 items · 21–22 Nov" />
            </Float>
          </BentoCard>
          <BentoCard className="md:col-span-2" href="/features/payments" eyebrow="Payments" title="Get paid faster" body="Razorpay UPI, Stripe, PayPal, payment links and cash.">
            <div className="grid h-64 place-items-center rounded-2xl bg-gradient-to-br from-[#e7f7ed] to-haze">
              <div className="relative w-[78%]">
                <div className="rounded-2xl bg-white p-4 shadow-xl ring-1 ring-line">
                  <p className="text-xs font-semibold text-mute">Order #3</p>
                  <p className="mt-1 font-display text-3xl font-extrabold text-ink">₹3,186</p>
                  <div className="mt-3 flex items-center gap-2 rounded-xl bg-[#e7f7ed] px-3 py-2 text-sm font-bold text-[#16a34a]">
                    <Check className="size-4" /> Paid in full
                  </div>
                </div>
                <div className="absolute -top-5 -right-5 grid size-14 place-items-center rounded-2xl bg-gradient-to-br from-violet to-indigo text-white shadow-lg">
                  <CreditCard className="size-6" />
                </div>
              </div>
            </div>
          </BentoCard>
          <BentoCard className="md:col-span-2" href="/features/inventory-management" eyebrow="Inventory" title="Live availability" body="Bulk and serialised stock, bundles, maintenance and shortage alerts.">
            <ShotCrop src="/shots/inventory.webp" alt="Booqora inventory list with products, stock value and prices" className="h-64" position="70% 40%" />
          </BentoCard>
          <BentoCard className="md:col-span-2" href="/features/rental-calendar" eyebrow="Calendar" title="Every pickup, planned" body="Agenda and timeline views of every booking.">
            <ShotCrop src="/shots/calendar.webp" alt="Booqora rental calendar timeline with bookings per product" className="h-64" position="62% 20%" />
          </BentoCard>
          <BentoCard className="md:col-span-2" href="/features/documents" eyebrow="Documents" title="Invoices that impress" body="Quotes, contracts, invoices and packing slips as branded PDFs.">
            <div className="relative grid h-64 place-items-center overflow-hidden rounded-2xl bg-gradient-to-br from-[#fde7f3] to-haze">
              <Image src="/shots/m-invoice.webp" alt="Booqora invoice PDF on the mobile app" width={360} height={800} className="absolute top-6 w-[62%] rounded-2xl shadow-2xl ring-1 ring-line transition duration-700 group-hover:-translate-y-3" />
            </div>
          </BentoCard>
          <BentoCard className="md:col-span-3" href="/features/order-management" eyebrow="Orders" title="From reservation to return" body="Automatic pricing, deposits, coupons and taxes on every booking.">
            <ShotCrop src="/shots/order.webp" alt="Booqora order screen with customer, rental period, payments and documents" className="h-64" position="center 10%" />
          </BentoCard>
          <BentoCard className="md:col-span-3" href="/features/reports" eyebrow="Reports" title="Know what earns" body="Revenue, product ROI, availability, customers and coupons.">
            <ShotCrop src="/shots/reports.webp" alt="Booqora reports overview" className="h-64" position="center 12%" />
          </BentoCard>
        </Stagger>
        <Reveal className="mt-12 text-center">
          <GhostButton href="/features">See all {features.length} features</GhostButton>
        </Reveal>
      </div>
    </section>
  );
}

function HowItWorks() {
  const steps = [
    { icon: PackagePlus, title: "Add your inventory", body: "Create products, set prices by the hour, day or week and add your stock. Add more stock as you grow." },
    { icon: MousePointerClick, title: "Take bookings anywhere", body: "Book walk-ins at the counter or from your phone, and let customers book online 24/7." },
    { icon: Zap, title: "Hand over & get paid", body: "Check gear out and back in, collect payment on the spot and send the invoice in one tap." },
  ];
  return (
    <section className="relative overflow-hidden py-24" aria-labelledby="how-title">
      <div className="bg-dots mask-fade absolute inset-0 opacity-70" aria-hidden />
      <div className="container-x relative">
        <Reveal>
          <SectionHeading eyebrow="How it works" title="Up and running" accent="in an afternoon" lead="No consultants, no long setup. If you can use a spreadsheet, you can run your rental business on Booqora." />
        </Reveal>
        <div className="relative mt-16 grid gap-6 md:grid-cols-3">
          <div className="absolute top-[4.5rem] right-[16%] left-[16%] hidden h-0.5 bg-gradient-to-r from-lavender via-violet to-rose md:block" aria-hidden />
          {steps.map((s, i) => (
            <Reveal key={s.title} delay={i * 0.12} className="relative">
              <div className="relative rounded-[2rem] bg-white p-8 text-center ring-1 ring-line card-lift">
                <div className="relative mx-auto grid size-[5.5rem] place-items-center">
                  <span className="absolute inset-0 animate-pulse-ring rounded-full bg-lavender/40" style={{ animationDelay: `${i * 0.6}s` }} aria-hidden />
                  <span className="relative grid size-[5.5rem] place-items-center rounded-full bg-gradient-to-br from-violet-bright to-indigo text-white shadow-[0_18px_40px_-14px_rgba(100,49,221,0.8)]">
                    <s.icon className="size-8" />
                  </span>
                  <span className="absolute -top-1 -right-1 grid size-8 place-items-center rounded-full bg-white font-display text-sm font-extrabold text-violet ring-2 ring-haze">{i + 1}</span>
                </div>
                <h3 className="mt-7 text-xl font-extrabold text-ink">{s.title}</h3>
                <p className="mt-3 text-ink-soft">{s.body}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

function Spotlights() {
  const rows = [
    {
      eyebrow: "Online store",
      title: "A booking website your customers will love",
      body: "Customers choose their dates, see what's really available and book in minutes. Online bookings land in Booqora as orders — stock reserved, customer saved, payment recorded.",
      bullets: ["Live availability for exact pickup and return times", "Pickup or delivery with delivery charges", "Pay online with Razorpay, Stripe or PayPal", "Your branding, SEO title and description"],
      href: "/features/online-booking",
      shot: "/shots/storefront.webp",
      alt: "Customer-facing Booqora booking page",
      url: "booqora-platform.web.app/s/your-store",
      chip: <Chip icon={<Globe2 />} tone="violet" label="Booking request received" sub="Online store · just now" />,
    },
    {
      eyebrow: "Availability",
      title: "Never rent the same item twice",
      body: "Booqora calculates availability from your real stock and every booking — including late returns and items in maintenance — so double bookings simply stop happening.",
      bullets: ["Bulk quantities or individually tracked units", "Late rentals keep holding stock", "Maintenance and repair downtime", "Shortages flagged before you confirm"],
      href: "/features/inventory-management",
      shot: "/shots/product.webp",
      alt: "Booqora product page with individual stock items and their availability",
      chip: <Chip icon={<ShieldCheck />} tone="green" label="No shortages this week" sub="20 stock items tracked" />,
    },
    {
      eyebrow: "Orders & payments",
      title: "Every booking, priced and paid — automatically",
      body: "Add items and dates and Booqora does the maths: rental price, deposits, discounts and taxes. Collect payment and the order updates itself.",
      bullets: ["Automatic rental pricing", "Security deposits tracked separately", "Coupons, discounts and taxes", "Quotes, contracts and invoices in one click"],
      href: "/features/order-management",
      shot: "/shots/order.webp",
      alt: "Booqora order editor with rental period and payments",
      chip: <Chip icon={<CreditCard />} tone="green" label="₹3,186 paid" sub="Due ₹0.00" />,
    },
  ];
  return (
    <section className="bg-white pb-12" aria-label="Product highlights">
      {rows.map((r, i) => (
        <div key={r.title} className="container-x grid items-center gap-12 py-16 lg:grid-cols-2 lg:gap-20">
          <Reveal className={cn(i % 2 === 1 && "lg:order-2")}>
            <Eyebrow>{r.eyebrow}</Eyebrow>
            <h2 className="mt-5 text-3xl leading-tight font-extrabold text-ink sm:text-[2.6rem]">{r.title}</h2>
            <p className="mt-5 text-lg leading-8 text-ink-soft">{r.body}</p>
            <ul className="mt-7 grid gap-3 sm:grid-cols-2">
              {r.bullets.map((b) => (
                <li key={b} className="flex gap-2.5 text-ink">
                  <span className="mt-0.5 grid size-5 shrink-0 place-items-center rounded-full bg-haze text-violet">
                    <Check className="size-3.5" />
                  </span>
                  <span className="text-[0.97rem]">{b}</span>
                </li>
              ))}
            </ul>
            <Link href={r.href} className="mt-8 inline-flex items-center gap-1.5 font-bold text-violet hover:gap-2.5 transition-all">
              Learn more <ArrowRight className="size-4" />
            </Link>
          </Reveal>
          <div className={cn("relative", i % 2 === 1 && "lg:order-1")}>
            <div className="absolute inset-6 -z-10 rounded-[3rem] bg-gradient-to-br from-lavender/60 via-haze to-[#fde7f3] blur-2xl" aria-hidden />
            <Parallax offset={30}>
              <BrowserFrame src={r.shot} alt={r.alt} url={r.url} />
            </Parallax>
            <Float className="absolute -bottom-6 left-4 sm:-left-6" delay={0.3} distance={8}>
              {r.chip}
            </Float>
          </div>
        </div>
      ))}
    </section>
  );
}

function MobileBand() {
  return (
    <section className="relative isolate overflow-hidden bg-aurora py-24 text-white" aria-labelledby="mobile-title">
      <div className="bg-dots-light mask-fade absolute inset-0 -z-10" aria-hidden />
      <div className="container-x grid items-center gap-16 lg:grid-cols-2">
        <Reveal>
          <Eyebrow dark>Mobile app</Eyebrow>
          <h2 id="mobile-title" className="mt-5 text-4xl leading-[1.08] font-extrabold sm:text-5xl">
            Your rental business, <span className="text-gradient-light">in your pocket</span>
          </h2>
          <p className="mt-5 text-lg leading-8 text-white/70">
            The Booqora app for Android and iOS puts the counter in your hand. Create orders, check availability, scan barcodes, take payments and share invoices — wherever you are.
          </p>
          <ul className="mt-8 grid gap-4 sm:grid-cols-2">
            {[
              [Smartphone, "Orders, inventory & calendar"],
              [CreditCard, "Native Razorpay checkout"],
              [ScanBarcode, "Barcode scanning with the camera"],
              [Zap, "Real-time sync with the web"],
            ].map(([Icon, t]) => {
              const I = Icon as typeof Smartphone;
              return (
                <li key={t as string} className="flex items-center gap-3">
                  <span className="glass grid size-10 place-items-center rounded-xl">
                    <I className="size-5 text-lavender" />
                  </span>
                  <span className="font-semibold">{t as string}</span>
                </li>
              );
            })}
          </ul>
          <div className="mt-10">
            <GhostButton href="/mobile-app" dark size="lg">
              Explore the mobile app
            </GhostButton>
          </div>
        </Reveal>
        <div className="relative mx-auto flex h-[34rem] w-full max-w-lg items-center justify-center">
          <Float className="absolute left-0 w-[40%] -rotate-[9deg]" delay={0.2} distance={10} rotate={-9}>
            <PhoneFrame src="/shots/m-orders.webp" alt="Booqora mobile orders list" />
          </Float>
          <Float className="absolute right-0 w-[40%]" delay={0.5} distance={10} rotate={9}>
            <PhoneFrame src="/shots/m-payment.webp" alt="Collecting a payment in the Booqora mobile app" />
          </Float>
          <Float className="relative z-10 w-[46%]" delay={0.1} distance={14} duration={7}>
            <PhoneFrame src="/shots/m-home.webp" alt="Booqora mobile dashboard" />
          </Float>
        </div>
      </div>
    </section>
  );
}

function IndustriesGrid() {
  return (
    <section className="py-24" aria-labelledby="ind-title">
      <div className="container-x">
        <Reveal>
          <SectionHeading eyebrow="Industries" title="Made for the way" accent="you rent" lead="Every rental business is different. Booqora adapts to yours — from serialised camera gear to hundreds of event chairs." />
        </Reveal>
        <Stagger className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {industries.map((ind) => (
            <StaggerItem key={ind.slug}>
              <Link href={`/industries/${ind.slug}`} className="group relative flex h-full flex-col overflow-hidden rounded-[2rem] bg-white p-7 ring-1 ring-line card-lift">
                <div className="relative h-48 overflow-hidden rounded-2xl bg-mist">
                  <Image
                    src={industryPhoto(ind.slug)}
                    alt={ind.photoAlt}
                    fill
                    sizes="(min-width: 1024px) 380px, (min-width: 640px) 50vw, 100vw"
                    className="object-cover transition duration-700 group-hover:scale-105"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-ink/35 via-transparent to-transparent" aria-hidden />
                </div>
                <h3 className="mt-6 text-xl font-extrabold text-ink group-hover:text-violet">{ind.name}</h3>
                <p className="mt-2 flex-1 text-ink-soft">{ind.short}</p>
                <span className="mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-violet">
                  Explore <ArrowRight className="size-4 transition group-hover:translate-x-1" />
                </span>
              </Link>
            </StaggerItem>
          ))}
        </Stagger>
      </div>
    </section>
  );
}

function IntegrationsCloud() {
  return (
    <section className="relative overflow-hidden bg-white py-24" aria-labelledby="int-title">
      <div className="container-x grid items-center gap-14 lg:grid-cols-[0.9fr_1.1fr]">
        <Reveal>
          <SectionHeading
            align="left"
            eyebrow="Integrations"
            title="Works with the tools"
            accent="you already use"
            lead={`Payments, analytics, marketing, accounting and more. Connect ${integrations.length} apps from the Booqora app store in a few clicks.`}
          />
          <div className="mt-8">
            <GhostButton href="/integrations">Browse integrations</GhostButton>
          </div>
        </Reveal>
        <Stagger className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {integrations.slice(0, 9).map((it) => (
            <StaggerItem key={it.id}>
              <div className="flex items-center gap-3 rounded-2xl bg-white p-3 ring-1 ring-line card-lift">
                <IntegrationTile name={it.name} color={it.color} className="size-10 text-base" />
                <span className="min-w-0">
                  <span className="block truncate text-sm font-bold text-ink">{it.name}</span>
                  <span className="block text-xs text-mute">{it.category}</span>
                </span>
              </div>
            </StaggerItem>
          ))}
        </Stagger>
      </div>
    </section>
  );
}
