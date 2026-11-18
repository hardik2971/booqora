// Booqora Cloud Functions — payments (Razorpay, Stripe, PayPal) and email (SMTP).
// All provider secrets are read from Google Secret Manager; nothing secret ships to the browser.
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { setGlobalOptions, logger } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import crypto from 'node:crypto';
// Heavy SDKs are loaded on first use (faster cold starts and deploy discovery).
const loadStripe = async () => new (await import('stripe')).default(STRIPE_SECRET_KEY.value());
const loadMailer = async () => (await import('nodemailer')).default;

initializeApp();
const db = getFirestore();
setGlobalOptions({ region: 'asia-south1', maxInstances: 10, memory: '256MiB' });

// ---------- Secrets ----------
const RAZORPAY_KEY_ID = defineSecret('RAZORPAY_KEY_ID');
const RAZORPAY_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const PAYPAL_CLIENT_ID = defineSecret('PAYPAL_CLIENT_ID');
const PAYPAL_CLIENT_SECRET = defineSecret('PAYPAL_CLIENT_SECRET');
const MAIL_USERNAME = defineSecret('MAIL_USERNAME');
const MAIL_PASSWORD = defineSecret('MAIL_PASSWORD');
const MAIL_FROM_ADDRESS = defineSecret('MAIL_FROM_ADDRESS');

const PAY_SECRETS = [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, STRIPE_SECRET_KEY, PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET];
const MAIL_SECRETS = [MAIL_USERNAME, MAIL_PASSWORD, MAIL_FROM_ADDRESS];

const env = (k, d = '') => (process.env[k] ?? d).toString().trim();
const ALLOWED_RETURN = [
  'https://booqora-platform.web.app',
  'https://booqora-platform.firebaseapp.com',
  'http://localhost',
];
const PROVIDER_NAMES = { razorpay: 'Razorpay', stripe: 'Stripe', paypal: 'PayPal' };

// ---------- Helpers ----------
const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;
const minor = (n) => Math.round(round2(n) * 100);

function paymentStatus(total, paid) {
  if (total <= 0 && paid <= 0) return 'paid';
  if (paid <= 0) return 'payment_due';
  if (Math.abs(paid - total) < 0.005) return 'paid';
  if (paid > total) return 'overpaid';
  return 'partially_paid';
}

async function loadWorkspace(wid) {
  if (!wid || typeof wid !== 'string') throw new HttpsError('invalid-argument', 'workspaceId is required');
  const s = await db.doc(`workspaces/${wid}`).get();
  if (!s.exists) throw new HttpsError('not-found', 'Store not found');
  return s.data();
}

async function resolveWorkspaceId({ workspaceId, slug }) {
  if (workspaceId) return workspaceId;
  if (!slug) throw new HttpsError('invalid-argument', 'workspaceId or slug is required');
  const s = await db.doc(`publicStores/${slug}`).get();
  if (!s.exists) throw new HttpsError('not-found', 'Store not found');
  return s.data().workspaceId;
}

async function isMember(wid, uid) {
  if (!uid) return false;
  return (await db.doc(`workspaces/${wid}/members/${uid}`).get()).exists;
}

function storeCurrency(ws) {
  return (ws?.settings?.pricing?.currency || 'INR').toString().toUpperCase();
}

function storeName(ws) {
  return ws?.settings?.general?.companyName || ws?.name || 'Booqora store';
}

function orderLabel(o) {
  return o.number ? `#${o.number}` : 'Web order';
}

/** Which providers can take payments for this workspace right now. */
function providerStatus(ws) {
  const cur = storeCurrency(ws);
  const pay = ws?.settings?.payments || {};
  const enabled = (p) => pay?.[p]?.enabled !== false;
  const out = {};

  const rzId = RAZORPAY_KEY_ID.value(), rzSecret = RAZORPAY_KEY_SECRET.value();
  const rzCur = env('RAZORPAY_CURRENCY', 'INR').toUpperCase();
  out.razorpay = {
    configured: !!(rzId && rzSecret),
    enabled: enabled('razorpay'),
    mode: rzId.startsWith('rzp_live') ? 'live' : 'test',
    currency: rzCur,
    keyId: rzId || null, // publishable id, required by Razorpay Checkout in the browser
    reason: cur !== rzCur ? `Razorpay is set up for ${rzCur}; this store uses ${cur}.` : null,
  };

  const sk = STRIPE_SECRET_KEY.value();
  out.stripe = {
    configured: !!sk,
    enabled: enabled('stripe'),
    mode: sk.startsWith('sk_live') ? 'live' : 'test',
    currency: cur, // Stripe Checkout charges in the store currency
    reason: null,
  };

  const ppId = PAYPAL_CLIENT_ID.value(), ppSecret = PAYPAL_CLIENT_SECRET.value();
  const ppCur = env('PAYPAL_CURRENCY', 'USD').toUpperCase();
  out.paypal = {
    configured: !!(ppId && ppSecret),
    enabled: enabled('paypal'),
    mode: env('PAYPAL_ENV', 'sandbox') === 'live' ? 'live' : 'test',
    currency: ppCur,
    reason: cur !== ppCur ? `PayPal is set up for ${ppCur}; this store uses ${cur}.` : null,
  };

  for (const k of Object.keys(out)) {
    const p = out[k];
    p.available = p.configured && p.enabled && !p.reason;
    if (!p.configured) p.reason = `${PROVIDER_NAMES[k]} keys are not configured on the server.`;
    else if (!p.enabled && !p.reason) p.reason = `${PROVIDER_NAMES[k]} is turned off in Settings → Payment providers.`;
  }
  return out;
}

function checkoutAmount(ws, order) {
  const c = ws?.settings?.checkout || {};
  const total = Number(order.total) || 0;
  const paid = Number(order.paid) || 0;
  const due = Math.max(0, total - paid);
  switch (c.paymentMode) {
    case 'full':
      return due;
    case 'down':
      return Math.min(due, round2((total * (Number(c.downPaymentPercent) || 25)) / 100));
    case 'deposit':
      return Math.max(0, (Number(order.deposit) || 0) - (Number(order.depositPaid) || 0));
    default:
      return 0;
  }
}

function checkReturnUrl(url) {
  if (typeof url !== 'string' || !ALLOWED_RETURN.some((o) => url.startsWith(o))) {
    throw new HttpsError('invalid-argument', 'returnUrl is not allowed');
  }
  return url.split('?')[0];
}

// ---------- Provider APIs ----------
async function razorpayCreateOrder(amount, currency, receipt, notes) {
  const auth = Buffer.from(`${RAZORPAY_KEY_ID.value()}:${RAZORPAY_KEY_SECRET.value()}`).toString('base64');
  const res = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ amount: minor(amount), currency, receipt: receipt.slice(0, 40), notes }),
  });
  const j = await res.json();
  if (!res.ok) throw new HttpsError('failed-precondition', `Razorpay: ${j?.error?.description || res.status}`);
  return j;
}

const paypalBase = () => (env('PAYPAL_ENV', 'sandbox') === 'live' ? 'https://api-m.paypal.com' : 'https://api-m.sandbox.paypal.com');

async function paypalToken() {
  const auth = Buffer.from(`${PAYPAL_CLIENT_ID.value()}:${PAYPAL_CLIENT_SECRET.value()}`).toString('base64');
  const res = await fetch(`${paypalBase()}/v1/oauth2/token`, {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=client_credentials',
  });
  const j = await res.json();
  if (!res.ok) throw new HttpsError('failed-precondition', `PayPal auth failed: ${j?.error_description || res.status}`);
  return j.access_token;
}

async function paypalApi(method, path, body) {
  const token = await paypalToken();
  const res = await fetch(`${paypalBase()}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const j = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, body: j };
}

// ---------- Email ----------
async function mailer() {
  const nodemailer = await loadMailer();
  return nodemailer.createTransport({
    host: env('MAIL_HOST', 'smtp.gmail.com'),
    port: Number(env('MAIL_PORT', '587')),
    secure: Number(env('MAIL_PORT', '587')) === 465,
    auth: { user: MAIL_USERNAME.value(), pass: MAIL_PASSWORD.value() },
  });
}

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

function emailHtml(ws, subject, body) {
  const brand = ws?.settings?.store?.brandColor || '#6431DD';
  const name = esc(storeName(ws));
  const logo = ws?.settings?.general?.logoUrl;
  const footer = esc(ws?.settings?.emails?.footer || '');
  return `<!doctype html><html><body style="margin:0;background:#f7f5fc;font-family:Segoe UI,Arial,sans-serif;color:#1c0938">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:24px 12px"><tr><td align="center">
  <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background:#fff;border-radius:14px;overflow:hidden;border:1px solid #e6e1f0">
  <tr><td style="background:${esc(brand)};padding:20px 28px;color:#fff;font-size:20px;font-weight:700">
    ${logo ? `<img src="${esc(logo)}" alt="" height="32" style="vertical-align:middle;margin-right:10px;border-radius:6px">` : ''}${name}</td></tr>
  <tr><td style="padding:28px">
    <h2 style="margin:0 0 16px;font-size:20px">${esc(subject)}</h2>
    <div style="font-size:15px;line-height:1.6">${esc(body).replace(/\n/g, '<br>')}</div>
  </td></tr>
  <tr><td style="padding:16px 28px;background:#faf8fe;color:#7a7090;font-size:12px">${footer || `Sent by ${name} via Booqora`}</td></tr>
  </table></td></tr></table></body></html>`;
}

async function sendMail(wid, ws, { to, subject, body, context = 'general', entityId = null, sentBy = 'system', cc }) {
  const fromName = ws?.settings?.emails?.fromName || storeName(ws);
  const replyTo = ws?.settings?.emails?.replyTo || ws?.settings?.general?.email || undefined;
  const ccAll = (ws?.settings?.emails?.ccAll || '').split(',').map((s) => s.trim()).filter(Boolean);
  const logRef = db.collection(`workspaces/${wid}/emailLog`).doc();
  try {
    const info = await (await mailer()).sendMail({
      from: `"${fromName.replace(/"/g, '')}" <${MAIL_FROM_ADDRESS.value()}>`,
      to,
      cc: [...(cc || []), ...ccAll].join(', ') || undefined,
      replyTo,
      subject,
      text: body,
      html: emailHtml(ws, subject, body),
    });
    await logRef.set({ to, subject, body, context, entityId, status: 'sent', messageId: info.messageId || null, sentBy, createdAt: FieldValue.serverTimestamp() });
    return { ok: true, id: logRef.id };
  } catch (e) {
    logger.error('sendMail failed', e);
    await logRef.set({ to, subject, body, context, entityId, status: 'failed', error: String(e.message || e).slice(0, 300), sentBy, createdAt: FieldValue.serverTimestamp() });
    throw new HttpsError('internal', 'Email could not be sent. Check the SMTP settings.');
  }
}

const isEmail = (s) => typeof s === 'string' && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(s.trim());

// ---------- Record a verified payment (idempotent) ----------
async function recordPayment(wid, sessionRef, txnId) {
  return db.runTransaction(async (tx) => {
    const ses = await tx.get(sessionRef);
    const s = ses.data();
    if (s.status === 'paid') return { already: true, session: s };
    const orderRef = db.doc(`workspaces/${wid}/orders/${s.orderId}`);
    const order = await tx.get(orderRef);
    if (!order.exists) throw new HttpsError('not-found', 'Order not found');
    const o = order.data();
    const isDeposit = s.kind === 'deposit';
    const total = Number(o.total) || 0;
    const paid = isDeposit ? Number(o.paid) || 0 : round2((Number(o.paid) || 0) + s.amount);
    const due = Math.max(0, round2(total - paid));
    const payRef = db.doc(`workspaces/${wid}/payments/${s.provider}_${txnId}`);
    tx.set(payRef, {
      orderId: s.orderId,
      orderNumber: o.number ?? null,
      amount: s.amount,
      currency: s.currency,
      method: 'online',
      provider: s.provider,
      kind: isDeposit ? 'deposit' : 'charge',
      reference: txnId,
      note: `Paid online via ${PROVIDER_NAMES[s.provider]}${s.mode === 'test' ? ' (test mode)' : ''}`,
      paidAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      createdBy: 'system',
    });
    tx.update(orderRef, {
      paid, due, paymentStatus: paymentStatus(total, paid), updatedAt: FieldValue.serverTimestamp(),
      ...(isDeposit ? { depositPaid: round2((Number(o.depositPaid) || 0) + s.amount) } : {}),
    });
    tx.update(sessionRef, { status: 'paid', transactionId: txnId, paidAt: FieldValue.serverTimestamp() });
    tx.set(db.collection(`workspaces/${wid}/activity`).doc(), {
      entity: 'orders', entityId: s.orderId, action: 'paid',
      label: `${orderLabel(o)} · ${s.currency} ${s.amount.toFixed(2)} via ${PROVIDER_NAMES[s.provider]}`,
      actorName: o.customerName || 'Customer', actorId: 'system', createdAt: FieldValue.serverTimestamp(),
    });
    return { already: false, session: s, order: o };
  });
}

// =====================================================================
// Callable: paymentConfig — which providers a store can use (public).
// =====================================================================
export const paymentConfig = onCall({ secrets: PAY_SECRETS }, async (req) => {
  const wid = await resolveWorkspaceId(req.data || {});
  const ws = await loadWorkspace(wid);
  const providers = providerStatus(ws);
  const checkout = ws?.settings?.checkout || {};
  return {
    workspaceId: wid,
    currency: storeCurrency(ws),
    checkout: { paymentMode: checkout.paymentMode || 'none', downPaymentPercent: Number(checkout.downPaymentPercent) || 25 },
    providers,
  };
});

// =====================================================================
// Callable: createPayment — starts a payment for an order.
//   purpose: 'checkout' (storefront rules) | 'balance' (amount due) | 'custom' (staff only)
// =====================================================================
export const createPayment = onCall({ secrets: PAY_SECRETS }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');
  const { workspaceId, orderId, provider, purpose = 'balance', amount: requested, returnUrl } = req.data || {};
  if (!PROVIDER_NAMES[provider]) throw new HttpsError('invalid-argument', 'Unknown provider');
  if (!orderId) throw new HttpsError('invalid-argument', 'orderId is required');
  const ws = await loadWorkspace(workspaceId);
  const status = providerStatus(ws)[provider];
  if (!status.available) throw new HttpsError('failed-precondition', status.reason || 'Provider unavailable');

  const orderSnap = await db.doc(`workspaces/${workspaceId}/orders/${orderId}`).get();
  if (!orderSnap.exists) throw new HttpsError('not-found', 'Order not found');
  const o = orderSnap.data();
  const staff = await isMember(workspaceId, req.auth.uid);
  const due = Math.max(0, round2((Number(o.total) || 0) - (Number(o.paid) || 0)));

  let amount;
  if (purpose === 'checkout') amount = checkoutAmount(ws, o);
  else if (purpose === 'custom') {
    if (!staff) throw new HttpsError('permission-denied', 'Only staff can request a custom amount');
    amount = Math.min(round2(requested), due);
  } else amount = due;
  amount = round2(amount);
  if (!(amount >= 1)) throw new HttpsError('failed-precondition', 'Nothing to pay on this order');

  const currency = status.currency;
  const sessionRef = db.collection(`workspaces/${workspaceId}/paymentSessions`).doc();
  const name = storeName(ws);
  const label = orderLabel(o);
  // A storefront checkout in "deposit only" mode collects the security deposit, not the rental.
  const kind = purpose === 'checkout' && ws?.settings?.checkout?.paymentMode === 'deposit' ? 'deposit' : 'charge';
  const base = { provider, orderId, amount, currency, purpose, kind, mode: status.mode, status: 'pending', createdBy: req.auth.uid, staff, createdAt: FieldValue.serverTimestamp() };

  if (provider === 'razorpay') {
    const rz = await razorpayCreateOrder(amount, currency, sessionRef.id, { workspaceId, orderId, sessionId: sessionRef.id });
    await sessionRef.set({ ...base, providerRef: rz.id });
    return {
      provider, sessionId: sessionRef.id, keyId: status.keyId, providerOrderId: rz.id, amount, amountMinor: rz.amount, currency,
      name, description: `Order ${label}`, prefill: { name: o.customerName || '', email: o.customerEmail || '', contact: o.customerPhone || '' },
      brandColor: ws?.settings?.store?.brandColor || '#6431DD', mode: status.mode,
    };
  }

  const ret = checkReturnUrl(returnUrl);
  const q = (extra) => `${ret}?provider=${provider}&w=${encodeURIComponent(workspaceId)}&s=${sessionRef.id}${extra}`;

  if (provider === 'stripe') {
    const stripe = await loadStripe();
    const cs = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [{ quantity: 1, price_data: { currency: currency.toLowerCase(), unit_amount: minor(amount), product_data: { name: `${name} — Order ${label}` } } }],
      customer_email: isEmail(o.customerEmail) ? o.customerEmail : undefined,
      success_url: q('&cs={CHECKOUT_SESSION_ID}'),
      cancel_url: q('&cancelled=1'),
      metadata: { workspaceId, orderId, sessionId: sessionRef.id },
    }).catch((e) => { throw new HttpsError('failed-precondition', `Stripe: ${e.message}`); });
    await sessionRef.set({ ...base, providerRef: cs.id });
    return { provider, sessionId: sessionRef.id, url: cs.url, amount, currency, mode: status.mode };
  }

  // PayPal
  const r = await paypalApi('POST', '/v2/checkout/orders', {
    intent: 'CAPTURE',
    purchase_units: [{ reference_id: sessionRef.id, custom_id: `${workspaceId}:${orderId}`, description: `${name} — Order ${label}`.slice(0, 127), amount: { currency_code: currency, value: amount.toFixed(2) } }],
    application_context: { brand_name: name.slice(0, 127), user_action: 'PAY_NOW', shipping_preference: 'NO_SHIPPING', return_url: q(''), cancel_url: q('&cancelled=1') },
  });
  if (!r.ok) throw new HttpsError('failed-precondition', `PayPal: ${r.body?.message || r.status}`);
  const approve = (r.body.links || []).find((l) => l.rel === 'approve' || l.rel === 'payer-action');
  await sessionRef.set({ ...base, providerRef: r.body.id });
  return { provider, sessionId: sessionRef.id, url: approve?.href, amount, currency, mode: status.mode };
});

// =====================================================================
// Callable: verifyPayment — confirms with the provider, then records it.
// =====================================================================
export const verifyPayment = onCall({ secrets: [...PAY_SECRETS, ...MAIL_SECRETS] }, async (req) => {
  const { workspaceId, sessionId, razorpay, stripeSessionId, paypalToken } = req.data || {};
  if (!workspaceId || !sessionId) throw new HttpsError('invalid-argument', 'workspaceId and sessionId are required');
  const ws = await loadWorkspace(workspaceId);
  const sessionRef = db.doc(`workspaces/${workspaceId}/paymentSessions/${sessionId}`);
  const ses = await sessionRef.get();
  if (!ses.exists) throw new HttpsError('not-found', 'Payment session not found');
  const s = ses.data();
  const result = (extra = {}) => ({ ok: true, amount: s.amount, currency: s.currency, provider: s.provider, orderId: s.orderId, storeName: storeName(ws), slug: ws.slug, mode: s.mode, ...extra });
  if (s.status === 'paid') return result({ already: true });

  let txnId;
  if (s.provider === 'razorpay') {
    const { paymentId, signature } = razorpay || {};
    if (!paymentId || !signature) throw new HttpsError('invalid-argument', 'Missing Razorpay payment details');
    const expected = crypto.createHmac('sha256', RAZORPAY_KEY_SECRET.value()).update(`${s.providerRef}|${paymentId}`).digest('hex');
    const ok = expected.length === signature.length && crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
    if (!ok) throw new HttpsError('permission-denied', 'Payment signature mismatch');
    txnId = paymentId;
  } else if (s.provider === 'stripe') {
    if (stripeSessionId !== s.providerRef) throw new HttpsError('invalid-argument', 'Session mismatch');
    const stripe = await loadStripe();
    const cs = await stripe.checkout.sessions.retrieve(stripeSessionId);
    if (cs.payment_status !== 'paid') return { ok: false, status: cs.payment_status, message: 'Payment not completed yet.' };
    txnId = typeof cs.payment_intent === 'string' ? cs.payment_intent : cs.payment_intent?.id || cs.id;
  } else {
    if (paypalToken !== s.providerRef) throw new HttpsError('invalid-argument', 'Order mismatch');
    let r = await paypalApi('POST', `/v2/checkout/orders/${s.providerRef}/capture`);
    if (!r.ok && r.body?.details?.some((d) => d.issue === 'ORDER_ALREADY_CAPTURED')) r = await paypalApi('GET', `/v2/checkout/orders/${s.providerRef}`);
    if (!r.ok || r.body.status !== 'COMPLETED') return { ok: false, status: r.body?.status || r.status, message: 'Payment was not approved.' };
    txnId = r.body.purchase_units?.[0]?.payments?.captures?.[0]?.id || s.providerRef;
  }

  const rec = await recordPayment(workspaceId, sessionRef, txnId);
  if (!rec.already && rec.order && isEmail(rec.order.customerEmail)) {
    const cur = s.currency;
    const body = `Hi ${rec.order.customerName || 'there'},\n\nWe've received your payment of ${cur} ${s.amount.toFixed(2)} for order ${orderLabel(rec.order)}.\nTransaction reference: ${txnId}\n\nThank you,\n${storeName(ws)}`;
    await sendMail(workspaceId, ws, { to: rec.order.customerEmail, subject: `Payment received — ${storeName(ws)}`, body, context: 'payments', entityId: s.orderId })
      .catch((e) => logger.warn('receipt email failed', e.message));
  }
  return result({ transactionId: txnId });
});

// =====================================================================
// Callable: sendEmail — staff send an email from the workspace (SMTP).
// =====================================================================
export const sendEmail = onCall({ secrets: MAIL_SECRETS }, async (req) => {
  if (!req.auth || req.auth.token.firebase?.sign_in_provider === 'anonymous') throw new HttpsError('unauthenticated', 'Sign in required');
  const { workspaceId, to, subject, body, context, entityId, cc } = req.data || {};
  const ws = await loadWorkspace(workspaceId);
  if (!(await isMember(workspaceId, req.auth.uid))) throw new HttpsError('permission-denied', 'Not a member of this workspace');
  const recipients = (Array.isArray(to) ? to : String(to || '').split(',')).map((s) => s.trim()).filter(Boolean);
  if (!recipients.length || !recipients.every(isEmail)) throw new HttpsError('invalid-argument', 'Enter valid recipient email addresses');
  if (recipients.length > 20) throw new HttpsError('invalid-argument', 'Too many recipients');
  if (!subject || !body) throw new HttpsError('invalid-argument', 'Subject and message are required');
  const member = (await db.doc(`workspaces/${workspaceId}/members/${req.auth.uid}`).get()).data();
  return sendMail(workspaceId, ws, {
    to: recipients.join(', '), subject: String(subject).slice(0, 300), body: String(body).slice(0, 20000),
    context: context || 'general', entityId: entityId || null, sentBy: member?.name || req.auth.uid,
    cc: (Array.isArray(cc) ? cc : []).filter(isEmail),
  });
});

// =====================================================================
// Trigger: online booking received → email the customer and the store.
// =====================================================================
export const onOnlineOrder = onDocumentCreated({ document: 'workspaces/{wid}/orders/{oid}', secrets: MAIL_SECRETS }, async (event) => {
  const o = event.data?.data();
  if (!o || o.source !== 'online') return;
  const wid = event.params.wid;
  const ws = await loadWorkspace(wid);
  const name = storeName(ws);
  const fmt = (d) => (d?.toDate ? d.toDate().toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short', timeZone: ws?.settings?.general?.timezone || 'Asia/Kolkata' }) : '');
  const lines = (o.lines || []).map((l) => `• ${l.qty} × ${l.name}`).join('\n');
  const cur = storeCurrency(ws);
  const summary = `${lines}\n\nRental period: ${fmt(o.startsAt)} → ${fmt(o.stopsAt)}\nTotal: ${cur} ${(Number(o.total) || 0).toFixed(2)}`;

  if (isEmail(o.customerEmail) && ws?.settings?.emails?.sysOrderConfirmation !== false) {
    await sendMail(wid, ws, {
      to: o.customerEmail,
      subject: `We received your booking request — ${name}`,
      body: `Hi ${o.customerName || 'there'},\n\nThanks for your booking request. We'll confirm availability shortly.\n\n${summary}\n\nKind regards,\n${name}`,
      context: 'orders', entityId: event.params.oid,
    }).catch((e) => logger.warn('customer confirmation failed', e.message));
  }
  const storeEmail = ws?.settings?.general?.email;
  if (isEmail(storeEmail)) {
    await sendMail(wid, ws, {
      to: storeEmail,
      subject: `New online booking from ${o.customerName || 'a customer'}`,
      body: `You have a new online booking request.\n\nCustomer: ${o.customerName || ''} (${o.customerEmail || ''}${o.customerPhone ? ', ' + o.customerPhone : ''})\n\n${summary}\n\nOpen Booqora → Orders to review and reserve it.`,
      context: 'orders', entityId: event.params.oid,
    }).catch((e) => logger.warn('store notification failed', e.message));
  }
});
