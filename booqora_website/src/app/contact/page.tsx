import type { Metadata } from "next";
import { LifeBuoy, LogIn, Mail, Rocket } from "lucide-react";
import { ContactForm } from "@/components/contact-form";
import { Reveal } from "@/components/motion";
import { AuroraHero, Breadcrumbs, JsonLd, breadcrumbLd } from "@/components/sections";
import { Eyebrow } from "@/components/ui-kit";
import { site } from "@/lib/site";

const description = "Contact Booqora about rental management software — demos, pricing, moving from another system or support.";

export const metadata: Metadata = {
  title: "Contact Us",
  description,
  alternates: { canonical: "/contact" },
  openGraph: { title: "Contact Booqora", description, url: "/contact" },
};

export default function ContactPage() {
  const crumbs = [
    { name: "Home", path: "/" },
    { name: "Contact", path: "/contact" },
  ];
  const cards = [
    { icon: Mail, title: "Email us", body: site.email, href: `mailto:${site.email}` },
    { icon: Rocket, title: "Try it yourself", body: `Start a ${site.trialDays}-day free trial`, href: site.signupUrl },
    { icon: LogIn, title: "Already a customer?", body: "Log in to your workspace", href: site.loginUrl },
    { icon: LifeBuoy, title: "In-app help", body: "Ask Bora inside Booqora", href: site.loginUrl },
  ];
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <AuroraHero className="pb-40" bottomFade={false}>
        <div className="container-x relative text-center">
          <Reveal className="flex justify-center">
            <Breadcrumbs items={crumbs} />
          </Reveal>
          <Reveal delay={0.05} className="mt-8">
            <Eyebrow dark>Contact</Eyebrow>
          </Reveal>
          <Reveal delay={0.1}>
            <h1 className="mx-auto mt-6 max-w-3xl text-[2.5rem] leading-[1.04] font-extrabold tracking-[-0.03em] sm:text-6xl">
              Let&apos;s talk about <span className="text-gradient-light">your rentals</span>
            </h1>
          </Reveal>
          <Reveal delay={0.16}>
            <p className="mx-auto mt-6 max-w-xl text-lg leading-8 text-white/75">Questions about features, pricing or moving from another system? Send us a message and we&apos;ll get back to you.</p>
          </Reveal>
        </div>
      </AuroraHero>
      <section className="relative -mt-24 pb-24">
        <div className="container-x grid gap-8 lg:grid-cols-[1.3fr_0.7fr]">
          <Reveal>
            <ContactForm />
          </Reveal>
          <div className="grid content-start gap-4 lg:pt-0">
            {cards.map((c, i) => (
              <Reveal key={c.title} delay={0.1 + i * 0.06}>
                <a href={c.href} className="flex items-center gap-4 rounded-2xl bg-white p-5 ring-1 ring-line card-lift">
                  <span className="grid size-12 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-violet to-indigo text-white shadow-md">
                    <c.icon className="size-5" />
                  </span>
                  <span>
                    <span className="block font-bold text-ink">{c.title}</span>
                    <span className="block text-sm text-ink-soft">{c.body}</span>
                  </span>
                </a>
              </Reveal>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
