import type { Metadata } from "next";
import { CalendarDays, Check, ClipboardList, CreditCard, FileText, Home, Package, RefreshCw, ScanBarcode } from "lucide-react";
import { Float, Reveal, Stagger, StaggerItem } from "@/components/motion";
import { AuroraHero, Breadcrumbs, CtaBand, FaqSection, JsonLd, breadcrumbLd } from "@/components/sections";
import { Eyebrow, GhostButton, PhoneFrame, PrimaryButton, SectionHeading } from "@/components/ui-kit";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";

const description =
  "The Booqora rental management app for Android and iOS. Create orders, check availability, scan barcodes, collect Razorpay payments and share invoices from your phone — synced in real time with the web platform.";

export const metadata: Metadata = {
  title: "Rental Management App for Android & iOS",
  description,
  alternates: { canonical: "/mobile-app" },
  openGraph: { title: "Booqora Mobile App — Rental Management on Your Phone", description, url: "/mobile-app" },
};

const screens = [
  { icon: Home, title: "Home dashboard", body: "Revenue, active rentals and today's pickups and returns the moment you open the app.", shot: "m-home" },
  { icon: ClipboardList, title: "Orders on the go", body: "Search, filter and open any order. Reserve, pick up and return with a tap.", shot: "m-orders" },
  { icon: CalendarDays, title: "Calendar agenda", body: "A clear day-by-day agenda of everything going out and coming back.", shot: "m-calendar" },
  { icon: Package, title: "Inventory in your pocket", body: "Products, stock and live availability — including late rentals.", shot: "m-inventory" },
  { icon: CreditCard, title: "Collect payments", body: "Native Razorpay checkout for UPI and cards, or send a Stripe payment link.", shot: "m-payment" },
  { icon: FileText, title: "Invoices & documents", body: "Generate branded PDFs and share or print them from your phone.", shot: "m-invoice" },
];

const faqs = [
  { q: "Is the mobile app included in my plan?", a: "Yes. The Booqora app is included in every plan at no extra cost." },
  { q: "Does the app use the same data as the web platform?", a: "Yes. The app and the web platform share the same account and workspace, and changes sync in real time." },
  { q: "Which phones are supported?", a: "Booqora is built for Android and iOS. Android 6.0 and newer is supported." },
  { q: "Can I scan barcodes without a scanner?", a: "Yes. The app uses your phone camera to scan barcodes, and you can type a code if a label is damaged." },
];

export default function MobileAppPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Mobile app", path: "/mobile-app" },
  ];
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-24">
        <div className="container-x grid items-center gap-16 lg:grid-cols-2">
          <div>
            <Reveal>
              <Breadcrumbs items={crumbs} />
            </Reveal>
            <Reveal delay={0.05} className="mt-8">
              <Eyebrow dark>Android & iOS</Eyebrow>
            </Reveal>
            <Reveal delay={0.1}>
              <h1 className="mt-6 text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
                Your rental business, <span className="text-gradient-light">in your pocket</span>
              </h1>
            </Reveal>
            <Reveal delay={0.16}>
              <p className="mt-6 max-w-xl text-lg leading-8 text-white/75">
                Take bookings at the counter, check availability in the warehouse and collect payment at the door. The Booqora app brings the whole platform to your phone.
              </p>
            </Reveal>
            <Reveal delay={0.22} className="mt-9 flex flex-col gap-3 sm:flex-row">
              <PrimaryButton href={site.signupUrl} size="lg">
                Create your free account
              </PrimaryButton>
              <GhostButton href={site.loginUrl} size="lg" dark>
                Log in on the web
              </GhostButton>
            </Reveal>
            <Reveal delay={0.28}>
              <p className="mt-5 text-sm text-white/55">Coming soon to Google Play and the App Store.</p>
            </Reveal>
          </div>
          <div className="relative mx-auto flex h-[36rem] w-full max-w-lg items-center justify-center">
            <div className="absolute inset-[12%] rounded-full bg-violet-bright/50 blur-[90px]" aria-hidden />
            <div className="absolute inset-[2%] animate-spin-slow rounded-full border border-dashed border-lavender/25" aria-hidden />
            <Float className="absolute left-[2%] w-[38%]" delay={0.3} rotate={-10}>
              <PhoneFrame src="/shots/m-calendar.webp" alt="Booqora mobile calendar agenda" />
            </Float>
            <Float className="absolute right-[2%] w-[38%]" delay={0.6} rotate={10}>
              <PhoneFrame src="/shots/m-inventory.webp" alt="Booqora mobile inventory" />
            </Float>
            <Float className="relative z-10 w-[46%]" delay={0.1} distance={14}>
              <PhoneFrame src="/shots/m-home.webp" alt="Booqora mobile home dashboard" priority />
            </Float>
          </div>
        </div>
      </AuroraHero>

      <section className="py-24" aria-labelledby="screens-title">
        <div className="container-x">
          <Reveal>
            <SectionHeading eyebrow="Inside the app" title="Everything you need," accent="nothing you don't" lead="Designed for one-handed use on a busy day, with the same modules as the web platform." />
          </Reveal>
          <div className="mt-16 space-y-24">
            {screens.map((s, i) => (
              <div key={s.title} className="grid items-center gap-10 md:grid-cols-2 md:gap-20">
                <Reveal className={cn(i % 2 === 1 && "md:order-2")}>
                  <span className="grid size-14 place-items-center rounded-2xl bg-gradient-to-br from-violet to-indigo text-white shadow-lg">
                    <s.icon className="size-7" />
                  </span>
                  <h2 className="mt-6 text-3xl font-extrabold text-ink sm:text-4xl">{s.title}</h2>
                  <p className="mt-4 max-w-md text-lg leading-8 text-ink-soft">{s.body}</p>
                </Reveal>
                <div className={cn("relative mx-auto w-full max-w-[17rem]", i % 2 === 1 && "md:order-1")}>
                  <div className="absolute -inset-10 -z-10 rounded-full bg-gradient-to-br from-lavender/70 via-haze to-[#fde7f3] blur-2xl" aria-hidden />
                  <Float distance={10} duration={7 + (i % 3)} rotate={i % 2 ? -4 : 4}>
                    <PhoneFrame src={`/shots/${s.shot}.webp`} alt={`${s.title} in the Booqora mobile app`} />
                  </Float>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="bg-mist py-24" aria-labelledby="more-title">
        <div className="container-x">
          <Reveal>
            <SectionHeading eyebrow="Built for the floor" title="Small details that" accent="save hours" />
          </Reveal>
          <Stagger className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
            {[
              { icon: ScanBarcode, title: "Scan with your camera", body: "Find any item by its barcode — no scanner hardware." },
              { icon: RefreshCw, title: "Real-time sync", body: "Everything you change appears on the web instantly." },
              { icon: CreditCard, title: "Server-verified payments", body: "Payment status is confirmed securely on the server." },
              { icon: Check, title: "Same login", body: "Use the account you already have on the web platform." },
            ].map((x) => (
              <StaggerItem key={x.title}>
                <div className="h-full rounded-[1.75rem] bg-white p-7 ring-1 ring-line card-lift">
                  <span className="grid size-12 place-items-center rounded-2xl bg-haze text-violet">
                    <x.icon className="size-6" />
                  </span>
                  <h3 className="mt-5 text-lg font-extrabold text-ink">{x.title}</h3>
                  <p className="mt-2 text-ink-soft">{x.body}</p>
                </div>
              </StaggerItem>
            ))}
          </Stagger>
        </div>
      </section>

      <FaqSection faqs={faqs} title="Mobile app FAQ" />
      <CtaBand />
    </>
  );
}
