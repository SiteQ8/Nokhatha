// The web app's building blocks, measured from its stylesheets: .top with the season pill,
// .ph and .band, .back, .segc, .chip grids, select, .nav-row, .setting, .empty, .actions.
package com.eworldq8.nokhatha.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.AppModel
import com.eworldq8.nokhatha.FitText
import com.eworldq8.nokhatha.R
import com.eworldq8.nokhatha.engine.seasonAt

/** The web's sticky top bar: the brand at the start and, off Today, the current season in a pill. */
@Composable
fun TopBar(model: AppModel, season: Boolean) {
    val p = pal()
    Row(
        Modifier.fillMaxWidth().background(p.bg.copy(alpha = 0.94f)).statusBarsPadding().padding(horizontal = 18.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            Image(painterResource(R.drawable.mark), null, Modifier.size(30.dp))
            Text(model.t("app.name"), style = title(21, 1.0), color = p.ink)
        }
        Spacer(Modifier.weight(1f))
        if (season) {
            val name = model.catalog.season(seasonAt(model.today, model.catalog.seasons).id)?.name(model.lang) ?: ""
            Row(
                Modifier.clip(CircleShape).background(p.surface).border(1.dp, p.line, CircleShape).padding(horizontal = 12.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp),
            ) {
                Box(Modifier.size(14.dp).clip(CircleShape).background(p.sadu.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(p.sadu))
                }
                Text(name, style = body(13, FontWeight.SemiBold, 1.2), color = p.ink2)
            }
        }
    }
}

/** The Sadu bands the web draws under page titles, 10px high: diamonds, triangles, circles or bars. */
@Composable
fun Band(kind: String) {
    val p = pal()
    Canvas(Modifier.fillMaxWidth().height(10.dp).padding(top = 0.dp)) {
        val h = size.height
        val u = h / 10f
        fun diamond(cx: Float, cy: Float, r: Float, c: Color) {
            drawPath(Path().apply { moveTo(cx, cy - r); lineTo(cx + r, cy); lineTo(cx, cy + r); lineTo(cx - r, cy); close() }, c)
        }
        var x = 0f
        when (kind) {
            "car" -> while (x < size.width) {
                drawPath(Path().apply { moveTo(x, h); lineTo(x + 6 * u, 0f); lineTo(x + 12 * u, h); close() }, p.sadu)
                drawPath(Path().apply { moveTo(x, 0f); lineTo(x + 6 * u, 0f); lineTo(x, h); close() }, p.bandInk)
                drawPath(Path().apply { moveTo(x + 6 * u, 0f); lineTo(x + 12 * u, 0f); lineTo(x + 12 * u, h); close() }, p.bandInk)
                x += 12 * u
            }
            "subs" -> while (x < size.width) {
                drawCircle(p.sadu, 3.2f * u, Offset(x + 3.5f * u, 5 * u))
                drawCircle(p.bandInk, 3.2f * u, Offset(x + 10.5f * u, 5 * u))
                x += 14 * u
            }
            "more" -> while (x < size.width) {
                drawRect(p.sadu, Offset(x, 0f), androidx.compose.ui.geometry.Size(4 * u, h))
                drawRect(p.bandInk, Offset(x + 8 * u, 0f), androidx.compose.ui.geometry.Size(4 * u, h))
                drawRect(p.sand, Offset(x + 4 * u, 4 * u), androidx.compose.ui.geometry.Size(4 * u, 2 * u))
                drawRect(p.sand, Offset(x + 12 * u, 4 * u), androidx.compose.ui.geometry.Size(4 * u, 2 * u))
                x += 16 * u
            }
            else -> while (x < size.width) {
                diamond(x + 5 * u, 5 * u, 5 * u, p.sadu)
                diamond(x + 15 * u, 5 * u, 5 * u, p.bandInk)
                diamond(x + 5 * u, 5 * u, 1.8f * u, p.sand)
                diamond(x + 15 * u, 5 * u, 1.8f * u, p.sand)
                x += 20 * u
            }
        }
    }
}

/** The web's .back link above a page opened from More. */
@Composable
fun BackLink(text: String, onBack: () -> Unit) {
    val p = pal()
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Row(Modifier.padding(top = 4.dp).clickable(role = Role.Button, onClick = onBack), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Ico("back", p.ink2, 18.dp, if (rtl) Modifier.scale(-1f, 1f) else Modifier)
        Text(text, style = body(14, FontWeight.SemiBold, 1.2), color = p.ink2)
    }
}

/** The web's page head: the title, anything that sits under it, then the band. */
@Composable
fun PageHead(title: String, band: String, back: (() -> Unit)? = null, backText: String = "", extra: (@Composable () -> Unit)? = null) {
    val p = pal()
    Column(Modifier.fillMaxWidth()) {
        if (back != null) BackLink(backText, back)
        Text(title, style = title(30, 1.25), color = p.ink, modifier = Modifier.padding(top = 8.dp, bottom = 12.dp))
        if (extra != null) extra()
        Box(Modifier.padding(top = 14.dp, bottom = 18.dp)) { Band(band) }
    }
}

/** The web's switch: green when on, a pale track with a white thumb when off. */
@Composable
fun webSwitch(): SwitchColors {
    val p = pal()
    return SwitchDefaults.colors(
        checkedTrackColor = p.ok, checkedThumbColor = p.onInk, checkedBorderColor = Color.Transparent,
        uncheckedTrackColor = p.ink.copy(alpha = 0.14f), uncheckedThumbColor = p.surface, uncheckedBorderColor = Color.Transparent,
    )
}

/** The web's .segc: equal parts in one tray, the chosen one raised. Compact sizes the parts by the widest word, as the web does off a field. */
@Composable
fun Seg(options: List<Pair<String, String>>, selected: String, modifier: Modifier = Modifier.fillMaxWidth(), compact: Boolean = false, onSelect: (String) -> Unit) {
    val p = pal()
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val partWidth = if (compact) remember(options) {
        val widest = options.maxOf { measurer.measure(it.second, body(14, FontWeight.Bold, 1.2), softWrap = false, maxLines = 1).size.width }
        with(density) { widest.toDp() } + 24.dp
    } else null
    Row(
        (if (compact) Modifier else modifier).clip(RoundedCornerShape(13.dp)).background(p.ink.copy(alpha = 0.06f)).border(1.dp, p.line, RoundedCornerShape(13.dp)).padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        for ((value, label) in options) {
            val on = value == selected
            Box(
                (if (partWidth != null) Modifier.width(partWidth) else Modifier.weight(1f)).height(38.dp)
                    .then(if (on) Modifier.shadow(1.5.dp, RoundedCornerShape(10.dp)) else Modifier)
                    .clip(RoundedCornerShape(10.dp)).background(if (on) p.surface else Color.Transparent)
                    .clickable(role = Role.RadioButton) { onSelect(value) }.semantics { this.selected = on }
                    .padding(horizontal = 6.dp),
                contentAlignment = Alignment.Center,
            ) {
                FitText(label, body(14, if (on) FontWeight.Bold else FontWeight.Medium, 1.2), if (on) p.ink else p.ink2, Modifier.fillMaxWidth())
            }
        }
    }
}

/** One of the web's chips, given the width of its column so every chip in a group is the same size. */
@Composable
fun ChoiceCell(text: String, on: Boolean, icon: String? = null, modifier: Modifier = Modifier, small: Boolean = false, onClick: () -> Unit) {
    val p = pal()
    Row(
        modifier.height(if (small) 36.dp else 40.dp).clip(CircleShape).background(if (on) p.ink else p.surface)
            .border(1.dp, if (on) p.ink else p.line, CircleShape)
            .clickable(role = Role.Checkbox, onClick = onClick).semantics { this.selected = on }
            .padding(horizontal = 10.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { Ico(icon, if (on) p.onInk else p.ink2, 18.dp); Spacer(Modifier.width(6.dp)) }
        FitText(text, body(if (small) 14.0 else 14.5, if (on) FontWeight.SemiBold else FontWeight.Normal, 1.2), if (on) p.onInk else p.ink2, Modifier.weight(1f, fill = false))
    }
}

/** Chips in equal columns; a short last row keeps its chips the same width. */
@Composable
fun <T> ChoiceGrid(items: List<T>, columns: Int, isOn: (T) -> Boolean, label: (T) -> String, icon: (T) -> String? = { null }, small: Boolean = false, onClick: (T) -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (row in items.chunked(columns)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (x in row) ChoiceCell(label(x), isOn(x), icon(x), Modifier.weight(1f), small) { onClick(x) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** The web's select: an input-shaped dropdown. */
@Composable
fun Select(value: String, options: List<Pair<String, String>>, modifier: Modifier = Modifier.fillMaxWidth(), onSelect: (String) -> Unit) {
    val p = pal()
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        Row(
            Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(13.dp)).background(p.bg).border(1.dp, p.line, RoundedCornerShape(13.dp))
                .clickable(role = Role.DropdownList) { open = true }.padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FitText(options.firstOrNull { it.first == value }?.second ?: value, body(16, lineHeight = 1.2), p.ink, Modifier.weight(1f))
            Spacer(Modifier.width(6.dp))
            Ico("next", p.ink3, 16.dp, Modifier.rotate(90f))
        }
        DropdownMenu(open, { open = false }, Modifier.background(p.surface)) {
            for ((v, label) in options) {
                DropdownMenuItem(
                    text = { Text(label, style = body(15, if (v == value) FontWeight.Bold else FontWeight.Normal), color = p.ink) },
                    onClick = { open = false; onSelect(v) },
                    trailingIcon = if (v == value) ({ Ico("done", p.ok, 18.dp) }) else null,
                )
            }
        }
    }
}

/** A chevron that points forward in both directions of reading. */
@Composable
fun Chevron(tint: Color, size: Dp = 18.dp) {
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Ico("next", tint, size, if (rtl) Modifier.scale(-1f, 1f) else Modifier)
}

/** The web's .list: rows in a surface card with lines between them. */
@Composable
fun ListCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val p = pal()
    Column(modifier.fillMaxWidth().clip(CardShape).background(p.surface).border(1.dp, p.line, CardShape), content = content)
}

@Composable
fun RowLine() { HorizontalDivider(color = pal().line) }

/** The icon square at the start of a row. */
@Composable
fun RowIcon(icon: String, tint: Color, bg: Color) {
    Box(Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(bg), contentAlignment = Alignment.Center) { Ico(icon, tint, 20.dp) }
}

/** The web's .nav-row: icon, label, an optional count, and the chevron. */
@Composable
fun NavRow(icon: String, label: String, count: String? = null, onClick: () -> Unit) {
    val p = pal()
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        RowIcon(icon, p.ink, p.ink.copy(alpha = 0.06f))
        Text(label, style = body(16, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
        if (count != null) {
            Text(count, style = body(13, FontWeight.Bold, 1.2), color = p.ink2,
                modifier = Modifier.clip(CircleShape).background(p.ink.copy(alpha = 0.07f)).padding(horizontal = 10.dp, vertical = 3.dp))
        }
        Chevron(p.ink3, 16.dp)
    }
}

/** The web's .setting: label with its icon at the start, the control at the end, a line below. */
@Composable
fun SettingRow(icon: String, label: String, control: @Composable () -> Unit) {
    val p = pal()
    Column(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().padding(vertical = 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.weight(1f)) {
                Ico(icon, p.ink3, 20.dp)
                Text(label, style = body(16, FontWeight.SemiBold, 1.3), color = p.ink)
            }
            control()
        }
        RowLine()
    }
}

/** The web's .lede: 15.5px ink-2 with a tall line, or the small 14px one. */
@Composable
fun Lede(text: String, small: Boolean = false) {
    Text(text, style = body(if (small) 14.0 else 15.5, lineHeight = 1.75), color = pal().ink2, modifier = Modifier.padding(bottom = if (small) 10.dp else 14.dp))
}

@Composable
fun Fine(text: String) {
    Text(text, style = body(13, lineHeight = 1.7), color = pal().ink3, modifier = Modifier.padding(top = 18.dp))
}

/** The web's .empty: a dashed card with an icon and a line; .big adds a button. */
@Composable
fun EmptyNote(icon: String, text: String, big: Boolean = false, button: (@Composable () -> Unit)? = null) {
    val p = pal()
    Column(
        Modifier.fillMaxWidth().clip(CardShape).background(p.surface)
            .drawBehind {
                drawRoundRect(p.line, cornerRadius = androidx.compose.ui.geometry.CornerRadius(20.dp.toPx()),
                    style = Stroke(width = 1.dp.toPx(), pathEffect = if (big) null else PathEffect.dashPathEffect(floatArrayOf(8f, 6f))))
            }
            .padding(horizontal = if (big) 22.dp else 20.dp, vertical = if (big) 40.dp else 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (big) 14.dp else 10.dp),
    ) {
        Ico(icon, if (big) p.ink3 else p.ok, if (big) 40.dp else 30.dp)
        Text(text, style = body(16), color = p.ink2, textAlign = TextAlign.Center)
        if (button != null) button()
    }
}

/** The web's .actions.two: two equal buttons side by side. */
@Composable
fun ButtonPair(
    a: String, onA: () -> Unit, b: String, onB: () -> Unit,
    aPrimary: Boolean = false, aIcon: String? = null, bIcon: String? = null, bQuiet: Boolean = false, bDanger: Boolean = false, height: Dp = 48.dp,
) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        WideButton(a, primary = aPrimary, modifier = Modifier.weight(1f), icon = aIcon, height = height, onClick = onA)
        WideButton(b, primary = false, quiet = bQuiet, danger = bDanger, modifier = Modifier.weight(1f), icon = bIcon, height = height, onClick = onB)
    }
}

@Composable
fun ConfirmDialog(text: String, confirm: String, cancel: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val p = pal()
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = p.surface,
        text = { Text(text, style = body(16, FontWeight.SemiBold), color = p.ink) },
        confirmButton = { TextButton({ onDismiss(); onConfirm() }) { Text(confirm, style = body(15, FontWeight.Bold), color = p.overdue) } },
        dismissButton = { TextButton(onDismiss) { Text(cancel, style = body(15), color = p.ink) } },
    )
}

/** A toggle row inside a card, as the web's feature and trial switches. */
@Composable
fun SwitchCard(rows: List<Triple<String, Boolean, (Boolean) -> Unit>>) {
    val p = pal()
    ListCard {
        rows.forEachIndexed { i, (label, on, set) ->
            if (i > 0) RowLine()
            Row(Modifier.fillMaxWidth().clickable { set(!on) }.padding(horizontal = 14.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(label, style = body(15.5), color = p.ink, modifier = Modifier.weight(1f))
                Switch(on, set, colors = webSwitch())
            }
        }
    }
}
