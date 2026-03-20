#!/usr/bin/env python3
"""Generate BillRaja Business Plan PDF"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm, cm
from reportlab.lib.colors import HexColor, white, black
from reportlab.pdfgen import canvas
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.platypus import Table, TableStyle
import math

W, H = A4
OUTPUT = "/Users/northeo/Desktop/billeasy/BillRaja_Pricing_Plan.pdf"

# Colors
DARK = HexColor("#0f1117")
CARD_BG = HexColor("#1a1d27")
ACCENT = HexColor("#6366f1")
GREEN = HexColor("#22c55e")
RED = HexColor("#ef4444")
AMBER = HexColor("#f59e0b")
TEAL = HexColor("#14b8a6")
PURPLE = HexColor("#a855f7")
MUTED = HexColor("#9ca3af")
LIGHT_BG = HexColor("#f8f9fa")
WHITE_BG = HexColor("#ffffff")
BORDER = HexColor("#e2e8f0")
DARK_TEXT = HexColor("#1a1a2e")
SUBTITLE = HexColor("#64748b")
RAJA_BLUE = HexColor("#2563eb")
MAHARAJA_GOLD = HexColor("#b45309")
MAHARAJA_BG = HexColor("#fef3c7")
FREE_GREEN = HexColor("#059669")

def draw_rounded_rect(c, x, y, w, h, r, fill=None, stroke=None, stroke_width=1):
    """Draw a rounded rectangle"""
    p = c.beginPath()
    p.roundRect(x, y, w, h, r)
    if fill:
        c.setFillColor(fill)
    if stroke:
        c.setStrokeColor(stroke)
        c.setLineWidth(stroke_width)
    if fill and stroke:
        c.drawPath(p, fill=1, stroke=1)
    elif fill:
        c.drawPath(p, fill=1, stroke=0)
    elif stroke:
        c.drawPath(p, fill=0, stroke=1)

def draw_gradient_rect(c, x, y, w, h, color1, color2, steps=50):
    """Simulate a vertical gradient"""
    step_h = h / steps
    for i in range(steps):
        t = i / steps
        r = color1.red + (color2.red - color1.red) * t
        g = color1.green + (color2.green - color1.green) * t
        b = color1.blue + (color2.blue - color1.blue) * t
        c.setFillColor(HexColor("#%02x%02x%02x" % (int(r*255), int(g*255), int(b*255))))
        c.rect(x, y + h - (i+1)*step_h, w, step_h+0.5, fill=1, stroke=0)

def draw_check(c, x, y, color=GREEN):
    c.setFillColor(color)
    c.circle(x, y+2, 5, fill=1, stroke=0)
    c.setStrokeColor(white)
    c.setLineWidth(1.2)
    c.line(x-2.5, y+2, x-0.5, y)
    c.line(x-0.5, y, x+3, y+4.5)

def draw_cross(c, x, y):
    c.setFillColor(HexColor("#dc2626"))
    c.circle(x, y+2, 5, fill=1, stroke=0)
    c.setStrokeColor(white)
    c.setLineWidth(1.2)
    c.line(x-2, y+4, x+2, y)
    c.line(x-2, y, x+2, y+4)

# ========================================
# PAGE 1 — COVER
# ========================================
def page1_cover(c):
    # Full page gradient background
    draw_gradient_rect(c, 0, 0, W, H, HexColor("#0f0c29"), HexColor("#302b63"))

    # Decorative circles
    c.setFillColor(HexColor("#6366f1"))
    c.setFillAlpha(0.08)
    c.circle(W*0.8, H*0.85, 200, fill=1, stroke=0)
    c.circle(W*0.15, H*0.2, 150, fill=1, stroke=0)
    c.setFillAlpha(0.05)
    c.circle(W*0.5, H*0.5, 300, fill=1, stroke=0)
    c.setFillAlpha(1)

    # Crown icon area
    cy = H * 0.68
    c.setFillColor(HexColor("#fbbf24"))
    c.setFillAlpha(0.15)
    c.circle(W/2, cy, 50, fill=1, stroke=0)
    c.setFillAlpha(1)

    # Crown symbol
    c.setFillColor(AMBER)
    c.setFont("Helvetica-Bold", 40)
    c.drawCentredString(W/2, cy-14, "👑")

    # Title
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 42)
    c.drawCentredString(W/2, H*0.55, "BillRaja")

    c.setFont("Helvetica", 16)
    c.setFillColor(HexColor("#a5b4fc"))
    c.drawCentredString(W/2, H*0.55 - 30, "Business & Pricing Plan 2026")

    # Tagline
    c.setFillColor(HexColor("#94a3b8"))
    c.setFont("Helvetica", 13)
    c.drawCentredString(W/2, H*0.43, "India's Most Affordable GST Billing App")
    c.drawCentredString(W/2, H*0.43 - 20, "Pricing  •  P&L Analysis  •  Competitor Comparison  •  Roadmap")

    # Bottom highlights
    boxes = [
        ("52-80%", "Cheaper than\ncompetitors"),
        ("₹0.20", "Cost per user\nper month"),
        ("98%", "Profit margin\nat scale"),
    ]
    bw = 130
    gap = 20
    total_w = 3*bw + 2*gap
    sx = (W - total_w) / 2
    by = H * 0.18

    for i, (val, label) in enumerate(boxes):
        bx = sx + i*(bw+gap)
        c.setFillColor(white)
        c.setFillAlpha(0.07)
        draw_rounded_rect(c, bx, by, bw, 80, 12, fill=white)
        c.setFillAlpha(1)

        c.setFillColor(AMBER)
        c.setFont("Helvetica-Bold", 22)
        c.drawCentredString(bx + bw/2, by + 50, val)

        c.setFillColor(HexColor("#94a3b8"))
        c.setFont("Helvetica", 9)
        lines = label.split("\n")
        for j, line in enumerate(lines):
            c.drawCentredString(bx + bw/2, by + 30 - j*12, line)

    # Footer
    c.setFillColor(HexColor("#64748b"))
    c.setFont("Helvetica", 9)
    c.drawCentredString(W/2, 30, "Confidential — BillRaja by Luhit Technologies — March 2026")

    c.showPage()

# ========================================
# PAGE 2 — PRICING PLANS
# ========================================
def page2_pricing(c):
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)

    # Header
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 28)
    c.drawCentredString(W/2, H-55, "Pricing Plans")

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 11)
    c.drawCentredString(W/2, H-75, "All prices shown are base prices. 18% GST applicable.")

    # Three plan cards
    card_w = 160
    card_gap = 15
    total_cw = 3*card_w + 2*card_gap
    sx = (W - total_cw) / 2
    card_top = H - 110
    card_h = 420

    plans = [
        {
            "name": "Free",
            "subtitle": "Getting Started",
            "price_base": "₹0",
            "price_sub": "forever free",
            "gst": "",
            "annual": "",
            "color": FREE_GREEN,
            "header_bg": HexColor("#ecfdf5"),
            "features": [
                (True, "20 invoices / month"),
                (True, "10 customers"),
                (True, "20 products"),
                (True, "1 PDF template"),
                (False, "WhatsApp share"),
                (False, "Reports & analytics"),
                (False, "E-Way Bill"),
                (False, "Purchase orders"),
                (False, "Data export"),
            ]
        },
        {
            "name": "Raja",
            "subtitle": "For Growing Business",
            "price_base": "₹126",
            "price_sub": "/ month + GST",
            "gst": "₹149 incl. GST",
            "annual": "₹1,016/yr + GST  (₹1,199 incl.)",
            "annual_save": "Save 33%",
            "color": RAJA_BLUE,
            "header_bg": HexColor("#eff6ff"),
            "badge": "BEST VALUE",
            "features": [
                (True, "50 invoices / month"),
                (True, "50 customers"),
                (True, "50 products"),
                (True, "3 PDF templates"),
                (True, "50 WhatsApp shares/mo"),
                (False, "Reports & analytics"),
                (False, "E-Way Bill"),
                (True, "Purchase orders"),
                (False, "Data export"),
            ]
        },
        {
            "name": "Maharaja",
            "subtitle": "Unlimited Power",
            "price_base": "₹338",
            "price_sub": "/ month + GST",
            "gst": "₹399 incl. GST",
            "annual": "₹2,541/yr + GST  (₹2,999 incl.)",
            "annual_save": "Save 37%",
            "color": HexColor("#7c3aed"),
            "header_bg": HexColor("#faf5ff"),
            "features": [
                (True, "Unlimited invoices"),
                (True, "Unlimited customers"),
                (True, "Unlimited products"),
                (True, "All PDF templates"),
                (True, "200 WhatsApp shares/mo"),
                (True, "Reports & analytics"),
                (True, "E-Way Bill generator"),
                (True, "Purchase orders"),
                (True, "Data export (CSV)"),
            ]
        },
    ]

    for i, plan in enumerate(plans):
        cx = sx + i*(card_w+card_gap)
        cy = card_top - card_h
        color = plan["color"]

        # Card shadow
        c.setFillColor(HexColor("#00000011"))
        draw_rounded_rect(c, cx+2, cy-2, card_w, card_h, 12, fill=HexColor("#d1d5db"))

        # Card background
        draw_rounded_rect(c, cx, cy, card_w, card_h, 12, fill=WHITE_BG, stroke=BORDER if i != 1 else color, stroke_width=1 if i != 1 else 2)

        # Header area
        header_h = 105
        # Clip header with rounded top
        p = c.beginPath()
        r = 12
        hx, hy = cx, cy+card_h-header_h
        hw, hh = card_w, header_h
        p.moveTo(hx+r, hy)
        p.lineTo(hx+hw-r, hy)
        p.lineTo(hx+hw, hy)
        p.lineTo(hx+hw, hy+hh-r)
        p.arcTo(hx+hw-2*r, hy+hh-2*r, hx+hw, hy+hh, -0, 90)
        p.lineTo(hx+r, hy+hh)
        p.arcTo(hx, hy+hh-2*r, hx+2*r, hy+hh, 90, 90)
        p.lineTo(hx, hy)
        p.close()
        c.setFillColor(plan["header_bg"])
        c.drawPath(p, fill=1, stroke=0)

        # Badge
        if "badge" in plan:
            bw_b = 60
            bx_b = cx + card_w - bw_b - 8
            by_b = cy + card_h - 20
            draw_rounded_rect(c, bx_b, by_b, bw_b, 16, 8, fill=AMBER)
            c.setFillColor(black)
            c.setFont("Helvetica-Bold", 6.5)
            c.drawCentredString(bx_b + bw_b/2, by_b + 5, plan["badge"])

        # Plan name
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 20)
        c.drawString(cx+14, cy+card_h-40, plan["name"])

        # Subtitle
        c.setFillColor(SUBTITLE)
        c.setFont("Helvetica", 8)
        c.drawString(cx+14, cy+card_h-54, plan["subtitle"])

        # Price
        c.setFillColor(DARK_TEXT)
        c.setFont("Helvetica-Bold", 24)
        c.drawString(cx+14, cy+card_h-82, plan["price_base"])

        # Price suffix
        c.setFillColor(SUBTITLE)
        c.setFont("Helvetica", 8)
        price_w = c.stringWidth(plan["price_base"], "Helvetica-Bold", 24)
        c.drawString(cx+14+price_w+4, cy+card_h-78, plan["price_sub"])

        # GST note
        if plan["gst"]:
            c.setFillColor(SUBTITLE)
            c.setFont("Helvetica", 7)
            c.drawString(cx+14, cy+card_h-94, plan["gst"])

        # Annual pricing
        if plan.get("annual"):
            ay = cy + card_h - header_h - 22
            draw_rounded_rect(c, cx+8, ay-2, card_w-16, 28, 6, fill=HexColor("#f0fdf4"))
            c.setFillColor(FREE_GREEN)
            c.setFont("Helvetica-Bold", 7)
            c.drawString(cx+14, ay+12, plan.get("annual_save", ""))
            c.setFillColor(DARK_TEXT)
            c.setFont("Helvetica", 6.5)
            c.drawString(cx+14, ay+2, plan["annual"])

        # Features
        feat_start = cy + card_h - header_h - (40 if plan.get("annual") else 18)
        for j, (included, label) in enumerate(plan["features"]):
            fy = feat_start - j*24
            if included:
                draw_check(c, cx+20, fy-3, color)
                c.setFillColor(DARK_TEXT)
            else:
                draw_cross(c, cx+20, fy-3)
                c.setFillColor(HexColor("#9ca3af"))
            c.setFont("Helvetica", 8.5)
            c.drawString(cx+32, fy, label)

    # Launch Offer Box
    offer_y = card_top - card_h - 55
    draw_rounded_rect(c, sx, offer_y, total_cw, 42, 10, fill=HexColor("#fef3c7"), stroke=AMBER, stroke_width=1.5)
    c.setFillColor(MAHARAJA_GOLD)
    c.setFont("Helvetica-Bold", 12)
    c.drawString(sx+14, offer_y+22, "🚀  Launch Offer — First 500 Users")
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica", 9)
    c.drawString(sx+14, offer_y+7, "Raja: ₹678 + GST (₹799 incl.) / year   |   Maharaja: ₹1,694 + GST (₹1,999 incl.) / year")

    # Footer
    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 8)
    c.drawCentredString(W/2, 25, "All prices in INR. GST @18% applicable. Annual plans billed yearly.")

    c.showPage()

# ========================================
# PAGE 3 — PLAN COMPARISON TABLE
# ========================================
def page3_comparison(c):
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)

    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 28)
    c.drawCentredString(W/2, H-55, "Plan Comparison")

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 11)
    c.drawCentredString(W/2, H-75, "Feature-by-feature breakdown across all plans")

    # Comparison table
    table_data = [
        ["Feature", "Free", "Raja (₹126+GST)", "Maharaja (₹338+GST)"],
        ["Monthly Price", "₹0", "₹126 + ₹23 GST", "₹338 + ₹61 GST"],
        ["Annual Price", "₹0", "₹1,016 + ₹183 GST", "₹2,541 + ₹458 GST"],
        ["Invoices / month", "20", "50", "Unlimited"],
        ["Customers", "10", "50", "Unlimited"],
        ["Products", "20", "50", "Unlimited"],
        ["PDF Templates", "1 (Classic)", "3 templates", "All templates"],
        ["WhatsApp Shares", "—", "50 / month", "200 / month"],
        ["GST Reports", "—", "—", "✓ Full"],
        ["E-Way Bill", "—", "—", "✓"],
        ["Purchase Orders", "—", "✓", "✓"],
        ["Data Export (CSV)", "—", "—", "✓"],
        ["Multi-language", "4 languages", "4 languages", "4 languages"],
        ["Email Support", "Community", "Email", "Priority"],
    ]

    col_widths = [130, 100, 120, 130]
    table_w = sum(col_widths)
    tx = (W - table_w) / 2
    ty = H - 110
    row_h = 26

    for i, row in enumerate(table_data):
        ry = ty - i * row_h

        # Row background
        if i == 0:
            draw_rounded_rect(c, tx-4, ry-4, table_w+8, row_h+2, 6, fill=DARK_TEXT)
        elif i % 2 == 0:
            c.setFillColor(HexColor("#f1f5f9"))
            c.rect(tx, ry-4, table_w, row_h, fill=1, stroke=0)

        cx = tx
        for j, cell in enumerate(row):
            if i == 0:
                c.setFillColor(white)
                c.setFont("Helvetica-Bold", 9)
            elif j == 0:
                c.setFillColor(DARK_TEXT)
                c.setFont("Helvetica-Bold", 8.5)
            else:
                c.setFillColor(DARK_TEXT)
                c.setFont("Helvetica", 8.5)
                if cell in ["✓", "✓ Full"]:
                    c.setFillColor(FREE_GREEN)
                    c.setFont("Helvetica-Bold", 9)
                elif cell == "—":
                    c.setFillColor(HexColor("#cbd5e1"))
                elif cell == "Unlimited":
                    c.setFillColor(HexColor("#7c3aed"))
                    c.setFont("Helvetica-Bold", 8.5)

            c.drawString(cx + 8, ry + 4, cell)
            cx += col_widths[j]

    # GST Breakdown Box
    gst_y = ty - len(table_data) * row_h - 40
    box_w = table_w + 8
    draw_rounded_rect(c, tx-4, gst_y, box_w, 90, 10, fill=WHITE_BG, stroke=BORDER)

    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(tx+10, gst_y+65, "GST Breakdown — What You Actually Pay")

    c.setFont("Helvetica", 9)
    c.setFillColor(SUBTITLE)

    gst_items = [
        ("Raja Monthly:", "₹126 base + ₹23 GST = ₹149 total", RAJA_BLUE),
        ("Raja Annual:", "₹1,016 base + ₹183 GST = ₹1,199 total  (₹85/mo effective)", RAJA_BLUE),
        ("Maharaja Monthly:", "₹338 base + ₹61 GST = ₹399 total", PURPLE),
        ("Maharaja Annual:", "₹2,541 base + ₹458 GST = ₹2,999 total  (₹212/mo effective)", PURPLE),
    ]

    for i, (label, detail, color) in enumerate(gst_items):
        iy = gst_y + 45 - i*14
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 8.5)
        c.drawString(tx+16, iy, label)
        c.setFillColor(DARK_TEXT)
        c.setFont("Helvetica", 8.5)
        c.drawString(tx+120, iy, detail)

    # Who should pick what
    pick_y = gst_y - 30
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 14)
    c.drawCentredString(W/2, pick_y, "Which Plan Is Right For You?")

    personas = [
        ("Free", "Freelancers, side hustlers, trying\nout invoicing for the first time", FREE_GREEN, HexColor("#ecfdf5")),
        ("Raja", "Small shops, traders with 10-50\ncustomers, growing businesses", RAJA_BLUE, HexColor("#eff6ff")),
        ("Maharaja", "Established businesses, GST-registered\nfirms, high-volume sellers", PURPLE, HexColor("#faf5ff")),
    ]

    pw = 155
    pgap = 10
    psx = (W - 3*pw - 2*pgap) / 2
    py = pick_y - 80

    for i, (name, desc, color, bg) in enumerate(personas):
        px = psx + i*(pw+pgap)
        draw_rounded_rect(c, px, py, pw, 65, 10, fill=bg, stroke=color, stroke_width=1)
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 12)
        c.drawString(px+12, py+45, name)
        c.setFillColor(DARK_TEXT)
        c.setFont("Helvetica", 7.5)
        lines = desc.split("\n")
        for j, line in enumerate(lines):
            c.drawString(px+12, py+30-j*11, line)

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 8)
    c.drawCentredString(W/2, 25, "BillRaja — India's most affordable GST billing app")

    c.showPage()

# ========================================
# PAGE 4 — PROFIT & LOSS
# ========================================
def page4_pnl(c):
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)

    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 28)
    c.drawCentredString(W/2, H-55, "Profit & Loss Analysis")

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 11)
    c.drawCentredString(W/2, H-75, "Monthly costs, revenue projections, and margins")

    # Cost breakdown
    mx = 40
    box_w = (W - 2*mx - 15) / 2

    # Left: Fixed Costs
    by = H - 105
    bh = 175
    draw_rounded_rect(c, mx, by-bh, box_w, bh, 10, fill=WHITE_BG, stroke=BORDER)
    c.setFillColor(RED)
    c.setFont("Helvetica-Bold", 13)
    c.drawString(mx+14, by-22, "Monthly Fixed Costs")

    costs = [
        ("Firebase (free tier)", "₹0"),
        ("Cloud Functions (minInstances=0)", "₹0"),
        ("Domain + SSL", "₹80"),
        ("Play Store (amortized)", "₹175"),
        ("Apple Developer (amortized)", "₹725"),
        ("Total Fixed Cost", "₹980/mo"),
    ]
    for i, (item, val) in enumerate(costs):
        iy = by - 42 - i*22
        is_total = i == len(costs) - 1
        if is_total:
            c.setStrokeColor(BORDER)
            c.line(mx+14, iy+14, mx+box_w-14, iy+14)
        c.setFillColor(DARK_TEXT if not is_total else RED)
        c.setFont("Helvetica-Bold" if is_total else "Helvetica", 9)
        c.drawString(mx+14, iy, item)
        c.setFont("Helvetica-Bold" if is_total else "Helvetica", 9)
        c.drawRightString(mx+box_w-14, iy, val)

    # Right: Marginal Costs
    rx = mx + box_w + 15
    draw_rounded_rect(c, rx, by-bh, box_w, bh, 10, fill=WHITE_BG, stroke=BORDER)
    c.setFillColor(TEAL)
    c.setFont("Helvetica-Bold", 13)
    c.drawString(rx+14, by-22, "Cost Per User (Marginal)")

    mcosts = [
        ("Firestore reads (500/user/mo)", "₹0.03"),
        ("Firestore writes (50/user/mo)", "₹0.05"),
        ("Storage (PDFs ~2MB/user/mo)", "₹0.02"),
        ("Cloud Functions invocations", "₹0.10"),
        ("Total per user per month", "₹0.20"),
    ]
    for i, (item, val) in enumerate(mcosts):
        iy = by - 42 - i*22
        is_total = i == len(mcosts) - 1
        if is_total:
            c.setStrokeColor(BORDER)
            c.line(rx+14, iy+14, rx+box_w-14, iy+14)
        c.setFillColor(DARK_TEXT if not is_total else TEAL)
        c.setFont("Helvetica-Bold" if is_total else "Helvetica", 9)
        c.drawString(rx+14, iy, item)
        c.drawRightString(rx+box_w-14, iy, val)

    # Revenue Projection Table
    table_y = by - bh - 30
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(mx, table_y, "Year 1 Revenue Projection (New Pricing)")

    proj_data = [
        ["Quarter", "Users", "Paid %", "Paid Users", "Avg Rev/User", "Revenue/mo", "Cost/mo", "Profit/mo", "Margin"],
        ["Q1 (M1-3)", "200", "5%", "10", "₹149", "₹1,490", "₹1,020", "₹470", "31%"],
        ["Q2 (M4-6)", "600", "8%", "48", "₹186", "₹8,928", "₹1,100", "₹7,828", "88%"],
        ["Q3 (M7-9)", "1,500", "10%", "150", "₹199", "₹29,850", "₹1,280", "₹28,570", "96%"],
        ["Q4 (M10-12)", "3,000", "12%", "360", "₹212", "₹76,320", "₹1,580", "₹74,740", "98%"],
    ]

    proj_cols = [70, 42, 38, 50, 62, 62, 55, 60, 42]
    proj_w = sum(proj_cols)
    ptx = (W - proj_w) / 2
    pty = table_y - 20
    prh = 22

    for i, row in enumerate(proj_data):
        ry = pty - i * prh
        if i == 0:
            draw_rounded_rect(c, ptx-4, ry-5, proj_w+8, prh+2, 4, fill=DARK_TEXT)
        elif i % 2 == 0:
            c.setFillColor(HexColor("#f1f5f9"))
            c.rect(ptx, ry-5, proj_w, prh, fill=1, stroke=0)

        cx = ptx
        for j, cell in enumerate(row):
            if i == 0:
                c.setFillColor(white)
                c.setFont("Helvetica-Bold", 7.5)
            else:
                c.setFillColor(DARK_TEXT)
                c.setFont("Helvetica", 8)
                if j == 7:  # Profit column
                    c.setFillColor(GREEN)
                    c.setFont("Helvetica-Bold", 8)
                elif j == 8:  # Margin
                    c.setFillColor(GREEN)
                    c.setFont("Helvetica-Bold", 8)
            c.drawString(cx + 4, ry + 2, cell)
            cx += proj_cols[j]

    # Year 1 summary
    sy = pty - len(proj_data) * prh - 20
    summary_w = proj_w + 8
    draw_rounded_rect(c, ptx-4, sy-5, summary_w, 30, 6, fill=HexColor("#f0fdf4"), stroke=GREEN)
    c.setFillColor(GREEN)
    c.setFont("Helvetica-Bold", 11)
    c.drawString(ptx+8, sy+6, "Year 1 Total:  Revenue ₹3.5L  |  Cost ₹15K  |  Profit ₹3.35L  |  Margin 96%")

    # Key metrics
    ky = sy - 50
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(mx, ky+10, "Key Financial Metrics")

    metrics = [
        ("Break-even", "Month 1", "Just 7 paid users cover all fixed costs", GREEN),
        ("CAC Target", "< ₹50", "Organic + referral + ASO keeps CAC low", RAJA_BLUE),
        ("LTV : CAC", "> 24x", "₹1,199 LTV vs ₹50 CAC = excellent ratio", PURPLE),
        ("Payback", "< 1 month", "Revenue covers cost from month 1", TEAL),
    ]

    mw = (W - 2*mx - 30) / 4
    for i, (label, val, desc, color) in enumerate(metrics):
        mx2 = mx + i*(mw+10)
        draw_rounded_rect(c, mx2, ky-60, mw, 60, 8, fill=WHITE_BG, stroke=BORDER)
        c.setFillColor(SUBTITLE)
        c.setFont("Helvetica", 7.5)
        c.drawString(mx2+10, ky-18, label)
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 16)
        c.drawString(mx2+10, ky-38, val)
        c.setFillColor(SUBTITLE)
        c.setFont("Helvetica", 6.5)
        c.drawString(mx2+10, ky-52, desc)

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 8)
    c.drawCentredString(W/2, 25, "Projections based on organic growth. Paid acquisition would accelerate.")

    c.showPage()

# ========================================
# PAGE 5 — COMPETITOR ANALYSIS
# ========================================
def page5_competitors(c):
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)

    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 28)
    c.drawCentredString(W/2, H-55, "Competitor Pricing")

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 11)
    c.drawCentredString(W/2, H-75, "BillRaja vs market — annual plan comparison")

    # Bar chart comparison
    mx = 50
    chart_top = H - 110
    bar_h = 34
    bar_gap = 10
    max_price = 5999
    bar_area_w = W - 2*mx - 130

    competitors = [
        ("BillRaja Raja", 1199, GREEN, "₹1,199/yr"),
        ("BillRaja Maharaja", 2999, TEAL, "₹2,999/yr"),
        ("myBillBook Silver", 2499, HexColor("#6b7280"), "₹2,499/yr"),
        ("myBillBook Gold", 3999, HexColor("#6b7280"), "₹3,999/yr"),
        ("Vyapar Mini", 2999, HexColor("#6b7280"), "₹2,999/yr"),
        ("Vyapar Pro", 5999, HexColor("#6b7280"), "₹5,999/yr"),
        ("Zoho Invoice Std", 3588, HexColor("#6b7280"), "₹3,588/yr"),
        ("Zoho Invoice Pro", 7188, HexColor("#6b7280"), "₹7,188/yr"),
    ]
    max_p = 7188

    for i, (name, price, color, label) in enumerate(competitors):
        by2 = chart_top - i*(bar_h+bar_gap)
        bw2 = (price / max_p) * bar_area_w

        # Name
        c.setFillColor(DARK_TEXT)
        c.setFont("Helvetica-Bold" if "BillRaja" in name else "Helvetica", 8.5)
        c.drawString(mx, by2+10, name)

        # Bar
        bar_x = mx + 120
        draw_rounded_rect(c, bar_x, by2+2, bw2, 24, 6, fill=color)

        # Price label
        c.setFillColor(DARK_TEXT)
        c.setFont("Helvetica-Bold", 8.5)
        c.drawString(bar_x + bw2 + 8, by2+10, label)

    # Savings callout
    savings_y = chart_top - len(competitors)*(bar_h+bar_gap) - 20
    sw = W - 2*mx
    draw_rounded_rect(c, mx, savings_y, sw, 55, 10, fill=HexColor("#f0fdf4"), stroke=GREEN)
    c.setFillColor(GREEN)
    c.setFont("Helvetica-Bold", 12)
    c.drawString(mx+16, savings_y+32, "💡  You Save Significantly with BillRaja")
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica", 9)
    c.drawString(mx+16, savings_y+16, "vs myBillBook: Save ₹1,300-3,000/yr  |  vs Vyapar: Save ₹1,800-3,000/yr  |  vs Zoho: Save ₹2,389-4,189/yr")
    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 8)
    c.drawString(mx+16, savings_y+4, "That's 52-80% cheaper than every major competitor in the Indian billing app market.")

    # Feature comparison table
    feat_y = savings_y - 30
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(mx, feat_y, "Feature Comparison at Similar Price Points")

    feat_data = [
        ["Feature", "BillRaja Raja\n₹1,199/yr", "myBillBook Silver\n₹2,499/yr", "Vyapar Mini\n₹2,999/yr"],
        ["Invoices/month", "50", "Unlimited", "Unlimited"],
        ["Customers", "50", "Unlimited", "Unlimited"],
        ["PDF Templates", "3", "5+", "8+"],
        ["WhatsApp Share", "✓ Included", "✓ Included", "✓ Included"],
        ["GST Reports", "Maharaja only", "✓", "✓"],
        ["Purchase Orders", "✓ Included", "✗", "✓"],
        ["Multi-language", "4 languages", "Hindi only", "10+"],
        ["Price", "₹1,199/yr", "₹2,499/yr", "₹2,999/yr"],
        ["Savings vs BillRaja", "—", "₹1,300 more", "₹1,800 more"],
    ]

    feat_cols = [100, 110, 110, 110]
    feat_tw = sum(feat_cols)
    ftx = (W - feat_tw) / 2
    fty = feat_y - 20
    frh = 22

    for i, row in enumerate(feat_data):
        ry = fty - i * frh
        if i == 0:
            draw_rounded_rect(c, ftx-4, ry-5, feat_tw+8, frh+2, 4, fill=DARK_TEXT)
        elif i % 2 == 0:
            c.setFillColor(HexColor("#f1f5f9"))
            c.rect(ftx, ry-5, feat_tw, frh, fill=1, stroke=0)

        cx = ftx
        for j, cell in enumerate(row):
            if i == 0:
                c.setFillColor(white)
                c.setFont("Helvetica-Bold", 8)
                # Only first line for header
                cell = cell.split("\n")[0]
            elif j == 0:
                c.setFillColor(DARK_TEXT)
                c.setFont("Helvetica-Bold", 8)
            else:
                c.setFillColor(DARK_TEXT)
                c.setFont("Helvetica", 8)
                if "✓" in cell:
                    c.setFillColor(GREEN)
                elif "✗" in cell:
                    c.setFillColor(RED)
                elif "more" in cell:
                    c.setFillColor(RED)
                elif j == 1 and i == len(feat_data) - 1:
                    c.setFillColor(GREEN)
                    c.setFont("Helvetica-Bold", 8)
            c.drawString(cx + 6, ry + 2, cell)
            cx += feat_cols[j]

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 8)
    c.drawCentredString(W/2, 25, "Prices as of March 2026. Competitor prices from their respective websites.")

    c.showPage()

# ========================================
# PAGE 6 — SCALING ROADMAP
# ========================================
def page6_roadmap(c):
    c.setFillColor(LIGHT_BG)
    c.rect(0, 0, W, H, fill=1, stroke=0)

    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 28)
    c.drawCentredString(W/2, H-55, "Scaling Roadmap")

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 11)
    c.drawCentredString(W/2, H-75, "12-month growth plan from launch to 10,000 users")

    mx = 50
    # Timeline
    phases = [
        ("Q1 2026", "Phase 1: Launch", "Core invoicing, GST, PDF generation, WhatsApp share\nFree + Raja + Maharaja plans go live\nPlay Store + basic ASO", RAJA_BLUE, True),
        ("Q1 2026", "Phase 2: Stickiness", "Inventory management, purchase orders\nProduct catalog, reports dashboard\nReferral system activation", TEAL, True),
        ("Q2 2026", "Phase 3: Growth", "Offline mode, barcode scanner\nRecurring invoices, payment reminders via WhatsApp\nRegional language marketing (Gujarati, Tamil)", GREEN, False),
        ("Q3 2026", "Phase 4: Monetization", "Razorpay/UPI payment collection integration\nAuto-reconciliation, credit notes\nMulti-business support", PURPLE, False),
        ("Q4 2026", "Phase 5: Scale", "E-invoicing (IRN) for GST compliance\nTally/Busy data sync\nStaff accounts & permissions, API access", AMBER, False),
    ]

    tl_x = mx + 50
    tl_top = H - 110
    phase_h = 75

    # Vertical line
    c.setStrokeColor(BORDER)
    c.setLineWidth(2)
    c.line(tl_x, tl_top, tl_x, tl_top - len(phases)*phase_h + 30)

    for i, (quarter, title, desc, color, done) in enumerate(phases):
        py = tl_top - i*phase_h

        # Dot
        if done:
            c.setFillColor(color)
            c.circle(tl_x, py, 7, fill=1, stroke=0)
            c.setFillColor(white)
            c.setFont("Helvetica-Bold", 8)
            c.drawCentredString(tl_x, py-3, "✓")
        else:
            c.setFillColor(LIGHT_BG)
            c.setStrokeColor(color)
            c.setLineWidth(2)
            c.circle(tl_x, py, 7, fill=1, stroke=1)

        # Quarter label
        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 8)
        c.drawRightString(tl_x - 14, py-3, quarter)

        # Title
        c.setFillColor(DARK_TEXT)
        c.setFont("Helvetica-Bold", 11)
        c.drawString(tl_x + 20, py+2, title)

        # Description
        c.setFillColor(SUBTITLE)
        c.setFont("Helvetica", 8)
        lines = desc.split("\n")
        for j, line in enumerate(lines):
            c.drawString(tl_x + 20, py - 12 - j*12, line)

    # Growth targets on right side
    gt_x = W/2 + 30
    gt_w = W - gt_x - mx
    gt_y = tl_top + 10

    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica-Bold", 14)
    c.drawString(gt_x, gt_y, "Growth Targets")

    targets = [
        ("Month 3", "500 users", "25 paid", "₹3,750/mo", RAJA_BLUE),
        ("Month 6", "2,000 users", "160 paid", "₹24K/mo", TEAL),
        ("Month 9", "5,000 users", "500 paid", "₹75K/mo", PURPLE),
        ("Month 12", "10,000 users", "1,200 paid", "₹1.8L/mo", GREEN),
    ]

    for i, (month, users, paid, rev, color) in enumerate(targets):
        ty2 = gt_y - 30 - i*65
        draw_rounded_rect(c, gt_x, ty2, gt_w, 55, 8, fill=WHITE_BG, stroke=color, stroke_width=1.5)

        c.setFillColor(color)
        c.setFont("Helvetica-Bold", 10)
        c.drawString(gt_x+12, ty2+36, month)

        c.setFillColor(DARK_TEXT)
        c.setFont("Helvetica-Bold", 14)
        c.drawString(gt_x+12, ty2+18, users)

        c.setFillColor(SUBTITLE)
        c.setFont("Helvetica", 8)
        c.drawString(gt_x+12, ty2+5, f"{paid}  •  {rev} revenue")

    # Unit economics at bottom
    ue_y = 70
    ue_w = W - 2*mx
    draw_rounded_rect(c, mx, ue_y, ue_w, 50, 10, fill=HexColor("#f0fdf4"), stroke=GREEN)
    c.setFillColor(GREEN)
    c.setFont("Helvetica-Bold", 12)
    c.drawString(mx+16, ue_y+30, "Unit Economics at 10K Users")
    c.setFillColor(DARK_TEXT)
    c.setFont("Helvetica", 9)
    c.drawString(mx+16, ue_y+14, "Cost: ₹3K/mo  →  Revenue: ₹1.8L/mo  →  Profit Margin: 98%")
    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 8)
    c.drawString(mx+16, ue_y+2, "Firebase serverless scales to 100K users within low-cost tiers. No server management or DevOps needed.")

    c.setFillColor(SUBTITLE)
    c.setFont("Helvetica", 8)
    c.drawCentredString(W/2, 25, "BillRaja — Confidential Business Plan — March 2026")

    c.showPage()


# ========================================
# BUILD PDF
# ========================================
c = canvas.Canvas(OUTPUT, pagesize=A4)
c.setTitle("BillRaja Business Plan 2026")
c.setAuthor("Luhit Technologies")

page1_cover(c)
page2_pricing(c)
page3_comparison(c)
page4_pnl(c)
page5_competitors(c)
page6_roadmap(c)

c.save()
print(f"✅ PDF generated: {OUTPUT}")
print(f"   6 pages: Cover, Pricing, Comparison, P&L, Competitors, Roadmap")
