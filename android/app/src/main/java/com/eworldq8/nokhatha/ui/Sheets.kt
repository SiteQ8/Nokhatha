// Adding and editing, laid out as the web's sheets: sh-head, facts, fields, actions.
package com.eworldq8.nokhatha.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.AppModel
import com.eworldq8.nokhatha.engine.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Sheet(model: AppModel, title: String?, onClose: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val p = pal()
    ModalBottomSheet(onDismissRequest = onClose, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = p.surface) {
        CompositionLocalProvider(LocalLayoutDirection provides if (model.isArabic) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 34.dp)) {
                if (title != null) Text(title, style = title(22, 1.35), color = p.ink, modifier = Modifier.padding(end = 44.dp))
                content()
            }
        }
    }
}

/** A date field shaped like the web's input; days are whole civil dates, so the picker works in UTC. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DayPicker(label: String, day: Day, modifier: Modifier = Modifier, onPick: (Day) -> Unit) {
    val p = pal()
    var open by remember { mutableStateOf(false) }
    val lang = if (LocalLayoutDirection.current == LayoutDirection.Rtl) "ar" else "en"
    Column(modifier) {
        FieldLabel(label)
        Row(
            Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(13.dp)).background(p.bg).border(1.dp, p.line, RoundedCornerShape(13.dp))
                .clickable(role = Role.Button) { open = true }.padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(formatDate(day, lang, 0) + " " + day.ymd.first, style = body(16, lineHeight = 1.2), color = p.ink, maxLines = 1, modifier = Modifier.weight(1f))
            Ico("calendar", p.ink3, 18.dp)
        }
    }
    if (open) {
        val state = rememberDatePickerState(initialSelectedDateMillis = day.n * 86_400_000L)
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton({
                    state.selectedDateMillis?.let { ms -> onPick(Day(Math.floorDiv(ms, 86_400_000L).toInt())) }
                    open = false
                }) { Text("OK") }
            },
        ) { DatePicker(state) }
    }
}

/** The web's .facts: small framed boxes, two to a row. */
@Composable
fun Facts(items: List<Pair<String, String>>) {
    val p = pal()
    Column(Modifier.fillMaxWidth().padding(top = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        for (row in items.chunked(2)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for ((k, v) in row) {
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(14.dp)).border(1.dp, p.line, RoundedCornerShape(14.dp)).padding(horizontal = 12.dp, vertical = 10.dp)) {
                        Text(k, style = body(12.5, FontWeight.SemiBold, 1.4), color = p.ink3)
                        Text(v, style = body(14.5, FontWeight.SemiBold, 1.5), color = p.ink, modifier = Modifier.padding(top = 2.dp))
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

// ---------------------------------------------------------------- task

@Composable
fun TaskSheet(model: AppModel, e: Evaluated, onClose: () -> Unit) {
    val p = pal()
    val w = model.words
    val line = w.due(e, model.today)
    val cur = model.state?.settings?.currency ?: "KWD"
    val car = e.asset.car
    var pick by remember { mutableStateOf(e.due ?: model.today.plus(30)) }
    var whenDay by remember { mutableStateOf(model.today) }
    var km by remember { mutableStateOf(if (car != null && set(e.every.km) != null) (kmOn(car, model.today)?.toString() ?: "") else "") }
    var cost by remember { mutableStateOf("") }
    var addTech by remember { mutableStateOf<String?>(null) }
    var interval by remember { mutableStateOf(false) }
    val logs = e.item.log.takeLast(6).reversed()
    Sheet(model, null, onClose) {
        Row(Modifier.fillMaxWidth().padding(top = 8.dp, end = 48.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RowIcon(e.icon, p.tint(e.status), p.tintBg(e.status))
            Column {
                Text(e.title(model.lang), style = title(22, 1.35), color = p.ink)
                Row(Modifier.padding(top = 2.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(line.first, style = body(13.5, FontWeight.SemiBold, 1.5), color = p.tint(e.status))
                    line.second?.let { Text(it, style = body(13.5, lineHeight = 1.5), color = p.ink3) }
                }
            }
        }
        e.tpl?.why(model.lang)?.let {
            Text(it, style = body(15, lineHeight = 1.8), color = p.ink, modifier = Modifier.padding(top = 14.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(p.bg).padding(horizontal = 16.dp, vertical = 14.dp))
        }
        Facts(listOfNotNull(
            model.t("item.every") to w.every(e.every, model.catalog),
            model.t("item.last") to (Day.parse(e.item.lastDone)?.let { w.date(it, model.today) } ?: model.t("item.never")),
            e.due?.let { model.t("item.next") to w.date(it, model.today) },
            if (e.item.lastKm != null && set(e.every.km) != null) model.t("item.at_km") to w.km(e.item.lastKm) else null,
        ))
        if (e.every.fixed == true) {
            DayPicker(model.t("item.expiry"), pick) { pick = it }
            Spacer(Modifier.height(14.dp))
            WideButton(model.t("act.save")) { model.update("toast.saved") { it.setDue(e.item.id, pick) }; onClose() }
            e.due?.let { due ->
                Spacer(Modifier.height(10.dp))
                WideButton(model.t("act.renewed_long", mapOf("date" to w.date(due.plusMonths(e.every.repeatMonths ?: 12), model.today))), primary = false, icon = "done") {
                    model.renew(e); onClose()
                }
            }
        } else {
            // logging the job: when, the reading for car tasks, what it cost
            Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                DayPicker(model.t("item.when"), whenDay, Modifier.weight(1f)) { whenDay = if (it > model.today) model.today else it }
                if (car != null && set(e.every.km) != null) {
                    Column(Modifier.weight(1f)) { FieldLabel(model.t("item.km")); Input(km, { km = it }, "84000", numbers = true) }
                }
            }
            FieldLabel(model.t("item.cost"))
            Input(cost, { cost = it }, w.money(0, cur), numbers = true)
            Spacer(Modifier.height(16.dp))
            WideButton(model.t("act.done"), icon = "done") {
                val k = if (km.isBlank()) null else wholeNumber(km)
                val c = if (cost.isBlank()) null else parseMoney(cost, cur)
                if (cost.isNotBlank() && c == null) { model.say("err.amount"); return@WideButton }
                model.update("toast.done", mapOf("title" to e.title(model.lang))) { it.markDone(e.item.id, whenDay, k, c) }
                onClose()
            }
            Spacer(Modifier.height(12.dp))
            if (e.every.season.isNullOrEmpty()) {
                ButtonPair(model.t("act.snooze"), { model.snooze(e); onClose() }, model.t("act.interval"), { interval = true }, aIcon = "snooze", bIcon = "edit")
            } else {
                WideButton(model.t("act.snooze"), primary = false, icon = "snooze") { model.snooze(e); onClose() }
            }
        }
        e.tpl?.trade?.let { trade ->
            val tradeName = model.catalog.trades.firstOrNull { it.id == trade }?.name(model.lang) ?: trade
            val tech = model.brain().techFor(trade)
            if (tech != null) {
                Column(Modifier.fillMaxWidth().padding(top = 18.dp).clip(RoundedCornerShape(16.dp)).background(p.bg).padding(14.dp)) {
                    Text(model.t("tech.for", mapOf("trade" to tradeName, "name" to tech.name)), style = body(16, FontWeight.SemiBold), color = p.ink)
                    Spacer(Modifier.height(10.dp))
                    TechButtons(model, tech)
                }
            } else {
                Row(Modifier.padding(top = 18.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(model.t("tech.none", mapOf("trade" to tradeName)), style = body(13, lineHeight = 1.7), color = p.ink3)
                    Text(model.t("tech.add_link"), style = body(13, FontWeight.SemiBold, 1.7), color = p.ink, modifier = Modifier.clickable { addTech = trade })
                }
            }
        }
        if (logs.isNotEmpty()) {
            SmallHead(model.t("item.history"))
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).border(1.dp, p.line, RoundedCornerShape(14.dp))) {
                logs.forEachIndexed { i, l ->
                    if (i > 0) RowLine()
                    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        Text(Day.parse(l.date)?.let { w.date(it, model.today) } ?: l.date, style = body(14, FontWeight.SemiBold), color = p.ink, modifier = Modifier.widthIn(min = 110.dp))
                        l.km?.let { Text(w.km(it), style = body(14), color = p.ink) }
                        l.cost?.let { Text(w.money(it, l.cur ?: cur), style = body(14), color = p.ink) }
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        WideButton(if (e.item.tpl == null) model.t("act.delete") else model.t("act.stop"), primary = false, danger = true, icon = "trash") {
            model.update(if (e.item.tpl == null) "toast.deleted" else "toast.stopped") { it.stop(e.item.id) }
            onClose()
        }
    }
    addTech?.let { TechSheet(model, null, it) { addTech = null } }
    if (interval) IntervalSheet(model, e) { interval = false; onClose() }
}

/** Every n days or months, the kilometre rule for car tasks, and a way back to the suggested interval. */
@Composable
fun IntervalSheet(model: AppModel, e: Evaluated, onClose: () -> Unit) {
    val base = e.every
    var n by remember { mutableStateOf((base.days ?: base.months ?: 6).toString()) }
    var unit by remember { mutableStateOf(if (set(base.days) != null) "days" else "months") }
    var km by remember { mutableStateOf(base.km?.toString() ?: "") }
    Sheet(model, model.t("act.interval"), onClose) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) { FieldLabel(model.t("int.every")); Input(n, { n = it }, "6", numbers = true) }
            Column(Modifier.weight(1f)) {
                FieldLabel(model.t("int.unit"))
                Seg(listOf("days" to model.t("int.days"), "months" to model.t("int.months")), unit) { unit = it }
            }
        }
        if (set(base.km) != null) {
            FieldLabel(model.t("int.km"))
            Input(km, { km = it }, base.km.toString(), numbers = true)
        }
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("act.save")) {
            val k = wholeNumber(n)
            if (k == null || k < 1 || k > 3650) { model.say("err.number"); return@WideButton }
            model.update("toast.saved") { it.setInterval(e.item.id, k, unit, wholeNumber(km)) }
            onClose()
        }
        if (e.item.every != null && e.item.tpl != null) {
            Spacer(Modifier.height(4.dp))
            WideButton(model.t("int.reset"), quiet = true) { model.update("toast.saved") { it.setInterval(e.item.id, null, unit, null) }; onClose() }
        }
    }
}

// ---------------------------------------------------------------- add task

@Composable
fun AddTaskSheet(model: AppModel, assetId: String, onClose: () -> Unit) {
    var title by remember { mutableStateOf("") }
    var n by remember { mutableStateOf("3") }
    var unit by remember { mutableStateOf("months") }
    Sheet(model, model.t("act.add_task"), onClose) {
        val list = model.brain().addable(assetId)
        if (list.isNotEmpty()) {
            FieldLabel(model.t("add.from_list"))
            ChoiceGrid(list, 2, { false }, { it.name(model.lang) }, { it.icon }) { t -> model.update("toast.added") { it.addTemplate(t.id, assetId) }; onClose() }
        }
        FieldLabel(model.t("add.custom"))
        FieldLabel(model.t("add.title"))
        Input(title, { title = it }, model.t("add.title_ph"))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) { FieldLabel(model.t("int.every")); Input(n, { n = it }, "3", numbers = true) }
            Column(Modifier.weight(1f)) {
                FieldLabel(model.t("int.unit"))
                Seg(listOf("days" to model.t("int.days"), "months" to model.t("int.months")), unit) { unit = it }
            }
        }
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("act.save")) {
            val name = title.trim()
            val k = wholeNumber(n)
            if (name.isEmpty()) { model.say("err.title"); return@WideButton }
            if (k == null || k <= 0) { model.say("err.number"); return@WideButton }
            model.update("toast.added") { it.addCustom(name, if (unit == "months") Every(months = minOf(k, 120)) else Every(days = k), assetId) }
            onClose()
        }
    }
}

// ---------------------------------------------------------------- subscription

private val subCats = listOf("stream" to "play", "music" to "music", "cloud" to "cloud", "games" to "game", "gym" to "gym", "internet" to "wifi", "phone" to "phone", "apps" to "apps", "other" to "repeat")

@Composable
fun SubSheet(model: AppModel, existing: Sub?, onClose: () -> Unit) {
    val b = model.brain()
    var confirm by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var currency by remember { mutableStateOf(existing?.currency ?: model.state?.settings?.currency ?: "KWD") }
    var amount by remember { mutableStateOf(existing?.let { formatMoney(it.amount, it.currency, "en").substringAfter(' ') } ?: "") }
    var cycle by remember { mutableStateOf(existing?.cycle ?: "monthly") }
    var next by remember { mutableStateOf(existing?.let { s -> b.subs().firstOrNull { it.sub.id == s.id }?.next } ?: model.today.plus(30)) }
    var trial by remember { mutableStateOf(existing?.trial == true) }
    var category by remember { mutableStateOf(existing?.category ?: "stream") }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    Sheet(model, existing?.name ?: model.t("act.add_sub"), onClose) {
        FieldLabel(model.t("sub.name"))
        Input(name, { name = it }, model.t("sub.name_ph"))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) { FieldLabel(model.t("sub.amount")); Input(amount, { amount = it }, "3.500", numbers = true) }
            Column(Modifier.weight(1f)) { FieldLabel(model.t("settings.currency")); Select(currency, currencies.keys.map { it to it }) { currency = it } }
        }
        FieldLabel(model.t("sub.cycle"))
        Seg(listOf("weekly", "monthly", "quarterly", "semiannual", "yearly").map { it to model.t("cyclename.$it") }, cycle) { cycle = it }
        DayPicker(model.t("sub.next"), next) { next = it }
        Spacer(Modifier.height(14.dp))
        SwitchCard(listOf(Triple(model.t("sub.trial_q"), trial) { v: Boolean -> trial = v }))
        FieldLabel(model.t("sub.category"))
        ChoiceGrid(subCats, 3, { category == it.first }, { model.t("cat.${it.first}") }, { it.second }) { category = it.first }
        FieldLabel(model.t("sub.note"))
        Input(note, { note = it }, model.t("sub.note_ph"))
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("act.save")) {
            val title = name.trim()
            val minor = parseMoney(amount, currency)
            if (title.isEmpty()) { model.say("err.title"); return@WideButton }
            if (minor == null) { model.say("err.amount"); return@WideButton }
            val s = (existing ?: Sub(newID(), title, minor, currency, cycle, next.iso))
                .copy(name = title, amount = minor, currency = currency, cycle = cycle, anchor = next.iso, trial = if (trial) true else null, category = category, note = note.trim().ifEmpty { null })
            model.update("toast.saved") { it.saveSub(s) }
            onClose()
        }
        existing?.let { s ->
            Spacer(Modifier.height(10.dp))
            if (s.cancelled == true) WideButton(model.t("sub.restore"), primary = false) { model.update("toast.saved") { it.restoreSub(s.id) }; onClose() }
            else WideButton(model.t("ask.cancelled"), primary = false) { model.update("toast.cancelled", mapOf("name" to s.name)) { it.cancelSub(s.id) }; onClose() }
            Spacer(Modifier.height(4.dp))
            WideButton(model.t("act.delete"), danger = true, icon = "trash") { confirm = true }
        }
    }
    if (confirm && existing != null) {
        ConfirmDialog(model.t("confirm.sub"), model.t("act.delete"), model.t("act.cancel"), { model.update("toast.deleted") { it.deleteSub(existing.id) }; onClose() }) { confirm = false }
    }
}

// ---------------------------------------------------------------- home, car, belonging

@Composable
fun AssetSheet(model: AppModel, kind: AssetKind, existingId: String?, onClose: () -> Unit) {
    val p = pal()
    val state = model.state ?: AppState()
    val home = state.homes.firstOrNull { it.id == existingId }
    val car = state.cars.firstOrNull { it.id == existingId }
    val thing = state.things.firstOrNull { it.id == existingId }
    var name by remember { mutableStateOf(home?.name ?: car?.name ?: thing?.name ?: "") }
    var type by remember { mutableStateOf(home?.type ?: thing?.type ?: if (kind == AssetKind.THING) "boat" else "house") }
    val features = remember { mutableStateMapOf<String, Boolean>().apply { putAll(mapOf("central_ac" to false, "tank" to true, "filter" to false) + (home?.features ?: emptyMap())) } }
    var km by remember { mutableStateOf("") }
    var daily by remember { mutableStateOf((car?.dailyKm ?: 40).toString()) }
    var confirm by remember { mutableStateOf(false) }
    val isNew = existingId == null
    val placeholder = when (kind) {
        AssetKind.HOME -> model.t("type.$type")
        AssetKind.CAR -> model.t("car.default")
        AssetKind.THING -> model.catalog.thingTypes.firstOrNull { it.id == type }?.name(model.lang) ?: model.t("thing.name")
    }
    val title = model.t(when (kind) {
        AssetKind.HOME -> if (isNew) "act.add_home" else "act.edit_home"
        AssetKind.CAR -> if (isNew) "act.add_car" else "act.edit_car"
        AssetKind.THING -> if (isNew) "act.add_thing" else "act.edit_thing"
    })
    Sheet(model, title, onClose) {
        if (kind == AssetKind.HOME) {
            FieldLabel(model.t("setup.type"))
            Seg(listOf("house", "flat", "chalet", "farm", "jakhoor").map { it to model.t("type.$it") }, type) { type = it }
        }
        if (kind == AssetKind.THING && isNew) {
            FieldLabel(model.t("thing.type"))
            ChoiceGrid(model.catalog.thingTypes, 3, { type == it.id }, { it.name(model.lang) }, { it.icon }) { type = it.id }
        }
        FieldLabel(model.t(when (kind) { AssetKind.CAR -> "car.name"; AssetKind.THING -> "thing.name"; else -> "setup.name" }))
        Input(name, { name = it }, placeholder)
        if (kind == AssetKind.HOME) {
            FieldLabel(model.t("setup.has"))
            SwitchCard(listOf("central_ac", "tank", "filter").map { f -> Triple(model.t("feat.$f"), features[f] == true) { v: Boolean -> features[f] = v } })
        }
        if (kind == AssetKind.CAR) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (isNew) Column(Modifier.weight(1f)) { FieldLabel(model.t("car.km_now")); Input(km, { km = it }, "84000", numbers = true) }
                Column(Modifier.weight(1f)) { FieldLabel(model.t("car.daily")); Input(daily, { daily = it }, "40", numbers = true) }
            }
            Fine(model.t("car.daily_note"))
        }
        if (kind == AssetKind.THING && isNew) Fine(model.t("thing.hint"))
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("act.save")) {
            val n = name.trim().ifEmpty { placeholder }
            if (existingId != null) {
                model.update("toast.saved") { b ->
                    val f = features.toMap()
                    b.state = b.state.copy(
                        homes = b.state.homes.map { if (it.id == existingId) it.copy(name = n, type = type, features = f) else it },
                        cars = b.state.cars.map { if (it.id == existingId) it.copy(name = n, dailyKm = wholeNumber(daily) ?: 40) else it },
                        things = b.state.things.map { if (it.id == existingId) it.copy(name = n) else it },
                    )
                    if (kind == AssetKind.HOME) {
                        for (t in b.catalog.templates.filter { it.kind == "home" && it.needs != null }) {
                            val has = f[t.needs] == true
                            if (b.state.items.any { it.asset == existingId && it.tpl == t.id }) {
                                b.state = b.state.copy(items = b.state.items.map { if (it.asset == existingId && it.tpl == t.id) it.copy(enabled = has) else it })
                            } else if (has && t.isDefault) b.addTemplate(t.id, existingId)
                        }
                        b.spreadNew(listOf(existingId))
                    }
                }
            } else {
                model.update("toast.added") { b ->
                    val id = when (kind) {
                        AssetKind.HOME -> b.addHome(type, n, features.toMap()).id
                        AssetKind.CAR -> b.addCar(n, wholeNumber(km), wholeNumber(daily) ?: 40).id
                        AssetKind.THING -> b.addThing(type, n).id
                    }
                    b.spreadNew(listOf(id))
                }
            }
            onClose()
        }
        if (existingId != null) {
            Spacer(Modifier.height(4.dp))
            WideButton(model.t(when (kind) { AssetKind.HOME -> "act.delete_home"; AssetKind.CAR -> "act.delete_car"; AssetKind.THING -> "act.delete_thing" }), danger = true, icon = "trash") { confirm = true }
        }
    }
    if (confirm && existingId != null) {
        ConfirmDialog(model.t("confirm.asset"), model.t("act.delete"), model.t("act.cancel"), { model.update("toast.deleted") { it.removeAsset(existingId) }; onClose() }) { confirm = false }
    }
}

// ---------------------------------------------------------------- odometer

@Composable
fun OdoSheet(model: AppModel, carId: String, onClose: () -> Unit) {
    val car = model.state?.cars?.firstOrNull { it.id == carId }
    var km by remember { mutableStateOf(car?.let { kmOn(it.odometer, model.today)?.toString() } ?: "") }
    var whenDay by remember { mutableStateOf(model.today) }
    Sheet(model, model.t("act.update_odo"), onClose) {
        Box(Modifier.padding(top = 6.dp)) { Lede(model.t("odo.body"), small = true) }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) { FieldLabel(model.t("item.km")); Input(km, { km = it }, "84000", numbers = true) }
            DayPicker(model.t("item.when"), whenDay, Modifier.weight(1f)) { whenDay = if (it > model.today) model.today else it }
        }
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("act.save")) {
            val k = wholeNumber(km)
            if (k == null) { model.say("err.number"); return@WideButton }
            model.update("toast.saved") { it.addReading(carId, k, whenDay) }
            onClose()
        }
    }
}

// ---------------------------------------------------------------- ask

/** The web's .ask card: the question in Kufi, the meta line, then a plain and a quiet button. */
@Composable
fun AskCard(model: AppModel, s: SubView) {
    val p = pal()
    val w = model.words
    val tone = if (s.planned) p.overdue else p.rutab
    Column(
        Modifier.fillMaxWidth().clip(CardShape).background(if (s.planned) p.overdue.copy(alpha = 0.11f) else p.rutab.copy(alpha = 0.11f))
            .border(1.dp, tone.copy(alpha = 0.32f), CardShape).padding(16.dp),
    ) {
        if (s.planned) {
            Text(model.t("ask.cancel_title", mapOf("name" to s.sub.name)), style = title(19, 1.4), color = p.ink)
            Text(model.t("ask.cancel_body"), style = body(14, lineHeight = 1.6), color = p.ink2, modifier = Modifier.padding(top = 4.dp))
            s.sub.note?.let {
                Text(it, style = body(13.5, lineHeight = 1.5), color = p.ink2,
                    modifier = Modifier.padding(top = 8.dp).fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(p.surface).padding(horizontal = 12.dp, vertical = 8.dp))
            }
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WideButton(model.t("ask.cancelled"), modifier = Modifier.weight(1f), height = 44.dp) { model.update("toast.cancelled", mapOf("name" to s.sub.name)) { it.cancelSub(s.sub.id) } }
                WideButton(model.t("ask.keep"), quiet = true, modifier = Modifier.weight(1f), height = 44.dp) { model.update("toast.kept", mapOf("name" to s.sub.name)) { it.answer(s.sub.id, true) } }
            }
        } else {
            val whenText = when {
                s.trial && s.days == 0 -> model.t("sub.trial_today")
                s.trial -> model.t("sub.trial", mapOf("rel" to w.rel(s.days)))
                s.days == 0 -> model.t("sub.renews_today")
                else -> model.t("sub.renews", mapOf("rel" to w.rel(s.days)))
            }
            Text(model.t(if (s.trial) "ask.q_trial" else "ask.q", mapOf("name" to s.sub.name)), style = title(19, 1.4), color = p.ink)
            Text(whenText + w.comma + w.money(s.sub.amount, s.sub.currency), style = body(14, lineHeight = 1.6), color = p.ink2, modifier = Modifier.padding(top = 4.dp))
            Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WideButton(model.t("ask.yes"), primary = false, modifier = Modifier.weight(1f), height = 44.dp) { model.update("toast.kept", mapOf("name" to s.sub.name)) { it.answer(s.sub.id, true) } }
                WideButton(model.t("ask.no"), quiet = true, modifier = Modifier.weight(1f), height = 44.dp) { model.update { it.answer(s.sub.id, false) } }
            }
        }
    }
}
