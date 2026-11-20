export const PLATFORM_URL = "https://booqora-platform.web.app";

export const site = {
  name: "Booqora",
  legalName: "Booqora",
  /** Public URL of this website. Set NEXT_PUBLIC_SITE_URL once the custom domain is live. */
  url: (process.env.NEXT_PUBLIC_SITE_URL ?? "https://booqora-infidec.web.app").replace(/\/$/, ""),
  tagline: "Rental software, beautifully simple",
  description:
    "Booqora is rental management software for rental businesses. Take online bookings, track inventory and availability, collect payments and send quotes, contracts and invoices — on the web and on your phone.",
  email: "support@booqora.app",
  loginUrl: `${PLATFORM_URL}/login`,
  signupUrl: `${PLATFORM_URL}/signup`,
  privacyUrl: `${PLATFORM_URL}/privacy`,
  trialDays: 14,
  currency: "INR",
} as const;

export function absoluteUrl(path = "/") {
  return `${site.url}${path === "/" ? "" : path}`;
}
