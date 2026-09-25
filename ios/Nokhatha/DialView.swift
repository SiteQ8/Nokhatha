// The year dial, the same drawing as the web: today is the pearl at the top, time runs
// clockwise, each Gulf season is a segment sized by its days, due tasks are dots.
import NokhathaKit
import SwiftUI

struct DialDot: Hashable {
    let days: Int
    let status: String
}

struct DialView: View {
    let today: Day
    let catalog: Catalog
    let dots: [DialDot]
    let center: Words.Center

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Canvas { ctx, size in draw(ctx, size) }
                VStack(spacing: side * 0.012) {
                    Text(center.title).font(Theme.display(side * 0.12)).foregroundStyle(Theme.ink)
                    Text(center.line1).font(Theme.body(side * 0.04)).foregroundStyle(Theme.ink2)
                    Text(center.line2).font(Theme.body(side * 0.042, "SemiBold")).foregroundStyle(Theme.ink)
                }
                .multilineTextAlignment(.center)
                .frame(width: side * 0.62)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(center.title)، \(center.line2)")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let s = min(size.width, size.height)
        let k = s / 400
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let rOut = 184 * k, rIn = 154 * k
        let ring = seasonRing(today, catalog.seasons)
        let per = 360 / Double(ring.total)
        func ang(_ off: Double) -> Double { -90 + off * per }
        func pt(_ r: Double, _ deg: Double) -> CGPoint {
            CGPoint(x: c.x + r * cos(deg * .pi / 180), y: c.y + r * sin(deg * .pi / 180))
        }
        func sector(_ a1: Double, _ a2: Double, _ r1: Double, _ r2: Double) -> Path {
            var p = Path()
            let steps = max(2, Int((a2 - a1) / 1.5))
            for i in 0...steps {
                let a = a1 + (a2 - a1) * Double(i) / Double(steps)
                if i == 0 { p.move(to: pt(r2, a)) } else { p.addLine(to: pt(r2, a)) }
            }
            for i in stride(from: steps, through: 0, by: -1) { p.addLine(to: pt(r1, a1 + (a2 - a1) * Double(i) / Double(steps))) }
            p.closeSubpath()
            return p
        }
        let gap = 0.8
        let groups = Dictionary(uniqueKeysWithValues: catalog.seasons.map { ($0.id, $0.group) })
        for (i, seg) in ring.segs.enumerated() {
            let a1 = ang(Double(seg.offset)) + gap / 2
            let a2 = ang(Double(seg.offset + seg.length)) - gap / 2
            if i == 0 {
                ctx.fill(sector(a1, ang(0), rIn, rOut), with: .color(Theme.ink.opacity(0.42)))
                ctx.fill(sector(ang(0), a2, rIn, rOut), with: .color(Theme.ink))
            } else {
                ctx.fill(sector(a1, a2, rIn, rOut), with: .color(Theme.group(groups[seg.id] ?? "")))
            }
        }
        // Sadu teeth along the current season
        let first = ring.segs[0]
        let t0 = ang(Double(first.offset)) + gap, t1 = ang(Double(first.offset + first.length)) - gap
        let r0 = rOut + 3 * k, r1 = r0 + 9 * k
        let step = (9 * k / r0) * 180 / .pi
        let count = max(1, Int((t1 - t0) / step))
        let start = t0 + (t1 - t0 - Double(count) * step) / 2
        var teeth = Path()
        for i in 0..<count {
            let b = start + Double(i) * step
            teeth.move(to: pt(r0, b)); teeth.addLine(to: pt(r1, b + step / 2)); teeth.addLine(to: pt(r0, b + step)); teeth.closeSubpath()
        }
        ctx.fill(teeth, with: .color(Theme.sadu))
        // month ticks
        var ticks = Path()
        let p = today.ymd
        for i in 0..<13 {
            let mm = (p.m - 1 + i) % 12 + 1, yy = p.y + (p.m - 1 + i) / 12
            let off = Day(y: yy, m: mm, d: 1) - today
            if off < first.offset || off >= first.offset + ring.total { continue }
            ticks.move(to: pt(rIn - 3 * k, ang(Double(off)))); ticks.addLine(to: pt(rIn - 9 * k, ang(Double(off))))
        }
        ctx.stroke(ticks, with: .color(Theme.ink3.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6 * k, lineCap: .round))
        // upcoming dots, stacked inward when they crowd
        var placed: [CGPoint] = []
        let dotR = 6 * k
        for d in dots.filter({ $0.days >= 0 && $0.days < first.offset + ring.total }).sorted(by: { $0.days < $1.days }) {
            let a = ang(max(Double(d.days), 1.5))
            for n in 0..<3 {
                let q = pt(136 * k - Double(n) * 14 * k, a)
                if placed.contains(where: { hypot($0.x - q.x, $0.y - q.y) < dotR * 2 + 1.5 * k }) { continue }
                placed.append(q)
                let color: Color = d.status == "overdue" ? Theme.overdue : ["today", "soon"].contains(d.status) ? Theme.soon : d.status == "sub" ? Theme.ink3 : Theme.ok
                let circle = Path(ellipseIn: CGRect(x: q.x - dotR, y: q.y - dotR, width: dotR * 2, height: dotR * 2))
                ctx.fill(circle, with: .color(color))
                ctx.stroke(circle, with: .color(Theme.bg), lineWidth: 2.4 * k)
                break
            }
        }
        // overdue count beside the pearl
        let late = dots.filter { $0.days < 0 }.count
        if late > 0 {
            let q = pt(132 * k, ang(-min(14, max(8, Double(-first.offset) * 0.5))))
            let r = dotR * 2.3
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)), with: .color(Theme.overdue))
            ctx.draw(Text(verbatim: String(late)).font(.system(size: 15 * k, weight: .bold)).foregroundColor(.white), at: q)
        }
        // today's pearl
        let bead = pt((rIn + rOut) / 2, -90)
        let br = 12 * k
        let rect = CGRect(x: bead.x - br, y: bead.y - br, width: br * 2, height: br * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.white, Color(hex: 0xEEF1F4), Color(hex: 0xBFC7D5)]),
                                                               center: CGPoint(x: rect.minX + br * 0.7, y: rect.minY + br * 0.6), startRadius: 0, endRadius: br * 1.6))
        ctx.stroke(Path(ellipseIn: rect), with: .color(Theme.sadu), lineWidth: 2.6 * k)
    }
}
