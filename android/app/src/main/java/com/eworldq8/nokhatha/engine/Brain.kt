// The app's logic, ported from the web app and the Swift port, so Android shows the same tasks,
// in the same order, with the same dates.
package com.eworldq8.nokhatha.engine

enum class AssetKind(val key: String) { HOME("home"), CAR("car"), THING("thing") }

data class AssetRef(val id: String, val kind: AssetKind, val name: String, val car: Odometer?)

data class Evaluated(
    val item: Item, val asset: AssetRef, val tpl: Template?, val every: Every, val due: Day?, val by: String,
    val status: String, val days: Int?,
) {
    fun title(lang: String) = tpl?.name(lang) ?: item.title ?: ""
    val icon: String get() = tpl?.icon ?: "spark"
}

data class SubView(
    val sub: Sub, val next: Day, val days: Int, val trial: Boolean, val status: String, val ask: Boolean, val planned: Boolean,
)

private val rank = mapOf("overdue" to 0, "today" to 1, "soon" to 2, "unset" to 3, "ok" to 4)

class Brain(val catalog: Catalog, var state: AppState, val today: Day) {

    fun asset(id: String): AssetRef? {
        state.homes.firstOrNull { it.id == id }?.let { return AssetRef(it.id, AssetKind.HOME, it.name, null) }
        state.cars.firstOrNull { it.id == id }?.let { return AssetRef(it.id, AssetKind.CAR, it.name, it.odometer) }
        state.things.firstOrNull { it.id == id }?.let { return AssetRef(it.id, AssetKind.THING, it.name, null) }
        return null
    }

    fun every(item: Item): Every = item.every ?: item.tpl?.let { catalog.template[it]?.every } ?: Every(months = 6)

    fun evaluate(item: Item): Evaluated? {
        val a = asset(item.asset) ?: return null
        val e = every(item)
        val nd = nextDue(
            DueInput(e, Day.parse(item.lastDone), item.lastKm, Day.parse(item.due), Day.parse(item.snoozeUntil), Day.parse(item.firstDue)),
            today, catalog.seasons, catalog.bawarih, a.car,
        )
        val lead = if (e.fixed == true) e.lead ?: 30 else state.settings.lead
        val st = statusOf(nd.due, today, lead)
        return Evaluated(item, a, item.tpl?.let { catalog.template[it] }, e, nd.due, nd.by, st.status, st.days)
    }

    /** Enabled tasks, most urgent first, then by date. */
    fun tasks(include: (Item) -> Boolean = { true }): List<Evaluated> =
        state.items.filter { it.isOn && include(it) }.mapNotNull { evaluate(it) }
            .sortedWith(compareBy<Evaluated> { rank[it.status] ?: 9 }.thenBy { it.due?.n ?: Int.MAX_VALUE })

    fun progress(e: Evaluated): Double? {
        if (e.every.fixed == true) return null
        val last = Day.parse(e.item.lastDone) ?: return null
        val due = e.due ?: return null
        return cycleProgress(last, due, today)
    }

    fun subs(): List<SubView> = state.subs.mapNotNull { s ->
        val anchor = Day.parse(s.anchor) ?: return@mapNotNull null
        val cycle = Cycle.of(s.cycle) ?: return@mapNotNull null
        val next = nextRenewal(anchor, cycle, today)
        val days = diffDays(today, next)
        val answer = s.usage[next.iso]
        val off = s.cancelled == true
        SubView(s, next, days, s.trial == true && anchor >= today, if (off) "off" else statusOf(next, today, 3).status,
            !off && days <= 7 && answer == null, !off && days <= 7 && answer == "no")
    }

    fun totals(): Map<String, SubTotal> =
        subTotals(state.subs.mapNotNull { s -> Cycle.of(s.cycle)?.let { SubAmount(s.amount, s.currency, it, s.cancelled == true) } })

    private fun updateItem(id: String, f: (Item) -> Item) {
        state = state.copy(items = state.items.map { if (it.id == id) f(it) else it })
    }

    // ---------------------------------------------------------------- changes

    fun markDone(id: String, on: Day? = null, km: Int? = null, cost: Int? = null) {
        val item = state.items.firstOrNull { it.id == id } ?: return
        val whenDay = on ?: today
        var entry = LogEntry(whenDay.iso)
        var lastKm = item.lastKm
        val a = asset(item.asset)
        if (a != null && a.kind == AssetKind.CAR && set(every(item).km) != null) {
            if (km != null) addReading(a.id, km, whenDay)
            val car = state.cars.first { it.id == a.id }
            val k = km ?: kmOn(car.odometer, whenDay)
            lastKm = k
            entry = entry.copy(km = k)
        }
        if (cost != null) entry = entry.copy(cost = cost, cur = state.settings.currency)
        updateItem(id) { it.copy(lastDone = whenDay.iso, snoozeUntil = null, lastKm = lastKm, log = it.log + entry) }
    }

    fun snooze(id: String, days: Int = 7) = updateItem(id) { it.copy(snoozeUntil = today.plus(days).iso) }

    fun renew(id: String) {
        val item = state.items.firstOrNull { it.id == id } ?: return
        val due = Day.parse(item.due) ?: return
        updateItem(id) { it.copy(due = due.plusMonths(every(item).repeatMonths ?: 12).iso, lastDone = today.iso, log = it.log + LogEntry(today.iso)) }
    }

    fun setDue(id: String, day: Day) = updateItem(id) { it.copy(due = day.iso) }

    private fun wants(t: Template, f: Map<String, Boolean>) = t.isDefault && (t.needs == null || f[t.needs] == true)

    fun addHome(type: String, name: String, features: Map<String, Boolean>): Home {
        val f = mapOf("central_ac" to false, "tank" to false, "filter" to false) + features
        val home = Home(newID(), type, name, f)
        state = state.copy(homes = state.homes + home,
            items = state.items + catalog.templates.filter { it.kind == "home" && wants(it, f) }.map { Item(newID(), home.id, it.id) })
        return home
    }

    fun addCar(name: String, km: Int?, dailyKm: Int = 40): Car {
        val car = Car(newID(), name, dailyKm, if (km != null) listOf(Reading(today.iso, km)) else emptyList())
        state = state.copy(cars = state.cars + car,
            items = state.items + catalog.templates.filter { it.kind == "car" && it.isDefault }.map { Item(newID(), car.id, it.id) })
        return car
    }

    fun addThing(type: String, name: String): Thing {
        val thing = Thing(newID(), type, name)
        state = state.copy(things = state.things + thing,
            items = state.items + catalog.templates.filter { it.kind == "thing" && it.forType == type && it.isDefault }.map { Item(newID(), thing.id, it.id) })
        return thing
    }

    /** New assets start with many never logged tasks; plan their first dates about two a week, shortest interval first. */
    fun spreadNew(assets: List<String>) {
        val pending = state.items.filter { assets.contains(it.asset) && it.isOn && it.lastDone == null && it.firstDue == null }
            .mapNotNull { it ->
                val e = every(it)
                if (e.fixed == true || e.season != null) null else Pair(it.id, e.days ?: ((e.months ?: 6) * 30))
            }.sortedBy { it.second }
        val first = HashMap<String, String>()
        pending.forEachIndexed { k, (id, span) -> first[id] = today.plus(minOf(Math.round(k * 3.5).toInt(), span)).iso }
        state = state.copy(items = state.items.map { first[it.id]?.let { d -> it.copy(firstDue = d) } ?: it })
    }

    // ---------------------------------------------------------------- first run, editing

    class Setup {
        var country = "KW"
        var homeType = "house"
        var homeName = ""
        var features = mutableMapOf("central_ac" to false, "tank" to true, "filter" to false)
        var extras = mutableListOf<Pair<String, Int>>()
        var hasCar = true
        var carName = ""
        var km: Int? = null
        var things = mutableListOf<String>()
        var otherName = ""
    }

    fun setUp(s: Setup, homeName: String, carName: String, thingName: (String) -> String): List<String> {
        state = state.copy(settings = state.settings.copy(country = s.country, currency = countries[s.country]?.third ?: "KWD"))
        val home = addHome(s.homeType, s.homeName.trim().ifEmpty { homeName }, s.features)
        val created = mutableListOf(home.id)
        for ((title, months) in s.extras) addCustom(title, Every(months = months), home.id)
        if (s.hasCar) created += addCar(s.carName.trim().ifEmpty { carName }, s.km).id
        for (type in s.things) created += addThing(type, if (type == "other" && s.otherName.isNotBlank()) s.otherName.trim() else thingName(type)).id
        return created
    }

    fun finishSetUp(created: List<String>, answers: Map<String, String>) {
        for ((id, key) in answers) {
            val days = lastOptions.firstOrNull { it.first == key }?.second ?: continue
            val item = state.items.firstOrNull { it.id == id } ?: continue
            var lastKm = item.lastKm
            val a = asset(item.asset)
            if (a?.kind == AssetKind.CAR && set(every(item).km) != null && a.car != null) {
                kmOn(a.car, today)?.let { now -> lastKm = maxOf(0, now - days * (if (a.car.dailyKm > 0) a.car.dailyKm else Engine.DEFAULT_DAILY_KM)) }
            }
            updateItem(id) { it.copy(lastDone = today.plus(-days).iso, lastKm = lastKm) }
        }
        spreadNew(created)
        state = state.copy(settings = state.settings.copy(onboarded = true))
    }

    fun lastQuestions(created: List<String>): List<Item> =
        state.items.filter { lastKeys.contains(it.tpl) && it.isOn && created.contains(it.asset) }.sortedBy { lastKeys.indexOf(it.tpl) }

    fun addable(assetId: String): List<Template> {
        val a = asset(assetId) ?: return emptyList()
        val have = state.items.filter { it.asset == assetId && it.isOn }.mapNotNull { it.tpl }.toSet()
        val type = state.things.firstOrNull { it.id == assetId }?.type
        return catalog.templates.filter { it.kind == a.kind.key && (a.kind != AssetKind.THING || it.forType == type) && !have.contains(it.id) }
    }

    fun addTemplate(tplId: String, assetId: String) {
        if (state.items.any { it.asset == assetId && it.tpl == tplId }) {
            state = state.copy(items = state.items.map { if (it.asset == assetId && it.tpl == tplId) it.copy(enabled = true) else it })
        } else {
            state = state.copy(items = state.items + Item(newID(), assetId, tplId))
        }
    }

    fun addCustom(title: String, every: Every, assetId: String) {
        state = state.copy(items = state.items + Item(newID(), assetId, null, title = title, every = every))
    }

    /** Suggested tasks are switched off, one's own tasks are removed. */
    fun stop(itemId: String) {
        val it0 = state.items.firstOrNull { it.id == itemId } ?: return
        state = if (it0.tpl == null) state.copy(items = state.items.filter { it.id != itemId })
        else state.copy(items = state.items.map { if (it.id == itemId) it.copy(enabled = false) else it })
    }

    fun removeAsset(id: String) {
        state = state.copy(homes = state.homes.filter { it.id != id }, cars = state.cars.filter { it.id != id },
            things = state.things.filter { it.id != id }, items = state.items.filter { it.asset != id })
    }

    fun addReading(carId: String, km: Int, on: Day) {
        state = state.copy(cars = state.cars.map { c ->
            if (c.id != carId) c else c.copy(readings = (c.readings.filter { it.date != on.iso } + Reading(on.iso, km)).sortedBy { it.date })
        })
    }

    fun saveSub(sub: Sub) {
        state = if (state.subs.any { it.id == sub.id }) state.copy(subs = state.subs.map { if (it.id == sub.id) sub else it })
        else state.copy(subs = state.subs + sub)
    }

    fun answer(subId: String, keep: Boolean) {
        val v = subs().firstOrNull { it.sub.id == subId } ?: return
        state = state.copy(subs = state.subs.map { if (it.id == subId) it.copy(usage = it.usage + (v.next.iso to if (keep) "yes" else "no")) else it })
    }

    fun cancelSub(id: String) {
        state = state.copy(subs = state.subs.map { if (it.id == id) it.copy(cancelled = true, cancelledOn = today.iso) else it })
    }

    fun deleteSub(id: String) { state = state.copy(subs = state.subs.filter { it.id != id }) }

    companion object {
        /** dialling code, local digits, currency */
        val countries = linkedMapOf(
            "KW" to Triple("965", 8, "KWD"), "SA" to Triple("966", 9, "SAR"), "AE" to Triple("971", 9, "AED"),
            "QA" to Triple("974", 8, "QAR"), "BH" to Triple("973", 8, "BHD"), "OM" to Triple("968", 8, "OMR"),
        )
        val lastKeys = listOf("ac_filters", "pests", "water_tank", "water_filter", "hood", "smoke", "oil", "tire_pressure")
        val lastOptions = listOf<Pair<String, Int?>>("unknown" to null, "month" to 15, "m3" to 90, "m6" to 180, "year" to 365)

        /** The web app's sample household. */
        fun sample(catalog: Catalog, lang: String, today: Day): AppState {
            val b = Brain(catalog, AppState(settings = Settings(lang = lang, onboarded = true), sample = true), today)
            val t = { ar: String, en: String -> if (lang == "ar") ar else en }
            val home = b.addHome("house", t("البيت", "Home"), mapOf("tank" to true, "filter" to true))
            val chalet = b.addHome("chalet", t("الشاليه", "Chalet"), mapOf("tank" to true))
            val car = b.addCar(t("سيارتي", "My car"), null)
            b.state = b.state.copy(cars = b.state.cars.map {
                if (it.id == car.id) it.copy(readings = listOf(Reading(today.plus(-130).iso, 61200), Reading(today.plus(-10).iso, 66050))) else it
            })
            fun ago(n: Int) = today.plus(-n).iso
            fun cost(n: Int, amount: Int, km: Int? = null) = LogEntry(ago(n), amount, "KWD", km)
            fun set(asset: String, tpl: String, f: (Item) -> Item) {
                b.state = b.state.copy(items = b.state.items.map { if (it.asset == asset && it.tpl == tpl) f(it) else it })
            }
            set(home.id, "ac_filters") { it.copy(lastDone = ago(33)) }
            set(home.id, "ac_service") { it.copy(lastDone = ago(178), log = listOf(cost(178, 25000))) }
            set(home.id, "water_tank") { it.copy(lastDone = ago(170), log = listOf(cost(170, 15000))) }
            set(home.id, "water_filter") { it.copy(lastDone = ago(84)) }
            set(home.id, "water_heater") { it.copy(lastDone = ago(305)) }
            set(home.id, "leaks") { it.copy(lastDone = ago(100)) }
            set(home.id, "seals") { it.copy(lastDone = ago(122)) }
            set(home.id, "smoke") { it.copy(lastDone = ago(150)) }
            set(home.id, "extinguisher") { it.copy(lastDone = ago(200)) }
            set(home.id, "gas_hose") { it.copy(lastDone = ago(176)) }
            set(home.id, "hood") { it.copy(lastDone = ago(45)) }
            set(home.id, "pests") { it.copy(lastDone = ago(96), log = listOf(cost(96, 12000))) }
            val keep = setOf("ac_filters", "water_tank", "pests", "roof_drains", "smoke")
            b.state = b.state.copy(items = b.state.items.map { if (it.asset == chalet.id && !keep.contains(it.tpl)) it.copy(enabled = false) else it })
            set(chalet.id, "ac_filters") { it.copy(lastDone = ago(20)) }
            set(chalet.id, "water_tank") { it.copy(lastDone = ago(60)) }
            set(chalet.id, "pests") { it.copy(lastDone = ago(40), log = listOf(cost(40, 10000))) }
            set(chalet.id, "smoke") { it.copy(lastDone = ago(90)) }
            set(car.id, "oil") { it.copy(lastDone = ago(100), lastKm = 61900, log = listOf(cost(100, 18500, 61900))) }
            set(car.id, "air_filter") { it.copy(lastDone = ago(200), lastKm = 57500) }
            set(car.id, "cabin_filter") { it.copy(lastDone = ago(190), lastKm = 58000) }
            set(car.id, "car_ac") { it.copy(lastDone = ago(172)) }
            set(car.id, "coolant") { it.copy(lastDone = ago(165)) }
            set(car.id, "tires") { it.copy(lastDone = ago(160), log = listOf(cost(160, 120000))) }
            set(car.id, "battery") { it.copy(lastDone = ago(158)) }
            set(car.id, "tire_pressure") { it.copy(lastDone = ago(27)) }
            set(car.id, "brake_fluid") { it.copy(lastDone = ago(400), lastKm = 50000) }
            set(car.id, "registration") { it.copy(due = today.plus(21).iso) }
            set(car.id, "insurance") { it.copy(due = today.plus(21).iso) }
            val boat = b.addThing("boat", t("الطراد", "The boat"))
            set(boat.id, "boat_engine") { it.copy(lastDone = ago(150), log = listOf(cost(150, 45000))) }
            set(boat.id, "boat_hull") { it.copy(lastDone = ago(70)) }
            set(boat.id, "boat_license") { it.copy(due = today.plus(45).iso) }
            b.spreadNew(listOf(home.id, chalet.id, car.id, boat.id))
            fun sub(ar: String, en: String, amount: Int, cycle: String, next: Day, back: Int, category: String, trial: Boolean = false) =
                Sub(newID(), t(ar, en), amount, "KWD", cycle, (if (back > 0) next.plusMonths(-back) else next).iso, category, emptyMap(), if (trial) true else null)
            b.state = b.state.copy(
                subs = listOf(
                    sub("منصة الأفلام", "Movie streaming", 3500, "monthly", today.plus(1), 9, "stream"),
                    sub("الموسيقى", "Music", 1990, "monthly", today.plus(12), 9, "music"),
                    sub("التخزين السحابي", "Cloud storage", 990, "monthly", today.plus(3), 0, "cloud", true),
                    sub("النادي الرياضي", "Gym", 45000, "quarterly", today.plus(40), 9, "gym"),
                    sub("إنترنت البيت", "Home internet", 15000, "monthly", today.plus(6), 9, "internet"),
                    sub("برنامج التصميم", "Design app", 35000, "yearly", today.plus(64), 12, "apps"),
                ),
                warranties = listOf(
                    Warranty(newID(), t("الثلاجة", "Fridge"), t("معرض الأجهزة", "Appliance store"), ago(300), 24),
                    Warranty(newID(), t("مكيف الصالة", "Living room AC"), t("وكيل المكيفات", "AC dealer"), today.plus(26).plusMonths(-24).iso, 24),
                ),
                techs = listOf(
                    Tech(newID(), t("أبو محمد", "Abu Mohammed"), "ac", "12345678"),
                    Tech(newID(), t("أبو علي", "Abu Ali"), "plumber", "12345679"),
                    Tech(newID(), t("كراج الشويخ", "Shuwaikh garage"), "mechanic", "12345680"),
                ),
            )
            return b.state
        }
    }
}

/** Words from the same strings.json the web app uses. */
class Words(private val strings: Map<String, Map<String, String>>, val lang: String) {
    val isArabic get() = lang == "ar"
    val comma get() = if (isArabic) "، " else ", "

    fun t(key: String, vars: Map<String, String> = emptyMap()): String {
        var s = strings[lang]?.get(key) ?: strings["ar"]?.get(key) ?: key
        for ((k, v) in vars) s = s.replace("{$k}", v)
        return s
    }

    fun money(minor: Int, cur: String) = formatMoney(minor, cur, lang)
    fun date(d: Day, today: Day) = formatDate(d, lang, today.ymd.first)
    fun rel(days: Int) = relative(days, lang)
    fun dayCount(n: Int) = if (isArabic) countAr(n, "day") else "$n day${if (n == 1) "" else "s"}"
    fun monthCount(n: Int) = if (isArabic) countAr(n, "month") else "$n month${if (n == 1) "" else "s"}"
    fun km(n: Int) = groupThousands(n.toString()) + if (isArabic) " كم" else " km"

    fun due(e: Evaluated, today: Day): Pair<String, String?> {
        if (e.status == "unset") return Pair(t("due.unset"), null)
        val d = e.due ?: return Pair("", null)
        val days = e.days ?: return Pair("", null)
        val r = when {
            e.every.fixed == true -> if (days < 0) t("due.expired", mapOf("rel" to rel(days))) else t("due.expires", mapOf("rel" to rel(days)))
            e.status == "overdue" -> if (days == -1) t("due.overdue_yesterday") else t("due.overdue", mapOf("rel" to rel(days)))
            e.status == "today" -> t("due.today")
            else -> t("due.in", mapOf("rel" to rel(days)))
        }
        if (e.by == "km" && e.item.lastKm != null && e.every.km != null) return Pair(r, t("due.km", mapOf("km" to km(e.item.lastKm + e.every.km))))
        return Pair(r, date(d, today))
    }

    fun every(e: Every, catalog: Catalog): String {
        if (e.fixed == true) {
            val m = e.repeatMonths ?: 12
            return t("every.fixed", mapOf("n" to if (m == 12) t("every.year") else monthCount(m)))
        }
        val season = e.season?.let { catalog.season(it) }
        if (season != null) {
            val name = season.name(lang)
            val o = e.offset ?: 0
            return if (o != 0) t("every.before", mapOf("season" to name, "n" to dayCount(-o))) else t("every.with", mapOf("season" to name))
        }
        var s = when {
            e.km != null -> t("every.km", mapOf("km" to km(e.km), "time" to monthCount(e.months ?: 6)))
            e.months != null -> t("every.plain", mapOf("n" to monthCount(e.months)))
            else -> t("every.plain", mapOf("n" to dayCount(e.days ?: 30)))
        }
        if (e.bawarih != null) s += t("every.bawarih", mapOf("n" to dayCount(e.bawarih)))
        return s
    }

    fun greeting(hour: Int) = if (hour in 4..11) t("greet.morning") else t("greet.evening")
    fun longDate(d: Day) = "${weekdayNames.getValue(if (isArabic) "ar" else "en")[d.weekday]} ${formatDate(d, lang, d.ymd.first)}"

    data class Center(val title: String, val line1: String, val line2: String)

    fun seasonCenter(info: SeasonInfo, catalog: Catalog, today: Day): Center {
        val name = catalog.season(info.id)?.name(lang) ?: ""
        val next = catalog.season(info.nextId)?.name(lang) ?: ""
        return Center(name, "${date(info.start, today)} ${t("dial.to")} ${date(info.next.plus(-1), today)}",
            t("dial.left", mapOf("n" to dayCount(info.daysLeft), "next" to next)))
    }
}
