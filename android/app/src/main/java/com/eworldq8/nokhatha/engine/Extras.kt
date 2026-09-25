// The rest of the web app's features for Android: warranties, technicians' numbers, the calendar
// file, the year's spending and the encrypted backup. Same rules as docs/app/app.js and
// docs/app/backup.js, so a backup made on the web opens on Android and the other way round.
package com.eworldq8.nokhatha.engine

import org.json.JSONObject
import java.security.SecureRandom
import java.util.Calendar
import java.util.TimeZone
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

// ---------------------------------------------------------------- warranties

data class WarrantyView(val w: Warranty, val end: Day, val status: String, val days: Int)

/** The warranty ends its months after the purchase; the reminder comes a month before. */
fun Brain.warranties(): List<WarrantyView> = state.warranties.mapNotNull { w ->
    val bought = Day.parse(w.bought) ?: return@mapNotNull null
    val end = bought.plusMonths(w.months)
    val st = statusOf(end, today, 30)
    WarrantyView(w, end, st.status, st.days ?: 0)
}.sortedBy { it.end.n }

// ---------------------------------------------------------------- technicians

/** A local number becomes international with the dialling code of the chosen country. */
fun phoneDigits(phone: String, country: String): String {
    var d = normalizeDigits(phone).filter { it in '0'..'9' || it == '+' }
    if (d.startsWith("+")) return d.substring(1)
    if (d.startsWith("00")) return d.substring(2)
    d = d.trimStart('0')
    val c = Brain.countries[country] ?: Brain.countries.getValue("KW")
    return if (d.length == c.second) c.first + d else d
}

fun Brain.techFor(trade: String?): Tech? = trade?.let { t -> state.techs.firstOrNull { it.trade == t } }

// ---------------------------------------------------------------- calendar

/** Every upcoming date as a calendar event, the same set the web app exports. */
fun Brain.calendarEvents(w: Words): List<CalendarEvent> {
    val out = ArrayList<CalendarEvent>()
    for (e in tasks()) {
        val due = e.due ?: continue
        out += CalendarEvent(
            "${e.item.id}-${due.iso}", if (due < today) today else due, e.title(w.lang) + w.comma + e.asset.name,
            e.tpl?.why(w.lang), if (e.every.fixed == true) 7 else if (e.status == "ok") 3 else 0,
        )
    }
    for (s in subs()) {
        if (s.sub.cancelled == true) continue
        out += CalendarEvent("sub-${s.sub.id}-${s.next.iso}", s.next,
            w.t("ics.sub", mapOf("name" to s.sub.name, "amount" to w.money(s.sub.amount, s.sub.currency))), null, if (s.days > 3) 3 else 0)
    }
    for (x in warranties()) {
        if (x.end < today) continue
        out += CalendarEvent("w-${x.w.id}", x.end, w.t("ics.warranty", mapOf("name" to x.w.name)), null, if (x.days > 14) 14 else 0)
    }
    return out
}

/** "20260925T090000Z" for the calendar file's time stamp, in UTC. */
fun utcStamp(millis: Long = System.currentTimeMillis()): String {
    val c = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = millis }
    fun p(n: Int) = if (n < 10) "0$n" else n.toString()
    return "${c.get(Calendar.YEAR)}${p(c.get(Calendar.MONTH) + 1)}${p(c.get(Calendar.DAY_OF_MONTH))}T${p(c.get(Calendar.HOUR_OF_DAY))}${p(c.get(Calendar.MINUTE))}${p(c.get(Calendar.SECOND))}Z"
}

// ---------------------------------------------------------------- spending

data class SpendBlock(val currency: String, val home: Int, val car: Int, val things: Int, val subs: Int, val projected: Int) {
    val total: Int get() = home + car + things + subs
}

data class SpendLog(val date: Day, val cost: Int, val currency: String, val title: String, val asset: String?)

class SpendReport(val year: Int, val blocks: List<SpendBlock>, val logs: List<SpendLog>)

/** What a year cost: the costs logged when tasks were done, and subscription charges up to today. */
fun Brain.spend(year: Int, lang: String): SpendReport {
    val from = Day.of(year, 1, 1)
    val to = Day.of(year, 12, 31)
    val upto = if (to < today) to else today
    val sums = LinkedHashMap<String, IntArray>() // home, car, things, subs, projected
    fun add(cur: String, i: Int, v: Int) { sums.getOrPut(cur) { IntArray(5) }[i] += v }
    val logs = ArrayList<SpendLog>()
    for (it in state.items) for (l in it.log) {
        val cost = l.cost ?: continue
        val d = Day.parse(l.date) ?: continue
        if (d < from || d > to) continue
        val a = asset(it.asset)
        val cur = l.cur ?: state.settings.currency
        add(cur, when (a?.kind) { AssetKind.CAR -> 1; AssetKind.THING -> 2; else -> 0 }, cost)
        logs += SpendLog(d, cost, cur, it.tpl?.let { id -> catalog.template[id]?.name(lang) } ?: it.title ?: "", a?.name)
    }
    for (s in state.subs) {
        val anchor = Day.parse(s.anchor) ?: continue
        val cycle = Cycle.of(s.cycle) ?: continue
        val stop = if (s.cancelled == true) Day.parse(s.cancelledOn) else null
        val n = chargesBetween(anchor, cycle, from, if (stop != null && stop < upto) stop else upto)
        val all = chargesBetween(anchor, cycle, from, if (stop != null && stop < to) stop else to)
        add(s.currency, 3, n * s.amount)
        sums.getValue(s.currency)[4] += all * s.amount
    }
    return SpendReport(year, sums.map { (cur, v) -> SpendBlock(cur, v[0], v[1], v[2], v[3], v[4]) }, logs.sortedByDescending { it.date.n })
}

// ---------------------------------------------------------------- backup

/** Standard base64 with padding, written here because android.util.Base64 is missing on the JVM and java.util.Base64 before Android 8. */
object B64 {
    private const val A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    fun encode(b: ByteArray): String {
        val sb = StringBuilder((b.size + 2) / 3 * 4)
        var i = 0
        while (i < b.size) {
            val n = (b[i].toInt() and 0xff shl 16) or ((if (i + 1 < b.size) b[i + 1].toInt() and 0xff else 0) shl 8) or (if (i + 2 < b.size) b[i + 2].toInt() and 0xff else 0)
            sb.append(A[n shr 18 and 63]).append(A[n shr 12 and 63])
            sb.append(if (i + 1 < b.size) A[n shr 6 and 63] else '=').append(if (i + 2 < b.size) A[n and 63] else '=')
            i += 3
        }
        return sb.toString()
    }

    fun decode(s: String): ByteArray {
        val clean = s.filter { it != '\n' && it != '\r' && it != ' ' }.trimEnd('=')
        val out = java.io.ByteArrayOutputStream(clean.length * 3 / 4)
        var buf = 0
        var bits = 0
        for (ch in clean) {
            val v = A.indexOf(ch)
            require(v >= 0) { "base64" }
            buf = (buf shl 6) or v
            bits += 6
            if (bits >= 8) {
                bits -= 8
                out.write(buf shr bits and 0xff)
            }
        }
        return out.toByteArray()
    }
}

class BackupError(val reason: String) : Exception(reason)

/** The web app's backup file: PBKDF2 with SHA-256 over 600,000 rounds, then AES-256-GCM. */
object Backup {
    const val ITERATIONS = 600_000
    private val random = SecureRandom()

    /** PBKDF2 with HMAC-SHA256 for one 32-byte block, written out so it runs on every Android version. */
    fun pbkdf2(pass: String, salt: ByteArray, iterations: Int): ByteArray {
        val key = pass.toByteArray(Charsets.UTF_8)
        if (key.isEmpty()) throw BackupError("pass")
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        mac.update(salt)
        mac.update(byteArrayOf(0, 0, 0, 1))
        var u = mac.doFinal()
        val t = u.copyOf()
        for (i in 1 until iterations) {
            u = mac.doFinal(u)
            for (j in t.indices) t[j] = (t[j].toInt() xor u[j].toInt()).toByte()
        }
        return t
    }

    fun encrypt(payload: String, pass: String, iterations: Int = ITERATIONS): String {
        val salt = ByteArray(16).also { random.nextBytes(it) }
        val iv = ByteArray(12).also { random.nextBytes(it) }
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, SecretKeySpec(pbkdf2(pass, salt, iterations), "AES"), GCMParameterSpec(128, iv))
        val data = c.doFinal(payload.toByteArray(Charsets.UTF_8))
        return JSONObject().put("app", "nokhatha").put("format", 1).put("kdf", "PBKDF2-SHA256").put("iterations", iterations)
            .put("cipher", "AES-256-GCM").put("salt", B64.encode(salt)).put("iv", B64.encode(iv)).put("data", B64.encode(data)).toString()
    }

    /** Returns the payload text, or throws BackupError("format") or BackupError("pass"). */
    fun decrypt(file: String, pass: String): String {
        val f = runCatching { JSONObject(file) }.getOrNull() ?: throw BackupError("format")
        if (f.optString("app") != "nokhatha" || f.optInt("format") != 1 || !f.has("salt") || !f.has("iv") || !f.has("data")) throw BackupError("format")
        val salt = runCatching { B64.decode(f.getString("salt")) }.getOrNull() ?: throw BackupError("format")
        val iv = runCatching { B64.decode(f.getString("iv")) }.getOrNull() ?: throw BackupError("format")
        val data = runCatching { B64.decode(f.getString("data")) }.getOrNull() ?: throw BackupError("format")
        val key = pbkdf2(pass, salt, f.optInt("iterations", ITERATIONS))
        return try {
            val c = Cipher.getInstance("AES/GCM/NoPadding")
            c.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
            String(c.doFinal(data), Charsets.UTF_8)
        } catch (e: AEADBadTagException) {
            throw BackupError("pass")
        } catch (e: java.security.GeneralSecurityException) {
            throw BackupError("pass")
        }
    }
}
