import { useState, useMemo } from "react";
import { Check, X, Crown, Zap, Star, TrendingUp, Users, FileText, Package, ChevronDown, ChevronUp, AlertTriangle, DollarSign, Server, ArrowRight } from "lucide-react";

const COLORS = {
  bg: "#0f0f13",
  card: "#1a1a24",
  cardHover: "#22222e",
  border: "#2a2a3a",
  accent: "#7c5cfc",
  accentLight: "#9b82fc",
  accentGlow: "rgba(124, 92, 252, 0.15)",
  green: "#22c55e",
  greenGlow: "rgba(34, 197, 94, 0.15)",
  orange: "#f59e0b",
  orangeGlow: "rgba(245, 158, 11, 0.15)",
  red: "#ef4444",
  redGlow: "rgba(239, 68, 68, 0.15)",
  text: "#e4e4e7",
  textMuted: "#9ca3af",
  textDim: "#6b7280",
  white: "#ffffff",
};

// ─── DATA ────────────────────────────────────────────────────────────
const CURRENT_PLANS = {
  free: { name: "Free", price: 0, invoices: 5, customers: 10, products: 20 },
  starter: { name: "Starter", price: 299, invoices: 50, customers: 100, products: 200 },
  pro: { name: "Pro", price: 699, invoices: "Unlimited", customers: "Unlimited", products: "Unlimited" },
};

const PROPOSED_PLANS = [
  {
    id: "free",
    name: "Free",
    tagline: "Get started, no card needed",
    monthlyPrice: 0,
    yearlyPrice: 0,
    icon: <Star size={22} />,
    color: COLORS.textMuted,
    limits: { invoices: 10, customers: 15, products: 30 },
    features: [
      { name: "GST invoicing (CGST/SGST/IGST)", included: true },
      { name: "1 PDF template (Classic)", included: true },
      { name: "Customer & product management", included: true },
      { name: "Basic dashboard", included: true },
      { name: "WhatsApp share", included: false },
      { name: "Purchase orders", included: false },
      { name: "Reports & analytics", included: false },
      { name: "E-Way Bill generation", included: false },
      { name: "Data export (CSV)", included: false },
      { name: "Priority support", included: false },
    ],
  },
  {
    id: "starter",
    name: "Starter",
    tagline: "For growing small businesses",
    monthlyPrice: 199,
    yearlyPrice: 1499,
    icon: <Zap size={22} />,
    color: COLORS.orange,
    popular: false,
    limits: { invoices: 100, customers: 250, products: 500 },
    features: [
      { name: "GST invoicing (CGST/SGST/IGST)", included: true },
      { name: "3 PDF templates", included: true },
      { name: "Customer & product management", included: true },
      { name: "Basic dashboard", included: true },
      { name: "WhatsApp share", included: true },
      { name: "Purchase orders", included: true },
      { name: "Reports & analytics", included: false },
      { name: "E-Way Bill generation", included: false },
      { name: "Data export (CSV)", included: false },
      { name: "Priority support", included: false },
    ],
  },
  {
    id: "pro",
    name: "Pro",
    tagline: "Full power for serious businesses",
    monthlyPrice: 499,
    yearlyPrice: 3999,
    icon: <Crown size={22} />,
    color: COLORS.accent,
    popular: true,
    limits: { invoices: "Unlimited", customers: "Unlimited", products: "Unlimited" },
    features: [
      { name: "GST invoicing (CGST/SGST/IGST)", included: true },
      { name: "All PDF templates + custom branding", included: true },
      { name: "Customer & product management", included: true },
      { name: "Advanced analytics dashboard", included: true },
      { name: "WhatsApp share", included: true },
      { name: "Purchase orders", included: true },
      { name: "GST reports (monthly/quarterly/yearly)", included: true },
      { name: "E-Way Bill generation", included: true },
      { name: "Data export (CSV)", included: true },
      { name: "Priority support", included: true },
    ],
  },
];

const COMPETITORS = [
  { name: "BillRaja (Current)", starter: "₹299/mo", pro: "₹699/mo", annual: "₹3,588–₹8,388/yr", free: "5 inv/mo" },
  { name: "BillRaja (Proposed)", starter: "₹199/mo", pro: "₹499/mo", annual: "₹1,499–₹3,999/yr", free: "10 inv/mo", highlight: true },
  { name: "myBillBook", starter: "₹399/yr", pro: "₹2,999/yr", annual: "₹399–₹2,999/yr", free: "14-day trial" },
  { name: "Vyapar", starter: "₹222/mo*", pro: "₹640/mo*", annual: "₹8,000–₹23,010/3yr", free: "Mobile free" },
  { name: "Zoho Invoice", starter: "Free", pro: "₹749/mo", annual: "Free–₹8,988/yr", free: "Free forever" },
  { name: "Swipe", starter: "₹399/mo", pro: "₹999/mo", annual: "₹4,788–₹11,988/yr", free: "25 inv/mo" },
];

const COST_BREAKDOWN = {
  infrastructure: [
    { item: "Firebase Auth", unitCost: "Free up to 50K MAU", monthlyCost: 0, note: "Google Sign-In, no SMS OTP cost" },
    { item: "Firestore Reads", unitCost: "$0.06/100K reads", monthlyCost: 0.54, note: "~900K reads/mo at 500 users" },
    { item: "Firestore Writes", unitCost: "$0.18/100K writes", monthlyCost: 0.36, note: "~200K writes/mo at 500 users" },
    { item: "Firestore Storage", unitCost: "$0.18/GB", monthlyCost: 0.18, note: "~1 GB at 500 users" },
    { item: "Cloud Functions", unitCost: "$0.40/M invocations", monthlyCost: 0.80, note: "~2M invocations/mo" },
    { item: "Firebase Hosting", unitCost: "$0.026/GB transfer", monthlyCost: 0.13, note: "~5 GB/mo bandwidth" },
    { item: "Cloud Messaging (FCM)", unitCost: "Free", monthlyCost: 0, note: "Push notifications free" },
    { item: "App Check (reCAPTCHA)", unitCost: "Free up to 10K/mo", monthlyCost: 0, note: "Security verification" },
  ],
  operations: [
    { item: "Google Play Developer", unitCost: "$25 one-time", monthlyCost: 2.08, note: "Amortized over 12 months" },
    { item: "Apple Developer Program", unitCost: "$99/year", monthlyCost: 8.25, note: "Required for App Store" },
    { item: "Domain & SSL", unitCost: "~$12/year", monthlyCost: 1.0, note: "Custom domain for web app" },
    { item: "Error Monitoring (Sentry)", unitCost: "Free tier", monthlyCost: 0, note: "Up to 5K events/mo" },
  ],
  payments: [
    { item: "Razorpay Gateway", unitCost: "2% per transaction", monthlyCost: "Variable", note: "Standard Indian gateway" },
    { item: "Razorpay Subscriptions", unitCost: "₹0 platform fee", monthlyCost: 0, note: "Recurring billing management" },
    { item: "GST on SaaS Revenue", unitCost: "18% of revenue", monthlyCost: "Variable", note: "Mandatory for SaaS in India" },
  ],
};

const REVENUE_PROJECTIONS = [
  { month: "M1", users: 200, free: 180, starter: 15, pro: 5, mrr: 5480 },
  { month: "M3", users: 800, free: 680, starter: 85, pro: 35, mrr: 34415 },
  { month: "M6", users: 2500, free: 2050, starter: 310, pro: 140, mrr: 131510 },
  { month: "M12", users: 8000, free: 6400, starter: 1100, pro: 500, mrr: 468400 },
  { month: "M18", users: 18000, free: 14000, starter: 2700, pro: 1300, mrr: 1184800 },
  { month: "M24", users: 35000, free: 27000, starter: 5200, pro: 2800, mrr: 2432600 },
];

const CRITICAL_ISSUES = [
  { severity: "critical", title: "Zero Quota Enforcement", desc: "Free users can create unlimited invoices/customers/products — plan limits exist in code but are never checked on save operations." },
  { severity: "critical", title: "No Payment Integration", desc: "Upgrade button shows 'Contact support' snackbar. No Razorpay/Stripe integration exists. Users literally cannot pay you." },
  { severity: "high", title: "No Firestore Rules for Quotas", desc: "Security rules don't enforce plan limits at the database level. A savvy user could bypass client-side checks entirely." },
  { severity: "high", title: "No Subscription Webhooks", desc: "No backend to handle payment confirmations, renewals, failures, or grace periods." },
  { severity: "medium", title: "Monthly Invoice Reset Missing", desc: "No mechanism to reset monthly invoice counts. The canCreateInvoice() method exists but is never called." },
  { severity: "medium", title: "No Annual Billing Option", desc: "Only monthly pricing defined. Annual billing (with discount) is standard and increases LTV significantly." },
];

// ─── COMPONENTS ──────────────────────────────────────────────────────

function Section({ title, subtitle, icon, children, id }) {
  return (
    <div id={id} style={{ marginBottom: 48 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 8 }}>
        {icon && <span style={{ color: COLORS.accent }}>{icon}</span>}
        <h2 style={{ fontSize: 24, fontWeight: 700, color: COLORS.white, margin: 0 }}>{title}</h2>
      </div>
      {subtitle && <p style={{ color: COLORS.textMuted, fontSize: 14, margin: "4px 0 20px 0" }}>{subtitle}</p>}
      {children}
    </div>
  );
}

function StatCard({ label, value, sub, color = COLORS.accent }) {
  return (
    <div style={{
      background: COLORS.card, border: `1px solid ${COLORS.border}`, borderRadius: 12,
      padding: "20px 24px", flex: "1 1 200px", minWidth: 180,
    }}>
      <div style={{ color: COLORS.textMuted, fontSize: 13, marginBottom: 6 }}>{label}</div>
      <div style={{ color, fontSize: 28, fontWeight: 800, lineHeight: 1.1 }}>{value}</div>
      {sub && <div style={{ color: COLORS.textDim, fontSize: 12, marginTop: 4 }}>{sub}</div>}
    </div>
  );
}

function CriticalIssuesPanel() {
  const [expanded, setExpanded] = useState(true);
  const severityColors = { critical: COLORS.red, high: COLORS.orange, medium: COLORS.textMuted };
  const severityBg = { critical: COLORS.redGlow, high: COLORS.orangeGlow, medium: "rgba(107,114,128,0.1)" };
  return (
    <div style={{ background: COLORS.card, border: `1px solid ${COLORS.red}33`, borderRadius: 14, overflow: "hidden", marginBottom: 32 }}>
      <button onClick={() => setExpanded(!expanded)} style={{
        width: "100%", display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "18px 24px", background: COLORS.redGlow, border: "none", cursor: "pointer", color: COLORS.red,
      }}>
        <span style={{ display: "flex", alignItems: "center", gap: 10, fontWeight: 700, fontSize: 16 }}>
          <AlertTriangle size={20} /> {CRITICAL_ISSUES.length} Issues Found in Current Implementation
        </span>
        {expanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
      </button>
      {expanded && (
        <div style={{ padding: "16px 24px 24px" }}>
          {CRITICAL_ISSUES.map((issue, i) => (
            <div key={i} style={{
              display: "flex", gap: 14, alignItems: "flex-start", padding: "14px 0",
              borderBottom: i < CRITICAL_ISSUES.length - 1 ? `1px solid ${COLORS.border}` : "none",
            }}>
              <span style={{
                background: severityBg[issue.severity], color: severityColors[issue.severity],
                fontSize: 11, fontWeight: 700, padding: "3px 10px", borderRadius: 20, whiteSpace: "nowrap",
                textTransform: "uppercase", letterSpacing: 0.5,
              }}>{issue.severity}</span>
              <div>
                <div style={{ color: COLORS.white, fontWeight: 600, fontSize: 14 }}>{issue.title}</div>
                <div style={{ color: COLORS.textMuted, fontSize: 13, marginTop: 3, lineHeight: 1.5 }}>{issue.desc}</div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function PricingToggle({ isAnnual, setIsAnnual }) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 14, marginBottom: 32 }}>
      <span style={{ color: !isAnnual ? COLORS.white : COLORS.textMuted, fontWeight: 600, fontSize: 15 }}>Monthly</span>
      <button onClick={() => setIsAnnual(!isAnnual)} style={{
        width: 56, height: 30, borderRadius: 15, border: "none", cursor: "pointer", position: "relative",
        background: isAnnual ? COLORS.accent : COLORS.border, transition: "background 0.2s",
      }}>
        <div style={{
          width: 22, height: 22, borderRadius: 11, background: COLORS.white, position: "absolute",
          top: 4, left: isAnnual ? 30 : 4, transition: "left 0.2s",
        }} />
      </button>
      <span style={{ color: isAnnual ? COLORS.white : COLORS.textMuted, fontWeight: 600, fontSize: 15 }}>
        Annual <span style={{ color: COLORS.green, fontSize: 12, fontWeight: 700 }}>Save 33%</span>
      </span>
    </div>
  );
}

function PricingCard({ plan, isAnnual }) {
  const price = isAnnual ? Math.round(plan.yearlyPrice / 12) : plan.monthlyPrice;
  const totalAnnual = plan.yearlyPrice;
  return (
    <div style={{
      background: plan.popular ? `linear-gradient(135deg, ${COLORS.accentGlow}, ${COLORS.card})` : COLORS.card,
      border: `1px solid ${plan.popular ? COLORS.accent + "55" : COLORS.border}`,
      borderRadius: 16, padding: 28, flex: "1 1 280px", minWidth: 260, maxWidth: 360,
      position: "relative", display: "flex", flexDirection: "column",
    }}>
      {plan.popular && (
        <div style={{
          position: "absolute", top: -12, left: "50%", transform: "translateX(-50%)",
          background: `linear-gradient(90deg, ${COLORS.accent}, ${COLORS.accentLight})`,
          color: COLORS.white, fontSize: 11, fontWeight: 700, padding: "5px 18px",
          borderRadius: 20, textTransform: "uppercase", letterSpacing: 1,
        }}>Most Popular</div>
      )}
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 4 }}>
        <span style={{ color: plan.color }}>{plan.icon}</span>
        <span style={{ color: COLORS.white, fontSize: 20, fontWeight: 700 }}>{plan.name}</span>
      </div>
      <p style={{ color: COLORS.textMuted, fontSize: 13, margin: "2px 0 18px" }}>{plan.tagline}</p>
      <div style={{ marginBottom: 18 }}>
        <span style={{ color: COLORS.white, fontSize: 40, fontWeight: 800 }}>
          {price === 0 ? "Free" : `₹${price}`}
        </span>
        {price > 0 && <span style={{ color: COLORS.textMuted, fontSize: 14 }}>/mo</span>}
        {isAnnual && price > 0 && (
          <div style={{ color: COLORS.textDim, fontSize: 12, marginTop: 2 }}>₹{totalAnnual} billed annually</div>
        )}
      </div>
      <div style={{
        background: "rgba(255,255,255,0.03)", borderRadius: 10, padding: "12px 14px", marginBottom: 18,
        display: "flex", gap: 14, flexWrap: "wrap",
      }}>
        <div><span style={{ color: COLORS.white, fontWeight: 700, fontSize: 15 }}>{plan.limits.invoices}</span><span style={{ color: COLORS.textMuted, fontSize: 12 }}> inv/mo</span></div>
        <div><span style={{ color: COLORS.white, fontWeight: 700, fontSize: 15 }}>{plan.limits.customers}</span><span style={{ color: COLORS.textMuted, fontSize: 12 }}> customers</span></div>
        <div><span style={{ color: COLORS.white, fontWeight: 700, fontSize: 15 }}>{plan.limits.products}</span><span style={{ color: COLORS.textMuted, fontSize: 12 }}> products</span></div>
      </div>
      <div style={{ flex: 1 }}>
        {plan.features.map((f, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 10, padding: "6px 0" }}>
            {f.included
              ? <Check size={15} color={COLORS.green} strokeWidth={3} />
              : <X size={15} color={COLORS.textDim} strokeWidth={2} />}
            <span style={{ color: f.included ? COLORS.text : COLORS.textDim, fontSize: 13.5 }}>{f.name}</span>
          </div>
        ))}
      </div>
      <button style={{
        marginTop: 20, width: "100%", padding: "13px 0", borderRadius: 10, border: "none",
        fontWeight: 700, fontSize: 15, cursor: "pointer", transition: "all 0.2s",
        background: plan.popular ? `linear-gradient(90deg, ${COLORS.accent}, ${COLORS.accentLight})` : "rgba(255,255,255,0.08)",
        color: COLORS.white,
      }}>
        {price === 0 ? "Get Started Free" : `Choose ${plan.name}`}
      </button>
    </div>
  );
}

function CompetitorTable() {
  return (
    <div style={{ overflowX: "auto" }}>
      <table style={{ width: "100%", borderCollapse: "separate", borderSpacing: 0, fontSize: 13.5 }}>
        <thead>
          <tr>
            {["Platform", "Free Tier", "Starter", "Pro / Premium", "Annual Range"].map((h, i) => (
              <th key={i} style={{
                textAlign: "left", padding: "12px 16px", color: COLORS.textMuted, fontWeight: 600,
                borderBottom: `1px solid ${COLORS.border}`, fontSize: 12, textTransform: "uppercase", letterSpacing: 0.5,
              }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {COMPETITORS.map((c, i) => (
            <tr key={i} style={{
              background: c.highlight ? COLORS.accentGlow : "transparent",
            }}>
              <td style={{ padding: "12px 16px", color: c.highlight ? COLORS.accent : COLORS.white, fontWeight: c.highlight ? 700 : 500, borderBottom: `1px solid ${COLORS.border}` }}>
                {c.name} {c.highlight && <span style={{ fontSize: 10, background: COLORS.accent, color: "#fff", padding: "2px 8px", borderRadius: 10, marginLeft: 6 }}>NEW</span>}
              </td>
              <td style={{ padding: "12px 16px", color: COLORS.text, borderBottom: `1px solid ${COLORS.border}` }}>{c.free}</td>
              <td style={{ padding: "12px 16px", color: COLORS.text, borderBottom: `1px solid ${COLORS.border}` }}>{c.starter}</td>
              <td style={{ padding: "12px 16px", color: COLORS.text, borderBottom: `1px solid ${COLORS.border}` }}>{c.pro}</td>
              <td style={{ padding: "12px 16px", color: COLORS.textMuted, borderBottom: `1px solid ${COLORS.border}` }}>{c.annual}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function CostTable({ items, title }) {
  const totalFixed = items.reduce((sum, item) => sum + (typeof item.monthlyCost === "number" ? item.monthlyCost : 0), 0);
  return (
    <div style={{ marginBottom: 24 }}>
      <h4 style={{ color: COLORS.textMuted, fontSize: 12, textTransform: "uppercase", letterSpacing: 1, margin: "0 0 12px" }}>{title}</h4>
      <table style={{ width: "100%", borderCollapse: "separate", borderSpacing: 0, fontSize: 13 }}>
        <thead>
          <tr>
            {["Service", "Unit Cost", "Est. Monthly", "Notes"].map((h, i) => (
              <th key={i} style={{
                textAlign: "left", padding: "10px 14px", color: COLORS.textDim, fontWeight: 600,
                borderBottom: `1px solid ${COLORS.border}`, fontSize: 11, textTransform: "uppercase",
              }}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {items.map((item, i) => (
            <tr key={i}>
              <td style={{ padding: "10px 14px", color: COLORS.white, borderBottom: `1px solid ${COLORS.border}` }}>{item.item}</td>
              <td style={{ padding: "10px 14px", color: COLORS.text, borderBottom: `1px solid ${COLORS.border}`, fontFamily: "monospace" }}>{item.unitCost}</td>
              <td style={{ padding: "10px 14px", color: typeof item.monthlyCost === "number" ? COLORS.green : COLORS.orange, borderBottom: `1px solid ${COLORS.border}`, fontWeight: 600, fontFamily: "monospace" }}>
                {typeof item.monthlyCost === "number" ? `$${item.monthlyCost.toFixed(2)}` : item.monthlyCost}
              </td>
              <td style={{ padding: "10px 14px", color: COLORS.textDim, borderBottom: `1px solid ${COLORS.border}`, fontSize: 12 }}>{item.note}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan={2} style={{ padding: "12px 14px", color: COLORS.white, fontWeight: 700 }}>Subtotal (fixed)</td>
            <td style={{ padding: "12px 14px", color: COLORS.green, fontWeight: 800, fontFamily: "monospace" }}>${totalFixed.toFixed(2)}</td>
            <td></td>
          </tr>
        </tfoot>
      </table>
    </div>
  );
}

function RevenueChart() {
  const maxMrr = Math.max(...REVENUE_PROJECTIONS.map(r => r.mrr));
  return (
    <div style={{ display: "flex", gap: 12, alignItems: "flex-end", height: 220, padding: "0 8px" }}>
      {REVENUE_PROJECTIONS.map((r, i) => {
        const h = (r.mrr / maxMrr) * 180;
        return (
          <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
            <span style={{ color: COLORS.textMuted, fontSize: 11, fontWeight: 600 }}>₹{(r.mrr / 1000).toFixed(0)}K</span>
            <div style={{
              width: "100%", maxWidth: 60, height: h, borderRadius: "8px 8px 4px 4px",
              background: `linear-gradient(180deg, ${COLORS.accent}, ${COLORS.accent}88)`,
              transition: "height 0.5s",
            }} />
            <span style={{ color: COLORS.textDim, fontSize: 12, fontWeight: 600 }}>{r.month}</span>
            <span style={{ color: COLORS.textMuted, fontSize: 10 }}>{r.users} users</span>
          </div>
        );
      })}
    </div>
  );
}

function StrategySection() {
  const strategies = [
    {
      phase: "Phase 1 — Foundation (Weeks 1–4)",
      color: COLORS.red,
      items: [
        "Integrate Razorpay Subscriptions for payment processing",
        "Enforce plan limits in client_service, product_service, and create_invoice_screen",
        "Add Firestore security rules for server-side quota enforcement",
        "Implement subscription webhook handler in Cloud Functions",
        "Add annual billing toggle (33% discount vs monthly)",
      ]
    },
    {
      phase: "Phase 2 — Growth Levers (Weeks 5–8)",
      color: COLORS.orange,
      items: [
        "Launch 14-day Pro trial for all new signups (no card required)",
        "Implement soft-limit warnings at 80% usage (nudge to upgrade)",
        "Add in-app upgrade modal with comparison matrix",
        "Build referral program: give 1 month free Starter for each referral",
        "Increase Free tier limits to 10/15/30 to be competitive with Swipe",
      ]
    },
    {
      phase: "Phase 3 — Retention & Expansion (Weeks 9–16)",
      color: COLORS.green,
      items: [
        "Add e-Invoice support (critical competitive gap identified in brief)",
        "Launch multi-user / team plan as Enterprise tier (₹999/mo)",
        "Implement annual lock-in with 2-months-free incentive",
        "Build churn prediction using usage analytics",
        "Add Starter→Pro upgrade path with prorated billing",
      ]
    },
  ];

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
      {strategies.map((s, i) => (
        <div key={i} style={{
          background: COLORS.card, border: `1px solid ${COLORS.border}`, borderRadius: 14,
          borderLeft: `4px solid ${s.color}`, padding: "20px 24px",
        }}>
          <h4 style={{ color: s.color, fontSize: 16, fontWeight: 700, margin: "0 0 14px" }}>{s.phase}</h4>
          {s.items.map((item, j) => (
            <div key={j} style={{ display: "flex", alignItems: "flex-start", gap: 10, padding: "5px 0" }}>
              <ArrowRight size={14} color={s.color} style={{ marginTop: 3, flexShrink: 0 }} />
              <span style={{ color: COLORS.text, fontSize: 13.5, lineHeight: 1.5 }}>{item}</span>
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

function UnitEconomicsCard() {
  const starterArpu = 199;
  const proArpu = 499;
  const blendedArpu = Math.round(starterArpu * 0.6 + proArpu * 0.4);
  const costPerUser = 0.25;
  const cac = 120;
  const ltv = blendedArpu * 14;
  const ltvCac = (ltv / cac).toFixed(1);
  const payback = (cac / blendedArpu).toFixed(1);

  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 16 }}>
      <StatCard label="Blended ARPU" value={`₹${blendedArpu}`} sub="60% Starter / 40% Pro mix" color={COLORS.accent} />
      <StatCard label="Cost per User" value={`₹${(costPerUser * 85).toFixed(0)}`} sub="~$0.25 Firebase at 500 users" color={COLORS.green} />
      <StatCard label="Est. CAC" value="₹120" sub="Meta/Google ads for SMBs" color={COLORS.orange} />
      <StatCard label="LTV : CAC" value={`${ltvCac}x`} sub={`LTV ₹${ltv.toLocaleString()} (14-mo avg life)`} color={COLORS.green} />
      <StatCard label="Payback Period" value={`${payback} mo`} sub="Months to recover CAC" color={COLORS.accent} />
      <StatCard label="Gross Margin" value="~94%" sub="Minimal infra cost per user" color={COLORS.green} />
    </div>
  );
}

// ─── MAIN APP ────────────────────────────────────────────────────────

export default function BillRajaPricingStrategy() {
  const [isAnnual, setIsAnnual] = useState(false);
  const [activeTab, setActiveTab] = useState("overview");

  const tabs = [
    { id: "overview", label: "Overview" },
    { id: "pricing", label: "Pricing Plans" },
    { id: "costs", label: "Cost Analysis" },
    { id: "strategy", label: "Strategy" },
    { id: "projections", label: "Projections" },
  ];

  const totalMonthlyCost = useMemo(() => {
    return Object.values(COST_BREAKDOWN).flat().reduce(
      (sum, item) => sum + (typeof item.monthlyCost === "number" ? item.monthlyCost : 0), 0
    );
  }, []);

  return (
    <div style={{
      background: COLORS.bg, color: COLORS.text, fontFamily: "'Inter', -apple-system, sans-serif",
      minHeight: "100vh", padding: "0",
    }}>
      {/* Header */}
      <div style={{
        background: `linear-gradient(135deg, ${COLORS.bg}, #1a1030)`,
        borderBottom: `1px solid ${COLORS.border}`, padding: "36px 32px 24px",
      }}>
        <div style={{ maxWidth: 1100, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 8 }}>
            <div style={{
              width: 44, height: 44, borderRadius: 12,
              background: `linear-gradient(135deg, ${COLORS.accent}, ${COLORS.accentLight})`,
              display: "flex", alignItems: "center", justifyContent: "center",
            }}>
              <Crown size={24} color="#fff" />
            </div>
            <div>
              <h1 style={{ fontSize: 26, fontWeight: 800, color: COLORS.white, margin: 0 }}>BillRaja — Pricing Strategy & Cost Analysis</h1>
              <p style={{ color: COLORS.textMuted, fontSize: 13, margin: "4px 0 0" }}>Complete monetization playbook with infrastructure cost estimates</p>
            </div>
          </div>
          {/* Tabs */}
          <div style={{ display: "flex", gap: 4, marginTop: 20, overflowX: "auto" }}>
            {tabs.map(tab => (
              <button key={tab.id} onClick={() => setActiveTab(tab.id)} style={{
                padding: "10px 20px", borderRadius: 8, border: "none", cursor: "pointer",
                fontWeight: 600, fontSize: 13.5, transition: "all 0.2s",
                background: activeTab === tab.id ? COLORS.accent : "transparent",
                color: activeTab === tab.id ? "#fff" : COLORS.textMuted,
              }}>{tab.label}</button>
            ))}
          </div>
        </div>
      </div>

      {/* Content */}
      <div style={{ maxWidth: 1100, margin: "0 auto", padding: "32px 32px 64px" }}>

        {/* OVERVIEW TAB */}
        {activeTab === "overview" && (
          <>
            <CriticalIssuesPanel />

            <Section title="Current vs Proposed at a Glance" icon={<TrendingUp size={22} />}>
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: 20 }}>
                <div style={{ background: COLORS.card, border: `1px solid ${COLORS.border}`, borderRadius: 14, padding: 24 }}>
                  <h4 style={{ color: COLORS.red, fontSize: 14, fontWeight: 700, margin: "0 0 14px", textTransform: "uppercase", letterSpacing: 0.5 }}>Current Pricing (Problems)</h4>
                  <div style={{ color: COLORS.text, fontSize: 13.5, lineHeight: 1.8 }}>
                    <div>• Starter at ₹299/mo = ₹3,588/yr — <span style={{color: COLORS.red}}>2.5x more than myBillBook's ₹399/yr</span></div>
                    <div>• Pro at ₹699/mo = ₹8,388/yr — <span style={{color: COLORS.red}}>above Vyapar Gold at ₹2,667/yr</span></div>
                    <div>• Free tier only 5 invoices — <span style={{color: COLORS.red}}>Swipe gives 25, Zoho gives unlimited</span></div>
                    <div>• No annual billing option — <span style={{color: COLORS.red}}>missing 33% discount lever</span></div>
                    <div>• Zero enforcement — <span style={{color: COLORS.red}}>plans exist on paper only</span></div>
                  </div>
                </div>
                <div style={{ background: COLORS.card, border: `1px solid ${COLORS.accent}33`, borderRadius: 14, padding: 24 }}>
                  <h4 style={{ color: COLORS.green, fontSize: 14, fontWeight: 700, margin: "0 0 14px", textTransform: "uppercase", letterSpacing: 0.5 }}>Proposed Pricing (Solutions)</h4>
                  <div style={{ color: COLORS.text, fontSize: 13.5, lineHeight: 1.8 }}>
                    <div>• Starter at ₹199/mo or <span style={{color: COLORS.green}}>₹1,499/yr (₹125/mo) — competitive</span></div>
                    <div>• Pro at ₹499/mo or <span style={{color: COLORS.green}}>₹3,999/yr (₹333/mo) — value positioned</span></div>
                    <div>• Free tier bumped to 10 inv/mo — <span style={{color: COLORS.green}}>competitive with Swipe</span></div>
                    <div>• Annual billing with 33% savings — <span style={{color: COLORS.green}}>increases LTV & retention</span></div>
                    <div>• Full enforcement + Razorpay — <span style={{color: COLORS.green}}>real revenue from day one</span></div>
                  </div>
                </div>
              </div>
            </Section>

            <Section title="Unit Economics" subtitle="Key metrics for the proposed pricing model" icon={<DollarSign size={22} />}>
              <UnitEconomicsCard />
            </Section>
          </>
        )}

        {/* PRICING TAB */}
        {activeTab === "pricing" && (
          <>
            <Section title="Proposed Pricing Plans" subtitle="Optimized for the Indian SMB market with annual billing incentive" icon={<Crown size={22} />}>
              <PricingToggle isAnnual={isAnnual} setIsAnnual={setIsAnnual} />
              <div style={{ display: "flex", gap: 20, flexWrap: "wrap", justifyContent: "center" }}>
                {PROPOSED_PLANS.map(plan => (
                  <PricingCard key={plan.id} plan={plan} isAnnual={isAnnual} />
                ))}
              </div>
            </Section>

            <Section title="Competitive Pricing Landscape" subtitle="How BillRaja stacks up against the Indian billing software market" icon={<Users size={22} />}>
              <CompetitorTable />
              <div style={{ background: COLORS.accentGlow, borderRadius: 10, padding: "14px 18px", marginTop: 16 }}>
                <p style={{ color: COLORS.accentLight, fontSize: 13, margin: 0, lineHeight: 1.6 }}>
                  <strong>Positioning:</strong> BillRaja's proposed annual pricing (₹1,499–₹3,999/yr) sits between myBillBook's aggressive ₹399/yr and Vyapar's ₹8,000/3yr, targeting the "quality + affordability" sweet spot. The generous Free tier (10 inv/mo) competes with Swipe while the Pro tier undercuts Zoho Books' ₹749/mo.
                </p>
              </div>
            </Section>
          </>
        )}

        {/* COSTS TAB */}
        {activeTab === "costs" && (
          <>
            <Section title="Infrastructure Cost Breakdown" subtitle="Estimated monthly costs at ~500 active users (Firebase Blaze plan)" icon={<Server size={22} />}>
              <CostTable items={COST_BREAKDOWN.infrastructure} title="Firebase & Cloud Services" />
              <CostTable items={COST_BREAKDOWN.operations} title="Operational Costs" />
              <CostTable items={COST_BREAKDOWN.payments} title="Payment Processing" />
              <div style={{
                background: `linear-gradient(135deg, ${COLORS.greenGlow}, ${COLORS.card})`,
                border: `1px solid ${COLORS.green}33`, borderRadius: 14, padding: 24, marginTop: 8,
              }}>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 24, alignItems: "center" }}>
                  <div>
                    <div style={{ color: COLORS.textMuted, fontSize: 12, textTransform: "uppercase", letterSpacing: 1 }}>Total Fixed Monthly Cost</div>
                    <div style={{ color: COLORS.green, fontSize: 32, fontWeight: 800 }}>${totalMonthlyCost.toFixed(2)}</div>
                    <div style={{ color: COLORS.textDim, fontSize: 12 }}>≈ ₹{Math.round(totalMonthlyCost * 85).toLocaleString()}/mo at 500 users</div>
                  </div>
                  <div style={{ flex: 1, minWidth: 200 }}>
                    <div style={{ color: COLORS.textMuted, fontSize: 13, lineHeight: 1.7 }}>
                      Firebase's generous free tier covers most early-stage costs. At 500 users, your total infra spend is under ₹1,200/mo — giving you ~94% gross margins even on the ₹199/mo Starter plan. The variable costs (Razorpay 2% + 18% GST) apply only to revenue, not to infrastructure.
                    </div>
                  </div>
                </div>
              </div>
            </Section>

            <Section title="Cost Scaling Projections" subtitle="How costs grow as your user base expands">
              <div style={{ display: "flex", flexWrap: "wrap", gap: 16 }}>
                {[
                  { users: "100 users", cost: "$2–5/mo", revenue: "~₹6K MRR", margin: "~97%" },
                  { users: "1,000 users", cost: "$15–30/mo", revenue: "~₹60K MRR", margin: "~96%" },
                  { users: "5,000 users", cost: "$80–150/mo", revenue: "~₹300K MRR", margin: "~95%" },
                  { users: "25,000 users", cost: "$400–800/mo", revenue: "~₹1.5M MRR", margin: "~94%" },
                ].map((s, i) => (
                  <div key={i} style={{
                    background: COLORS.card, border: `1px solid ${COLORS.border}`, borderRadius: 12,
                    padding: "18px 22px", flex: "1 1 220px", minWidth: 200,
                  }}>
                    <div style={{ color: COLORS.accent, fontWeight: 700, fontSize: 15 }}>{s.users}</div>
                    <div style={{ color: COLORS.text, fontSize: 13, marginTop: 8 }}>Infra: <span style={{ color: COLORS.green, fontWeight: 600 }}>{s.cost}</span></div>
                    <div style={{ color: COLORS.text, fontSize: 13 }}>Revenue: <span style={{ fontWeight: 600 }}>{s.revenue}</span></div>
                    <div style={{ color: COLORS.green, fontSize: 13, fontWeight: 700 }}>Margin: {s.margin}</div>
                  </div>
                ))}
              </div>
            </Section>
          </>
        )}

        {/* STRATEGY TAB */}
        {activeTab === "strategy" && (
          <Section title="Go-to-Market Pricing Strategy" subtitle="16-week phased rollout plan" icon={<TrendingUp size={22} />}>
            <StrategySection />
            <div style={{
              background: COLORS.card, border: `1px solid ${COLORS.border}`, borderRadius: 14,
              padding: 24, marginTop: 24,
            }}>
              <h4 style={{ color: COLORS.white, fontSize: 16, fontWeight: 700, margin: "0 0 14px" }}>Key Strategic Principles</h4>
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: 16 }}>
                {[
                  { title: "Land with Free, Expand to Pro", desc: "Generous free tier (10 inv/mo) gets users hooked. Soft limits at 80% usage trigger upgrade nudges. 14-day Pro trial shows full value before asking for money." },
                  { title: "Annual Billing = Retention Moat", desc: "33% annual discount locks users in for 12 months. Reduces churn from ~8% monthly to ~3%. Improves cash flow with upfront annual payments." },
                  { title: "Price Below Vyapar, Above myBillBook", desc: "₹1,499/yr Starter sits above myBillBook's ₹399/yr but delivers more value. ₹3,999/yr Pro undercuts Vyapar Gold's ₹8,000/3yr while offering modern UX." },
                  { title: "E-Invoice is Non-Negotiable", desc: "Competitive brief shows e-Invoice support is absent. This is a dealbreaker for growing businesses. Ship it in Phase 3 to unlock Enterprise tier." },
                ].map((s, i) => (
                  <div key={i} style={{ background: "rgba(255,255,255,0.03)", borderRadius: 10, padding: "16px 18px" }}>
                    <div style={{ color: COLORS.accent, fontWeight: 700, fontSize: 14, marginBottom: 8 }}>{s.title}</div>
                    <div style={{ color: COLORS.textMuted, fontSize: 13, lineHeight: 1.6 }}>{s.desc}</div>
                  </div>
                ))}
              </div>
            </div>
          </Section>
        )}

        {/* PROJECTIONS TAB */}
        {activeTab === "projections" && (
          <>
            <Section title="24-Month Revenue Projections" subtitle="Conservative estimates assuming 5% free→paid conversion, 15% monthly user growth" icon={<TrendingUp size={22} />}>
              <RevenueChart />
              <div style={{ overflowX: "auto", marginTop: 24 }}>
                <table style={{ width: "100%", borderCollapse: "separate", borderSpacing: 0, fontSize: 13 }}>
                  <thead>
                    <tr>
                      {["Month", "Total Users", "Free", "Starter", "Pro", "MRR", "ARR"].map((h, i) => (
                        <th key={i} style={{
                          textAlign: "left", padding: "10px 14px", color: COLORS.textDim, fontWeight: 600,
                          borderBottom: `1px solid ${COLORS.border}`, fontSize: 11, textTransform: "uppercase",
                        }}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {REVENUE_PROJECTIONS.map((r, i) => (
                      <tr key={i}>
                        <td style={{ padding: "10px 14px", color: COLORS.accent, fontWeight: 700, borderBottom: `1px solid ${COLORS.border}` }}>{r.month}</td>
                        <td style={{ padding: "10px 14px", color: COLORS.white, fontWeight: 600, borderBottom: `1px solid ${COLORS.border}` }}>{r.users.toLocaleString()}</td>
                        <td style={{ padding: "10px 14px", color: COLORS.textMuted, borderBottom: `1px solid ${COLORS.border}` }}>{r.free.toLocaleString()}</td>
                        <td style={{ padding: "10px 14px", color: COLORS.orange, borderBottom: `1px solid ${COLORS.border}` }}>{r.starter.toLocaleString()}</td>
                        <td style={{ padding: "10px 14px", color: COLORS.accent, borderBottom: `1px solid ${COLORS.border}` }}>{r.pro.toLocaleString()}</td>
                        <td style={{ padding: "10px 14px", color: COLORS.green, fontWeight: 700, borderBottom: `1px solid ${COLORS.border}`, fontFamily: "monospace" }}>₹{r.mrr.toLocaleString()}</td>
                        <td style={{ padding: "10px 14px", color: COLORS.green, borderBottom: `1px solid ${COLORS.border}`, fontFamily: "monospace" }}>₹{(r.mrr * 12).toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Section>

            <Section title="Break-Even Analysis" icon={<DollarSign size={22} />}>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 16 }}>
                <StatCard label="Break-Even Point" value="~25 paid users" sub="At ₹199–499/mo blended ARPU" color={COLORS.green} />
                <StatCard label="Month to Break-Even" value="Month 2–3" sub="With organic + low-cost acquisition" color={COLORS.accent} />
                <StatCard label="Year 1 Projected ARR" value="₹56L" sub="₹4.68L MRR × 12 at Month 12" color={COLORS.green} />
                <StatCard label="Year 2 Projected ARR" value="₹2.9Cr" sub="₹24.3L MRR × 12 at Month 24" color={COLORS.accent} />
              </div>
            </Section>
          </>
        )}
      </div>
    </div>
  );
}
