import Link from "next/link";
import { AuroraHero } from "@/components/sections";
import { GhostButton, PrimaryButton } from "@/components/ui-kit";

export default function NotFound() {
  return (
    <AuroraHero className="pb-32" bottomFade={false}>
      <div className="container-x text-center">
        <p className="font-display text-7xl font-extrabold text-gradient-light">404</p>
        <h1 className="mt-4 text-3xl font-extrabold sm:text-4xl">This page has been rented out</h1>
        <p className="mx-auto mt-4 max-w-md text-white/70">We couldn&apos;t find the page you were looking for. It may have moved, or the link may be wrong.</p>
        <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <PrimaryButton href="/">Back to home</PrimaryButton>
          <GhostButton href="/features" dark>
            Explore features
          </GhostButton>
        </div>
        <p className="mt-8 text-sm text-white/55">
          Looking for your workspace? <Link href="https://booqora-platform.web.app/login" className="font-semibold text-lavender underline underline-offset-4">Log in here</Link>.
        </p>
      </div>
    </AuroraHero>
  );
}
