import type { Metadata, Viewport } from "next";
import { Inter, Plus_Jakarta_Sans } from "next/font/google";
import "./globals.css";
import { SiteHeader } from "@/components/site-header";
import { JsonLd, SiteFooter } from "@/components/sections";
import { plans } from "@/content/catalog";
import { absoluteUrl, site } from "@/lib/site";

const jakarta = Plus_Jakarta_Sans({ variable: "--font-jakarta", subsets: ["latin"], weight: ["500", "600", "700", "800"], display: "swap" });
const inter = Inter({ variable: "--font-inter", subsets: ["latin"], display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: "Booqora — Rental Management Software for Rental Businesses",
    template: "%s | Booqora",
  },
  description: site.description,
  applicationName: site.name,
  keywords: [
    "rental software",
    "rental management software",
    "equipment rental software",
    "rental booking system",
    "rental inventory management",
    "online rental store",
    "rental software India",
  ],
  authors: [{ name: site.name }],
  creator: site.name,
  publisher: site.name,
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    siteName: site.name,
    locale: "en_IN",
    url: "/",
    title: "Booqora — Rental software, beautifully simple",
    description: site.description,
    images: [{ url: "/og.png", width: 1200, height: 630, alt: "Booqora rental management software" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Booqora — Rental software, beautifully simple",
    description: site.description,
    images: ["/og.png"],
  },
  robots: { index: true, follow: true, googleBot: { index: true, follow: true, "max-image-preview": "large", "max-snippet": -1 } },
  category: "business",
};

export const viewport: Viewport = {
  themeColor: "#1a0638",
  width: "device-width",
  initialScale: 1,
};

const orgLd = [
  {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: site.name,
    url: site.url,
    logo: absoluteUrl("/logo-mark.png"),
    email: site.email,
  },
  {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: site.name,
    url: site.url,
  },
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: site.name,
    applicationCategory: "BusinessApplication",
    operatingSystem: "Web, Android, iOS",
    description: site.description,
    url: site.url,
    offers: plans.map((p) => ({
      "@type": "Offer",
      name: `${p.name} plan`,
      price: p.monthly,
      priceCurrency: site.currency,
      url: absoluteUrl("/pricing"),
    })),
  },
];

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${jakarta.variable} ${inter.variable} h-full`}>
      <body className="flex min-h-full flex-col overflow-x-clip">
        <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-[60] focus:rounded-full focus:bg-white focus:px-4 focus:py-2 focus:text-ink">
          Skip to content
        </a>
        <JsonLd data={orgLd} />
        <SiteHeader />
        <main id="main" className="flex-1">
          {children}
        </main>
        <SiteFooter />
      </body>
    </html>
  );
}
