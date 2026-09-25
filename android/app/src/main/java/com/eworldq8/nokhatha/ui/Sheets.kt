// Adding and editing: task details, tasks, subscriptions, homes, cars, belongings, the odometer.
package com.eworldq8.nokhatha.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.AppModel
import com.eworldq8.nokhatha.Toast
import com.eworldq8.nokhatha.engine.*
import java.util.Calendar
import java.util.TimeZone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Sheet(model: AppModel, title: String, onClose: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val p = pal()
    ModalBottomSheet(onDismissRequest = onClose, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true), containerColor = p.surface) {
        CompositionLocalProvider(LocalLayoutDirection provides if (model.isArabic) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 30.dp)) {
                Text(title, style = title(22), color = p.ink)
                content()
            }
        }
    }
}

/** A date picker in the sheet: days are whole civil dates, so the picker works in UTC. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DayPicker(label: String, day: Day, onPick: (Day) -> Unit) {
    val p = pal()
    var open by remember { mutableStateOf(false) }
    FieldLabel(label)
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(p.bg).border(1.dp, p.line, RoundedCornerShape(13.dp))) {
        TextButton({ open = true }, Modifier.fillMaxWidth()) { Text(formatDate(day, if (LocalLayoutDirection.current == LayoutDirection.Rtl) "ar" else "en", 0) + "  " + day.ymd.first, style = body(16), color = p.ink) }
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

@Composable
fun Fact(k: String, v: String) {
    val p = pal()
    Column(Modifier.fillMaxWidth().padding(top = 10.dp).clip(RoundedCornerShape(14.dp)).border(1.dp, p.line, RoundedCornerShape(14.dp)).padding(12.dp)) {
        Text(k, style = body(12, FontWeight.SemiBold), color = p.ink3)
        Text(v, style = body(15, FontWeight.SemiBold), color = p.ink)
    }
}

@Composable
fun TaskSheet(model: AppModel, e: Evaluated, onClose: () -> Unit) {
    val p = pal()
    val w = model.words
    val line = w.due(e, model.today)
    var pick by remember { mutableStateOf(e.due ?: model.today.plus(30)) }
    var addTech by remember { mutableStateOf<String?>(null) }
    Sheet(model, e.title(model.lang), onClose) {
        Text(listOfNotNull(line.first, line.second).joinToString("  "), style = body(14, FontWeight.SemiBold), color = p.tint(e.status))
        e.tpl?.why(model.lang)?.let {
            Text(it, style = body(15), color = p.ink2, modifier = Modifier.padding(top = 12.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(p.bg).padding(14.dp))
        }
        Fact(model.t("item.every"), w.every(e.every, model.catalog))
        Fact(model.t("item.last"), Day.parse(e.item.lastDone)?.let { w.date(it, model.today) } ?: model.t("item.never"))
        e.due?.let { Fact(model.t("item.next"), w.date(it, model.today)) }
        e.tpl?.trade?.let { trade ->
            val tradeName = model.catalog.trades.firstOrNull { it.id == trade }?.name(model.lang) ?: trade
            val tech = model.brain().techFor(trade)
            Spacer(Modifier.height(10.dp))
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).border(1.dp, p.line, RoundedCornerShape(16.dp)).padding(12.dp)) {
                if (tech != null) {
                    Text(model.t("tech.for", mapOf("trade" to tradeName, "name" to tech.name)), style = body(14, FontWeight.SemiBold), color = p.ink)
                    Spacer(Modifier.height(8.dp))
                    TechButtons(model, tech)
                } else {
                    Text(model.t("tech.none", mapOf("trade" to tradeName)), style = body(14), color = p.ink2)
                    Spacer(Modifier.height(8.dp))
                    WideButton(model.t("tech.add_link"), primary = false, icon = "plus") { addTech = trade }
                }
            }
        }
        Spacer(Modifier.height(14.dp))
        if (e.every.fixed == true) {
            DayPicker(model.t("item.expiry"), pick) { pick = it }
            Spacer(Modifier.height(12.dp))
            WideButton(model.t("act.save")) { model.update("toast.saved") { it.setDue(e.item.id, pick) }; onClose() }
        } else {
            WideButton(model.t("act.done")) { model.done(e); onClose() }
            Spacer(Modifier.height(8.dp))
            WideButton(model.t("act.snooze"), primary = false) { model.snooze(e); onClose() }
        }
        Spacer(Modifier.height(8.dp))
        WideButton(if (e.item.tpl == null) model.t("act.delete") else model.t("act.stop"), primary = false, danger = true) {
            model.update(if (e.item.tpl == null) "toast.deleted" else "toast.stopped") { it.stop(e.item.id) }
            onClose()
        }
    }
    addTech?.let { TechSheet(model, null, it) { addTech = null } }
}


@Composable
fun OdoSheet(model: AppModel, carId: String, onClose: () -> Unit) {
    val car = model.state?.cars?.firstOrNull { it.id == carId }
    var km by remember { mutableStateOf(car?.let { kmOn(it.odometer, model.today)?.toString() } ?: "") }
    Sheet(model, model.t("act.update_odo"), onClose) {
        Text(model.t("odo.body"), style = body(14), color = pal().ink2, modifier = Modifier.padding(top = 4.dp))
        FieldLabel(model.t("item.km"))
        Input(km, { km = it }, "84000", numbers = true)
        Spacer(Modifier.height(18.dp))
        WideButton(model.t("act.save")) {
            val k = wholeNumber(km)
            if (k == null) { model.toast = Toast(model.t("err.number"), null); return@WideButton }
            model.update("toast.saved") { it.addReading(carId, k, model.today) }
            onClose()
        }
    }
}

@Composable
fun AskCard(model: AppModel, s: SubView) {
    val p = pal()
    val w = model.words
    val tone = if (s.planned) p.overdue else p.soon
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(tone.copy(alpha = 0.1f)).border(1.dp, tone.copy(alpha = 0.3f), RoundedCornerShape(20.dp)).padding(16.dp)) {
        if (s.planned) {
            Text(model.t("ask.cancel_title", mapOf("name" to s.sub.name)), style = title(18), color = p.ink)
            Text(model.t("ask.cancel_body"), style = body(14), color = p.ink2)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WideButton(model.t("ask.cancelled"), modifier = Modifier.weight(1f)) { model.update("toast.cancelled", mapOf("name" to s.sub.name)) { it.cancelSub(s.sub.id) } }
                WideButton(model.t("ask.keep"), primary = false, modifier = Modifier.weight(1f)) { model.update("toast.kept", mapOf("name" to s.sub.name)) { it.answer(s.sub.id, true) } }
            }
        } else {
            Text(model.t(if (s.trial) "ask.q_trial" else "ask.q", mapOf("name" to s.sub.name)), style = title(18), color = p.ink)
            Text((if (s.days == 0) model.t("sub.renews_today") else model.t("sub.renews", mapOf("rel" to w.rel(s.days)))) + w.comma + w.money(s.sub.amount, s.sub.currency),
                style = body(14), color = p.ink2)
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WideButton(model.t("ask.yes"), primary = false, modifier = Modifier.weight(1f)) { model.update("toast.kept", mapOf("name" to s.sub.name)) { it.answer(s.sub.id, true) } }
                WideButton(model.t("ask.no"), primary = false, modifier = Modifier.weight(1f)) { model.update { it.answer(s.sub.id, false) } }
            }
        }
    }
}

@Composable
fun AddTaskSheet(model: AppModel, assetId: String, onClose: () -> Unit) {
    val p = pal()
    var title by remember { mutableStateOf("") }
    var n by remember { mutableStateOf("3") }
    var unit by remember { mutableStateOf("months") }
    Sheet(model, model.t("act.add_task"), onClose) {
        val list = model.brain().addable(assetId)
        if (list.isNotEmpty()) {
            FieldLabel(model.t("add.from_list"))
            ListCard {
                list.forEachIndexed { i, t ->
                    if (i > 0) HorizontalDivider(color = p.line)
                    Row(Modifier.fillMaxWidth().clickable { model.update("toast.added") { it.addTemplate(t.id, assetId) }; onClose() }
                        .padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(p.ink.copy(alpha = 0.06f)), contentAlignment = Alignment.Center) { Ico(t.icon, p.ink, 18.dp) }
                        Spacer(Modifier.width(12.dp))
                        Text(t.name(model.lang), style = body(15, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
                        Ico("plus", p.ok, 20.dp)
                    }
                }
            }
        }
        FieldLabel(model.t("add.custom"))
        Input(title, { title = it }, model.t("add.title_ph"))
        FieldLabel(model.t("int.every"))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Input(n, { n = it }, "3", numbers = true, modifier = Modifier.width(96.dp))
            Seg(listOf("months" to model.t("int.months"), "days" to model.t("int.days")), unit, Modifier.weight(1f)) { unit = it }
        }
        Spacer(Modifier.height(18.dp))
        WideButton(model.t("act.save")) {
            val name = title.trim()
            val k = wholeNumber(n)
            if (name.isEmpty()) { model.toast = Toast(model.t("err.title"), null); return@WideButton }
            if (k == null || k <= 0) { model.toast = Toast(model.t("err.number"), null); return@WideButton }
            model.update("toast.added") { it.addCustom(name, if (unit == "months") Every(months = minOf(k, 120)) else Every(days = k), assetId) }
            onClose()
        }
    }
}

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
    Sheet(model, existing?.name ?: model.t("act.add_sub"), onClose) {
        FieldLabel(model.t("sub.name"))
        Input(name, { name = it }, model.t("sub.name_ph"))
        FieldLabel(model.t("sub.amount"))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Input(amount, { amount = it }, "3.500", numbers = true, modifier = Modifier.weight(1f))
            Select(currency, currencies.keys.map { it to it }, Modifier.width(110.dp)) { currency = it }
        }
        FieldLabel(model.t("sub.cycle"))
        ChoiceGrid(listOf("weekly", "monthly", "quarterly", "semiannual", "yearly"), 3, { cycle == it }, { model.t("cyclename.$it") }) { cycle = it }
        DayPicker(model.t("sub.next"), next) { next = it }
        Spacer(Modifier.height(10.dp))
        SwitchCard(listOf(Triple(model.t("sub.trial_q"), trial) { v: Boolean -> trial = v }))
        FieldLabel(model.t("sub.category"))
        ChoiceGrid(subCats, 3, { category == it.first }, { model.t("cat.${it.first}") }, { it.second }) { category = it.first }
        Spacer(Modifier.height(18.dp))
        WideButton(model.t("act.save")) {
            val title = name.trim()
            val minor = parseMoney(amount, currency)
            if (title.isEmpty()) { model.toast = Toast(model.t("err.title"), null); return@WideButton }
            if (minor == null) { model.toast = Toast(model.t("err.amount"), null); return@WideButton }
            val s = (existing ?: Sub(newID(), title, minor, currency, cycle, next.iso))
                .copy(name = title, amount = minor, currency = currency, cycle = cycle, anchor = next.iso, trial = if (trial) true else null, category = category)
            model.update("toast.saved") { it.saveSub(s) }
            onClose()
        }
        existing?.let { s ->
            Spacer(Modifier.height(8.dp))
            if (s.cancelled != true) {
                ButtonPair(model.t("ask.cancelled"), { model.update("toast.cancelled", mapOf("name" to s.name)) { it.cancelSub(s.id) }; onClose() },
                    model.t("act.delete"), { confirm = true }, bDanger = true)
            } else {
                WideButton(model.t("act.delete"), primary = false, danger = true, icon = "trash") { confirm = true }
            }
        }
    }
    if (confirm && existing != null) {
        ConfirmDialog(model.t("confirm.sub"), model.t("act.delete"), model.t("act.cancel"), { model.update("toast.deleted") { it.deleteSub(existing.id) }; onClose() }) { confirm = false }
    }
}

@Composable
fun AssetSheet(model: AppModel, kind: AssetKind, existingId: String?, onClose: () -> Unit) {
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
            ChoiceGrid(listOf("house", "flat", "chalet", "farm", "jakhoor"), 3, { type == it }, { model.t("type.$it") }) { type = it }
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
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (isNew) Column(Modifier.weight(1f)) { FieldLabel(model.t("car.km_now")); Input(km, { km = it }, "84000", numbers = true) }
                Column(Modifier.weight(1f)) { FieldLabel(model.t("car.daily")); Input(daily, { daily = it }, "40", numbers = true) }
            }
            Text(model.t("car.daily_note"), style = body(13), color = pal().ink3, modifier = Modifier.padding(top = 6.dp))
        }
        if (kind == AssetKind.THING && isNew) Text(model.t("thing.hint"), style = body(13), color = pal().ink3, modifier = Modifier.padding(top = 8.dp))
        Spacer(Modifier.height(18.dp))
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
            Spacer(Modifier.height(8.dp))
            WideButton(model.t(when (kind) { AssetKind.HOME -> "act.delete_home"; AssetKind.CAR -> "act.delete_car"; AssetKind.THING -> "act.delete_thing" }),
                primary = false, danger = true, icon = "trash") { confirm = true }
        }
    }
    if (confirm && existingId != null) {
        ConfirmDialog(model.t("confirm.asset"), model.t("act.delete"), model.t("act.cancel"), { model.update("toast.deleted") { it.removeAsset(existingId) }; onClose() }) { confirm = false }
    }
}
