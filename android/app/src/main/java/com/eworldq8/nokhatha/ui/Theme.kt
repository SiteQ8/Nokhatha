// The web identity on Android: pearl, night, Sadu red, sea and ripe dates, light and dark,
// Reem Kufi for titles and IBM Plex Sans Arabic for text, and the web's own line icons.
package com.eworldq8.nokhatha.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.eworldq8.nokhatha.R

data class Pal(
    val bg: Color, val surface: Color, val ink: Color, val ink2: Color, val ink3: Color, val line: Color,
    val sadu: Color, val overdue: Color, val soon: Color, val soonInk: Color, val ok: Color, val onInk: Color,
    val safari: Color, val shita: Color, val rabi: Color, val qaith: Color,
) {
    fun tint(status: String) = when (status) {
        "overdue" -> overdue
        "today", "soon" -> soonInk
        "unset", "off" -> ink3
        else -> ok
    }

    fun group(g: String) = when (g) {
        "safari" -> safari
        "shita" -> shita
        "rabi" -> rabi
        else -> qaith
    }
}

private val light = Pal(
    Color(0xFFEEF1F4), Color(0xFFFFFFFF), Color(0xFF1C2340), Color(0xFF3A4263), Color(0xFF5F6886), Color(0xFFD9DEE7),
    Color(0xFFA4262C), Color(0xFFA4262C), Color(0xFFC98A1B), Color(0xFF8C5A08), Color(0xFF127A74), Color(0xFFEEF1F4),
    Color(0xFFA3C8C8), Color(0xFFB8BCC8), Color(0xFFC0CEBD), Color(0xFFE1CCA6),
)

private val dark = Pal(
    Color(0xFF121728), Color(0xFF1B2238), Color(0xFFEEF1F4), Color(0xFFBAC1D5), Color(0xFF8B94AE), Color(0xFF2B3453),
    Color(0xFFD8474D), Color(0xFFE8676C), Color(0xFFE7AF4B), Color(0xFFE7AF4B), Color(0xFF41B8AC), Color(0xFF121728),
    Color(0xFF204750), Color(0xFF363C50), Color(0xFF394841), Color(0xFF564833),
)

@Composable
fun pal(): Pal = if (isSystemInDarkTheme()) dark else light

val Plex = FontFamily(
    Font(R.font.plex_regular, FontWeight.Normal), Font(R.font.plex_medium, FontWeight.Medium),
    Font(R.font.plex_semibold, FontWeight.SemiBold), Font(R.font.plex_bold, FontWeight.Bold),
)
val Kufi = FontFamily(Font(R.font.kufi_semibold, FontWeight.SemiBold), Font(R.font.kufi_bold, FontWeight.Bold))

fun body(size: Int = 16, weight: FontWeight = FontWeight.Normal) = TextStyle(fontFamily = Plex, fontSize = size.sp, fontWeight = weight, lineHeight = (size * 1.55).sp)
fun title(size: Int) = TextStyle(fontFamily = Kufi, fontSize = size.sp, fontWeight = FontWeight.SemiBold, lineHeight = (size * 1.35).sp)
fun display(size: Int) = TextStyle(fontFamily = Kufi, fontSize = size.sp, fontWeight = FontWeight.Bold, lineHeight = (size * 1.25).sp)

@Composable
fun Ico(name: String, tint: Color, size: Dp = 22.dp, modifier: Modifier = Modifier) {
    val parts = ICON_PATHS[name] ?: ICON_PATHS["spark"] ?: ICON_PATHS.getValue("today")
    val vector = remember(name) {
        ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply {
            for (p in parts) {
                addPath(
                    pathData = addPathNodes(p.d),
                    fill = if (p.fill) SolidColor(Color.Black) else null,
                    stroke = if (p.fill) null else SolidColor(Color.Black),
                    strokeLineWidth = 1.75f, strokeLineCap = StrokeCap.Round, strokeLineJoin = StrokeJoin.Round,
                )
            }
        }.build()
    }
    Icon(vector, contentDescription = null, tint = tint, modifier = modifier.size(size))
}

@Composable
fun CardBox(modifier: Modifier = Modifier, padding: Dp = 16.dp, content: @Composable ColumnScope.() -> Unit) {
    val p = pal()
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(p.surface)
            .border(1.dp, p.line, RoundedCornerShape(20.dp))
            .padding(padding),
        content = content,
    )
}

@Composable
fun Chip(text: String, on: Boolean, icon: String? = null, onClick: () -> Unit) {
    val p = pal()
    Row(
        Modifier
            .height(40.dp)
            .clip(CircleShape)
            .background(if (on) p.ink else p.surface)
            .border(1.dp, if (on) p.ink else p.line, CircleShape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) Ico(icon, if (on) p.onInk else p.ink2, 16.dp)
        Text(text, style = body(14, if (on) FontWeight.SemiBold else FontWeight.Normal), color = if (on) p.onInk else p.ink2)
    }
}

@Composable
fun WideButton(text: String, primary: Boolean = true, danger: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val p = pal()
    val filled = primary && !danger
    Box(
        modifier
            .fillMaxWidth()
            .height(50.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(if (filled) p.ink else p.surface)
            .then(if (filled) Modifier else Modifier.border(1.dp, p.line, RoundedCornerShape(14.dp)))
            .clickable(role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = body(16, FontWeight.SemiBold), color = if (danger) p.overdue else if (filled) p.onInk else p.ink)
    }
}

@Composable
fun Input(value: String, onChange: (String) -> Unit, placeholder: String, numbers: Boolean = false, modifier: Modifier = Modifier) {
    val p = pal()
    OutlinedTextField(
        value = value, onValueChange = onChange, singleLine = true, modifier = modifier.fillMaxWidth(),
        textStyle = body(16).copy(color = p.ink),
        placeholder = { Text(placeholder, style = body(16), color = p.ink3) },
        keyboardOptions = KeyboardOptions(keyboardType = if (numbers) KeyboardType.Decimal else KeyboardType.Text),
        shape = RoundedCornerShape(13.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = p.ink, unfocusedBorderColor = p.line, focusedContainerColor = p.bg, unfocusedContainerColor = p.bg, cursorColor = p.ink,
        ),
    )
}

@Composable
fun FieldLabel(text: String) {
    Text(text, style = body(13, FontWeight.Bold), color = pal().ink2, modifier = Modifier.padding(top = 14.dp, bottom = 6.dp))
}

@Composable
fun SectionTitle(text: String, count: Int? = null) {
    val p = pal()
    Row(Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = title(20), color = p.ink, modifier = Modifier.weight(1f))
        if (count != null && count > 0) {
            Text(count.toString(), style = body(13, FontWeight.Bold), color = p.overdue,
                modifier = Modifier.clip(CircleShape).background(p.overdue.copy(alpha = 0.11f)).padding(horizontal = 10.dp, vertical = 2.dp))
        }
    }
}

@Composable
fun ProgressLine(value: Double, color: Color) {
    val p = pal()
    Box(Modifier.widthIn(max = 240.dp).fillMaxWidth().height(5.dp).clip(CircleShape).background(p.ink.copy(alpha = 0.08f))) {
        Box(Modifier.fillMaxWidth(value.toFloat().coerceIn(0f, 1f)).fillMaxHeight().clip(CircleShape).background(color))
    }
}

fun Modifier.outline(color: Color, radius: Dp = 16.dp) = this.border(BorderStroke(1.dp, color), RoundedCornerShape(radius))

/** Reads digits typed in Arabic or Western numerals. */
fun wholeNumber(s: String): Int? {
    val digits = buildString {
        for (ch in s) when (ch) {
            in '0'..'9' -> append(ch)
            in '\u0660'..'\u0669' -> append('0' + (ch - '\u0660'))
            in '\u06F0'..'\u06F9' -> append('0' + (ch - '\u06F0'))
        }
    }
    return if (digits.isEmpty()) null else digits.toIntOrNull()
}
