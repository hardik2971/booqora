import type { Faq } from "./features";

export type Integration = { id: string; name: string; category: string; short: string; pricing: string; beta?: boolean; color: string; builtIn?: boolean };

/** Mirrors the app catalog inside the Booqora platform. */
export const integrations: Integration[] = [
  { id: "razorpay", name: "Razorpay", category: "Payments", short: "Accept UPI, cards and netbanking in India.", pricing: "Processing fees", color: "#0C2451", builtIn: true },
  { id: "stripe", name: "Stripe", category: "Payments", short: "Accept card payments and deposits worldwide.", pricing: "Processing fees", color: "#635BFF", builtIn: true },
  { id: "paypal", name: "PayPal", category: "Payments", short: "Let customers pay with their PayPal account.", pricing: "Processing fees", color: "#003087", builtIn: true },
  { id: "google-analytics", name: "Google Analytics", category: "Analytics", short: "Track visitors and conversions on your online store.", pricing: "Free", color: "#E37400" },
  { id: "meta-pixel", name: "Meta Pixel", category: "Marketing", short: "Measure ad performance on Facebook and Instagram.", pricing: "Free", color: "#0866FF" },
  { id: "mailchimp", name: "Mailchimp", category: "Marketing", short: "Sync customers who opted in to marketing.", pricing: "Free", color: "#B8A000" },
  { id: "whatsapp-business", name: "WhatsApp Business", category: "Communication", short: "Send order updates to customers on WhatsApp.", pricing: "Free", beta: true, color: "#25D366" },
  { id: "slack", name: "Slack", category: "Communication", short: "Get notified about new orders in Slack.", pricing: "Free", color: "#4A154B" },
  { id: "quickbooks", name: "QuickBooks", category: "Accounting", short: "Sync invoices and payments to QuickBooks Online.", pricing: "Free", color: "#2CA01C" },
  { id: "xero", name: "Xero", category: "Accounting", short: "Send invoices and payments to Xero.", pricing: "Free", color: "#13B5EA" },
  { id: "tally", name: "Tally", category: "Accounting", short: "Export vouchers for Tally Prime.", pricing: "Free", color: "#1F3A93" },
  { id: "shiprocket", name: "Shiprocket", category: "Fulfilment", short: "Ship delivery orders with Indian couriers.", pricing: "Processing fees", color: "#7A3EF0" },
  { id: "google-calendar", name: "Google Calendar", category: "Productivity", short: "See pickups and returns in Google Calendar.", pricing: "Free", color: "#4285F4" },
  { id: "zapier", name: "Zapier", category: "Productivity", short: "Connect Booqora to thousands of apps.", pricing: "Free", beta: true, color: "#FF4F00" },
  { id: "weglot", name: "Weglot", category: "Website", short: "Translate your online store into other languages.", pricing: "Free", color: "#3B8AFF" },
  { id: "tawk-to", name: "Tawk.to chat", category: "Website", short: "Add live chat to your online store.", pricing: "Free", color: "#03A84E" },
];

export type Plan = { key: string; name: string; tagline: string; monthly: number; seats: number; features: string[]; popular?: boolean };

/** Mirrors the plans in the platform's billing settings. Yearly billing saves 20%. */
export const plans: Plan[] = [
  {
    key: "starter",
    name: "Starter",
    tagline: "For new rental shops getting organised",
    monthly: 1499,
    seats: 3,
    features: ["Up to 3 team members", "Orders, inventory and customers", "Invoices, quotes and contracts", "Online store with your branding", "Mobile app for Android & iOS", "Email support"],
  },
  {
    key: "pro",
    name: "Pro",
    tagline: "For growing businesses taking bookings online",
    monthly: 3999,
    seats: 10,
    popular: true,
    features: ["Up to 10 team members", "Everything in Starter", "Pricing structures and custom fields", "Multiple locations", "Reports and app integrations", "Priority support"],
  },
  {
    key: "business",
    name: "Business",
    tagline: "For multi-location operations at scale",
    monthly: 8999,
    seats: 25,
    features: ["Up to 25 team members", "Everything in Pro", "Security controls (2FA, IP allow-lists, SSO)", "Advanced permissions", "Dedicated onboarding manager"],
  },
];

export const yearlyMonthly = (monthly: number) => Math.round((monthly * 12 * 0.8) / 12);

export const inr = (n: number) => "₹" + n.toLocaleString("en-IN");

export const pricingFaqs: Faq[] = [
  { q: "Is there a free trial?", a: "Yes. Every new workspace starts with a 14-day free trial with full access. No credit card is required to start." },
  { q: "How much do I save with yearly billing?", a: "Yearly billing saves 20% compared with paying monthly." },
  { q: "Can I change plans later?", a: "Yes. Upgrade or downgrade at any time from Settings → Billing inside Booqora." },
  { q: "Does Booqora take a cut of my payments?", a: "No. Booqora doesn't add a transaction fee. Payment providers such as Razorpay, Stripe and PayPal charge their standard processing fees." },
  { q: "Is the mobile app included?", a: "Yes. The Booqora app for Android and iOS is included in every plan and uses the same account and data as the web platform." },
];

export const homeFaqs: Faq[] = [
  { q: "What is Booqora?", a: "Booqora is rental management software for businesses that rent out equipment, gear or furniture. It brings online bookings, inventory and availability, orders, payments, documents, customers and reports together in one platform, on the web and on your phone." },
  { q: "Who is Booqora for?", a: "Rental businesses of every size — camera and AV rental houses, party and event rental companies, bike and scooter rentals, tool hire, outdoor gear and furniture rental." },
  { q: "Can my customers book online?", a: "Yes. Every workspace includes a branded online store where customers see live availability, choose pickup or delivery, and pay online." },
  { q: "Which payment methods are supported?", a: "Razorpay for UPI, cards, netbanking and wallets; Stripe and PayPal for card payments and payment links; plus manual cash, bank and UPI payments." },
  { q: "Is there a mobile app?", a: "Yes. The Booqora app for Android and iOS gives you bookings, inventory, payments, barcode scanning and documents on your phone, synced in real time with the web platform." },
  { q: "How do I get started?", a: "Create a free account, name your workspace and add your first products. The 14-day free trial needs no credit card." },
];
