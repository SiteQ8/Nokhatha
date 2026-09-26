// The web identity on Android, with the web's own sizes: base.css and app.css are the source
// of every number here, so a screen on Android measures the same as the same screen on the web.
package com.eworldq8.nokhatha.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.eworldq8.nokhatha.FitText
import com.eworldq8.nokhatha.R

data class Pal(
    val bg: Color, val surface: Color, val ink: Color, val ink2: Color, val ink3: Color, val line: Color,
    val sadu: Color, val overdue: Color, val soon: Color, val soonInk: Color, val ok: Color, val onInk: Color,
    val safari: Color, val shita: Color, val rabi: Color, val qaith: Color, val rutab: Color, val sand: Color, val bandInk: Color,
) {
    fun tint(status: String) = when (status) {
        "overdue" -> overdue
        "today", "soon" -> soonInk
        "unset", "off" -> ink3
        else -> ok
    }

    /** The soft background behind a row's icon, as the web's tint colours. */
    fun tintBg(status: String) = tint(status).copy(alpha = 0.12f)

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
    Color(0xFFA3C8C8), Color(0xFFB8BCC8), Color(0xFFC0CEBD), Color(0xFFE1CCA6), Color(0xFFC98A1B), Color(0xFFE4D8C4), Color(0xFF1C2340),
)

private val dark = Pal(
    Color(0xFF121728), Color(0xFF1B2238), Color(0xFFEEF1F4), Color(0xFFBAC1D5), Color(0xFF8B94AE), Color(0xFF2B3453),
    Color(0xFFD8474D), Color(0xFFE8676C), Color(0xFFE7AF4B), Color(0xFFE7AF4B), Color(0xFF41B8AC), Color(0xFF121728),
    Color(0xFF204750), Color(0xFF363C50), Color(0xFF394841), Color(0xFF564833), Color(0xFFE7AF4B), Color(0xFF121728), Color(0xFFEEF1F4),
)

/** The theme chosen in Settings: null follows the phone. */
val LocalDark = staticCompositionLocalOf<Boolean?> { null }

@Composable
fun pal(): Pal = if (LocalDark.current ?: isSystemInDarkTheme()) dark else light

val Plex = FontFamily(
    Font(R.font.plex_regular, FontWeight.Normal), Font(R.font.plex_medium, FontWeight.Medium),
    Font(R.font.plex_semibold, FontWeight.SemiBold), Font(R.font.plex_bold, FontWeight.Bold),
)
val Kufi = FontFamily(Font(R.font.kufi_semibold, FontWeight.SemiBold), Font(R.font.kufi_bold, FontWeight.Bold))

/** Body text: IBM Plex Sans Arabic, line height 1.65 as the web. */
fun body(size: Double = 16.0, weight: FontWeight = FontWeight.Normal, lineHeight: Double = 1.65) =
    TextStyle(fontFamily = Plex, fontSize = size.sp, fontWeight = weight, lineHeight = (size * lineHeight).sp)
fun body(size: Int, weight: FontWeight = FontWeight.Normal, lineHeight: Double = 1.65) = body(size.toDouble(), weight, lineHeight)

/** Display text: Reem Kufi 600. */
fun title(size: Double, lineHeight: Double = 1.3) = TextStyle(fontFamily = Kufi, fontSize = size.sp, fontWeight = FontWeight.SemiBold, lineHeight = (size * lineHeight).sp)
fun title(size: Int, lineHeight: Double = 1.3) = title(size.toDouble(), lineHeight)
fun display(size: Int) = TextStyle(fontFamily = Kufi, fontSize = size.sp, fontWeight = FontWeight.Bold, lineHeight = (size * 1.1).sp)

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

val CardShape = RoundedCornerShape(20.dp)

/** A surface card with the web's 20px corners and hairline. */
@Composable
fun CardBox(modifier: Modifier = Modifier, padding: Dp = 16.dp, content: @Composable ColumnScope.() -> Unit) {
    val p = pal()
    Column(modifier.fillMaxWidth().clip(CardShape).background(p.surface).border(1.dp, p.line, CardShape).padding(padding), content = content)
}

/** The web's chip: a 40px pill sized to its words, for the asset tabs. */
@Composable
fun Chip(text: String, on: Boolean, icon: String? = null, dashed: Boolean = false, onClick: () -> Unit) {
    val p = pal()
    val stroke = if (on) p.ink else p.line
    Row(
        Modifier.height(40.dp).clip(CircleShape).background(if (on) p.ink else p.surface)
            .then(if (dashed) Modifier.drawBehind {
                drawRoundRect(stroke, cornerRadius = CornerRadius(size.height / 2),
                    style = Stroke(width = 1.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 5f))))
            } else Modifier.border(1.dp, stroke, CircleShape))
            .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 15.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) Ico(icon, if (on) p.onInk else if (dashed) p.ink3 else p.ink2, 18.dp)
        Text(text, style = body(14.5, if (on) FontWeight.SemiBold else FontWeight.Normal, 1.2), color = if (on) p.onInk else if (dashed) p.ink3 else p.ink2, maxLines = 1)
    }
}

/** The web's .btn: 48px, 14px corners, 15px semibold; primary is filled ink, quiet has no frame. */
@Composable
fun WideButton(
    text: String, primary: Boolean = true, danger: Boolean = false, modifier: Modifier = Modifier, icon: String? = null,
    quiet: Boolean = false, height: Dp = 48.dp, block: Boolean = true, onClick: () -> Unit,
) {
    val p = pal()
    val filled = primary && !danger && !quiet
    val bare = quiet || danger
    val ink = if (danger) p.overdue else if (filled) p.onInk else if (quiet) p.ink2 else p.ink
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier.then(if (block) Modifier.fillMaxWidth() else Modifier).height(height).clip(shape).background(if (filled) p.ink else if (bare) Color.Transparent else p.surface)
            .then(if (filled || bare) Modifier else Modifier.border(1.dp, p.line, shape))
            .clickable(role = Role.Button, onClick = onClick).padding(horizontal = 18.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { Ico(icon, ink, 18.dp); Spacer(Modifier.width(8.dp)) }
        FitText(text, body(15, FontWeight.SemiBold, 1.2), ink, Modifier.weight(1f, fill = false))
    }
}

/** The web's .input: 48px tall, 13px corners, on the page colour. */
@Composable
fun Input(
    value: String, onChange: (String) -> Unit, placeholder: String, numbers: Boolean = false, modifier: Modifier = Modifier,
    phone: Boolean = false, password: Boolean = false,
) {
    val p = pal()
    val field = @Composable {
        BasicTextField(
            value = value, onValueChange = onChange, singleLine = true,
            textStyle = body(16, lineHeight = 1.3).copy(color = p.ink),
            cursorBrush = SolidColor(p.ink),
            keyboardOptions = KeyboardOptions(keyboardType = when {
                password -> KeyboardType.Password
                phone -> KeyboardType.Phone
                numbers -> KeyboardType.Decimal
                else -> KeyboardType.Text
            }),
            visualTransformation = if (password) PasswordVisualTransformation() else VisualTransformation.None,
            modifier = modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(13.dp)).background(p.bg).border(1.dp, p.line, RoundedCornerShape(13.dp)),
            decorationBox = { inner ->
                Box(Modifier.fillMaxSize().padding(horizontal = 14.dp), contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) Text(placeholder, style = body(16, lineHeight = 1.3), color = p.ink3.copy(alpha = 0.8f), maxLines = 1)
                    inner()
                }
            },
        )
    }
    // phone numbers and passwords read left to right in both languages
    if (phone || password) CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) { field() } else field()
}

/** The web's field label: 13.5px bold, 14px above, 7px below. */
@Composable
fun FieldLabel(text: String) {
    Text(text, style = body(13.5, FontWeight.Bold, 1.4), color = pal().ink2, modifier = Modifier.padding(top = 14.dp, bottom = 7.dp))
}

/** The web's .sec: a 20px Kufi heading with an optional count, 26px above and 10px below. */
@Composable
fun SectionTitle(text: String, count: Int? = null) {
    val p = pal()
    Row(Modifier.fillMaxWidth().padding(top = 26.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = title(20), color = p.ink, modifier = Modifier.weight(1f))
        if (count != null && count > 0) CountPill(count)
    }
}

@Composable
fun CountPill(count: Int) {
    val p = pal()
    Box(Modifier.heightIn(min = 26.dp).widthIn(min = 26.dp).clip(CircleShape).background(p.overdue.copy(alpha = 0.11f)).padding(horizontal = 8.dp), contentAlignment = Alignment.Center) {
        Text(count.toString(), style = body(13, FontWeight.Bold, 1.2), color = p.overdue)
    }
}

/** The web's small heading over a group of rows: 13px bold, ink-3. */
@Composable
fun SmallHead(text: String, top: Dp = 22.dp) {
    Text(text, style = body(13, FontWeight.Bold, 1.4), color = pal().ink3, modifier = Modifier.padding(top = top, bottom = 8.dp))
}

/** The web's weave: a 5px line under a row showing how much of the cycle has passed. */
@Composable
fun ProgressLine(value: Double, color: Color) {
    val p = pal()
    Box(Modifier.padding(top = 5.dp).widthIn(max = 240.dp).fillMaxWidth().height(5.dp).clip(CircleShape).background(p.ink.copy(alpha = 0.08f))) {
        Box(Modifier.fillMaxWidth(value.toFloat().coerceIn(0f, 1f)).fillMaxHeight().clip(CircleShape).background(color))
    }
}

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
