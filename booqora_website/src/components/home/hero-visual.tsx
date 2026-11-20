import { BadgeCheck, CalendarCheck2, IndianRupee, PackageCheck } from "lucide-react";
import { Float, TiltIn } from "@/components/motion";
import { BrowserFrame, Chip, PhoneFrame } from "@/components/ui-kit";

export function HeroVisual() {
  return (
    <div className="relative mx-auto mt-16 max-w-6xl px-2 sm:mt-20">
      {/* glow + orbit behind the product */}
      <div className="absolute inset-x-[8%] top-[8%] bottom-[10%] -z-10 rounded-full bg-violet-bright/50 blur-[120px]" aria-hidden />
      <div className="absolute top-1/2 left-1/2 -z-10 aspect-square w-[115%] -translate-x-1/2 -translate-y-1/2 animate-spin-slow rounded-full border border-white/10" aria-hidden>
        <span className="absolute top-[6%] left-[22%] size-2.5 rounded-full bg-lavender shadow-[0_0_14px_#c2a3f9]" />
        <span className="absolute right-[14%] bottom-[18%] size-2 rounded-full bg-rose shadow-[0_0_14px_#f472b6]" />
      </div>

      <TiltIn>
        <BrowserFrame src="/shots/dashboard.webp" alt="Booqora rental dashboard showing revenue, active rentals and today's pickups and returns" priority sizes="(min-width: 1280px) 1100px, 100vw" />
      </TiltIn>

      <Float className="absolute -right-2 -bottom-10 w-[30%] max-w-[250px] sm:right-[-2%] sm:-bottom-14" delay={0.5} distance={10} duration={7}>
        <PhoneFrame src="/shots/m-home.webp" alt="Booqora mobile app home screen" priority />
      </Float>

      {/* floating live-data chips */}
      <Float className="absolute top-[18%] -left-3 hidden sm:block lg:-left-14" delay={0.7} distance={9}>
        <Chip icon={<IndianRupee />} tone="green" label="Payment received" sub="₹3,186 · Razorpay UPI" />
      </Float>
      <Float className="absolute top-[52%] -left-2 hidden md:block lg:-left-20" delay={1.1} distance={11} duration={7.5}>
        <Chip icon={<PackageCheck />} tone="violet" label="Canon EOS R100 Kit" sub="3 available · 16–19 Nov" />
      </Float>
      <Float className="absolute -top-6 right-[18%] hidden md:block" delay={0.9} distance={8} duration={6.5}>
        <Chip icon={<CalendarCheck2 />} tone="blue" label="2 pickups today" sub="Next at 16:01" />
      </Float>
      <Float className="absolute right-[26%] -bottom-8 hidden lg:block" delay={1.4} distance={10}>
        <Chip icon={<BadgeCheck />} tone="pink" label="Returned on time" sub="Order #3 · Priya Nair" />
      </Float>

    </div>
  );
}
