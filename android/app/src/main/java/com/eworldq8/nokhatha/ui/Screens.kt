// The screens, the same as the web and iPhone: Today with the year dial, Home, Car, belongings,
// Subscriptions, More, and the first run.
package com.eworldq8.nokhatha.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.AppModel
import com.eworldq8.nokhatha.R
import com.eworldq8.nokhatha.engine.*
import java.util.Calendar

@Composable
fun Page(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding()
            .padding(horizontal = 18.dp).padding(bottom = 120.dp),
        content = content,
    )
}

@Composable
fun Header(model: AppModel) {
    Row(Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Image(painterResource(R.drawable.mark), null, Modifier.size(30.dp))
        Spacer(Modifier.width(9.dp))
        Text(model.t("app.name"), style = title(21), color = pal().ink)
    }
}

@Composable
fun TaskRow(model: AppModel, e: Evaluated, showAsset: Boolean) {
    val p = pal()
    val w = model.words
    val line = w.due(e, model.today)
    var open by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f).clickable(role = Role.Button) { open = true }, verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(p.tint(e.status).copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                Ico(e.icon, p.tint(e.status), 20.dp)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(e.title(model.lang), style = body(15, FontWeight.SemiBold), color = p.ink, maxLines = 2)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(line.first, style = body(13, FontWeight.SemiBold), color = p.tint(e.status), maxLines = 1)
                    line.second?.let { Text(it, style = body(13), color = p.ink3, maxLines = 1) }
                }
                if (showAsset) {
                    Text(e.asset.name, style = body(12, FontWeight.SemiBold), color = p.ink2,
                        modifier = Modifier.clip(CircleShape).background(p.ink.copy(alpha = 0.07f)).padding(horizontal = 8.dp))
                }
                model.brain().progress(e)?.let { ProgressLine(it, p.tint(e.status)) }
            }
        }
        Spacer(Modifier.width(8.dp))
        if (e.every.fixed == true) {
            Text(if (e.due == null) model.t("act.setdate") else model.t("act.renewed"), style = body(13, FontWeight.Bold), color = p.ink,
                modifier = Modifier.clip(CircleShape).border(1.5.dp, p.line, CircleShape).clickable(role = Role.Button) { if (e.due == null) open = true else model.renew(e) }
                    .padding(horizontal = 14.dp, vertical = 11.dp))
        } else {
            Box(
                Modifier.size(46.dp).clip(CircleShape).border(1.6.dp, if (e.status == "overdue") p.overdue.copy(alpha = 0.5f) else p.line, CircleShape)
                    .clickable(role = Role.Button) { model.done(e) }
                    .semantics { contentDescription = model.t("act.done_label", mapOf("title" to e.title(model.lang))) },
                contentAlignment = Alignment.Center,
            ) { Ico("check", p.ink3, 20.dp) }
        }
    }
    if (open) TaskSheet(model, e) { open = false }
}

@Composable
fun TaskList(model: AppModel, rows: List<Evaluated>, showAsset: Boolean = false) {
    val p = pal()
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(p.surface).border(1.dp, p.line, RoundedCornerShape(20.dp))) {
        rows.forEachIndexed { i, e ->
            if (i > 0) HorizontalDivider(color = p.line)
            key(e.item.id) { TaskRow(model, e, showAsset) }
        }
    }
}

@Composable
fun TodayScreen(model: AppModel) {
    val p = pal()
    val b = model.brain()
    val w = model.words
    val tasks = b.tasks()
    val now = tasks.filter { it.status in setOf("overdue", "today", "soon") }
    val later = tasks.filter { it.status == "ok" && (it.days ?: 999) <= 30 }.take(6)
    val subs = b.subs()
    val season = seasonAt(model.today, model.catalog.seasons)
    val dots = tasks.mapNotNull { e -> e.days?.let { DialDot(it, e.status) } } + subs.filter { it.status != "off" }.map { DialDot(it.days, "sub") }
    val totals = b.totals()
    val cur = model.state?.settings?.currency?.takeIf { totals.containsKey(it) } ?: totals.keys.sorted().firstOrNull()
    Page {
        Header(model)
        Text(w.greeting(Calendar.getInstance().get(Calendar.HOUR_OF_DAY)), style = title(24), color = p.ink)
        Text(w.longDate(model.today), style = body(14), color = p.ink3)
        Spacer(Modifier.height(8.dp))
        Dial(model.today, model.catalog, dots, w.seasonCenter(season, model.catalog, model.today))
        model.catalog.season(season.id)?.hint(model.lang)?.let { hint ->
            Spacer(Modifier.height(8.dp))
            CardBox(padding = 14.dp) {
                Row { Ico("spark", p.sadu, 18.dp, Modifier.padding(top = 3.dp)); Spacer(Modifier.width(10.dp)); Text(hint, style = body(14), color = p.ink2) }
            }
        }
        SectionTitle(model.t("today.now"), now.size)
        if (now.isEmpty()) CardBox { Text(model.t("today.clear"), style = body(15), color = p.ink2) } else TaskList(model, now, true)
        subs.firstOrNull { it.ask || it.planned }?.let { Spacer(Modifier.height(10.dp)); AskCard(model, it) }
        if (cur != null) {
            val t = totals.getValue(cur)
            Spacer(Modifier.height(10.dp))
            CardBox(Modifier.clickable { model.tab = "subs" }, padding = 14.dp) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Ico("repeat", p.ok, 20.dp)
                    Spacer(Modifier.width(10.dp))
                    Text(model.t("today.subs", mapOf("amount" to w.money(t.month, cur))), style = body(15, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
                }
            }
        }
        if (later.isNotEmpty()) {
            SectionTitle(model.t("today.later"))
            TaskList(model, later, true)
        }
    }
}

@Composable
fun AssetsScreen(model: AppModel, kind: AssetKind) {
    val p = pal()
    val state = model.state ?: AppState()
    val list = when (kind) {
        AssetKind.HOME -> state.homes.map { it.id to it.name }
        AssetKind.CAR -> state.cars.map { it.id to it.name }
        AssetKind.THING -> state.things.map { it.id to it.name }
    }
    var selected by remember { mutableStateOf<String?>(null) }
    var sheet by remember { mutableStateOf<String?>(null) }
    val current = list.firstOrNull { it.first == selected } ?: list.firstOrNull()
    val tasks = current?.let { c -> model.brain().tasks { it.asset == c.first } } ?: emptyList()
    val areas = model.catalog.areas[kind.key] ?: emptyList()
    val add = when (kind) { AssetKind.HOME -> "act.add_home"; AssetKind.CAR -> "act.add_car"; AssetKind.THING -> "act.add_thing" }
    val edit = when (kind) { AssetKind.HOME -> "act.edit_home"; AssetKind.CAR -> "act.edit_car"; AssetKind.THING -> "act.edit_thing" }
    Page {
        Header(model)
        Text(model.t(when (kind) { AssetKind.HOME -> "tab.home"; AssetKind.CAR -> "tab.car"; AssetKind.THING -> "more.things" }), style = title(30), color = p.ink)
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for ((id, name) in list) Chip(name, id == current?.first) { selected = id }
            Chip(model.t(add), false, "plus") { sheet = "add" }
        }
        if (kind == AssetKind.CAR && current != null) {
            state.cars.firstOrNull { it.id == current.first }?.let { car ->
                CardBox {
                    Text(model.t("car.odo"), style = body(13, FontWeight.SemiBold), color = p.ink3)
                    Text(kmOn(car.odometer, model.today)?.let { model.words.km(it) } ?: model.t("car.odo_unknown"), style = title(28), color = p.ink)
                    Row(Modifier.clickable { sheet = "odo" }.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Ico("gauge", p.ink, 18.dp); Spacer(Modifier.width(6.dp)); Text(model.t("act.update_odo"), style = body(14, FontWeight.SemiBold), color = p.ink)
                    }
                }
            }
        }
        if (current != null) {
            Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                WideButton(model.t("act.add_task"), modifier = Modifier.weight(1f)) { sheet = "task" }
                WideButton(model.t(edit), primary = false, modifier = Modifier.weight(1f)) { sheet = "edit" }
            }
        }
        if (tasks.isEmpty()) {
            Spacer(Modifier.height(10.dp))
            CardBox { Text(model.t("empty.${kind.key}"), style = body(15), color = p.ink2) }
        }
        for (area in areas) {
            val rows = tasks.filter { (it.tpl?.area ?: "custom") == area.id }
            if (rows.isEmpty()) continue
            Text(area.name(model.lang), style = body(13, FontWeight.Bold), color = p.ink3, modifier = Modifier.padding(top = 16.dp, bottom = 6.dp))
            TaskList(model, rows)
        }
    }
    when (sheet) {
        "add" -> AssetSheet(model, kind, null) { sheet = null }
        "edit" -> current?.let { AssetSheet(model, kind, it.first) { sheet = null } }
        "task" -> current?.let { AddTaskSheet(model, it.first) { sheet = null } }
        "odo" -> current?.let { OdoSheet(model, it.first) { sheet = null } }
    }
}

@Composable
fun SubsScreen(model: AppModel) {
    val p = pal()
    val b = model.brain()
    val w = model.words
    val totals = b.totals()
    val main = model.state?.settings?.currency?.takeIf { totals.containsKey(it) } ?: totals.keys.sorted().firstOrNull()
    val subs = b.subs().sortedWith(compareBy<SubView> { if (it.status == "off") 1 else 0 }.thenBy { it.next.n })
    var editing by remember { mutableStateOf<Sub?>(null) }
    var adding by remember { mutableStateOf(false) }
    Page {
        Header(model)
        Text(model.t("tab.subs"), style = title(30), color = p.ink)
        if (main != null) {
            val t = totals.getValue(main)
            Spacer(Modifier.height(8.dp))
            CardBox {
                Text(model.t("subs.month"), style = body(13, FontWeight.SemiBold), color = p.ink3)
                Text(w.money(t.month, main), style = title(38), color = p.ink)
                Text(model.t("subs.year", mapOf("amount" to w.money(t.year, main))), style = body(14), color = p.ink2)
            }
        }
        for (s in b.subs().filter { it.ask || it.planned }) { Spacer(Modifier.height(10.dp)); AskCard(model, s) }
        SectionTitle(model.t("subs.all"))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(p.surface).border(1.dp, p.line, RoundedCornerShape(20.dp))) {
            subs.forEachIndexed { i, s ->
                if (i > 0) HorizontalDivider(color = p.line)
                Row(Modifier.fillMaxWidth().clickable { editing = s.sub }.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(s.sub.name, style = body(15, FontWeight.SemiBold), color = if (s.status == "off") p.ink3 else p.ink)
                        Text(
                            when {
                                s.status == "off" -> model.t("sub.cancelled")
                                s.trial -> model.t("sub.trial", mapOf("rel" to w.rel(s.days)))
                                s.days == 0 -> model.t("sub.renews_today")
                                else -> model.t("sub.renews", mapOf("rel" to w.rel(s.days)))
                            },
                            style = body(13, FontWeight.SemiBold), color = p.tint(s.status),
                        )
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(w.money(s.sub.amount, s.sub.currency), style = body(15, FontWeight.Bold), color = p.ink)
                        Text(model.t("cycle." + s.sub.cycle), style = body(12), color = p.ink3)
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("act.add_sub")) { adding = true }
    }
    editing?.let { SubSheet(model, it) { editing = null } }
    if (adding) SubSheet(model, null) { adding = false }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MoreScreen(model: AppModel, open: (String) -> Unit) {
    val p = pal()
    val ctx = androidx.compose.ui.platform.LocalContext.current
    var confirm by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        model.update { b -> b.state = b.state.copy(settings = b.state.settings.copy(notify = granted)) }
        if (!granted) model.say("notify.denied")
    }
    val s = model.state?.settings ?: Settings()
    Page {
        Header(model)
        Text(model.t("tab.more"), style = title(30), color = p.ink)
        Spacer(Modifier.height(8.dp))
        CardBox(Modifier.clickable { open("things") }, padding = 14.dp) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Ico("box", p.ink, 20.dp); Spacer(Modifier.width(10.dp))
                Text(model.t("more.things"), style = body(16, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
                Text((model.state?.things?.size ?: 0).toString(), style = body(13, FontWeight.Bold), color = p.ink3)
            }
        }
        SectionTitle(model.t("settings.lang"))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip("عربي", model.lang == "ar") { model.setLang("ar") }
            Chip("English", model.lang == "en") { model.setLang("en") }
        }
        SectionTitle(model.t("settings.country"))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for (c in Brain.countries.keys) Chip(model.t("country.$c"), s.country == c) {
                model.update { b ->
                    val before = Brain.countries[b.state.settings.country]?.third
                    val cur = if (b.state.settings.currency == before) Brain.countries[c]?.third ?: "KWD" else b.state.settings.currency
                    b.state = b.state.copy(settings = b.state.settings.copy(country = c, currency = cur))
                }
            }
        }
        SectionTitle(model.t("settings.currency"))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            for (c in currencies.keys) Chip(c, s.currency == c) { model.update { b -> b.state = b.state.copy(settings = b.state.settings.copy(currency = c)) } }
        }
        SectionTitle(model.t("settings.lead"))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (n in listOf(3, 7, 14)) Chip(model.words.dayCount(n), s.lead == n) { model.update { b -> b.state = b.state.copy(settings = b.state.settings.copy(lead = n)) } }
        }
        SectionTitle(model.t("settings.notify"))
        Text(if (s.notify == true) model.t("notify.state_on") else model.t("notify.android_ready"), style = body(14), color = p.ink2)
        if (s.notify != true) {
            Spacer(Modifier.height(10.dp))
            WideButton(model.t("notify.on")) {
                if (Build.VERSION.SDK_INT >= 33) ask.launch(Manifest.permission.POST_NOTIFICATIONS)
                else model.update { b -> b.state = b.state.copy(settings = b.state.settings.copy(notify = true)) }
            }
        } else {
            Spacer(Modifier.height(10.dp))
            WideButton(model.t("notify.off"), primary = false) { model.update { b -> b.state = b.state.copy(settings = b.state.settings.copy(notify = false)) } }
        }
        SectionTitle(model.t("about.privacy_h"))
        Text(model.t("about.privacy"), style = body(14), color = p.ink2)
        Spacer(Modifier.height(16.dp))
        WideButton(model.t("act.wipe"), primary = false, danger = true) { confirm = true }
        Text(model.t("about.copyright"), style = body(12), color = p.ink3, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 10.dp))
    }
    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            text = { Text(model.t("confirm.wipe"), style = body(15)) },
            confirmButton = { TextButton({ confirm = false; model.eraseAll() }) { Text(model.t("act.wipe"), color = p.overdue) } },
            dismissButton = { TextButton({ confirm = false }) { Text(model.t("act.cancel")) } },
        )
    }
}

@Composable
fun WelcomeScreen(model: AppModel) {
    val p = pal()
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 24.dp, vertical = 30.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        Spacer(Modifier.height(30.dp))
        Image(painterResource(R.drawable.mark), null, Modifier.size(108.dp))
        Text(model.t("app.name"), style = display(54), color = p.ink)
        Text(model.t("welcome.tag"), style = title(21), color = p.overdue)
        Spacer(Modifier.height(8.dp))
        Text(model.t("welcome.body"), style = body(16), color = p.ink2, textAlign = TextAlign.Center)
        Row(Modifier.padding(vertical = 18.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip("عربي", model.lang == "ar") { model.setLang("ar") }
            Chip("English", model.lang == "en") { model.setLang("en") }
        }
        WideButton(model.t("welcome.start")) { model.beginSetup() }
        Text(model.t("welcome.demo"), style = body(15, FontWeight.SemiBold), color = p.ink2, modifier = Modifier.clickable { model.startWithSample() }.padding(14.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Ico("lock", p.ink3, 16.dp); Spacer(Modifier.width(6.dp)); Text(model.t("welcome.private"), style = body(13), color = p.ink3)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SetupScreen(model: AppModel) {
    val p = pal()
    val d = remember { Brain.Setup().apply { country = AppModel.guessCountry() } }
    var tick by remember { mutableStateOf(0) }
    fun touch() { tick++ }
    var extraName by remember { mutableStateOf("") }
    var extraMonths by remember { mutableStateOf(6) }
    var homeName by remember { mutableStateOf("") }
    var carName by remember { mutableStateOf("") }
    var km by remember { mutableStateOf("") }
    var other by remember { mutableStateOf("") }
    key(tick) {
        Page {
            Text(model.t("setup.step", mapOf("n" to "1", "of" to "2")), style = body(13, FontWeight.Bold), color = p.overdue, modifier = Modifier.padding(top = 20.dp))
            Text(model.t("setup.title"), style = title(30), color = p.ink)
            FieldLabel(model.t("setup.country"))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (c in Brain.countries.keys) Chip(model.t("country.$c"), d.country == c) { d.country = c; touch() }
            }
            FieldLabel(model.t("setup.type"))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (ty in listOf("house", "flat", "chalet", "farm", "jakhoor")) Chip(model.t("type.$ty"), d.homeType == ty) { d.homeType = ty; d.features["tank"] = ty != "flat"; touch() }
            }
            FieldLabel(model.t("setup.name"))
            Input(homeName, { homeName = it }, model.t("type.${d.homeType}"))
            FieldLabel(model.t("setup.has"))
            Column(Modifier.clip(RoundedCornerShape(16.dp)).background(p.surface).border(1.dp, p.line, RoundedCornerShape(16.dp))) {
                for (f in listOf("central_ac", "tank", "filter")) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(model.t("feat.$f"), style = body(15), color = p.ink, modifier = Modifier.weight(1f))
                        Switch(d.features[f] == true, { d.features[f] = it; touch() }, colors = SwitchDefaults.colors(checkedTrackColor = p.ok))
                    }
                }
            }
            FieldLabel(model.t("setup.extra"))
            if (d.extras.isNotEmpty()) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    d.extras.forEachIndexed { i, (t, m) -> Chip("$t  ${model.t("setup.every_$m")}", true, "close") { d.extras.removeAt(i); touch() } }
                }
                Spacer(Modifier.height(8.dp))
            }
            Input(extraName, { extraName = it }, model.t("setup.extra_ph"))
            Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                for (n in listOf(1, 3, 6, 12)) Chip(model.t("setup.every_$n"), extraMonths == n) { extraMonths = n }
            }
            Spacer(Modifier.height(8.dp))
            WideButton(model.t("act.add"), primary = false) {
                val t = extraName.trim()
                if (t.isNotEmpty()) { d.extras.add(t to extraMonths); extraName = ""; touch() }
            }
            FieldLabel(model.t("setup.car"))
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(p.surface).border(1.dp, p.line, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Text(model.t("setup.has_car"), style = body(15), color = p.ink, modifier = Modifier.weight(1f))
                Switch(d.hasCar, { d.hasCar = it; touch() }, colors = SwitchDefaults.colors(checkedTrackColor = p.ok))
            }
            if (d.hasCar) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Column(Modifier.weight(1f)) { FieldLabel(model.t("car.name")); Input(carName, { carName = it }, model.t("car.default")) }
                    Column(Modifier.weight(1f)) { FieldLabel(model.t("car.km_now")); Input(km, { km = it }, "84000", numbers = true) }
                }
            }
            FieldLabel(model.t("setup.things"))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (tt in model.catalog.thingTypes) Chip(tt.name(model.lang), d.things.contains(tt.id), tt.icon) {
                    if (d.things.contains(tt.id)) d.things.remove(tt.id) else d.things.add(tt.id); touch()
                }
            }
            if (d.things.contains("other")) {
                FieldLabel(model.t("setup.other"))
                Input(other, { other = it }, model.t("setup.other_ph"))
            }
            Spacer(Modifier.height(22.dp))
            WideButton(model.t("act.next")) {
                d.homeName = homeName; d.carName = carName; d.km = wholeNumber(km); d.otherName = other
                model.runSetup(d)
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LastTimeScreen(model: AppModel, created: List<String>) {
    val p = pal()
    val answers = remember { mutableStateMapOf<String, String>() }
    val questions = model.brain().lastQuestions(created)
    Page {
        Text(model.t("setup.step", mapOf("n" to "2", "of" to "2")), style = body(13, FontWeight.Bold), color = p.overdue, modifier = Modifier.padding(top = 20.dp))
        Text(model.t("last.title"), style = title(30), color = p.ink)
        Text(model.t("last.body"), style = body(15), color = p.ink2)
        for (q in questions) {
            Text(q.tpl?.let { model.catalog.template[it]?.name(model.lang) } ?: "", style = body(15, FontWeight.SemiBold), color = p.ink, modifier = Modifier.padding(top = 16.dp, bottom = 8.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for ((k, _) in Brain.lastOptions) Chip(model.t("last.$k"), (answers[q.id] ?: "unknown") == k) { answers[q.id] = k }
            }
            HorizontalDivider(color = p.line, modifier = Modifier.padding(top = 12.dp))
        }
        Spacer(Modifier.height(20.dp))
        WideButton(model.t("act.finish")) { model.finishSetup(created, answers.toMap()) }
    }
}
