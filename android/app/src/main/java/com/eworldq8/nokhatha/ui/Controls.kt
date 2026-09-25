// The web app's controls, one size each and laid out on a grid: a segmented control with equal
// parts (.segc), a grid of equal choices, a dropdown (select), navigation rows (.nav-row) and
// settings rows (.setting). Nothing here is sized by the length of its words.
package com.eworldq8.nokhatha.ui

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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.FitText

/** The height every button and choice shares. */
val ControlHeight = 46.dp

/** A segmented control: equal parts in one rounded tray, the chosen part raised. */
@Composable
fun Seg(options: List<Pair<String, String>>, selected: String, modifier: Modifier = Modifier.fillMaxWidth(), onSelect: (String) -> Unit) {
    val p = pal()
    Row(
        modifier.clip(RoundedCornerShape(14.dp)).background(p.ink.copy(alpha = 0.06f)).border(1.dp, p.line, RoundedCornerShape(14.dp)).padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        for ((value, label) in options) {
            val on = value == selected
            Box(
                Modifier.weight(1f).height(ControlHeight - 6.dp)
                    .then(if (on) Modifier.shadow(1.5.dp, RoundedCornerShape(11.dp)) else Modifier)
                    .clip(RoundedCornerShape(11.dp)).background(if (on) p.surface else Color.Transparent)
                    .clickable(role = Role.RadioButton) { onSelect(value) }.semantics { this.selected = on }
                    .padding(horizontal = 6.dp),
                contentAlignment = Alignment.Center,
            ) {
                FitText(label, body(14, if (on) FontWeight.Bold else FontWeight.Medium), if (on) p.ink else p.ink2, Modifier.fillMaxWidth())
            }
        }
    }
}

/** One choice in a grid: every cell the same width and height, whatever its words. */
@Composable
fun ChoiceCell(text: String, on: Boolean, icon: String? = null, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val p = pal()
    Row(
        modifier.height(ControlHeight).clip(RoundedCornerShape(14.dp)).background(if (on) p.ink else p.surface)
            .border(1.dp, if (on) p.ink else p.line, RoundedCornerShape(14.dp))
            .clickable(role = Role.Checkbox, onClick = onClick).semantics { this.selected = on }
            .padding(horizontal = 8.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { Ico(icon, if (on) p.onInk else p.ink2, 17.dp); Spacer(Modifier.width(6.dp)) }
        FitText(text, body(14, if (on) FontWeight.SemiBold else FontWeight.Normal), if (on) p.onInk else p.ink2, Modifier.weight(1f, fill = false))
    }
}

/** Choices laid out in equal columns; a short last row keeps its cells the same width. */
@Composable
fun <T> ChoiceGrid(items: List<T>, columns: Int, isOn: (T) -> Boolean, label: (T) -> String, icon: (T) -> String? = { null }, onClick: (T) -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (row in items.chunked(columns)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (x in row) ChoiceCell(label(x), isOn(x), icon(x), Modifier.weight(1f)) { onClick(x) }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** A dropdown, like the web's select. */
@Composable
fun Select(value: String, options: List<Pair<String, String>>, modifier: Modifier = Modifier.fillMaxWidth(), onSelect: (String) -> Unit) {
    val p = pal()
    var open by remember { mutableStateOf(false) }
    Box(modifier) {
        Row(
            Modifier.fillMaxWidth().height(ControlHeight).clip(RoundedCornerShape(14.dp)).background(p.bg).border(1.dp, p.line, RoundedCornerShape(14.dp))
                .clickable(role = Role.DropdownList) { open = true }.padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            FitText(options.firstOrNull { it.first == value }?.second ?: value, body(15), p.ink, Modifier.weight(1f))
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

@Composable
fun ListCard(content: @Composable ColumnScope.() -> Unit) {
    val p = pal()
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(p.surface).border(1.dp, p.line, RoundedCornerShape(20.dp)), content = content)
}

/** A row that opens a page: icon, label, an optional count, and the chevron. */
@Composable
fun NavRow(icon: String, label: String, count: String? = null, onClick: () -> Unit) {
    val p = pal()
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(p.ink.copy(alpha = 0.06f)), contentAlignment = Alignment.Center) { Ico(icon, p.ink, 20.dp) }
        Spacer(Modifier.width(12.dp))
        Text(label, style = body(16, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
        if (count != null) {
            Text(count, style = body(13, FontWeight.Bold), color = p.ink2,
                modifier = Modifier.clip(CircleShape).background(p.ink.copy(alpha = 0.07f)).padding(horizontal = 10.dp, vertical = 1.dp))
            Spacer(Modifier.width(8.dp))
        }
        Chevron(p.ink3)
    }
}

/** One setting: icon and name on one side, its control on the other, every control the same width. */
@Composable
fun SettingRow(icon: String, label: String, control: @Composable () -> Unit) {
    val p = pal()
    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Ico(icon, p.ink2, 20.dp)
        Spacer(Modifier.width(10.dp))
        Text(label, style = body(15, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(10.dp))
        Box(Modifier.width(196.dp)) { control() }
    }
}

/** A page opened from More: a back button beside the title. */
@Composable
fun PageHead(title: String, onBack: (() -> Unit)? = null) {
    val p = pal()
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Row(Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        if (onBack != null) {
            Box(Modifier.size(42.dp).clip(CircleShape).border(1.dp, p.line, CircleShape).background(p.surface).clickable(role = Role.Button, onClick = onBack),
                contentAlignment = Alignment.Center) { Ico("back", p.ink, 20.dp, if (rtl) Modifier.scale(-1f, 1f) else Modifier) }
            Spacer(Modifier.width(12.dp))
        }
        Text(title, style = title(28), color = p.ink)
    }
}

@Composable
fun Lede(text: String, small: Boolean = false) {
    Text(text, style = body(if (small) 14 else 15), color = pal().ink2, modifier = Modifier.padding(top = 6.dp, bottom = 4.dp))
}

@Composable
fun SmallHead(text: String) {
    Text(text, style = body(15, FontWeight.Bold), color = pal().ink, modifier = Modifier.padding(top = 20.dp, bottom = 8.dp))
}

/** Two equal buttons side by side. */
@Composable
fun ButtonPair(a: String, onA: () -> Unit, b: String, onB: () -> Unit, aPrimary: Boolean = false, bDanger: Boolean = false) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        WideButton(a, primary = aPrimary, modifier = Modifier.weight(1f), onClick = onA)
        WideButton(b, primary = false, danger = bDanger, modifier = Modifier.weight(1f), onClick = onB)
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

@Composable
fun EmptyNote(icon: String, text: String) {
    val p = pal()
    Column(Modifier.fillMaxWidth().padding(vertical = 22.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Ico(icon, p.ink3, 36.dp)
        Spacer(Modifier.height(10.dp))
        Text(text, style = body(15), color = p.ink2, textAlign = TextAlign.Center)
    }
}
