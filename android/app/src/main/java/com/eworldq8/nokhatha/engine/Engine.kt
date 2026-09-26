// The Nokhatha engine for Android: a line for line port of docs/engine/nokhatha.js and the
// Swift port. tests/vectors.json is the contract all three satisfy, so every date and every
// amount comes out the same on the web, iPhone and Android.
//
//   * Dates are whole day numbers on the civil calendar, no time zones, no floating point.
//   * Money is integer minor units (fils for KWD).
//   * Digits are always Western: nothing here goes through the device locale.
package com.eworldq8.nokhatha.engine

import java.util.Calendar

object Engine {
    const val SEASONAL_MIN_GAP = 60
    const val SEASONAL_GRACE = 60
    const val DEFAULT_DAILY_KM = 40
}

fun floorDiv(a: Int, b: Int): Int = Math.floorDiv(a, b)
fun ceilDiv(a: Int, b: Int): Int = -Math.floorDiv(-a, b)

/** Round half up for non negative numerators. */
fun roundDiv(a: Int, b: Int): Int = Math.floorDiv(2 * a + b, 2 * b)

private fun pad(n: Int, width: Int): String {
    val s = n.toString()
    return if (s.length >= width) s else "0".repeat(width - s.length) + s
}

// ---------------------------------------------------------------- days

/** A civil date as days since 1970-01-01 (proleptic Gregorian). */
data class Day(val n: Int) : Comparable<Day> {
    override fun compareTo(other: Day) = n.compareTo(other.n)

    operator fun minus(other: Day): Int = n - other.n
    fun plus(days: Int) = Day(n + days)

    val ymd: Triple<Int, Int, Int>
        get() {
            val z = n + 719468
            val era = floorDiv(z, 146097)
            val doe = z - era * 146097
            val yoe = floorDiv(doe - floorDiv(doe, 1460) + floorDiv(doe, 36524) - floorDiv(doe, 146096), 365)
            val doy = doe - (365 * yoe + floorDiv(yoe, 4) - floorDiv(yoe, 100))
            val mp = floorDiv(5 * doy + 2, 153)
            val d = doy - floorDiv(153 * mp + 2, 5) + 1
            val m = if (mp < 10) mp + 3 else mp - 9
            return Triple(yoe + era * 400 + if (m <= 2) 1 else 0, m, d)
        }

    val iso: String
        get() {
            val (y, m, d) = ymd
            return "${pad(y, 4)}-${pad(m, 2)}-${pad(d, 2)}"
        }

    /** Calendar months, clamped to the last day of the target month. */
    fun plusMonths(k: Int): Day {
        val (y, m, d) = ymd
        val t = y * 12 + (m - 1) + k
        val ny = floorDiv(t, 12)
        val nm = t - ny * 12 + 1
        return of(ny, nm, minOf(d, daysInMonth(ny, nm)))
    }

    /** 0 is Sunday, 6 is Saturday. */
    val weekday: Int get() = ((n % 7) + 7 + 4) % 7

    /** "MM-DD", used for windows such as the Bawarih. */
    val monthDay: String get() = iso.substring(5)

    override fun toString() = iso

    companion object {
        fun isLeap(y: Int) = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0

        fun daysInMonth(y: Int, m: Int) = intArrayOf(31, if (isLeap(y)) 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[m - 1]

        fun number(year: Int, m: Int, d: Int): Int {
            val y = if (m <= 2) year - 1 else year
            val era = floorDiv(y, 400)
            val yoe = y - era * 400
            val mp = (m + 9) % 12
            val doy = floorDiv(153 * mp + 2, 5) + d - 1
            val doe = yoe * 365 + floorDiv(yoe, 4) - floorDiv(yoe, 100) + doy
            return era * 146097 + doe - 719468
        }

        fun of(y: Int, m: Int, d: Int) = Day(number(y, m, d))

        fun parse(s: String?): Day? {
            if (s == null || s.length != 10 || s[4] != '-' || s[7] != '-') return null
            fun num(from: Int, to: Int): Int? {
                var v = 0
                for (i in from until to) {
                    val c = s[i]
                    if (c !in '0'..'9') return null
                    v = v * 10 + (c - '0')
                }
                return v
            }
            val y = num(0, 4) ?: return null
            val m = num(5, 7) ?: return null
            val d = num(8, 10) ?: return null
            if (m < 1 || m > 12 || d < 1 || d > daysInMonth(y, m)) return null
            return of(y, m, d)
        }

        /** Today on the device's own calendar. */
        fun today(): Day {
            val c = Calendar.getInstance()
            return of(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
        }
    }
}

fun isISO(s: String): Boolean = Day.parse(s) != null

/** b minus a, in days. */
fun diffDays(a: Day, b: Day): Int = b.n - a.n

// ---------------------------------------------------------------- seasons

data class Season(
    val id: String, val start: String, val group: String, val ar: String, val en: String,
    val noteAr: String? = null, val noteEn: String? = null, val hintAr: String? = null, val hintEn: String? = null,
) {
    fun name(lang: String) = if (lang == "ar") ar else en
    fun hint(lang: String) = if (lang == "ar") hintAr else hintEn
}

/** A month-day range such as the Bawarih winds, start "06-07", end "07-28". */
data class Window(val start: String, val end: String)

private fun startIn(s: Season, year: Int): Day {
    val p = s.start.split("-")
    return Day.of(year, p[0].toInt(), p[1].toInt())
}

private data class SeasonStart(val i: Int, val date: Day)

private fun startsAround(day: Day, seasons: List<Season>): List<SeasonStart> {
    val y = day.ymd.first
    val out = ArrayList<SeasonStart>()
    for (yy in (y - 1)..(y + 2)) seasons.forEachIndexed { i, s -> out.add(SeasonStart(i, startIn(s, yy))) }
    return out.sortedBy { it.date.n }
}

private fun currentIndex(list: List<SeasonStart>, day: Day): Int {
    var k = -1
    list.forEachIndexed { j, x -> if (x.date <= day) k = j }
    return k
}

data class SeasonInfo(
    val id: String, val index: Int, val start: Day, val next: Day, val nextId: String,
    val length: Int, val dayIn: Int, val daysLeft: Int,
)

/** The Gulf season a date falls in. */
fun seasonAt(day: Day, seasons: List<Season>): SeasonInfo {
    val list = startsAround(day, seasons)
    val k = currentIndex(list, day)
    val cur = list[k]
    val nxt = list[k + 1]
    return SeasonInfo(
        seasons[cur.i].id, cur.i, cur.date, nxt.date, seasons[nxt.i].id,
        diffDays(cur.date, nxt.date), diffDays(cur.date, day) + 1, diffDays(day, nxt.date),
    )
}

data class RingSegment(val id: String, val start: Day, val offset: Int, val length: Int)

/** One full turn of the calendar starting with the season that contains the day. */
fun seasonRing(day: Day, seasons: List<Season>): Pair<Int, List<RingSegment>> {
    val list = startsAround(day, seasons)
    val k = currentIndex(list, day)
    val segs = (0 until seasons.size).map { j ->
        val a = list[k + j]
        val b = list[k + j + 1]
        RingSegment(seasons[a.i].id, a.date, diffDays(day, a.date), diffDays(a.date, b.date))
    }
    return Pair(segs.sumOf { it.length }, segs)
}

fun seasonStartOnOrAfter(day: Day, id: String, seasons: List<Season>): Day? {
    val s = seasons.firstOrNull { it.id == id } ?: return null
    val y = day.ymd.first
    for (yy in (y - 1)..(y + 2)) {
        val d = startIn(s, yy)
        if (d >= day) return d
    }
    return null
}

fun inWindow(day: Day, w: Window): Boolean {
    val md = day.monthDay
    return if (w.start <= w.end) md >= w.start && md <= w.end else md >= w.start || md <= w.end
}

private fun anchors(id: String, offset: Int, y0: Int, y1: Int, seasons: List<Season>): List<Day> {
    val s = seasons.firstOrNull { it.id == id } ?: return emptyList()
    return (y0..y1).map { startIn(s, it).plus(offset) }
}

/** Next due date of a yearly task pinned to a season (for example 21 days before Al-Wasm). */
fun seasonalDue(lastDone: Day?, season: String, offset: Int, today: Day, seasons: List<Season>): Day? {
    if (lastDone != null) {
        val th = lastDone.plus(Engine.SEASONAL_MIN_GAP)
        val y = th.ymd.first
        return anchors(season, offset, y - 1, y + 2, seasons).firstOrNull { it >= th }
    }
    val y = today.ymd.first
    val all = anchors(season, offset, y - 1, y + 2, seasons)
    val prev = all.lastOrNull { it <= today }
    if (prev != null && diffDays(prev, today) <= Engine.SEASONAL_GRACE) return prev
    return all.firstOrNull { it > today }
}

// ---------------------------------------------------------------- odometer

data class Reading(val date: String, val km: Int)

data class Odometer(val dailyKm: Int, val readings: List<Reading>)

private fun sortedReadings(car: Odometer): List<Pair<Day, Int>> =
    car.readings.mapNotNull { r -> Day.parse(r.date)?.let { Pair(it, r.km) } }.sortedBy { it.first.n }

fun lastReading(car: Odometer): Reading? = sortedReadings(car).lastOrNull()?.let { Reading(it.first.iso, it.second) }

/** Kilometres per day as an exact fraction (num / den). */
fun kmRate(car: Odometer): Pair<Int, Int> {
    val r = sortedReadings(car)
    if (r.size >= 2) {
        val last = r.last()
        val from = last.first.plus(-180)
        val early = r.firstOrNull { it.first >= from && it.first < last.first } ?: r[0]
        val span = diffDays(early.first, last.first)
        val dist = last.second - early.second
        if (span >= 14 && dist > 0) return Pair(dist, span)
    }
    return Pair(if (car.dailyKm > 0) car.dailyKm else Engine.DEFAULT_DAILY_KM, 1)
}

/** The date the odometer is expected to reach the target, rounded up so a reminder is never late. */
fun dateAtKm(car: Odometer, target: Int): Day? {
    val last = sortedReadings(car).lastOrNull() ?: return null
    val (num, den) = kmRate(car)
    return last.first.plus(ceilDiv((target - last.second) * den, num))
}

fun kmOn(car: Odometer, day: Day): Int? {
    val last = sortedReadings(car).lastOrNull() ?: return null
    val d = diffDays(last.first, day)
    if (d <= 0) return last.second
    val (num, den) = kmRate(car)
    return last.second + floorDiv(d * num, den)
}

// ---------------------------------------------------------------- schedules

data class Every(
    val days: Int? = null, val months: Int? = null, val km: Int? = null, val bawarih: Int? = null,
    val season: String? = null, val offset: Int? = null, val fixed: Boolean? = null, val lead: Int? = null,
    val repeatMonths: Int? = null, val heat: Int? = null,
)

class DueInput(
    val every: Every, val lastDone: Day? = null, val lastKm: Int? = null, val due: Day? = null,
    val snoozeUntil: Day? = null, val firstDue: Day? = null,
)

data class Due(val due: Day?, val by: String)

/** JS truthiness for optional numbers: absent and zero both mean "not set". */
internal fun set(v: Int?): Int? = if (v != null && v != 0) v else null

fun nextDue(item: DueInput, today: Day, seasons: List<Season>, bawarih: Window?, car: Odometer?, heat: Window? = null): Due {
    val s = item.every
    var res: Due = when {
        s.fixed == true -> if (item.due != null) Due(item.due, "fixed") else Due(null, "unset")
        !s.season.isNullOrEmpty() -> Due(seasonalDue(item.lastDone, s.season, s.offset ?: 0, today, seasons), "season")
        else -> {
            var due: Day? = null
            var by = "time"
            val last = item.lastDone
            if (last != null) {
                set(s.months)?.let { due = last.plusMonths(it) }
                set(s.days)?.let { d0 ->
                    var n = d0
                    val b = set(s.bawarih)
                    if (b != null && bawarih != null && inWindow(last, bawarih)) n = b
                    val h = set(s.heat)
                    if (h != null && heat != null && inWindow(last, heat)) n = minOf(n, h)
                    val t = last.plus(n)
                    due = due?.let { if (it < t) it else t } ?: t
                }
            } else {
                // never logged: due on its planned first date, or today when there is none
                due = item.firstDue ?: today
                by = "new"
            }
            val km = set(s.km)
            if (km != null && car != null && item.lastKm != null) {
                val kd = dateAtKm(car, item.lastKm + km)
                if (kd != null && (due == null || kd < due!!)) {
                    due = kd
                    by = "km"
                }
            }
            Due(due, by)
        }
    }
    val sn = item.snoozeUntil
    val d = res.due
    if (sn != null && d != null && sn > d) res = Due(sn, "snooze")
    return res
}

data class Status(val status: String, val days: Int?)

/** overdue, today, soon, ok or unset */
fun statusOf(due: Day?, today: Day, lead: Int): Status {
    if (due == null) return Status("unset", null)
    val days = diffDays(today, due)
    return Status(if (days < 0) "overdue" else if (days == 0) "today" else if (days <= lead) "soon" else "ok", days)
}

/** Share of the current cycle already used, 0 to 1. For display only. */
fun cycleProgress(lastDone: Day?, due: Day?, today: Day): Double {
    if (lastDone == null || due == null) return 0.0
    val total = diffDays(lastDone, due)
    if (total <= 0) return 1.0
    return (diffDays(lastDone, today).toDouble() / total).coerceIn(0.0, 1.0)
}

// ---------------------------------------------------------------- subscriptions

enum class Cycle(val key: String, val months: Int) {
    WEEKLY("weekly", 0), MONTHLY("monthly", 1), QUARTERLY("quarterly", 3), SEMIANNUAL("semiannual", 6), YEARLY("yearly", 12);

    companion object {
        fun of(key: String?): Cycle? = values().firstOrNull { it.key == key }
    }
}

/** Renewals are computed from the anchor, never chained, so a subscription on the 31st returns to the 31st. */
fun nthRenewal(anchor: Day, cycle: Cycle, n: Int): Day =
    if (cycle == Cycle.WEEKLY) anchor.plus(7 * n) else anchor.plusMonths(cycle.months * n)

fun nextRenewal(anchor: Day, cycle: Cycle, today: Day): Day {
    if (anchor >= today) return anchor
    val gap = diffDays(anchor, today)
    var n = maxOf(0, (if (cycle == Cycle.WEEKLY) floorDiv(gap, 7) else floorDiv(gap, cycle.months * 31)) - 1)
    while (nthRenewal(anchor, cycle, n) < today) n++
    return nthRenewal(anchor, cycle, n)
}

fun chargesBetween(anchor: Day, cycle: Cycle, from: Day, to: Day): Int {
    var n = 0
    var count = 0
    while (true) {
        val d = nthRenewal(anchor, cycle, n)
        if (d > to) break
        if (d >= from) count++
        n++
        if (n > 2000) break
    }
    return count
}

fun perMonth(minor: Int, cycle: Cycle): Int = when (cycle) {
    Cycle.WEEKLY -> roundDiv(minor * 52, 12)
    Cycle.MONTHLY -> minor
    Cycle.QUARTERLY -> roundDiv(minor, 3)
    Cycle.SEMIANNUAL -> roundDiv(minor, 6)
    Cycle.YEARLY -> roundDiv(minor, 12)
}

fun perYear(minor: Int, cycle: Cycle): Int = when (cycle) {
    Cycle.WEEKLY -> minor * 52
    Cycle.MONTHLY -> minor * 12
    Cycle.QUARTERLY -> minor * 4
    Cycle.SEMIANNUAL -> minor * 2
    Cycle.YEARLY -> minor
}

data class SubAmount(val amount: Int, val currency: String, val cycle: Cycle, val cancelled: Boolean = false)
data class SubTotal(val month: Int = 0, val year: Int = 0, val count: Int = 0)

fun subTotals(subs: List<SubAmount>): Map<String, SubTotal> {
    val out = LinkedHashMap<String, SubTotal>()
    for (s in subs) {
        if (s.cancelled) continue
        val t = out[s.currency] ?: SubTotal()
        out[s.currency] = SubTotal(t.month + perMonth(s.amount, s.cycle), t.year + perYear(s.amount, s.cycle), t.count + 1)
    }
    return out
}

// ---------------------------------------------------------------- money

data class CurrencyInfo(val digits: Int, val ar: String)

val currencies: Map<String, CurrencyInfo> = linkedMapOf(
    "KWD" to CurrencyInfo(3, "د.ك"), "SAR" to CurrencyInfo(2, "ر.س"), "AED" to CurrencyInfo(2, "د.إ"),
    "QAR" to CurrencyInfo(2, "ر.ق"), "BHD" to CurrencyInfo(3, "د.ب"), "OMR" to CurrencyInfo(3, "ر.ع"),
    "USD" to CurrencyInfo(2, "دولار"),
)

private fun pow10(k: Int): Int { var p = 1; repeat(k) { p *= 10 }; return p }

internal fun groupThousands(s: String): String {
    val sb = StringBuilder()
    s.forEachIndexed { i, ch ->
        if (i > 0 && (s.length - i) % 3 == 0) sb.append(',')
        sb.append(ch)
    }
    return sb.toString()
}

/** "4.500 د.ك" in Arabic, "KWD 4.500" in English. */
fun formatMoney(minor: Int, code: String, lang: String): String {
    val c = currencies[code] ?: return ""
    val a = Math.abs(minor)
    val p = pow10(c.digits)
    val frac = pad(a % p, c.digits)
    val num = (if (minor < 0) "-" else "") + groupThousands(floorDiv(a, p).toString()) + "." + frac
    return if (lang == "ar") "$num ${c.ar}" else "$code $num"
}

/** Arabic Indic and Persian digits, Arabic decimal and thousands marks, to ASCII. */
fun normalizeDigits(s: String): String {
    val sb = StringBuilder()
    var i = 0
    while (i < s.length) {
        val cp = s.codePointAt(i)
        when (cp) {
            in 0x0660..0x0669 -> sb.append(('0'.code + cp - 0x0660).toChar())
            in 0x06F0..0x06F9 -> sb.append(('0'.code + cp - 0x06F0).toChar())
            0x066B -> sb.append('.')
            0x066C -> sb.append(',')
            else -> sb.appendCodePoint(cp)
        }
        i += Character.charCount(cp)
    }
    return sb.toString()
}

private val moneyRun = Regex("[0-9.,]*[0-9]")
private val plainNumber = Regex("^[0-9]+(\\.[0-9]+)?$")

/** Reads what a person types ("4.5", "٤٫٥٠٠", "2,5", "1,500 SAR") into minor units. */
fun parseMoney(text: String, code: String): Int? {
    val c = currencies[code] ?: return null
    var s = moneyRun.find(normalizeDigits(text))?.value ?: return null
    if (s.startsWith(".") || s.startsWith(",")) s = "0$s"
    if (s.contains('.') && s.contains(',')) {
        s = s.replace(",", "")
    } else if (s.contains(',')) {
        val parts = s.split(",")
        s = if (parts.size == 2 && parts[1].length <= c.digits) parts[0] + "." + parts[1] else parts.joinToString("")
    }
    if (!plainNumber.matches(s)) return null
    val comps = s.split(".")
    var fp = if (comps.size > 1) comps[1] else ""
    while (fp.length < c.digits + 1) fp += "0"
    val ip = comps[0].toIntOrNull() ?: return null
    var minor = ip * pow10(c.digits) + (if (c.digits > 0) fp.substring(0, c.digits).toInt() else 0)
    if (fp[c.digits] - '0' >= 5) minor += 1
    return minor
}

// ---------------------------------------------------------------- wording

private fun spanOf(days: Int): Pair<Int, String> = when {
    days < 14 -> Pair(days, "day")
    days < 30 -> Pair(floorDiv(days, 7), "week")
    days < 335 -> Pair(floorDiv(days, 30), "month")
    else -> Pair(maxOf(1, roundDiv(days, 365)), "year")
}

// Kuwaiti dialect counting: 1, 2 (dual), 3 to 10 plural, 11 and up singular.
private val arUnits = mapOf(
    "day" to listOf("يوم", "يومين", "أيام", "يوم"),
    "week" to listOf("أسبوع", "أسبوعين", "أسابيع", "أسبوع"),
    "month" to listOf("شهر", "شهرين", "شهور", "شهر"),
    "year" to listOf("سنة", "سنتين", "سنوات", "سنة"),
)

fun countAr(n: Int, unit: String): String {
    val f = arUnits[unit] ?: arUnits.getValue("day")
    return when {
        n == 1 -> f[0]
        n == 2 -> f[1]
        n <= 10 -> "$n ${f[2]}"
        else -> "$n ${f[3]}"
    }
}

fun relative(days: Int, lang: String): String {
    if (lang == "ar") {
        if (days == 0) return "اليوم"
        if (days == 1) return "باچر"
        if (days == -1) return "أمس"
        val (n, u) = spanOf(Math.abs(days))
        return (if (days > 0) "بعد " else "من ") + countAr(n, u)
    }
    if (days == 0) return "today"
    if (days == 1) return "tomorrow"
    if (days == -1) return "yesterday"
    val (n, u) = spanOf(Math.abs(days))
    val w = "$n $u${if (n == 1) "" else "s"}"
    return if (days > 0) "in $w" else "$w ago"
}

val monthNames = mapOf(
    "ar" to listOf("يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"),
    "en" to listOf("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"),
)

val weekdayNames = mapOf(
    "ar" to listOf("الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"),
    "en" to listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"),
)

fun formatDate(day: Day, lang: String, refYear: Int? = null): String {
    val (y, m, d) = day.ymd
    val base = "$d ${monthNames.getValue(if (lang == "ar") "ar" else "en")[m - 1]}"
    return if (refYear != null && refYear != 0 && y != refYear) "$base $y" else base
}

// ---------------------------------------------------------------- calendar export

internal fun icsEscape(s: String): String {
    val sb = StringBuilder()
    var i = 0
    while (i < s.length) {
        val c = s[i]
        when {
            c == '\\' -> sb.append("\\\\")
            c == ';' -> sb.append("\\;")
            c == ',' -> sb.append("\\,")
            c == '\r' && i + 1 < s.length && s[i + 1] == '\n' -> { sb.append("\\n"); i++ }
            c == '\n' -> sb.append("\\n")
            else -> sb.append(c)
        }
        i++
    }
    return sb.toString()
}

/** Folds a content line at 75 octets without splitting a character (RFC 5545 3.1). */
fun foldLine(line: String): String {
    val out = ArrayList<String>()
    var cur = StringBuilder()
    var bytes = 0
    var i = 0
    while (i < line.length) {
        val cp = line.codePointAt(i)
        val b = String(Character.toChars(cp)).toByteArray(Charsets.UTF_8).size
        if (bytes + b > 75) {
            out.add(cur.toString())
            cur = StringBuilder(" ")
            cur.appendCodePoint(cp)
            bytes = 1 + b
        } else {
            cur.appendCodePoint(cp)
            bytes += b
        }
        i += Character.charCount(cp)
    }
    out.add(cur.toString())
    return out.joinToString("\r\n")
}

data class CalendarEvent(val uid: String, val date: Day, val title: String, val note: String? = null, val lead: Int = 0)

fun toICS(events: List<CalendarEvent>, stamp: String, calName: String): String {
    val lines = mutableListOf("BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Nokhatha//Nokhatha//AR", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", "X-WR-CALNAME:${icsEscape(calName)}")
    for (e in events) {
        val title = icsEscape(e.title)
        lines += listOf(
            "BEGIN:VEVENT", "UID:${e.uid}@nokhatha.3li.info", "DTSTAMP:$stamp",
            "DTSTART;VALUE=DATE:${e.date.iso.replace("-", "")}", "DTEND;VALUE=DATE:${e.date.plus(1).iso.replace("-", "")}", "SUMMARY:$title",
        )
        if (!e.note.isNullOrEmpty()) lines += "DESCRIPTION:${icsEscape(e.note)}"
        lines += listOf("BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:$title", "TRIGGER:PT9H", "END:VALARM")
        if (e.lead > 0) {
            val trigger = if (e.lead - 1 > 0) "-P${e.lead - 1}DT15H" else "-PT15H"
            lines += listOf("BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:$title", "TRIGGER:$trigger", "END:VALARM")
        }
        lines += "END:VEVENT"
    }
    lines += "END:VCALENDAR"
    return lines.joinToString("\r\n") { foldLine(it) } + "\r\n"
}
