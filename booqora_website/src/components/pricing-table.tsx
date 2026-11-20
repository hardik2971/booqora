"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Check, Sparkles } from "lucide-react";
import { inr, plans, yearlyMonthly } from "@/content/catalog";
import { PrimaryButton, GhostButton } from "@/components/ui-kit";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";

export function PricingTable() {
  const [yearly, setYearly] = useState(true);
  return (
    <div>
      <div className="flex justify-center">
        <div className="glass relative inline-flex rounded-full p-1.5" role="radiogroup" aria-label="Billing period">
          {[
            { v: false, label: "Monthly" },
            { v: true, label: "Yearly" },
          ].map((o) => (
            <button
              key={o.label}
              type="button"
              role="radio"
              aria-checked={yearly === o.v}
              onClick={() => setYearly(o.v)}
              className={cn("relative z-10 rounded-full px-6 py-2.5 text-sm font-bold transition-colors", yearly === o.v ? "text-ink" : "text-white/80 hover:text-white")}
            >
              {yearly === o.v && <motion.span layoutId="billing-pill" className="absolute inset-0 -z-10 rounded-full bg-white shadow" transition={{ type: "spring", stiffness: 400, damping: 32 }} />}
              {o.label}
              {o.v && <span className="ml-2 rounded-full bg-mint/90 px-2 py-0.5 text-[0.7rem] text-ink">Save 20%</span>}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-14 grid items-stretch gap-6 lg:grid-cols-3">
        {plans.map((p, i) => {
          const price = yearly ? yearlyMonthly(p.monthly) : p.monthly;
          return (
            <motion.div
              key={p.key}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.15 + i * 0.1, duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
              className={cn(
                "relative flex flex-col rounded-[2rem] p-8",
                p.popular ? "bg-white text-ink shadow-[0_40px_90px_-30px_rgba(123,63,242,0.9)] ring-2 ring-lavender lg:-my-4 lg:py-12" : "glass text-white",
              )}
            >
              {p.popular && (
                <span className="absolute -top-4 left-1/2 inline-flex -translate-x-1/2 items-center gap-1.5 rounded-full bg-gradient-to-r from-violet to-rose px-4 py-1.5 text-xs font-bold tracking-wider text-white uppercase shadow-lg">
                  <Sparkles className="size-3.5" /> Most popular
                </span>
              )}
              <h2 className="text-2xl font-extrabold">{p.name}</h2>
              <p className={cn("mt-2 text-[0.95rem]", p.popular ? "text-ink-soft" : "text-white/65")}>{p.tagline}</p>
              <div className="mt-7 flex items-end gap-1.5">
                <AnimatePresence mode="popLayout" initial={false}>
                  <motion.span
                    key={price}
                    initial={{ y: 20, opacity: 0 }}
                    animate={{ y: 0, opacity: 1 }}
                    exit={{ y: -20, opacity: 0 }}
                    transition={{ duration: 0.3 }}
                    className="font-display text-5xl font-extrabold tracking-tight"
                  >
                    {inr(price)}
                  </motion.span>
                </AnimatePresence>
                <span className={cn("mb-1.5 text-sm", p.popular ? "text-mute" : "text-white/60")}>/ month</span>
              </div>
              <p className={cn("mt-1.5 h-5 text-sm", p.popular ? "text-mute" : "text-white/55")}>
                {yearly ? `${inr(Math.round(p.monthly * 12 * 0.8))} billed yearly` : "Billed monthly"}
              </p>
              <div className="mt-7">
                {p.popular ? (
                  <PrimaryButton href={site.signupUrl} className="w-full">
                    Start free trial
                  </PrimaryButton>
                ) : (
                  <GhostButton href={site.signupUrl} className="w-full" dark>
                    Start free trial
                  </GhostButton>
                )}
              </div>
              <ul className="mt-8 space-y-3.5">
                {p.features.map((f) => (
                  <li key={f} className="flex gap-3 text-[0.97rem]">
                    <span className={cn("mt-0.5 grid size-5 shrink-0 place-items-center rounded-full", p.popular ? "bg-haze text-violet" : "bg-white/15 text-lavender")}>
                      <Check className="size-3.5" />
                    </span>
                    {f}
                  </li>
                ))}
              </ul>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
