"use client";

import { useState } from "react";
import { Send } from "lucide-react";
import { site } from "@/lib/site";

const topics = ["A demo of Booqora", "Pricing and plans", "Moving from another system", "Technical support", "Something else"];

/** No backend: composes the message in the visitor's own email app. */
export function ContactForm() {
  const [sent, setSent] = useState(false);
  const onSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const d = new FormData(e.currentTarget);
    const subject = `${d.get("topic")} — ${d.get("business") || d.get("name")}`;
    const body = [`Name: ${d.get("name")}`, `Email: ${d.get("email")}`, `Phone: ${d.get("phone") || "-"}`, `Business: ${d.get("business") || "-"}`, "", String(d.get("message") ?? "")].join("\n");
    window.location.href = `mailto:${site.email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    setSent(true);
  };
  const field = "mt-2 block w-full rounded-xl bg-white px-4 py-3 text-ink ring-1 ring-line outline-none transition placeholder:text-mute focus:ring-2 focus:ring-violet";
  return (
    <form onSubmit={onSubmit} className="rounded-[2rem] bg-white p-7 shadow-[0_40px_90px_-40px_rgba(28,9,56,0.45)] ring-1 ring-line sm:p-9">
      <div className="grid gap-5 sm:grid-cols-2">
        <label className="text-sm font-semibold text-ink">
          Your name
          <input name="name" required autoComplete="name" className={field} placeholder="Priya Nair" />
        </label>
        <label className="text-sm font-semibold text-ink">
          Email
          <input name="email" type="email" required autoComplete="email" className={field} placeholder="you@business.com" />
        </label>
        <label className="text-sm font-semibold text-ink">
          Phone <span className="font-normal text-mute">(optional)</span>
          <input name="phone" type="tel" autoComplete="tel" className={field} placeholder="+91" />
        </label>
        <label className="text-sm font-semibold text-ink">
          Business name <span className="font-normal text-mute">(optional)</span>
          <input name="business" autoComplete="organization" className={field} placeholder="Your rental business" />
        </label>
        <label className="text-sm font-semibold text-ink sm:col-span-2">
          What can we help with?
          <select name="topic" className={field} defaultValue={topics[0]}>
            {topics.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </label>
        <label className="text-sm font-semibold text-ink sm:col-span-2">
          Message
          <textarea name="message" required rows={5} className={field} placeholder="Tell us about what you rent and how you work today." />
        </label>
      </div>
      <button type="submit" className="btn-shine mt-7 inline-flex h-12 w-full items-center justify-center gap-2 rounded-full font-semibold text-white shadow-[0_14px_30px_-12px_rgba(100,49,221,0.75)] transition hover:-translate-y-0.5">
        Send message <Send className="size-4" />
      </button>
      <p className="mt-4 text-center text-sm text-mute" aria-live="polite">
        {sent ? "Your email app should now be open with your message ready to send." : "This opens your email app with your message ready to send."}
      </p>
    </form>
  );
}
