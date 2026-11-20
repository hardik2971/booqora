export type Block =
  | { t: "p"; c: string }
  | { t: "h2"; c: string }
  | { t: "h3"; c: string }
  | { t: "ul"; c: string[] }
  | { t: "ol"; c: string[] }
  | { t: "tip"; c: string };

export type Post = {
  slug: string;
  title: string;
  description: string;
  category: string;
  date: string; // ISO
  readMinutes: number;
  keywords: string[];
  art: "launch" | "pricing" | "calendar";
  body: Block[];
};

export const posts: Post[] = [
  {
    slug: "how-to-start-a-rental-business",
    title: "How to start a rental business: a practical step-by-step guide",
    description:
      "Thinking of starting an equipment, camera, party or bike rental business? Learn how to choose a niche, price your inventory, set up bookings and payments, and grow — step by step.",
    category: "Guides",
    date: "2026-11-10",
    readMinutes: 9,
    keywords: ["how to start a rental business", "equipment rental business", "rental business ideas", "start rental company"],
    art: "launch",
    body: [
      { t: "p", c: "A rental business can be one of the most capital-efficient businesses you can start. You buy an asset once and earn from it again and again. But the details — availability, deposits, damage, late returns and pricing — decide whether each item pays for itself or quietly loses money. This guide walks through the practical steps, from choosing what to rent to running day-to-day operations." },
      { t: "h2", c: "1. Choose a niche you understand" },
      { t: "p", c: "The most successful rental businesses start narrow. Pick a category where you understand the customer and the gear, and where demand is frequent enough to keep items earning." },
      { t: "ul", c: ["Camera, lens and AV equipment for creators and production teams", "Party and event rentals such as tents, furniture, decor and sound", "Bikes, e-bikes and scooters for tourists and commuters", "Tools and construction equipment for contractors and DIYers", "Camping, water-sports and outdoor gear", "Furniture and appliances for homes, offices and staging"] },
      { t: "p", c: "Look at what people in your area already rent, what they complain about and what they travel to rent. A niche with repeat customers — such as contractors or production houses — gives you predictable revenue." },
      { t: "h2", c: "2. Work out the economics of each item" },
      { t: "p", c: "Before you buy anything, estimate how quickly each item will pay for itself. A simple model is enough to start:" },
      { t: "ol", c: ["Purchase cost of the item, including accessories", "Expected rental price per day or week", "Expected rentals per month (be conservative)", "Cleaning, maintenance and repair costs", "Expected life of the item"] },
      { t: "p", c: "Divide the purchase cost by the expected monthly rental income after costs to find the payback period. Items that pay back within a few months are excellent; items that take years need a second look." },
      { t: "tip", c: "Track return on investment per product from day one. In Booqora, the product performance report shows times rented, rent duration, revenue and ROI for every item, so you know what to buy more of." },
      { t: "h2", c: "3. Set your rental pricing" },
      { t: "p", c: "Rental pricing usually combines a period rate with incentives for longer rentals. A common approach is a daily rate with a weekly rate that is cheaper than seven daily rates. Add a security deposit for high-value items and a flat fee for services such as delivery or setup. Our guide to rental pricing covers this in detail." },
      { t: "h2", c: "4. Prepare your policies" },
      { t: "p", c: "Clear policies protect you and make customers more confident. Write them down before your first rental:" },
      { t: "ul", c: ["Identification and deposit requirements", "Late return charges and what counts as late", "Damage, loss and cleaning charges", "Cancellation and rescheduling rules", "Pickup, delivery and return procedures"] },
      { t: "p", c: "Put the important terms in your rental contract and ask customers to accept them when they book." },
      { t: "h2", c: "5. Set up bookings, inventory and payments" },
      { t: "p", c: "Spreadsheets and paper diaries work for the first few rentals, but they break down quickly. The moment two people take bookings, or a customer returns late, you risk renting the same item twice. Rental software solves this by connecting bookings to real availability." },
      { t: "p", c: "At a minimum, your system should handle:" },
      { t: "ul", c: ["Real-time availability for any date range", "Orders with pickup and return times, deposits and taxes", "Online bookings so customers can reserve 24/7", "Online payments and payment links", "Quotes, contracts and invoices generated from the order"] },
      { t: "h2", c: "6. Get your first customers" },
      { t: "p", c: "Start where your customers already are. Create a Google Business Profile, share your booking page on Instagram and WhatsApp, and partner with related businesses — photographers with camera rental, wedding planners with event rental, hotels with bike rental. Ask every happy customer for a review." },
      { t: "h2", c: "7. Measure, then grow" },
      { t: "p", c: "Once rentals are flowing, look at the numbers every month: revenue, utilisation per product, shortages (unmet demand) and outstanding balances. Shortages tell you what to buy next; low-utilisation items can be sold or bundled. Grow inventory where the data says demand exists." },
      { t: "h2", c: "Start with the right foundation" },
      { t: "p", c: "Booqora gives new rental businesses everything above in one place: inventory with live availability, orders, an online store, payments with Razorpay, Stripe and PayPal, professional documents and reports — on the web and on your phone. You can try it free for 14 days without a credit card." },
    ],
  },
  {
    slug: "rental-pricing-strategy",
    title: "How to price your rentals: daily, weekly and tiered pricing explained",
    description:
      "Learn how to set rental prices that customers accept and that pay back your inventory. Covers daily and weekly rates, tiered pricing, deposits, flat fees, discounts and seasonal demand.",
    category: "Pricing",
    date: "2026-11-04",
    readMinutes: 7,
    keywords: ["rental pricing strategy", "how to price rental equipment", "tiered rental pricing", "rental rates"],
    art: "pricing",
    body: [
      { t: "p", c: "Price too high and customers go elsewhere. Price too low and your gear wears out before it pays for itself. Good rental pricing balances what the market will pay with what each item needs to earn. Here is a practical framework." },
      { t: "h2", c: "Start with the cost of the item" },
      { t: "p", c: "A widely used starting point is to charge a daily rate of roughly 3–5% of the item's replacement cost, then adjust for your market. Fragile, high-maintenance or high-demand items sit at the top of the range; durable, commodity items at the bottom." },
      { t: "h2", c: "Choose the right rental periods" },
      { t: "p", c: "Match your periods to how customers actually rent:" },
      { t: "ul", c: ["Hourly — bikes, scooters, sports equipment and short-term tools", "Daily — cameras, AV, tools and most equipment", "Weekly — longer projects, travel and productions", "Monthly — furniture, appliances and long-term hire"] },
      { t: "h2", c: "Reward longer rentals with tiered pricing" },
      { t: "p", c: "Tiered pricing charges less per day as the rental gets longer. A weekly rate that equals four or five daily rates encourages customers to keep items longer, which reduces handling and cleaning for you." },
      { t: "tip", c: "In Booqora, pricing structures let you define tiers once and assign them to any product. Every order — including online bookings — is priced correctly automatically." },
      { t: "h2", c: "Use deposits for high-value items" },
      { t: "p", c: "A security deposit protects you against damage and late returns. Keep deposits separate from rental payments so you always know what you owe back. Make the amount proportional to the item's value and state it clearly when customers book." },
      { t: "h2", c: "Add flat fees for services" },
      { t: "p", c: "Delivery, setup, cleaning and insurance are real costs. Charge them as flat fees or services rather than hiding them in the rental rate — customers appreciate transparent pricing." },
      { t: "h2", c: "Use discounts deliberately" },
      { t: "p", c: "Coupons and discounts are useful for filling quiet weeks, rewarding repeat customers and launching new products. Measure every coupon's redemptions and revenue so you know which ones work." },
      { t: "h2", c: "Review prices every season" },
      { t: "p", c: "Look at utilisation and shortages each season. If an item is constantly short, demand is higher than supply — raise the price or buy more units. If an item rarely goes out, lower the price, bundle it, or sell it." },
      { t: "h2", c: "Summary" },
      { t: "ol", c: ["Anchor the daily rate to the item's replacement cost", "Offer the periods your customers actually need", "Make longer rentals better value with tiers", "Protect high-value gear with deposits", "Charge transparently for services", "Review pricing using real utilisation data"] },
    ],
  },
  {
    slug: "prevent-double-bookings",
    title: "How to stop double bookings in your rental business",
    description:
      "Double bookings cost rental businesses money and reputation. Learn why they happen — late returns, manual calendars, multiple booking channels — and how to prevent them for good.",
    category: "Operations",
    date: "2026-10-28",
    readMinutes: 6,
    keywords: ["prevent double bookings", "rental availability", "rental booking calendar", "overbooking rental"],
    art: "calendar",
    body: [
      { t: "p", c: "Few things damage a rental business faster than a customer arriving to collect an item that isn't there. Double bookings lead to refunds, bad reviews and stressed staff. The good news: they're almost always caused by the same handful of problems, and each has a fix." },
      { t: "h2", c: "Why double bookings happen" },
      { t: "h3", c: "1. Availability lives in more than one place" },
      { t: "p", c: "A paper diary at the counter, a spreadsheet at home and bookings in your WhatsApp chats. When availability is split across several places, it is only a matter of time before two of them disagree." },
      { t: "h3", c: "2. Late returns aren't accounted for" },
      { t: "p", c: "An item booked to come back on Friday is still out on Saturday. If your system assumes it's back on time, Saturday's customer is in for a surprise." },
      { t: "h3", c: "3. Counting quantities by hand" },
      { t: "p", c: "For bulk items like chairs or tables, overlapping orders make manual counting error-prone — especially across busy weekends." },
      { t: "h3", c: "4. Items out for maintenance" },
      { t: "p", c: "A bike in the workshop or a camera away for repair still looks available unless it's blocked." },
      { t: "h2", c: "How to prevent them" },
      { t: "ol", c: ["Use one source of truth for availability, shared by everyone on your team", "Calculate availability for the exact pickup and return time, not just the day", "Keep late rentals holding stock until they are actually returned", "Block items in maintenance or repair", "Connect online bookings directly to the same availability", "Review shortages before confirming large or overlapping orders"] },
      { t: "tip", c: "Booqora calculates availability from real stock and every reserved and started order. Late rentals keep holding stock until they are returned, maintenance downtime is excluded, and your online store uses the same live availability." },
      { t: "h2", c: "What to do if a double booking happens" },
      { t: "p", c: "Act early. Contact the affected customer as soon as you know, offer an equivalent or better alternative, and consider a discount for the inconvenience. Then find the root cause and fix the process so it doesn't happen again." },
      { t: "h2", c: "The takeaway" },
      { t: "p", c: "Double bookings are a systems problem, not a people problem. Put all bookings into one system that understands time, quantities, late returns and maintenance, and they simply stop happening." },
    ],
  },
];

export const getPost = (slug: string) => posts.find((p) => p.slug === slug);
