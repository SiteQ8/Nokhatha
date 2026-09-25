// The year dial: today is the pearl at the top, time runs clockwise, each Gulf season is a
// segment sized by its days, due tasks are dots. The same drawing as the web and iPhone.
package com.eworldq8.nokhatha.ui

import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.engine.*
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

data class DialDot(val days: Int, val status: String)

@Composable
fun Dial(today: Day, catalog: Catalog, dots: List<DialDot>, center: Words.Center, modifier: Modifier = Modifier) {
    val p = pal()
    val side = minOf(LocalConfiguration.current.screenWidthDp - 36, 380)
    Box(modifier.fillMaxWidth().semantics { contentDescription = "${center.title}، ${center.line2}" }, contentAlignment = Alignment.Center) {
        Box(Modifier.size(side.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize()) {
                val s = size.minDimension
                val k = s / 400f
                val c = Offset(size.width / 2, size.height / 2)
                val rOut = 184 * k
                val rIn = 154 * k
                val (total, segs) = seasonRing(today, catalog.seasons)
                val per = 360.0 / total
                fun ang(off: Double) = -90 + off * per
                fun pt(r: Float, deg: Double) = Offset(c.x + (r * cos(Math.toRadians(deg))).toFloat(), c.y + (r * sin(Math.toRadians(deg))).toFloat())
                fun sector(a1: Double, a2: Double, r1: Float, r2: Float): Path {
                    val path = Path()
                    val steps = maxOf(2, ((a2 - a1) / 1.5).toInt())
                    for (i in 0..steps) {
                        val q = pt(r2, a1 + (a2 - a1) * i / steps)
                        if (i == 0) path.moveTo(q.x, q.y) else path.lineTo(q.x, q.y)
                    }
                    for (i in steps downTo 0) {
                        val q = pt(r1, a1 + (a2 - a1) * i / steps)
                        path.lineTo(q.x, q.y)
                    }
                    path.close()
                    return path
                }
                val gap = 0.8
                val groups = catalog.seasons.associate { it.id to it.group }
                segs.forEachIndexed { i, seg ->
                    val a1 = ang(seg.offset.toDouble()) + gap / 2
                    val a2 = ang((seg.offset + seg.length).toDouble()) - gap / 2
                    if (i == 0) {
                        drawPath(sector(a1, ang(0.0), rIn, rOut), p.ink.copy(alpha = 0.42f))
                        drawPath(sector(ang(0.0), a2, rIn, rOut), p.ink)
                    } else {
                        drawPath(sector(a1, a2, rIn, rOut), p.group(groups[seg.id] ?: ""))
                    }
                }
                // Sadu teeth along the current season
                val first = segs[0]
                val t0 = ang(first.offset.toDouble()) + gap
                val t1 = ang((first.offset + first.length).toDouble()) - gap
                val r0 = rOut + 3 * k
                val r1 = r0 + 9 * k
                val step = Math.toDegrees((9 * k / r0).toDouble())
                val count = maxOf(1, ((t1 - t0) / step).toInt())
                val start = t0 + (t1 - t0 - count * step) / 2
                val teeth = Path()
                for (i in 0 until count) {
                    val b = start + i * step
                    val a = pt(r0, b); val m = pt(r1, b + step / 2); val e = pt(r0, b + step)
                    teeth.moveTo(a.x, a.y); teeth.lineTo(m.x, m.y); teeth.lineTo(e.x, e.y); teeth.close()
                }
                drawPath(teeth, p.sadu)
                // month ticks
                val (y0, m0, _) = today.ymd
                for (i in 0 until 13) {
                    val mm = (m0 - 1 + i) % 12 + 1
                    val yy = y0 + (m0 - 1 + i) / 12
                    val off = Day.of(yy, mm, 1) - today
                    if (off < first.offset || off >= first.offset + total) continue
                    drawLine(p.ink3.copy(alpha = 0.55f), pt(rIn - 3 * k, ang(off.toDouble())), pt(rIn - 9 * k, ang(off.toDouble())), strokeWidth = 1.6f * k, cap = StrokeCap.Round)
                }
                // upcoming dots, stacked inward when they crowd
                val placed = ArrayList<Offset>()
                val dotR = 6 * k
                for (d in dots.filter { it.days >= 0 && it.days < first.offset + total }.sortedBy { it.days }) {
                    val a = ang(maxOf(d.days.toDouble(), 1.5))
                    for (n in 0 until 3) {
                        val q = pt(136 * k - n * 14 * k, a)
                        if (placed.any { hypot(it.x - q.x, it.y - q.y) < dotR * 2 + 1.5f * k }) continue
                        placed += q
                        val col = when (d.status) {
                            "overdue" -> p.overdue
                            "today", "soon" -> p.soon
                            "sub" -> p.ink3
                            else -> p.ok
                        }
                        drawCircle(col, dotR, q)
                        drawCircle(p.bg, dotR, q, style = Stroke(2.4f * k))
                        break
                    }
                }
                // overdue count beside the pearl
                val late = dots.count { it.days < 0 }
                if (late > 0) {
                    val q = pt(132 * k, ang(-minOf(14.0, maxOf(8.0, -first.offset * 0.5))))
                    drawCircle(p.overdue, dotR * 2.3f, q)
                    drawIntoCanvas {
                        val paint = Paint().apply {
                            color = Color.White.toArgb(); textSize = 15 * k * 1.55f; isAntiAlias = true
                            textAlign = Paint.Align.CENTER; typeface = Typeface.DEFAULT_BOLD
                        }
                        it.nativeCanvas.drawText(late.toString(), q.x, q.y + paint.textSize * 0.36f, paint)
                    }
                }
                // today's pearl
                val bead = pt((rIn + rOut) / 2, -90.0)
                val br = 12 * k
                drawCircle(Brush.radialGradient(listOf(Color.White, Color(0xFFEEF1F4), Color(0xFFBFC7D5)), Offset(bead.x - br * 0.3f, bead.y - br * 0.4f), br * 1.6f), br, bead)
                drawCircle(p.sadu, br, bead, style = Stroke(2.6f * k))
            }
            Column(Modifier.widthIn(max = (side * 0.62f).dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(center.title, style = display((side * 0.105f).toInt()), color = p.ink, textAlign = TextAlign.Center)
                Text(center.line1, style = body((side * 0.037f).toInt()), color = p.ink2, textAlign = TextAlign.Center)
                Text(center.line2, style = body((side * 0.039f).toInt(), FontWeight.SemiBold), color = p.ink, textAlign = TextAlign.Center)
            }
        }
    }
}
