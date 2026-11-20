import type { LucideIcon } from "lucide-react";
import {
  BarChart3,
  Boxes,
  CalendarRange,
  ClipboardList,
  CreditCard,
  FileSignature,
  Globe,
  Plug,
  ScanBarcode,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Users,
} from "lucide-react";

export type Faq = { q: string; a: string };

export type Feature = {
  slug: string;
  /** Overrides the default /features/[slug] route (e.g. /mobile-app). */
  href?: string;
  name: string;
  short: string;
  icon: LucideIcon;
  /** Tailwind gradient stops for the icon tile. */
  tint: string;
  seoTitle: string;
  metaDescription: string;
  keywords: string[];
  eyebrow: string;
  headline: string;
  headlineAccent: string;
  lead: string;
  /** Screenshot in /public/shots (without extension). */
  shot: string;
  highlights: { title: string; body: string }[];
  sections: { title: string; body: string; bullets: string[]; shot?: string }[];
  faqs: Faq[];
  related: string[];
};

export const features: Feature[] = [
  {
    slug: "online-booking",
    name: "Online store & bookings",
    short: "A branded booking website where customers check availability and book 24/7.",
    icon: Globe,
    tint: "from-violet to-indigo",
    seoTitle: "Online Rental Booking Website & Store",
    metaDescription:
      "Give customers a branded rental booking website with live availability, cart, checkout, pickup or delivery and online payments. Booqora's online store turns visitors into confirmed rental orders 24/7.",
    keywords: ["rental booking website", "online rental store", "rental booking system", "equipment rental website"],
    eyebrow: "Online store",
    headline: "Your rental shop,",
    headlineAccent: "open around the clock",
    lead:
      "Publish a beautiful booking page in minutes. Customers pick dates, see what is really available, add items to a cart and check out — and the order lands straight in your Booqora workspace.",
    shot: "storefront",
    highlights: [
      { title: "Live availability", body: "Every product shows what is free for the customer's exact pickup and return time — no double bookings." },
      { title: "Branded design", body: "Your logo, colours and content. It looks like your business, not like a template." },
      { title: "Pickup or delivery", body: "Let customers choose fulfilment, ask for the delivery address up front and charge delivery fees." },
      { title: "Online payments", body: "Take full payment or a deposit at checkout with Razorpay, Stripe or PayPal." },
      { title: "Cross-sell", body: "Recommend related products on product pages to grow the value of every booking." },
      { title: "Search-ready", body: "Control the title, description and preview so your booking page shows up well on Google and social media." },
    ],
    sections: [
      {
        title: "A checkout built for rentals, not retail",
        body:
          "Rental checkout needs dates, quantities, deposits and terms — not just a basket. Booqora's checkout collects exactly what your business needs and nothing more.",
        bullets: [
          "Choose and reorder the checkout fields you collect",
          "Require customers to accept your terms and conditions",
          "Show only products that are available for the chosen dates",
          "Send automatic confirmation emails to you and the customer",
        ],
        shot: "online-store",
      },
      {
        title: "Online orders arrive ready to fulfil",
        body:
          "Every booking request becomes a real order with the customer, items, dates and payment status already filled in. Review it, reserve the stock and you're done.",
        bullets: [
          "Orders sync instantly to the web platform and the mobile app",
          "Stock is held for the booked period as soon as you reserve",
          "Payment status updates automatically when the customer pays",
        ],
        shot: "orders",
      },
      {
        title: "Use it on its own or inside your website",
        body:
          "Share your booking page link on Instagram, WhatsApp and Google Business Profile, or connect it to the website you already have.",
        bullets: [
          "Hosted booking page with its own shareable link",
          "Website integration options for an existing site",
          "Turn the store off any time — visitors see an offline message",
        ],
      },
    ],
    faqs: [
      { q: "Do I need a website to use the Booqora online store?", a: "No. Every workspace gets a hosted booking page with its own link that you can share anywhere. If you already have a website, you can link or integrate the booking page into it." },
      { q: "Can customers pay online when they book?", a: "Yes. Connect Razorpay for UPI, cards, netbanking and wallets in India, or Stripe and PayPal for card payments, and customers can pay during checkout." },
      { q: "How does the store prevent double bookings?", a: "Availability is calculated from your real stock and every reserved and started order, for the exact pickup and return time the customer selects." },
      { q: "Can I offer delivery as well as pickup?", a: "Yes. Choose the default fulfilment method, enable delivery, set the countries you deliver to and how delivery is charged." },
    ],
    related: ["payments", "inventory-management", "order-management"],
  },
  {
    slug: "inventory-management",
    name: "Inventory management",
    short: "Products, bundles, stock items and maintenance — always in sync with your bookings.",
    icon: Boxes,
    tint: "from-[#7b3ff2] to-[#db5fb0]",
    seoTitle: "Rental Inventory Management Software",
    metaDescription:
      "Track every rental product, bundle and serialised stock item. Booqora shows real-time availability, flags shortages, schedules maintenance and supports hourly, daily, weekly and tiered rental pricing.",
    keywords: ["rental inventory management", "rental inventory software", "equipment tracking", "rental availability"],
    eyebrow: "Inventory",
    headline: "Know exactly what's",
    headlineAccent: "in, out and coming back",
    lead:
      "Booqora tracks every product and every unit across all your bookings, so you always know what you can rent out — today, next weekend or next month.",
    shot: "inventory",
    highlights: [
      { title: "Bulk or trackable", body: "Track simple items by quantity, or give valuable gear individual identifiers and serial numbers." },
      { title: "Bundles & kits", body: "Group products that are rented together and offer the kit at a special price." },
      { title: "Collections", body: "Organise your catalogue into collections for your team and your online store." },
      { title: "Flexible pricing", body: "Price by the hour, day or week, use flat fees, or build tiered pricing structures." },
      { title: "Maintenance & repair", body: "Block units for maintenance or repair so they can't be booked while they're out of action." },
      { title: "Shortage alerts", body: "See shortages before they happen when demand for a period exceeds the stock you own." },
    ],
    sections: [
      {
        title: "Real-time availability for any date range",
        body:
          "Availability isn't a single number. Booqora calculates it for the exact period you're looking at, including late returns that are still out with a customer.",
        bullets: [
          "Stock on hand versus units reserved for any period",
          "Late rentals keep holding stock until they're returned",
          "Shortages flagged on orders and in the availability report",
        ],
        shot: "product",
      },
      {
        title: "Pricing that matches how you rent",
        body:
          "A weekly rate that is cheaper than seven daily rates, a weekend price, or a fixed fee for setup — model it once and every order is priced correctly.",
        bullets: [
          "Hourly, daily and weekly rental periods",
          "Tiered pricing structures you can assign to any product",
          "Flat fees, sale items and services alongside rentals",
          "Security deposits per product, tracked separately from payments",
        ],
      },
      {
        title: "Every unit, accounted for",
        body:
          "For trackable products, each stock item gets its own identifier. Scan it, see its history and know exactly which unit went out on which order.",
        bullets: [
          "Automatic identifiers when you add stock",
          "Barcode lookup from the mobile app camera",
          "Temporary and expected stock for growing fleets",
        ],
      },
    ],
    faqs: [
      { q: "What is the difference between bulk and trackable products?", a: "Bulk products are tracked by quantity only — useful for chairs, cables or tableware. Trackable products have individual stock items with their own identifiers — ideal for cameras, bikes or tools where you need to know exactly which unit is where." },
      { q: "Can I put items into maintenance?", a: "Yes. Schedule maintenance or repair downtime for stock so it is excluded from availability for that period." },
      { q: "Does Booqora support bundles?", a: "Yes. Bundles group products that are often rented together, with an optional bundle price override so you can offer kits at a discount." },
      { q: "How are late returns handled?", a: "A rental that is past its return date keeps holding its stock until it is returned, so you never accidentally re-book an item that is still out." },
    ],
    related: ["barcode-scanning", "order-management", "reports"],
  },
  {
    slug: "order-management",
    name: "Orders & bookings",
    short: "Create orders in seconds with automatic pricing, deposits, discounts and taxes.",
    icon: ClipboardList,
    tint: "from-indigo to-[#5b8cff]",
    seoTitle: "Rental Order & Booking Management",
    metaDescription:
      "Create rental orders in seconds with automatic pricing, live availability, deposits, coupons and taxes. Manage every booking from draft to reserved, picked up and returned with Booqora.",
    keywords: ["rental order management", "rental booking software", "rental reservation system", "booking management"],
    eyebrow: "Orders",
    headline: "From reservation to return,",
    headlineAccent: "without the paperwork",
    lead:
      "Every booking follows a clear path — draft, reserved, picked up, returned. Booqora prices it, checks availability, tracks payments and tells you what needs attention.",
    shot: "orders",
    highlights: [
      { title: "Automatic pricing", body: "Rental prices calculate from the period and your pricing structures — no spreadsheets." },
      { title: "Live availability", body: "See available quantities while you add items, for the exact pickup and return time." },
      { title: "Deposits", body: "Hold security deposits separately so they never get mixed up with what's owed." },
      { title: "Coupons & discounts", body: "Apply discount codes or manual discounts; taxes recalculate instantly." },
      { title: "Pickup & return", body: "Check items out and back in with one tap when customers collect and return." },
      { title: "Late & shortage alerts", body: "Late returns and shortages surface on the dashboard before they become problems." },
    ],
    sections: [
      {
        title: "Everything about a booking on one screen",
        body:
          "Customer, dates, items, pricing, payments, documents and notes — the order screen brings it all together so your team never has to hunt for information.",
        bullets: [
          "Draft, reserved, started, returned and archived statuses",
          "Paid and due amounts update as payments are recorded",
          "Generate quotes, contracts, invoices and packing slips from the order",
        ],
        shot: "order",
      },
      {
        title: "A dashboard that tells you what's next",
        body:
          "Start the day knowing exactly which orders are going out, which are coming back and which are late.",
        bullets: [
          "Today's pickups and returns at a glance",
          "Late rentals listed under “Coming back”",
          "Revenue, top products and outstanding balances",
        ],
        shot: "dashboard",
      },
      {
        title: "Built for busy counters",
        body:
          "Create an order for a walk-in customer in seconds on the web or from the mobile app, then hand over the gear and collect payment on the spot.",
        bullets: [
          "Quick-create orders, customers and products",
          "Search orders by number, customer or product",
          "Same data on web and mobile, always in sync",
        ],
      },
    ],
    faqs: [
      { q: "Can I edit an order after it's reserved?", a: "Yes. Change dates, items or quantities and Booqora re-checks availability and recalculates the price." },
      { q: "How are security deposits handled?", a: "Deposits are shown on the order and tracked separately from payments, so they don't reduce the amount due and you always know how much you're holding." },
      { q: "Does Booqora calculate tax?", a: "Yes. Configure your tax rates in settings and taxes are calculated on every order and document." },
      { q: "Can customers' online bookings become orders automatically?", a: "Yes. Bookings from your online store arrive as orders in your workspace with the customer, items, dates and payment status filled in." },
    ],
    related: ["rental-calendar", "payments", "documents"],
  },
  {
    slug: "rental-calendar",
    name: "Rental calendar",
    short: "Agenda and timeline views of every pickup and return.",
    icon: CalendarRange,
    tint: "from-[#5b8cff] to-[#7b3ff2]",
    seoTitle: "Rental Calendar & Scheduling Software",
    metaDescription:
      "See every pickup and return in one rental calendar. Booqora's agenda and timeline views help your team plan the day, prepare orders and never miss a handover.",
    keywords: ["rental calendar", "rental scheduling software", "booking calendar", "equipment scheduling"],
    eyebrow: "Calendar",
    headline: "Never miss",
    headlineAccent: "a pickup again",
    lead:
      "The Booqora calendar turns your bookings into a clear plan. See what's going out and coming back each day, then jump straight into any order.",
    shot: "calendar",
    highlights: [
      { title: "Agenda view", body: "A day-by-day list of pickups and returns your team can work through." },
      { title: "Week at a glance", body: "Spot busy days early and plan staff and preparation accordingly." },
      { title: "Colour-coded status", body: "Instantly tell reserved, started and late orders apart." },
      { title: "One tap to the order", body: "Open any booking straight from the calendar to prepare or check it in." },
      { title: "On your phone", body: "Carry the calendar in your pocket with the Booqora mobile app." },
      { title: "Always current", body: "New orders and online bookings appear the moment they're created." },
    ],
    sections: [
      {
        title: "Plan the day in seconds",
        body:
          "Open the calendar each morning to see exactly which customers are coming, what they're collecting and what needs to be prepared.",
        bullets: [
          "Pickups and returns grouped by day",
          "Customer and item details on every entry",
          "Late returns highlighted so you can follow up",
        ],
        shot: "calendar",
      },
      {
        title: "Fewer surprises, smoother handovers",
        body:
          "Because the calendar is built on the same data as availability, it always reflects reality — including changes made on the counter or online.",
        bullets: [
          "Synced across web and mobile in real time",
          "Works together with shortage and late alerts",
        ],
      },
    ],
    faqs: [
      { q: "Can my whole team see the calendar?", a: "Yes. Everyone in your workspace sees the same live calendar on the web platform and the mobile app." },
      { q: "Does the calendar include online bookings?", a: "Yes. Online store bookings appear in the calendar as soon as they're placed." },
      { q: "Can I sync with Google Calendar?", a: "Google Calendar is available in the Booqora app catalog so you can connect your workspace to it." },
    ],
    related: ["order-management", "inventory-management", "mobile-app"],
  },
  {
    slug: "payments",
    name: "Payments",
    short: "Collect UPI, card and wallet payments with Razorpay, Stripe and PayPal.",
    icon: CreditCard,
    tint: "from-[#16a34a] to-[#0ea5a4]",
    seoTitle: "Rental Payments — Razorpay, Stripe & PayPal",
    metaDescription:
      "Get paid faster for rentals. Collect UPI, cards, netbanking and wallets with Razorpay, send Stripe or PayPal payment links, and record cash and bank payments — paid and due update instantly.",
    keywords: ["rental payments", "razorpay rental software", "payment links", "collect deposits online"],
    eyebrow: "Payments",
    headline: "Get paid",
    headlineAccent: "on the spot",
    lead:
      "Collect payments at the counter, online at checkout or with a payment link — and watch the order update itself the moment the money arrives.",
    shot: "order",
    highlights: [
      { title: "Razorpay", body: "UPI, cards, netbanking and wallets for customers in India — in the app or at checkout." },
      { title: "Stripe", body: "Card payments and secure payment links for international customers." },
      { title: "PayPal", body: "Let customers who prefer PayPal pay with their account." },
      { title: "Payment links", body: "Send a secure link by email or WhatsApp and get paid before pickup." },
      { title: "Cash & bank", body: "Record cash, bank transfer and UPI payments made outside Booqora." },
      { title: "Always reconciled", body: "Paid and due amounts update instantly on the order and in reports." },
    ],
    sections: [
      {
        title: "One place for every way your customers pay",
        body:
          "Whether a customer pays at checkout, from a link or in cash at the counter, every payment lands on the right order with the right status.",
        bullets: [
          "Native Razorpay checkout in the mobile app",
          "Stripe and PayPal payment links opened in a secure browser",
          "Manual payments for cash, bank transfer and UPI",
          "Payment status verified on the server, not the device",
        ],
        shot: "order",
      },
      {
        title: "Deposits handled properly",
        body:
          "Security deposits are tracked separately from rental payments, so your books stay clean and you always know what you owe back.",
        bullets: [
          "Deposits shown on every order",
          "Deposits on reserved and started orders in one report",
        ],
      },
      {
        title: "Secure by design",
        body:
          "Card and UPI details are entered on the payment provider's own secure screens. Booqora never sees or stores them.",
        bullets: [
          "Payment secrets stay on the server",
          "Test mode for trying things before going live",
        ],
      },
    ],
    faqs: [
      { q: "Which payment gateways does Booqora support?", a: "Razorpay (UPI, cards, netbanking, wallets), Stripe (cards and payment links) and PayPal. You can also record cash, bank and UPI payments manually." },
      { q: "Does Booqora charge a fee per transaction?", a: "Booqora doesn't add its own transaction fee. Your payment provider charges its standard processing fees." },
      { q: "Can I send a payment link before pickup?", a: "Yes. Create a Stripe or PayPal payment link from the order and share it by email or WhatsApp." },
      { q: "Is PayPal available for INR?", a: "PayPal payments are processed in USD, so for INR stores Razorpay is the recommended gateway." },
    ],
    related: ["documents", "order-management", "online-booking"],
  },
  {
    slug: "documents",
    name: "Quotes, contracts & invoices",
    short: "Professional PDF documents in your brand, ready to share, print or sign.",
    icon: FileSignature,
    tint: "from-[#db5fb0] to-[#7b3ff2]",
    seoTitle: "Rental Quotes, Contracts & Invoices",
    metaDescription:
      "Create professional rental quotes, contracts, invoices and packing slips from any order. Booqora generates branded PDFs with automatic numbering, signatures and payment tracking.",
    keywords: ["rental invoice software", "rental contract template", "rental quote", "rental agreement"],
    eyebrow: "Documents",
    headline: "Invoices that",
    headlineAccent: "look premium",
    lead:
      "Turn any order into a polished quote, contract, invoice or packing slip in one click — branded, numbered and ready to share.",
    shot: "documents",
    highlights: [
      { title: "Quotes", body: "Send a professional quote before the customer commits." },
      { title: "Contracts", body: "Rental agreements with your terms, ready to be signed." },
      { title: "Invoices", body: "Tax-ready invoices with automatic numbering." },
      { title: "Packing slips", body: "A checklist of every item going out for your warehouse team." },
      { title: "Your branding", body: "Your logo and colours on every document." },
      { title: "Share in one tap", body: "Download, print or share the PDF from the web or the app." },
    ],
    sections: [
      {
        title: "Generated from the order, never retyped",
        body:
          "Documents pull customer details, items, dates, prices, taxes and payments directly from the order, so they're always accurate.",
        bullets: [
          "Automatic document numbering",
          "Payments and amount due shown on invoices",
          "Signatures captured on contracts",
        ],
        shot: "documents",
      },
      {
        title: "Configured once, consistent forever",
        body:
          "Set your company details, terms and footer text in settings and every document follows the same professional layout.",
        bullets: [
          "Document settings for each document type",
          "Email templates for sending documents to customers",
        ],
      },
    ],
    faqs: [
      { q: "Which documents can Booqora create?", a: "Quotes, contracts, invoices and packing slips — all generated from the order." },
      { q: "Can customers sign contracts?", a: "Yes. Contracts support signatures so you have a signed rental agreement for every booking." },
      { q: "Can I print or share documents from my phone?", a: "Yes. The mobile app generates the PDF and opens your phone's share sheet or print preview." },
    ],
    related: ["payments", "order-management", "customer-management"],
  },
  {
    slug: "customer-management",
    name: "Customer management",
    short: "Customer profiles with order history, balances and contact details.",
    icon: Users,
    tint: "from-[#f59e0b] to-[#db5fb0]",
    seoTitle: "Rental Customer Management (CRM)",
    metaDescription:
      "Keep every rental customer's details, order history and outstanding balance in one place. Booqora's customer management helps you serve repeat customers faster and chase payments with confidence.",
    keywords: ["rental crm", "customer management for rentals", "rental customer database"],
    eyebrow: "Customers",
    headline: "Every customer,",
    headlineAccent: "remembered",
    lead:
      "Booqora builds a profile for every customer automatically — what they rented, what they paid and what they still owe.",
    shot: "customers",
    highlights: [
      { title: "Complete history", body: "Every order a customer has placed, newest first." },
      { title: "Balances", body: "See outstanding amounts at a glance and follow up quickly." },
      { title: "Contact details", body: "Phone, email and address ready when you need them." },
      { title: "Custom fields", body: "Store the extra details your business needs, like ID numbers." },
      { title: "Marketing opt-in", body: "Sync customers who opted in to Mailchimp." },
      { title: "Customer reports", body: "Find your best customers and average order value." },
    ],
    sections: [
      {
        title: "Serve repeat customers in seconds",
        body:
          "Search by name, email or phone, open the profile and start a new order with everything pre-filled.",
        bullets: [
          "Start a new order from the customer profile",
          "Online store customers are added automatically",
        ],
        shot: "customers",
      },
      {
        title: "Know who owes you",
        body:
          "Outstanding balances are calculated from orders and payments, so following up is quick and friendly.",
        bullets: ["Balances on every profile", "Customer report with outstanding balances"],
      },
    ],
    faqs: [
      { q: "Are online store customers saved automatically?", a: "Yes. When someone books through your online store, their details are saved as a customer in your workspace." },
      { q: "Can I add my own fields?", a: "Yes. Custom fields let you capture extra information such as ID numbers or company names." },
    ],
    related: ["order-management", "reports", "documents"],
  },
  {
    slug: "reports",
    name: "Reports & analytics",
    short: "Revenue, product performance, availability, customers and coupons.",
    icon: BarChart3,
    tint: "from-[#0ea5a4] to-indigo",
    seoTitle: "Rental Business Reports & Analytics",
    metaDescription:
      "Understand how your rental business performs. Booqora reports cover revenue, orders, product ROI, availability and shortages, customers, coupons and a full activity log.",
    keywords: ["rental reports", "rental analytics", "rental business metrics", "product roi rental"],
    eyebrow: "Reports",
    headline: "Decisions backed by",
    headlineAccent: "real numbers",
    lead:
      "See which products earn their keep, who your best customers are and where stock runs short — without exporting a single spreadsheet.",
    shot: "reports",
    highlights: [
      { title: "Company performance", body: "Revenue, orders, average order value, items rented and deposits held." },
      { title: "Product performance", body: "Times rented, rent duration, revenue and ROI for every product." },
      { title: "Availability", body: "Stock on hand versus units reserved, with shortages flagged." },
      { title: "Product fulfilment", body: "A pick list of every line going out in a period." },
      { title: "Customers", body: "New customers, revenue share and outstanding balances." },
      { title: "Coupons & activity", body: "Coupon redemptions and a complete audit trail of changes." },
    ],
    sections: [
      {
        title: "Know what to buy next",
        body:
          "Product performance shows revenue and ROI for every item, so you can invest in the gear that pays for itself and retire what doesn't.",
        bullets: ["ROI per product", "Utilisation by times rented and duration", "Shortages that signal unmet demand"],
        shot: "reports",
      },
      {
        title: "A full audit trail",
        body:
          "Activity logs record who created, updated or deleted what — searchable and filterable by record type.",
        bullets: ["Every change attributed to a team member", "Filter by record type"],
      },
    ],
    faqs: [
      { q: "Which reports are included?", a: "Company performance, product performance, availability, product fulfilment, customers, coupons and activity logs." },
      { q: "Can I see revenue on my phone?", a: "Yes. The mobile app dashboard shows revenue and key numbers, and the full reports are available on the web platform." },
    ],
    related: ["inventory-management", "customer-management", "payments"],
  },
  {
    slug: "barcode-scanning",
    name: "Barcode scanning",
    short: "Scan items with your phone camera to find any product instantly.",
    icon: ScanBarcode,
    tint: "from-ink to-violet",
    seoTitle: "Rental Barcode Scanning with Your Phone",
    metaDescription:
      "Find any rental item instantly by scanning its barcode with the Booqora mobile app. No extra hardware — just your phone camera.",
    keywords: ["rental barcode scanning", "inventory barcode app", "equipment barcode tracking"],
    eyebrow: "Barcodes",
    headline: "Point, scan,",
    headlineAccent: "found it",
    lead:
      "Every stock item can carry a barcode. Scan it with the Booqora app to jump straight to the product — no scanner hardware required.",
    shot: "product",
    highlights: [
      { title: "Phone camera", body: "Use the camera you already carry — no extra hardware to buy." },
      { title: "Type to find", body: "No label handy? Type the code and Booqora finds the item." },
      { title: "Straight to the product", body: "See availability, pricing and stock the moment you scan." },
      { title: "Works with any label", body: "Use the barcodes already on your gear or print your own." },
    ],
    sections: [
      {
        title: "Faster check-in and check-out",
        body:
          "On a busy day, scanning is quicker and more accurate than searching. Scan the item and you're on the right product instantly.",
        bullets: ["Camera scanning in the mobile app", "Manual code lookup as a fallback"],
      },
    ],
    faqs: [
      { q: "Do I need a barcode scanner?", a: "No. The Booqora mobile app uses your phone's camera to scan barcodes." },
      { q: "Can I use existing barcodes?", a: "Yes. Store the code on the product or stock item and scanning will find it." },
    ],
    related: ["inventory-management", "mobile-app", "order-management"],
  },
  {
    slug: "mobile-app",
    href: "/mobile-app",
    name: "Mobile app",
    short: "Run your rental business from your phone on Android and iOS.",
    icon: Smartphone,
    tint: "from-violet to-[#db5fb0]",
    seoTitle: "Rental Management Mobile App",
    metaDescription: "The Booqora mobile app puts bookings, inventory, payments and documents in your pocket.",
    keywords: ["rental app", "rental management app"],
    eyebrow: "Mobile",
    headline: "Your rental business,",
    headlineAccent: "in your pocket",
    lead: "",
    shot: "dashboard",
    highlights: [],
    sections: [],
    faqs: [],
    related: [],
  },
  {
    slug: "integrations",
    href: "/integrations",
    name: "Integrations",
    short: "Connect analytics, marketing, accounting, payments and more.",
    icon: Plug,
    tint: "from-[#5b8cff] to-[#0ea5a4]",
    seoTitle: "Integrations",
    metaDescription: "Connect Booqora with the tools you already use.",
    keywords: [],
    eyebrow: "Apps",
    headline: "",
    headlineAccent: "",
    lead: "",
    shot: "apps",
    highlights: [],
    sections: [],
    faqs: [],
    related: [],
  },
  {
    slug: "team-and-security",
    name: "Team, locations & security",
    short: "Invite your team, run multiple locations and protect your workspace.",
    icon: ShieldCheck,
    tint: "from-indigo to-ink",
    seoTitle: "Team Management, Multiple Locations & Security",
    metaDescription:
      "Invite your team, manage multiple rental locations, configure taxes, translations and email templates, and protect your workspace with Booqora's security settings.",
    keywords: ["rental software for teams", "multi location rental software", "rental business settings"],
    eyebrow: "Workspace",
    headline: "Built for teams that",
    headlineAccent: "grow together",
    lead:
      "Bring your whole team into one workspace, set up every location and configure Booqora to work exactly the way your business does.",
    shot: "settings",
    highlights: [
      { title: "Team members", body: "Invite colleagues so everyone works from the same live data." },
      { title: "Multiple locations", body: "Run several pickup points or branches from one workspace." },
      { title: "Taxes", body: "Configure the tax rates that apply to your rentals." },
      { title: "Translations", body: "Adapt customer-facing text to your customers' language." },
      { title: "Email templates", body: "Control the emails customers receive and the sending address." },
      { title: "Security settings", body: "Two-factor authentication, sign-in confirmation, IP restrictions and SSO options." },
    ],
    sections: [
      {
        title: "Settings for how your business really works",
        body:
          "General, rental, pricing, documents, emails, taxes, payments, custom fields, locations, team, translations and security — all in one organised settings area.",
        bullets: ["Rental periods and pricing defaults", "Custom fields for orders, customers and products", "Payment gateway configuration"],
        shot: "settings",
      },
    ],
    faqs: [
      { q: "How many team members can I add?", a: "Starter includes up to 3 team members, Pro up to 10 and Business up to 25." },
      { q: "Can I manage more than one location?", a: "Yes. Multiple locations are included from the Pro plan." },
    ],
    related: ["reports", "order-management", "inventory-management"],
  },
  {
    slug: "bora-assistant",
    name: "Bora assistant",
    short: "Ask Bora quick questions about your business and how to use Booqora.",
    icon: Sparkles,
    tint: "from-[#c2a3f9] to-violet",
    seoTitle: "Bora — Your Built-in Rental Assistant",
    metaDescription:
      "Bora is Booqora's built-in assistant. Ask about today's pickups, revenue or how to set something up and get a quick answer with a link to the right screen.",
    keywords: ["rental software assistant", "booqora bora"],
    eyebrow: "Assistant",
    headline: "Meet Bora,",
    headlineAccent: "your rental sidekick",
    lead:
      "Bora answers quick questions about your workspace and guides you to the right place — so new team members get up to speed faster.",
    shot: "assistant",
    highlights: [
      { title: "Quick answers", body: "Ask about today's pickups, returns, revenue and more." },
      { title: "How-to help", body: "Ask how to set something up and Bora points you to the right screen." },
      { title: "Always available", body: "Built into the web platform and the mobile app." },
    ],
    sections: [
      {
        title: "Help without leaving the app",
        body: "Instead of searching documentation, ask Bora. It understands common rental questions and links you straight to the answer.",
        bullets: ["Setup and how-to questions", "Questions about your own workspace data"],
        shot: "assistant",
      },
    ],
    faqs: [{ q: "Is Bora included in every plan?", a: "Yes. Bora is available in every Booqora workspace." }],
    related: ["reports", "order-management", "team-and-security"],
  },
];

export const featureHref = (f: Feature) => f.href ?? `/features/${f.slug}`;
export const getFeature = (slug: string) => features.find((f) => f.slug === slug);
/** Features that have their own /features/[slug] page. */
export const featurePages = features.filter((f) => !f.href);
