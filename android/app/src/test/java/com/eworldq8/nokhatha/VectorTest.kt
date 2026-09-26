// Runs tests/vectors.json, the contract shared with the web and Swift engines, against the Kotlin port,
// and checks the web app's sample household comes out identical here, task for task.
package com.eworldq8.nokhatha

import com.eworldq8.nokhatha.engine.*
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class VectorTest {
    private val root = File("../..").canonicalFile
    private fun read(p: String) = File(root, p).readText()
    private val catalog = Catalog.load { read("docs/data/$it") }
    private val seasons = catalog.seasons

    private fun day(x: Any?): Day? = (x as? String)?.let { Day.parse(it) }
    private fun iso(d: Day?): Any = d?.iso ?: JSONObject.NULL
    private fun int(x: Any?): Int = (x as Number).toInt()
    private fun window(x: Any?): Window = if (x == "\$bawarih") catalog.bawarih else if (x == "\$heat") catalog.heat!! else (x as JSONObject).let { Window(it.getString("start"), it.getString("end")) }
    private fun car(x: Any?): Odometer? = (x as? JSONObject)?.let { o ->
        val r = o.getJSONArray("readings")
        Odometer(o.optInt("dailyKm", 40), (0 until r.length()).map { Reading(r.getJSONObject(it).getString("date"), r.getJSONObject(it).getInt("km")) })
    }
    private fun nul(o: JSONObject, k: String): Any? = if (o.has(k) && !o.isNull(k)) o.get(k) else null

    private fun run(fn: String, a: JSONArray): Any? {
        fun g(i: Int): Any? = if (i < a.length() && !a.isNull(i)) a.get(i) else null
        return when (fn) {
            "dayNumber" -> Day.parse(g(0) as String)!!.n
            "fromDayNumber" -> Day(int(g(0))).iso
            "weekday" -> Day.parse(g(0) as String)!!.weekday
            "addDays" -> Day.parse(g(0) as String)!!.plus(int(g(1))).iso
            "diffDays" -> diffDays(day(g(0))!!, day(g(1))!!)
            "addMonths" -> Day.parse(g(0) as String)!!.plusMonths(int(g(1))).iso
            "isISO" -> isISO(g(0) as String)
            "seasonAt" -> seasonAt(day(g(0))!!, seasons).let {
                JSONObject().put("id", it.id).put("index", it.index).put("start", it.start.iso).put("next", it.next.iso).put("nextId", it.nextId)
                    .put("length", it.length).put("dayIn", it.dayIn).put("daysLeft", it.daysLeft)
            }
            "seasonRing" -> seasonRing(day(g(0))!!, seasons).let { (total, segs) ->
                JSONObject().put("total", total).put("segs", JSONArray(segs.map { JSONObject().put("id", it.id).put("start", it.start.iso).put("offset", it.offset).put("length", it.length) }))
            }
            "seasonStartOnOrAfter" -> iso(seasonStartOnOrAfter(day(g(0))!!, g(1) as String, seasons))
            "inWindow" -> inWindow(day(g(0))!!, window(g(1)))
            "seasonalDue" -> iso(seasonalDue(day(g(0)), g(1) as String, int(g(2)), day(g(3))!!, seasons))
            "kmRate" -> kmRate(car(g(0))!!).let { JSONObject().put("num", it.first).put("den", it.second) }
            "kmOn" -> kmOn(car(g(0))!!, day(g(1))!!) ?: JSONObject.NULL
            "dateAtKm" -> iso(dateAtKm(car(g(0))!!, int(g(1))))
            "lastReading" -> lastReading(car(g(0))!!)?.let { JSONObject().put("date", it.date).put("km", it.km) } ?: JSONObject.NULL
            "nextDue" -> {
                val item = g(0) as JSONObject
                val ctx = g(1) as JSONObject
                val input = DueInput(everyFrom(item.getJSONObject("every"))!!, day(nul(item, "lastDone")), nul(item, "lastKm")?.let { int(it) },
                    day(nul(item, "due")), day(nul(item, "snoozeUntil")), day(nul(item, "firstDue")))
                val d = nextDue(input, day(ctx.get("today"))!!, seasons, nul(ctx, "bawarih")?.let { window(it) }, car(nul(ctx, "car")), nul(ctx, "heat")?.let { window(it) })
                JSONObject().put("due", iso(d.due)).put("by", d.by)
            }
            "statusOf" -> statusOf(day(g(0)), day(g(1))!!, int(g(2))).let { JSONObject().put("status", it.status).put("days", it.days ?: JSONObject.NULL) }
            "cycleProgress" -> cycleProgress(day(g(0)), day(g(1)), day(g(2))!!)
            "nextRenewal" -> (g(0) as JSONObject).let { nextRenewal(Day.parse(it.getString("anchor"))!!, Cycle.of(it.getString("cycle"))!!, day(g(1))!!).iso }
            "nthRenewal" -> nthRenewal(day(g(0))!!, Cycle.of(g(1) as String)!!, int(g(2))).iso
            "chargesBetween" -> (g(0) as JSONObject).let { chargesBetween(Day.parse(it.getString("anchor"))!!, Cycle.of(it.getString("cycle"))!!, day(g(1))!!, day(g(2))!!) }
            "perMonth" -> perMonth(int(g(0)), Cycle.of(g(1) as String)!!)
            "perYear" -> perYear(int(g(0)), Cycle.of(g(1) as String)!!)
            "subTotals" -> (g(0) as JSONArray).let { arr ->
                val subs = (0 until arr.length()).map { arr.getJSONObject(it) }.map { SubAmount(it.getInt("amount"), it.getString("currency"), Cycle.of(it.getString("cycle"))!!, it.optBoolean("cancelled", false)) }
                JSONObject().apply { subTotals(subs).forEach { (k, v) -> put(k, JSONObject().put("month", v.month).put("year", v.year).put("count", v.count)) } }
            }
            "formatMoney" -> formatMoney(int(g(0)), g(1) as String, g(2) as String)
            "normalizeDigits" -> normalizeDigits(g(0) as String)
            "parseMoney" -> parseMoney(g(0) as String, g(1) as String) ?: JSONObject.NULL
            "countAr" -> countAr(int(g(0)), g(1) as String)
            "relative" -> relative(int(g(0)), g(1) as String)
            "formatDate" -> formatDate(day(g(0))!!, g(1) as String, g(2)?.let { int(it) })
            "toICS" -> {
                val evs = g(0) as JSONArray
                val opts = g(1) as JSONObject
                toICS((0 until evs.length()).map { evs.getJSONObject(it) }.map {
                    CalendarEvent(it.getString("uid"), Day.parse(it.getString("date"))!!, it.getString("title"), nul(it, "note") as String?, it.optInt("lead", 0))
                }, opts.getString("stamp"), opts.getString("calName"))
            }
            "foldLine" -> foldLine(g(0) as String)
            else -> "missing function $fn"
        }
    }

    private fun same(x: Any?, y: Any?): Boolean {
        val a = if (x == JSONObject.NULL) null else x
        val b = if (y == JSONObject.NULL) null else y
        if (a == null || b == null) return a == null && b == null
        if (a is String || b is String) return a == b
        if (a is Boolean || b is Boolean) return a == b
        if (a is Number && b is Number) return Math.abs(a.toDouble() - b.toDouble()) < 1e-9
        if (a is JSONArray && b is JSONArray) return a.length() == b.length() && (0 until a.length()).all { same(a.get(it), b.get(it)) }
        if (a is JSONObject && b is JSONObject) return a.keySet() == b.keySet() && a.keySet().all { same(a.get(it), b.get(it)) }
        return false
    }

    @Test
    fun sharedVectors() {
        val cases = JSONObject(read("tests/vectors.json")).getJSONArray("cases")
        assertTrue(cases.length() >= 180)
        val failures = ArrayList<String>()
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val got = run(c.getString("fn"), c.getJSONArray("args"))
            if (!same(got, c.get("out"))) failures += "${c.getString("fn")} ${c.getJSONArray("args")} expected ${c.get("out")} got $got"
        }
        println("NokhathaKit Kotlin: ${cases.length() - failures.size} of ${cases.length()} shared vectors pass")
        assertEquals(failures.joinToString("\n"), 0, failures.size)
    }

    @Test
    fun dayNumbersRoundTrip() {
        val from = Day.parse("1900-01-01")!!.n
        val to = Day.parse("2100-12-31")!!.n
        for (z in from..to) assertEquals(z, Day.parse(Day(z).iso)!!.n)
    }

    @Test
    fun seasonStructureEveryDay() {
        var d = Day.parse("2024-01-01")!!
        val end = Day.parse("2032-12-31")!!
        while (d <= end) {
            val s = seasonAt(d, seasons)
            val (total, segs) = seasonRing(d, seasons)
            assertTrue("season on $d", s.start <= d && d < s.next && s.dayIn - 1 + s.daysLeft == s.length && (total == 365 || total == 366)
                && segs.size == 14 && segs[0].id == s.id && (1 until segs.size).all { segs[it].offset == segs[it - 1].offset + segs[it - 1].length })
            d = d.plus(1)
        }
    }

    @Test
    fun tasksMatchTheWebApp() {
        val f = JSONObject(read("tests/fixtures/parity.json"))
        val today = Day.parse(f.getString("today"))!!
        val brain = Brain(catalog, AppState.fromJson(f.getJSONObject("state")), today)
        val got = brain.tasks()
        val want = f.getJSONArray("tasks")
        assertEquals(want.length(), got.size)
        for (i in 0 until want.length()) {
            val w = want.getJSONObject(i)
            val g = got[i]
            assertEquals("order at $i", w.getString("id"), g.item.id)
            assertEquals("due of ${w.getString("id")}", if (w.isNull("due")) null else w.getString("due"), g.due?.iso)
            assertEquals(w.getString("by"), g.by)
            assertEquals(w.getString("status"), g.status)
            assertEquals(if (w.isNull("days")) null else w.getInt("days"), g.days)
        }
        val subs = brain.subs().associateBy { it.sub.id }
        val ws = f.getJSONArray("subs")
        for (i in 0 until ws.length()) {
            val w = ws.getJSONObject(i)
            assertEquals(w.getString("next"), subs[w.getString("id")]!!.next.iso)
        }
        val t = f.getJSONObject("totals").getJSONObject("KWD")
        assertEquals(SubTotal(t.getInt("month"), t.getInt("year"), t.getInt("count")), brain.totals()["KWD"])
        // the state survives being written and read back
        val back = AppState.fromJson(JSONObject(brain.state.toJson().toString()))
        assertEquals(brain.state.copy(settings = brain.state.settings.copy(extra = null)), back.copy(settings = back.settings.copy(extra = null)))
    }

    @Test
    fun setupAndWordsLikeTheOthers() {
        val today = Day.parse("2026-09-25")!!
        val b = Brain(catalog, AppState(), today)
        val s = Brain.Setup().apply {
            country = "AE"; homeType = "flat"; features = mutableMapOf("central_ac" to true, "tank" to false, "filter" to false)
            extras = mutableListOf("صيانة المصعد" to 3); km = 42000; things = mutableListOf("boat", "other"); otherName = "البئر"
        }
        val created = b.setUp(s, "شقة", "سيارتي") { it }
        assertEquals(4, created.size)
        assertEquals("AED", b.state.settings.currency)
        val q = b.lastQuestions(created)
        assertEquals("ac_filters", q.first().tpl)
        b.finishSetUp(created, mapOf(q[0].id to "m3"))
        assertEquals("2026-06-27", b.state.items.first { it.id == q[0].id }.lastDone)
        val w = Words(catalog.strings, "ar")
        val center = w.seasonCenter(seasonAt(today, seasons), catalog, today)
        assertEquals("سهيل", center.title)
        assertEquals("باقي 20 يوم على الوسم", center.line2)
        assertEquals("كل 30 يوم، وكل 14 يوم بالبوارح", w.every(Every(days = 30, bawarih = 14), catalog))
        assertEquals("كل 30 يوم، وكل 14 يوم بالقيظ", w.every(Every(days = 30, bawarih = 14, heat = 14), catalog))
    }
}

class ExtrasTest {
    private val root = java.io.File("../..").canonicalFile
    private fun read(p: String) = java.io.File(root, p).readText()
    private val catalog = Catalog.load { read("docs/data/$it") }

    @Test
    fun opensABackupMadeByTheWebApp() {
        val f = JSONObject(read("tests/fixtures/backup-web.json"))
        val payload = JSONObject(Backup.decrypt(f.getJSONObject("file").toString(), "nokhatha-test-2026"))
        val want = AppState.fromJson(f.getJSONObject("state"))
        val got = AppState.fromJson(payload.getJSONObject("state"))
        assertEquals(want.copy(settings = want.settings.copy(extra = null)), got.copy(settings = got.settings.copy(extra = null)))
        assertEquals("r1", got.warranties.single().receipt)
        val r = payload.getJSONObject("receipts").getJSONObject("r1")
        assertEquals("image/jpeg", r.getString("type"))
        assertEquals(listOf(0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 0xff, 0xd9), B64.decode(r.getString("data")).map { it.toInt() and 0xff })
        try {
            Backup.decrypt(f.getJSONObject("file").toString(), "wrong-password")
            throw AssertionError("a wrong password must fail")
        } catch (e: BackupError) {
            assertEquals("pass", e.reason)
        }
        try {
            Backup.decrypt("{\"app\":\"other\"}", "x")
            throw AssertionError("a foreign file must fail")
        } catch (e: BackupError) {
            assertEquals("format", e.reason)
        }
    }

    @Test
    fun backupRoundTripAndBase64() {
        val text = "{\"state\":{\"v\":1},\"note\":\"نُوخذة\"}"
        val file = Backup.encrypt(text, "12345678", 1000)
        assertEquals(text, Backup.decrypt(file, "12345678"))
        for (n in 0..40) {
            val b = ByteArray(n) { (it * 37 + n).toByte() }
            assertEquals(java.util.Base64.getEncoder().encodeToString(b), B64.encode(b))
            assertTrue(b.contentEquals(B64.decode(B64.encode(b))))
        }
    }

    @Test
    fun phoneNumbersLikeTheWeb() {
        assertEquals("96551153554", phoneDigits("51153554", "KW"))
        assertEquals("96551153554", phoneDigits("٥١١٥٣٥٥٤", "KW"))
        assertEquals("96551153554", phoneDigits("+965 5115 3554", "KW"))
        assertEquals("96551153554", phoneDigits("00965-51153554", "KW"))
        assertEquals("966512345678", phoneDigits("0512345678", "SA"))
        assertEquals("1234", phoneDigits("1234", "KW"))
    }

    @Test
    fun intervalsAndRestoreLikeTheWeb() {
        val today = Day.parse("2026-09-25")!!
        val b = Brain(catalog, Brain.sample(catalog, "ar", today), today)
        val oil = b.state.items.first { it.tpl == "oil" }
        b.setInterval(oil.id, 8, "months", 12000)
        assertEquals(Every(months = 8, km = 12000), b.state.items.first { it.id == oil.id }.every)
        b.setInterval(oil.id, 45, "days", null)
        assertEquals(Every(days = 45, km = 12000), b.state.items.first { it.id == oil.id }.every)
        b.setInterval(oil.id, null, "days", null)
        assertEquals(null, b.state.items.first { it.id == oil.id }.every)
        val filters = b.state.items.first { it.tpl == "ac_filters" }
        b.setInterval(filters.id, 200, "months", null)
        assertEquals(Every(months = 120), b.state.items.first { it.id == filters.id }.every)
        val sub = b.state.subs.first()
        b.cancelSub(sub.id)
        assertEquals(true, b.state.subs.first().cancelled)
        b.restoreSub(sub.id)
        assertEquals(null, b.state.subs.first().cancelled)
        assertEquals(null, b.state.subs.first().cancelledOn)
        b.markDone(oil.id, today.plus(-3), 66500, 18000)
        val done = b.state.items.first { it.id == oil.id }
        assertEquals(today.plus(-3).iso, done.lastDone)
        assertEquals(66500, done.lastKm)
        assertEquals(LogEntry(today.plus(-3).iso, 18000, "KWD", 66500), done.log.last())
    }

    @Test
    fun documentsAndRenewalLikeTheWeb() {
        val today = Day.parse("2026-09-25")!!
        val b = Brain(catalog, Brain.sample(catalog, "ar", today), today)
        val docs = b.docs()
        assertEquals(4, docs.size)
        assertEquals("civil_id", docs.first().type.id)
        assertEquals("soon", docs.first().status)                       // 40 days ahead, lead 45
        val res = docs.first { it.type.id == "residency" }
        assertEquals("soon", res.status)                                  // 52 days ahead, lead 60
        assertEquals("health", res.needType?.id)
        assertEquals("soon", res.need?.status)                            // the driver's health cover ends first
        assertEquals("الإقامة", b.docTitle(res.d, "ar"))
        assertEquals("Iqama", catalog.docType.getValue("residency").name("en", "SA"))
        val renewed = b.renewDoc(res.d.id)!!
        assertEquals(today.plus(52).plusMonths(12).iso, renewed.expiry)   // a year on from the old date
        val old = Doc("x", "passport", "أنا", null, today.plus(-30).iso)
        b.saveDoc(old)
        assertEquals("overdue", b.evalDoc(old).status)
        assertEquals(today.plusMonths(120).iso, b.renewDoc("x")!!.expiry) // ten years from today when already expired
        b.deleteDoc("x")
        assertEquals(4, b.state.docs.size)
        // the registration renewal path
        val car = b.state.cars.first()
        assertEquals(true, b.renewalShown(car.id))                        // registration due in 21 days
        b.setRenewStep(car.id, "insurance", true)
        b.setRenewYears(car.id, 2)
        assertEquals(listOf("insurance"), b.state.cars.first().renewal?.done)
        b.finishRenewal(car.id)
        val reg = b.state.items.first { it.asset == car.id && it.tpl == "registration" }
        assertEquals(today.plus(21).plusMonths(24).iso, reg.due)
        assertEquals(today.plus(21).plusMonths(24).iso, b.state.items.first { it.asset == car.id && it.tpl == "insurance" }.due)
        assertEquals(today.iso, reg.lastDone)
        assertEquals(null, b.state.cars.first().renewal)
        assertEquals(false, b.renewalShown(car.id))
        val events = b.calendarEvents(Words(catalog.strings, "ar"))
        assertEquals(4, events.count { it.uid.startsWith("d-") })
    }

    @Test
    fun warrantiesSpendAndCalendar() {
        val today = Day.parse("2026-09-25")!!
        val sample = Brain.sample(catalog, "ar", today)
        val b = Brain(catalog, sample, today)
        val ws = b.warranties()
        assertEquals(2, ws.size)
        assertEquals("soon", ws.first().status)
        assertEquals(26, ws.first().days)
        val report = b.spend(2026, "ar")
        val kwd = report.blocks.single { it.currency == "KWD" }
        // costs the sample household logged this year, from the web's sample data
        val logged = sample.items.flatMap { it.log }.filter { it.cost != null && it.date.startsWith("2026") }.sumOf { it.cost!! }
        assertEquals(logged, kwd.home + kwd.car + kwd.things)
        assertTrue(kwd.subs > 0 && kwd.projected >= kwd.subs)
        assertEquals(report.logs.sortedByDescending { it.date.n }, report.logs)
        val events = b.calendarEvents(Words(catalog.strings, "ar"))
        assertEquals(b.tasks().count { it.due != null } + b.subs().count { it.sub.cancelled != true } + ws.count { it.end >= today } + b.docs().size, events.size)
        assertTrue(events.all { it.date >= today })
        val ics = toICS(events, utcStamp(0), "نُوخذة")
        assertTrue(ics.startsWith("BEGIN:VCALENDAR\r\n") && ics.contains("DTSTAMP:19700101T000000Z"))
    }
}

class WeatherTest {
    private val today = Day.parse("2026-09-25")!!

    private fun place(todayDust: Int, tomorrowDust: Int, tmax: List<Int>? = null, tmin: List<Int>? = null, rain: List<Int>? = null,
                      chance: List<Int>? = null, gust: List<Int>? = null, historyDays: Int = 60): Weather.Summary {
        val time = JSONArray(); val pm10 = JSONArray()
        for (i in historyDays downTo 1) { time.put("${today.plus(-i).iso}T12:00"); pm10.put(100 + (historyDays - i)) }
        for ((k, v) in listOf(0 to todayDust, 1 to tomorrowDust, 2 to 120)) { time.put("${today.plus(k).iso}T12:00"); pm10.put(v) }
        val daily = JSONObject().put("time", JSONArray(listOf(today.iso, today.plus(1).iso, today.plus(2).iso)))
            .put("temperature_2m_max", JSONArray(tmax ?: listOf(44, 44, 44))).put("temperature_2m_min", JSONArray(tmin ?: listOf(30, 30, 30)))
            .put("precipitation_sum", JSONArray(rain ?: listOf(0, 0, 0))).put("precipitation_probability_max", JSONArray(chance ?: listOf(0, 0, 0)))
            .put("wind_gusts_10m_max", JSONArray(gust ?: listOf(30, 30, 30)))
        return Weather.summarize(JSONObject().put("daily", daily), JSONObject().put("hourly", JSONObject().put("time", time).put("pm10", pm10)))
    }

    private fun kinds(s: Weather.Summary) = Weather.alerts(s, today).joinToString(" ") { "${it.day}:${it.kind}${it.value?.let { v -> "=$v" } ?: ""}" }

    @Test
    fun sameAlertsAsTheWeb() {
        val s1 = place(160, 250, tmax = listOf(49, 44, 44), rain = listOf(0, 2, 0), gust = listOf(30, 70, 30))
        assertEquals(153, s1.dusty)
        assertEquals(191, s1.heavy)
        assertEquals("0:dust 0:heat=49 1:dust_heavy 1:rain 1:wind", kinds(s1))
        assertEquals("", kinds(place(120, 130)))
        assertEquals("", kinds(place(160, 250, historyDays = 10)))
        assertEquals("0:rain 1:cold=3", kinds(place(120, 120, tmin = listOf(30, 3, 30), chance = listOf(60, 0, 0))))
        val clean = place(149, 149)
        assertTrue(clean.dusty >= 150 && kinds(clean).isEmpty())
        val (forecast, air) = Weather.urls(29.4, 48.0)
        assertTrue(forecast.contains("latitude=29.4&longitude=48&") && air.contains("past_days=60"))
        val back = Weather.fromJson(JSONObject(Weather.toJson(s1).toString()))
        assertEquals(s1, back)
        val st = AppState(settings = Settings(weather = WeatherSetting(true, "kw_city", 29.37, 47.98)))
        assertEquals(st.settings.weather, AppState.fromJson(JSONObject(st.toJson().toString())).settings.weather)
    }
}
