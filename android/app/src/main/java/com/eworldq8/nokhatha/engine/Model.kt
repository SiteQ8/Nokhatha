// The bundled data (the same docs/data files the web app reads) and the person's state,
// read and written in exactly the web app's JSON shape, so data moves between web, iPhone and Android.
package com.eworldq8.nokhatha.engine

import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom

private fun JSONObject.str(k: String): String? = if (has(k) && !isNull(k)) getString(k) else null
private fun JSONObject.int(k: String): Int? = if (has(k) && !isNull(k)) getInt(k) else null
private fun JSONObject.bool(k: String): Boolean? = if (has(k) && !isNull(k)) getBoolean(k) else null
private fun JSONObject.dbl(k: String): Double? = if (has(k) && !isNull(k)) getDouble(k) else null
private fun JSONObject.arr(k: String): JSONArray = if (has(k) && !isNull(k)) getJSONArray(k) else JSONArray()
private fun <T> JSONArray.map(f: (JSONObject) -> T): List<T> = (0 until length()).map { f(getJSONObject(it)) }
private fun JSONObject.opt(k: String, v: Any?): JSONObject { if (v != null) put(k, v); return this }

fun everyFrom(o: JSONObject?): Every? = o?.let {
    Every(it.int("days"), it.int("months"), it.int("km"), it.int("bawarih"), it.str("season"), it.int("offset"),
        it.bool("fixed"), it.int("lead"), it.int("repeat"))
}

fun Every.toJson(): JSONObject = JSONObject().opt("days", days).opt("months", months).opt("km", km).opt("bawarih", bawarih)
    .opt("season", season).opt("offset", offset).opt("fixed", fixed).opt("lead", lead).opt("repeat", repeatMonths)

// ---------------------------------------------------------------- catalog

data class Template(
    val id: String, val kind: String, val area: String, val icon: String, val trade: String?, val isDefault: Boolean,
    val needs: String?, val forType: String?, val every: Every, val ar: String, val en: String, val whyAr: String, val whyEn: String,
) {
    fun name(lang: String) = if (lang == "ar") ar else en
    fun why(lang: String) = if (lang == "ar") whyAr else whyEn
}

data class Named(val id: String, val ar: String, val en: String, val icon: String? = null) {
    fun name(lang: String) = if (lang == "ar") ar else en
}

data class Place(val id: String, val country: String, val ar: String, val en: String, val lat: Double, val lon: Double)

class Catalog(
    val seasons: List<Season>, val bawarih: Window, val templates: List<Template>, val areas: Map<String, List<Named>>,
    val trades: List<Named>, val travel: List<Named>, val thingTypes: List<Named>, val places: List<Place>,
    val strings: Map<String, Map<String, String>>,
) {
    val template: Map<String, Template> = templates.associateBy { it.id }
    fun season(id: String) = seasons.firstOrNull { it.id == id }

    companion object {
        /** read(name) returns the text of seasons.json, tasks.json, strings.json or places.json. */
        fun load(read: (String) -> String): Catalog {
            val s = JSONObject(read("seasons.json"))
            val t = JSONObject(read("tasks.json"))
            val p = JSONObject(read("places.json"))
            val str = JSONObject(read("strings.json"))
            val named = { o: JSONObject -> Named(o.getString("id"), o.getString("ar"), o.getString("en"), o.str("icon")) }
            val areas = t.getJSONObject("areas").let { a -> a.keys().asSequence().associateWith { k -> a.getJSONArray(k).map(named) } }
            val strings = str.keys().asSequence().associateWith { lang ->
                val o = str.getJSONObject(lang)
                o.keys().asSequence().associateWith { o.getString(it) }
            }
            return Catalog(
                seasons = s.getJSONArray("seasons").map {
                    Season(it.getString("id"), it.getString("start"), it.getString("group"), it.getString("ar"), it.getString("en"),
                        it.str("note_ar"), it.str("note_en"), it.str("hint_ar"), it.str("hint_en"))
                },
                bawarih = s.getJSONObject("bawarih").let { Window(it.getString("start"), it.getString("end")) },
                templates = t.getJSONArray("templates").map {
                    Template(it.getString("id"), it.getString("kind"), it.getString("area"), it.getString("icon"), it.str("trade"),
                        it.optBoolean("default", false), it.str("needs"), it.str("for"), everyFrom(it.getJSONObject("every"))!!,
                        it.getString("ar"), it.getString("en"), it.getString("why_ar"), it.getString("why_en"))
                },
                areas = areas,
                trades = t.getJSONArray("trades").map(named),
                travel = t.getJSONArray("travel").map(named),
                thingTypes = t.getJSONArray("thingTypes").map(named),
                places = p.getJSONArray("places").map { Place(it.getString("id"), it.getString("country"), it.getString("ar"), it.getString("en"), it.getDouble("lat"), it.getDouble("lon")) },
                strings = strings,
            )
        }
    }
}

// ---------------------------------------------------------------- state

data class LogEntry(val date: String, val cost: Int? = null, val cur: String? = null, val km: Int? = null)

data class Item(
    val id: String, val asset: String, val tpl: String?, val enabled: Boolean? = true, val lastDone: String? = null,
    val lastKm: Int? = null, val due: String? = null, val snoozeUntil: String? = null, val firstDue: String? = null,
    val title: String? = null, val every: Every? = null, val log: List<LogEntry> = emptyList(),
) {
    val isOn: Boolean get() = enabled != false
}

data class Home(val id: String, val type: String, val name: String, val features: Map<String, Boolean> = emptyMap())
data class Car(val id: String, val name: String, val dailyKm: Int? = 40, val readings: List<Reading> = emptyList()) {
    val odometer: Odometer get() = Odometer(dailyKm ?: Engine.DEFAULT_DAILY_KM, readings)
}
data class Thing(val id: String, val type: String, val name: String)
data class Sub(
    val id: String, val name: String, val amount: Int, val currency: String, val cycle: String, val anchor: String,
    val category: String? = null, val usage: Map<String, String> = emptyMap(), val trial: Boolean? = null,
    val note: String? = null, val cancelled: Boolean? = null, val cancelledOn: String? = null,
)
data class Warranty(val id: String, val name: String, val store: String?, val bought: String, val months: Int, val receipt: String? = null)
data class Tech(val id: String, val name: String, val trade: String, val phone: String, val note: String? = null)

data class Settings(
    val lang: String = "ar", val country: String = "KW", val theme: String = "auto", val currency: String = "KWD",
    val lead: Int = 7, val onboarded: Boolean = false, val notify: Boolean? = null, val lastBackup: String? = null,
    val extra: JSONObject? = null,
)

data class AppState(
    val v: Int = 1, val settings: Settings = Settings(), val homes: List<Home> = emptyList(), val cars: List<Car> = emptyList(),
    val things: List<Thing> = emptyList(), val items: List<Item> = emptyList(), val subs: List<Sub> = emptyList(),
    val warranties: List<Warranty> = emptyList(), val techs: List<Tech> = emptyList(), val travelDone: List<String> = emptyList(),
    val sample: Boolean? = null,
) {
    val isEmpty: Boolean get() = homes.isEmpty() && cars.isEmpty() && things.isEmpty() && subs.isEmpty()

    fun toJson(): JSONObject {
        val s = JSONObject(settings.extra?.toString() ?: "{}")
            .put("lang", settings.lang).put("country", settings.country).put("theme", settings.theme)
            .put("currency", settings.currency).put("lead", settings.lead).put("onboarded", settings.onboarded)
            .opt("notify", settings.notify).opt("lastBackup", settings.lastBackup)
        return JSONObject().put("v", v).put("settings", s)
            .put("homes", JSONArray(homes.map { h ->
                JSONObject().put("id", h.id).put("kind", "home").put("type", h.type).put("name", h.name).put("features", JSONObject(h.features as Map<*, *>))
            }))
            .put("cars", JSONArray(cars.map { c ->
                JSONObject().put("id", c.id).put("kind", "car").put("name", c.name).opt("dailyKm", c.dailyKm)
                    .put("readings", JSONArray(c.readings.map { JSONObject().put("date", it.date).put("km", it.km) }))
            }))
            .put("things", JSONArray(things.map { JSONObject().put("id", it.id).put("kind", "thing").put("type", it.type).put("name", it.name) }))
            .put("items", JSONArray(items.map { i ->
                JSONObject().put("id", i.id).put("asset", i.asset).put("tpl", i.tpl ?: JSONObject.NULL).put("enabled", i.enabled ?: true)
                    .put("lastDone", i.lastDone ?: JSONObject.NULL).opt("lastKm", i.lastKm).opt("due", i.due).opt("snoozeUntil", i.snoozeUntil)
                    .opt("firstDue", i.firstDue).opt("title", i.title).opt("every", i.every?.toJson())
                    .put("log", JSONArray(i.log.map { l -> JSONObject().put("date", l.date).opt("cost", l.cost).opt("cur", l.cur).opt("km", l.km) }))
            }))
            .put("subs", JSONArray(subs.map { s ->
                JSONObject().put("id", s.id).put("name", s.name).put("amount", s.amount).put("currency", s.currency).put("cycle", s.cycle)
                    .put("anchor", s.anchor).opt("category", s.category).put("usage", JSONObject(s.usage as Map<*, *>)).opt("trial", s.trial)
                    .opt("note", s.note).opt("cancelled", s.cancelled).opt("cancelledOn", s.cancelledOn)
            }))
            .put("warranties", JSONArray(warranties.map { w ->
                JSONObject().put("id", w.id).put("name", w.name).opt("store", w.store).put("bought", w.bought).put("months", w.months).opt("receipt", w.receipt)
            }))
            .put("techs", JSONArray(techs.map { t -> JSONObject().put("id", t.id).put("name", t.name).put("trade", t.trade).put("phone", t.phone).opt("note", t.note) }))
            .put("travel", JSONObject().put("done", JSONArray(travelDone)))
            .opt("sample", sample)
    }

    companion object {
        fun fromJson(o: JSONObject): AppState {
            val s = if (o.has("settings")) o.getJSONObject("settings") else JSONObject()
            return AppState(
                v = o.int("v") ?: 1,
                settings = Settings(s.str("lang") ?: "ar", s.str("country") ?: "KW", s.str("theme") ?: "auto", s.str("currency") ?: "KWD",
                    s.int("lead") ?: 7, s.bool("onboarded") ?: false, s.bool("notify"), s.str("lastBackup"), s),
                homes = o.arr("homes").map { h ->
                    val f = if (h.has("features") && !h.isNull("features")) h.getJSONObject("features") else JSONObject()
                    Home(h.getString("id"), h.str("type") ?: "house", h.getString("name"), f.keys().asSequence().associateWith { f.getBoolean(it) })
                },
                cars = o.arr("cars").map { c -> Car(c.getString("id"), c.getString("name"), c.int("dailyKm"), c.arr("readings").map { Reading(it.getString("date"), it.getInt("km")) }) },
                things = o.arr("things").map { Thing(it.getString("id"), it.getString("type"), it.getString("name")) },
                items = o.arr("items").map { i ->
                    Item(i.getString("id"), i.getString("asset"), i.str("tpl"), i.bool("enabled"), i.str("lastDone"), i.int("lastKm"), i.str("due"),
                        i.str("snoozeUntil"), i.str("firstDue"), i.str("title"), everyFrom(if (i.has("every") && !i.isNull("every")) i.getJSONObject("every") else null),
                        i.arr("log").map { LogEntry(it.getString("date"), it.int("cost"), it.str("cur"), it.int("km")) })
                },
                subs = o.arr("subs").map { s2 ->
                    val u = if (s2.has("usage") && !s2.isNull("usage")) s2.getJSONObject("usage") else JSONObject()
                    Sub(s2.getString("id"), s2.getString("name"), s2.getInt("amount"), s2.getString("currency"), s2.getString("cycle"), s2.getString("anchor"),
                        s2.str("category"), u.keys().asSequence().associateWith { u.getString(it) }, s2.bool("trial"), s2.str("note"), s2.bool("cancelled"), s2.str("cancelledOn"))
                },
                warranties = o.arr("warranties").map { Warranty(it.getString("id"), it.getString("name"), it.str("store"), it.getString("bought"), it.getInt("months"), it.str("receipt")) },
                techs = o.arr("techs").map { Tech(it.getString("id"), it.getString("name"), it.getString("trade"), it.getString("phone"), it.str("note")) },
                travelDone = (if (o.has("travel") && !o.isNull("travel")) o.getJSONObject("travel").arr("done") else JSONArray()).let { a -> (0 until a.length()).map { a.getString(it) } },
                sample = o.bool("sample"),
            )
        }
    }
}

private val random = SecureRandom()

fun newID(): String {
    val b = ByteArray(6)
    random.nextBytes(b)
    return b.joinToString("") { "%02x".format(java.util.Locale.ROOT, it.toInt() and 0xff) }
}
