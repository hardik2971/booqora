import type { Faq } from "./features";

export type ItemArt = "camera" | "speaker" | "balloons" | "bike" | "scooter" | "drill" | "ladder" | "tent" | "kayak" | "chair" | "lamp" | "projector" | "skis" | "sofa";

export type Industry = {
  slug: string;
  name: string;
  short: string;
  art: ItemArt[];
  /** Photo in /public/industries (Unsplash License). */
  photoAlt: string;
  seoTitle: string;
  metaDescription: string;
  keywords: string[];
  headline: string;
  headlineAccent: string;
  lead: string;
  examples: string[];
  challenges: { title: string; body: string }[];
  howItHelps: { title: string; body: string; feature: string }[];
  faqs: Faq[];
};

export const industries: Industry[] = [
  {
    slug: "camera-av-rental",
    photoAlt: "Professional cameras and lenses laid out ready for rental",
    name: "Camera & AV rental",
    short: "Cameras, lenses, lighting, audio and production gear.",
    art: ["camera", "projector", "lamp"],
    seoTitle: "Camera & AV Rental Software",
    metaDescription:
      "Rental software for camera, lens, lighting and AV rental houses. Track every serialised unit, build kits, take online bookings, collect deposits and send contracts with Booqora.",
    keywords: ["camera rental software", "av rental software", "equipment rental software for production", "lens rental management"],
    headline: "Rental software for",
    headlineAccent: "camera & AV houses",
    lead:
      "High-value gear, demanding clients and tight shoot schedules. Booqora tracks every body, lens and light by serial number, prices kits automatically and makes sure nothing goes out twice.",
    examples: ["Camera bodies & lenses", "Gimbals & stabilisers", "Lighting kits", "Wireless audio", "Projectors & screens", "Production packages"],
    challenges: [
      { title: "Expensive, serialised gear", body: "You need to know exactly which body or lens went out with which client — and when it's due back." },
      { title: "Kits that change per shoot", body: "Clients rent combinations of gear, often at the last minute, and expect a quote fast." },
      { title: "Deposits and damage", body: "High-value rentals need deposits and a signed agreement before anything leaves the shelf." },
    ],
    howItHelps: [
      { title: "Trackable stock items", body: "Give every body, lens and light its own identifier and see its full history.", feature: "inventory-management" },
      { title: "Bundles for production kits", body: "Package a camera, lenses, batteries and media as one kit with a bundle price.", feature: "inventory-management" },
      { title: "Quotes and signed contracts", body: "Send a branded quote in minutes and capture a signature on the rental agreement.", feature: "documents" },
      { title: "Deposits tracked separately", body: "Hold security deposits on the order without mixing them with rental payments.", feature: "payments" },
    ],
    faqs: [
      { q: "Can I track individual serial numbers?", a: "Yes. Make a product trackable and each stock item gets its own identifier, so you always know which unit is on which order." },
      { q: "Can clients book gear online?", a: "Yes. Your Booqora online store shows live availability for the client's shoot dates and turns their request into an order." },
    ],
  },
  {
    slug: "party-event-rental",
    photoAlt: "Wedding reception with round tables, chairs and floral centrepieces",
    name: "Party & event rental",
    short: "Tents, furniture, decor, tableware and sound for events.",
    art: ["balloons", "tent", "speaker"],
    seoTitle: "Party & Event Rental Software",
    metaDescription:
      "Event rental software for tents, furniture, decor, tableware and sound. Manage bulk inventory, delivery, deposits and invoices for every wedding, party and corporate event with Booqora.",
    keywords: ["party rental software", "event rental software", "tent rental software", "wedding rental management"],
    headline: "Rental software for",
    headlineAccent: "parties & events",
    lead:
      "Hundreds of chairs, dozens of tables and a weekend full of events. Booqora keeps bulk inventory, deliveries and payments under control so every event goes up on time.",
    examples: ["Tents & canopies", "Tables & chairs", "Decor & lighting", "Tableware & linen", "Sound systems", "Stages & dance floors"],
    challenges: [
      { title: "Large quantities", body: "Counting hundreds of chairs and plates across overlapping weekends by hand leads to costly shortages." },
      { title: "Delivery and setup", body: "Most event orders are delivered, set up and collected — and the address matters for pricing." },
      { title: "Peak-season pressure", body: "Wedding and festival seasons bring a flood of enquiries that need quick, accurate quotes." },
    ],
    howItHelps: [
      { title: "Bulk inventory with shortage alerts", body: "Track quantities and see shortages for any date before you confirm an event.", feature: "inventory-management" },
      { title: "Delivery built into checkout", body: "Customers choose delivery, enter the address and see delivery charges up front.", feature: "online-booking" },
      { title: "Quotes for every enquiry", body: "Turn an enquiry into a professional quote and convert it to an order when the client says yes.", feature: "documents" },
      { title: "Packing slips for the crew", body: "Give your team a clear list of everything that needs to be loaded for each event.", feature: "documents" },
    ],
    faqs: [
      { q: "Can Booqora handle items rented in large quantities?", a: "Yes. Bulk products are tracked by quantity, and availability accounts for every overlapping order." },
      { q: "Can I charge for delivery?", a: "Yes. Enable delivery in your online store settings and configure how delivery is charged." },
    ],
  },
  {
    slug: "bike-scooter-rental",
    photoAlt: "A row of rental bicycles lined up at a docking station",
    name: "Bike & scooter rental",
    short: "Bicycles, e-bikes, scooters and mobility rentals.",
    art: ["bike", "scooter"],
    seoTitle: "Bike & Scooter Rental Software",
    metaDescription:
      "Bike, e-bike and scooter rental software with hourly and daily pricing, online bookings, deposits and fast check-in from your phone. Run your rental fleet with Booqora.",
    keywords: ["bike rental software", "scooter rental software", "e-bike rental booking system", "bicycle rental management"],
    headline: "Rental software for",
    headlineAccent: "bikes & scooters",
    lead:
      "Tourists booking by the hour, locals renting for the week and a fleet that needs regular servicing. Booqora handles hourly pricing, online bookings and maintenance in one place.",
    examples: ["City & road bikes", "E-bikes", "Scooters & mopeds", "Kids' bikes", "Helmets & accessories", "Guided tour packages"],
    challenges: [
      { title: "Short, frequent rentals", body: "Hourly and half-day rentals mean lots of handovers — every one needs to be quick." },
      { title: "Fleet maintenance", body: "Bikes need regular servicing, and a bike in the workshop must not be booked." },
      { title: "Walk-ins and online bookings", body: "Customers turn up at the counter and book online at the same time." },
    ],
    howItHelps: [
      { title: "Hourly and tiered pricing", body: "Price by the hour, day or week and reward longer rentals automatically.", feature: "inventory-management" },
      { title: "Maintenance downtime", body: "Block a bike for servicing so it disappears from availability until it's ready.", feature: "inventory-management" },
      { title: "Counter orders from your phone", body: "Create a walk-in order and take payment in seconds with the mobile app.", feature: "order-management" },
      { title: "UPI and card payments", body: "Collect payment instantly with Razorpay at the counter or online.", feature: "payments" },
    ],
    faqs: [
      { q: "Can I rent bikes by the hour?", a: "Yes. Booqora supports hourly, daily and weekly rental periods and tiered pricing structures." },
      { q: "How do I stop a bike in service from being booked?", a: "Schedule maintenance or repair downtime for that stock item and it will be excluded from availability." },
    ],
  },
  {
    slug: "tool-equipment-rental",
    photoAlt: "Power tools and hand tools hanging on a workshop wall",
    name: "Tool & equipment rental",
    short: "Power tools, construction and DIY equipment.",
    art: ["drill", "ladder"],
    seoTitle: "Tool & Equipment Rental Software",
    metaDescription:
      "Tool hire and equipment rental software. Track tools by serial number, scan barcodes at the counter, price by day or week, hold deposits and manage repairs with Booqora.",
    keywords: ["tool rental software", "equipment rental software", "tool hire software", "construction equipment rental"],
    headline: "Rental software for",
    headlineAccent: "tools & equipment",
    lead:
      "Contractors want the right tool today and the invoice to match. Booqora gives your counter staff instant availability, barcode lookup and accurate pricing for every hire.",
    examples: ["Power tools", "Access equipment & ladders", "Generators & compressors", "Concrete & flooring tools", "Garden machinery", "Safety equipment"],
    challenges: [
      { title: "Busy counters", body: "Trade customers expect to be in and out in minutes." },
      { title: "Wear and repairs", body: "Tools come back needing repairs and must be taken out of circulation." },
      { title: "Repeat trade customers", body: "Regular contractors rent often and need clear account balances." },
    ],
    howItHelps: [
      { title: "Barcode lookup", body: "Scan a tool with your phone to pull up the product instantly.", feature: "barcode-scanning" },
      { title: "Repair downtime", body: "Mark tools as in repair so they can't be hired until they're fixed.", feature: "inventory-management" },
      { title: "Customer balances", body: "See what each contractor owes and their full rental history.", feature: "customer-management" },
      { title: "Product ROI reports", body: "Find out which tools pay for themselves and which sit on the shelf.", feature: "reports" },
    ],
    faqs: [
      { q: "Can I scan barcodes on my tools?", a: "Yes. The Booqora mobile app scans barcodes with your phone's camera — no scanner hardware needed." },
      { q: "Can I see which tools earn the most?", a: "Yes. The product performance report shows times rented, revenue and ROI for every product." },
    ],
  },
  {
    slug: "sports-outdoor-rental",
    photoAlt: "Rental kayaks and canoes on a mountain lake shore",
    name: "Sports & outdoor rental",
    short: "Camping, water sports, ski and adventure gear.",
    art: ["kayak", "skis", "tent"],
    seoTitle: "Sports & Outdoor Gear Rental Software",
    metaDescription:
      "Rental software for camping, kayak, ski and outdoor adventure gear. Take online bookings, manage seasonal inventory, sell add-ons and get paid upfront with Booqora.",
    keywords: ["outdoor gear rental software", "kayak rental software", "ski rental software", "camping gear rental"],
    headline: "Rental software for",
    headlineAccent: "sports & outdoors",
    lead:
      "Seasonal peaks, sizes and add-ons. Booqora helps adventure rental shops take bookings online, upsell the extras and get every customer out on the trail faster.",
    examples: ["Camping gear", "Kayaks & SUPs", "Ski & snowboard", "Climbing & trekking", "Fitness equipment", "Beach gear"],
    challenges: [
      { title: "Seasonal demand", body: "Everyone wants the same gear on the same holiday weekends." },
      { title: "Lots of add-ons", body: "Life jackets, sleeping bags and helmets are easy to forget — and easy revenue." },
      { title: "Remote customers", body: "Travellers want to book and pay before they arrive." },
    ],
    howItHelps: [
      { title: "Online bookings with live availability", body: "Let travellers book and pay before they arrive.", feature: "online-booking" },
      { title: "Cross-sell add-ons", body: "Recommend the extras on every product page.", feature: "online-booking" },
      { title: "Bundles for trip packages", body: "Offer a complete camping or paddling kit at a bundle price.", feature: "inventory-management" },
      { title: "Coupons for the off-season", body: "Run discount codes to fill quieter weeks and track how they perform.", feature: "reports" },
    ],
    faqs: [
      { q: "Can customers pay before they arrive?", a: "Yes. Connect Razorpay, Stripe or PayPal and customers can pay during online checkout or from a payment link." },
      { q: "Can I offer coupon codes?", a: "Yes. Create coupons in Booqora and measure redemptions and revenue in the coupon report." },
    ],
  },
  {
    slug: "furniture-decor-rental",
    photoAlt: "Bright living room with a sectional sofa, coffee table and decor",
    name: "Furniture & decor rental",
    short: "Furniture, home decor, staging and appliances.",
    art: ["sofa", "chair", "lamp"],
    seoTitle: "Furniture & Decor Rental Software",
    metaDescription:
      "Furniture and decor rental software for staging, events and long-term rentals. Manage delivery, deposits, contracts and recurring customers with Booqora.",
    keywords: ["furniture rental software", "decor rental software", "home staging rental", "appliance rental software"],
    headline: "Rental software for",
    headlineAccent: "furniture & decor",
    lead:
      "Longer rentals, bigger items and delivery to the door. Booqora keeps contracts, deposits and delivery schedules organised from first enquiry to final collection.",
    examples: ["Living & dining furniture", "Office furniture", "Home staging", "Decor & accessories", "Appliances", "Lounge furniture for events"],
    challenges: [
      { title: "Long rental periods", body: "Monthly and multi-week rentals need clear pricing and agreements." },
      { title: "Delivery logistics", body: "Every order is delivered and collected, often by your own team." },
      { title: "Condition and deposits", body: "Furniture must come back in good shape, so deposits and contracts matter." },
    ],
    howItHelps: [
      { title: "Weekly and tiered pricing", body: "Make longer rentals better value automatically.", feature: "inventory-management" },
      { title: "Delivery addresses at checkout", body: "Collect the delivery address up front and plan your routes.", feature: "online-booking" },
      { title: "Contracts with signatures", body: "Get the rental agreement signed before delivery.", feature: "documents" },
      { title: "Calendar of deliveries", body: "See every delivery and collection in the rental calendar.", feature: "rental-calendar" },
    ],
    faqs: [
      { q: "Can Booqora handle month-long rentals?", a: "Yes. Rental periods can be as long as you need, and pricing structures make long rentals priced correctly." },
      { q: "Can I require a signed contract?", a: "Yes. Generate a contract from the order and capture the customer's signature." },
    ],
  },
];

export const industryPhoto = (slug: string) => `/industries/${slug}.webp`;

export const getIndustry = (slug: string) => industries.find((i) => i.slug === slug);
