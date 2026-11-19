// Booqora Firestore schema — single source of truth for collection names and
// document shapes. All tenant data lives under `workspaces/{wid}/<collection>`.
//
// Conventions (every tenant document):
//   createdAt: Timestamp (server), updatedAt: Timestamp (server), createdBy: uid
//   tags: List<String> (optional)
//   number: int  (sequential, for orders / customers / documents) via Db.nextNumber
//
// Query rule: only use a single orderBy (createdAt) or a single equality where()
// per query; do any further filtering/sorting client-side. This avoids composite
// indexes. Workspaces are small enough for client-side filtering.

class C {
  // ---- Top level ----
  /// users/{uid}: {name, email, workspaceId, avatarUrl, locale, createdAt}
  static const users = 'users';

  /// workspaces/{wid}: {name, slug, ownerId, plan:'trial'|'starter'|'pro'|'business',
  ///   trialEndsAt: Timestamp, counters:{order,customer,quote,contract,invoice,packing},
  ///   onboarding: Map<String,bool>, settings: {<section>: Map}}
  ///   settings sections: general, pricing, taxes, rentalPeriod, payments, emails,
  ///   documents, translations, security, store (online-store preferences),
  ///   crossSell, fulfillment, checkout, seo
  static const workspaces = 'workspaces';

  /// publicStores/{slug}: {workspaceId, name, logoUrl, brandColor, enabled,
  ///   description, currency, currencyPosition, seoTitle, seoDescription,
  ///   showPrices, termsRequired, termsLabel, termsText, email, phone}
  static const publicStores = 'publicStores';

  /// invites/{emailLowercase}: {workspaceId, workspaceName, role, invitedBy, createdAt}
  static const invites = 'invites';

  // ---- Tenant sub-collections ----
  /// members/{uid}: {uid, name, email, role:'owner'|'admin'|'member', active, joinedAt}
  static const members = 'members';

  /// products: {name, sku, type:'rental'|'sale'|'service', trackingType:'trackable'|'bulk',
  ///   description, excerpt, imageUrls:List<String>, status:'active'|'archived',
  ///   pricingMethod:'flat'|'fixed'|'structure'|'none', price:num, pricePer:'hour'|'day'|'week'|'month',
  ///   pricingStructureId, chargeEnabled:bool, taxable:bool, taxProfileId, discountEligible:bool,
  ///   deposit:num, purchaseCost:num, weight:num, weightUnit, allowShortage:bool,
  ///   bufferBefore:num, bufferAfter:num (hours), quantity:int (stock count, kept in sync),
  ///   collectionIds:List<String>, crossSellIds:List<String>,
  ///   variationsEnabled:bool, properties:List<String>,
  ///   variations: List<{id,name,values:Map<String,String>,price,weight,sku}>,
  ///   showInStore:bool, slug, seoTitle, seoDescription, tags}
  static const products = 'products';

  /// stockItems: {productId, productName, variationId, identifier, kind:'regular'|'temporary',
  ///   availableFrom:Timestamp, availableTill:Timestamp?, purchaseCost, purchaseDate, locationId,
  ///   status:'available'|'out'|'downtime'}
  static const stockItems = 'stockItems';

  /// bundles: {name, description, imageUrl, items:List<{productId,name,qty,discount}>,
  ///   price:num?, collectionIds, showInStore, tags}
  static const bundles = 'bundles';

  /// collections: {name, parentId, imageUrl, showInStore:bool, description, slug,
  ///   seoTitle, seoDescription, isSystem:bool}
  static const collections = 'collections';

  /// downtimes: {productId, productName, stockItemId?, quantity, reason:'maintenance'|'repair'|'missing',
  ///   status:'scheduled'|'started'|'ended'|'cancelled', startsAt, endsAt, locationId, note}
  static const downtimes = 'downtimes';

  /// customers: {number, name, email, phone, type:'individual'|'company', marketing:bool,
  ///   discountPercent:num, taxProfileId, depositMode:'default'|'none'|'percentage'|'product'|'fixed',
  ///   depositValue:num, addresses:List<{label,country,firstName,lastName,line1,line2,city,state,zip,isMain}>,
  ///   customFields:Map, balanceDue:num, orderCount:int, revenue:num, latestOrderAt, tags}
  static const customers = 'customers';

  /// orders: {number, status:'draft'|'reserved'|'started'|'returned'|'archived'|'canceled',
  ///   paymentStatus:'payment_due'|'partially_paid'|'paid'|'overpaid'|'process_deposit',
  ///   source:'manual'|'online', customerId, customerName, customerEmail, customerPhone,
  ///   billingAddress:Map, deliveryAddress:Map, fulfillment:'pickup'|'delivery', locationId,
  ///   startsAt:Timestamp, stopsAt:Timestamp,
  ///   lines: List<{id, kind:'product'|'bundle'|'custom', productId, name, qty, unitPrice,
  ///          periods:num, total:num, taxRate:num, imageUrl}>,
  ///   discountPercent:num, couponCode, couponDiscount:num, subtotal, discountTotal, taxTotal,
  ///   total, deposit, paid:num, due:num, itemCount:int, customFields:Map, tags}
  static const orders = 'orders';

  /// payments: {orderId, orderNumber, amount, method:'cash'|'card'|'bank'|'upi'|'online',
  ///   kind:'charge'|'refund'|'deposit', note, paidAt}
  static const payments = 'payments';

  /// coupons: {code (UPPERCASE), active:bool, discountType:'percentage'|'fixed', value:num,
  ///   startsAt?, endsAt?, eligible:'all'|'products'|'collections', productIds, collectionIds,
  ///   minimumSpend:num?, maxUses:int?, onePerCustomer:bool, stackWithCustomerDiscount:bool,
  ///   uses:int}
  static const coupons = 'coupons';

  /// documents: {type:'invoice'|'quote'|'contract'|'packing', number, orderId, orderNumber,
  ///   customerId, customerName, date, dueDate?, reference, lines(copied from order),
  ///   subtotal, taxTotal, total, deposit, paid, due, paymentStatus, finalized:bool, sent:bool,
  ///   text, footer, signature:{name, signedAt}?, tags}
  static const documents = 'documents';

  /// notes: {entity, entityId, text, authorName, createdAt}
  static const notes = 'notes';

  /// activity: {entity, entityId, action:'created'|'updated'|'deleted'|..., label, actorName, createdAt}
  static const activity = 'activity';

  /// taxProfiles: {name, kind:'product'|'customer', rate:num (percent), compound:bool}
  static const taxProfiles = 'taxProfiles';

  /// pricingStructures: {name, interval:'hour'|'day'|'week', tiers:List<{upTo:num, price:num}>,
  ///   minimum:num, description}
  static const pricingStructures = 'pricingStructures';

  /// locations: {name, address, pickup:bool, delivery:bool, showInStore:bool, isDefault:bool}
  static const locations = 'locations';

  /// customFields: {scope:'customer'|'order'|'product', name, type:'text'|'number'|'date'|'select'|'checkbox',
  ///   options:List<String>, showOnDocuments:bool, inCheckout:bool, position:int}
  static const customFields = 'customFields';

  /// emailTemplates: {name, kind:'system'|'manual', context:'orders'|'invoices'|'quotes'|'contracts'|'customers',
  ///   subject, body, enabled}
  static const emailTemplates = 'emailTemplates';

  /// emailLog: {to, subject, body, context, entityId, status:'queued'|'sent', createdAt}
  static const emailLog = 'emailLog';

  /// apps: {appId, name, category, installedAt, status:'configured'|'needs_attention', config:Map}
  static const apps = 'apps';

  /// pages / menus / blogPosts / redirects for the website builder
  static const pages = 'pages'; // {title, slug, body, published}
  static const menus = 'menus'; // {name, items:List<{label,url}>}
  static const blogPosts = 'blogPosts'; // {title, body, status:'draft'|'published'|'scheduled', publishAt}
  static const redirects = 'redirects'; // {from, to}

  /// assistantChats: {role:'user'|'assistant', text, createdAt}
  static const assistantChats = 'assistantChats';
}

// Status vocabularies shared by every module.
class OrderStatus {
  static const all = ['draft', 'reserved', 'started', 'returned', 'archived', 'canceled'];
}

class PaymentStatus {
  static const all = ['payment_due', 'partially_paid', 'paid', 'overpaid', 'process_deposit'];
}
