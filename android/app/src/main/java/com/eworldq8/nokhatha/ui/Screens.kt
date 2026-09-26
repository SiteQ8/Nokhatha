// The screens, laid out as the web lays them out: docs/app/app.js is the reference for what
// goes where, and app.css for how big it is.
package com.eworldq8.nokhatha.ui

import androidx.activity.compose.BackHandler
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
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.AppModel
import com.eworldq8.nokhatha.R
import com.eworldq8.nokhatha.engine.*
import java.util.Calendar

/** The web's .page: 18px at the sides, room for the tab bar below. */
@Composable
fun Page(content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 18.dp, end = 18.dp, top = 6.dp, bottom = 110.dp), content = content)
}

// ---------------------------------------------------------------- rows

private val subCatIcons = mapOf("stream" to "play", "music" to "music", "cloud" to "cloud", "games" to "game", "gym" to "gym", "internet" to "wifi", "phone" to "phone", "apps" to "apps")

/** The web's .row for a task: icon, title and meta, the weave, and the done button at the end. */
@Composable
fun TaskRow(model: AppModel, e: Evaluated, showAsset: Boolean) {
    val p = pal()
    val w = model.words
    val line = w.due(e, model.today)
    var open by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { if (model.autoSheet == "task" && e.status == "overdue") { model.autoSheet = null; open = true } }
    Row(Modifier.fillMaxWidth().padding(start = 14.dp, end = 12.dp, top = 10.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.weight(1f).clickable(role = Role.Button) { open = true }.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RowIcon(e.icon, p.tint(e.status), p.tintBg(e.status))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(e.title(model.lang), style = body(15.5, FontWeight.SemiBold, 1.45), color = p.ink, maxLines = 2)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(line.first, style = body(13.5, FontWeight.SemiBold, 1.5), color = p.tint(e.status), maxLines = 1)
                    line.second?.let { Text(it, style = body(13.5, lineHeight = 1.5), color = p.ink3, maxLines = 1) }
                    if (showAsset) {
                        Text(e.asset.name, style = body(12, FontWeight.SemiBold, 1.6), color = p.ink2,
                            modifier = Modifier.clip(CircleShape).background(p.ink.copy(alpha = 0.07f)).padding(horizontal = 8.dp))
                    }
                }
                model.brain().progress(e)?.let { ProgressLine(it, p.tint(e.status)) }
            }
        }
        if (e.every.fixed == true) {
            Text(if (e.due == null) model.t("act.setdate") else model.t("act.renewed"), style = body(13.5, FontWeight.Bold, 1.2), color = p.ink,
                modifier = Modifier.widthIn(min = 64.dp).height(46.dp).clip(CircleShape).background(p.surface).border(1.6.dp, p.line, CircleShape)
                    .clickable(role = Role.Button) { if (e.due == null) open = true else model.renew(e) }.padding(horizontal = 14.dp).wrapContentHeight(Alignment.CenterVertically))
        } else {
            Box(
                Modifier.size(46.dp).clip(CircleShape).background(p.surface).border(1.6.dp, if (e.status == "overdue") p.overdue.copy(alpha = 0.45f) else p.line, CircleShape)
                    .clickable(role = Role.Button) { model.done(e) }
                    .semantics { contentDescription = model.t("act.done_label", mapOf("title" to e.title(model.lang))) },
                contentAlignment = Alignment.Center,
            ) { Ico("done", p.ink3, 20.dp) }
        }
    }
    if (open) TaskSheet(model, e) { open = false }
}

@Composable
fun TaskList(model: AppModel, rows: List<Evaluated>, showAsset: Boolean = false) {
    ListCard {
        rows.forEachIndexed { i, e ->
            if (i > 0) RowLine()
            key(e.item.id) { TaskRow(model, e, showAsset) }
        }
    }
}

/** The web's grouped rows: a small area heading, then a list. */
@Composable
fun GroupedRows(model: AppModel, tasks: List<Evaluated>, areas: List<Named>) {
    for (area in areas) {
        val rows = tasks.filter { (it.tpl?.area ?: "custom") == area.id }
        if (rows.isEmpty()) continue
        SmallHead(area.name(model.lang))
        TaskList(model, rows)
    }
}

// ---------------------------------------------------------------- today

@Composable
fun TodayScreen(model: AppModel) {
    val p = pal()
    val b = model.brain()
    val w = model.words
    val tasks = b.tasks()
    val now = tasks.filter { it.status in setOf("overdue", "today", "soon") }
    val later = tasks.filter { it.status == "ok" && (it.days ?: 999) <= 30 }.take(6)
    val subs = b.subs()
    val talk = subs.filter { it.ask || it.planned }
    val warr = b.warranties().filter { it.status == "soon" || it.status == "today" }
    val docsSoon = b.docs().filter { it.status in setOf("soon", "today", "overdue") }
    val season = seasonAt(model.today, model.catalog.seasons)
    val dots = tasks.mapNotNull { e -> e.days?.let { DialDot(it, e.status) } } + subs.filter { it.status != "off" }.map { DialDot(it.days, "sub") }
    val totals = b.totals()
    val cur = model.state?.settings?.currency?.takeIf { totals.containsKey(it) } ?: totals.keys.sorted().firstOrNull()
    Page {
        Column(Modifier.padding(top = 2.dp, bottom = 4.dp)) {
            Text(w.greeting(Calendar.getInstance().get(Calendar.HOUR_OF_DAY)), style = title(24), color = p.ink)
            Text(w.longDate(model.today), style = body(14), color = p.ink3)
        }
        Box(Modifier.padding(top = 4.dp, bottom = 10.dp)) { Dial(model.today, model.catalog, dots, w.seasonCenter(season, model.catalog, model.today)) }
        model.catalog.season(season.id)?.hint(model.lang)?.let { hint ->
            Row(Modifier.padding(top = 6.dp).fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(p.surface).border(1.dp, p.line, RoundedCornerShape(18.dp)).padding(horizontal = 16.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Ico("spark", p.sadu, 18.dp, Modifier.padding(top = 3.dp))
                Text(hint, style = body(14.5, lineHeight = 1.7), color = p.ink2)
            }
        }
        LaunchedEffect(model.state?.settings?.weather) { model.refreshWeather() }
        WeatherCard(model)
        SectionTitle(model.t("today.now"), now.size)
        if (now.isEmpty()) EmptyNote("done", model.t("today.clear")) else TaskList(model, now, true)
        talk.firstOrNull()?.let { Box(Modifier.padding(top = 14.dp)) { AskCard(model, it) } }
        if (talk.size > 1) {
            Text(model.t("today.more_asks"), style = body(14, FontWeight.SemiBold), color = p.ink2,
                modifier = Modifier.fillMaxWidth().clickable { model.tab = "subs" }.padding(vertical = 10.dp), textAlign = TextAlign.Center)
        }
        if (cur != null) {
            val t = totals.getValue(cur)
            ListCard(Modifier.padding(top = 14.dp)) {
                Row(Modifier.fillMaxWidth().clickable { model.tab = "subs" }.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Ico("repeat", p.ok, 20.dp)
                    Text(model.t("today.subs", mapOf("amount" to w.money(t.month, cur))), style = body(15, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
                    Chevron(p.ink3, 16.dp)
                }
            }
        }
        if (warr.isNotEmpty()) {
            SectionTitle(model.t("today.warranties"))
            WarrantyList(model, warr)
        }
        if (docsSoon.isNotEmpty()) {
            SectionTitle(model.t("today.docs"))
            DocList(model, docsSoon)
        }
        if (later.isNotEmpty()) {
            SectionTitle(model.t("today.later"))
            TaskList(model, later, true)
        }
    }
}

// ---------------------------------------------------------------- home, car, belongings

@Composable
fun AssetsScreen(model: AppModel, kind: AssetKind, onBack: (() -> Unit)? = null) {
    val p = pal()
    val w = model.words
    val state = model.state ?: AppState()
    val list = when (kind) {
        AssetKind.HOME -> state.homes.map { it.id to it.name }
        AssetKind.CAR -> state.cars.map { it.id to it.name }
        AssetKind.THING -> state.things.map { it.id to it.name }
    }
    var selected by remember { mutableStateOf<String?>(null) }
    var sheet by remember { mutableStateOf<String?>(null) }
    val current = list.firstOrNull { it.first == selected } ?: list.firstOrNull()
    LaunchedEffect(Unit) { when (model.autoSheet) { "addtask" -> sheet = "task"; "edit" -> sheet = "edit"; "odo" -> sheet = "odo"; else -> return@LaunchedEffect }; model.autoSheet = null }
    val tasks = current?.let { c -> model.brain().tasks { it.asset == c.first } } ?: emptyList()
    val areas = model.catalog.areas[kind.key] ?: emptyList()
    val add = when (kind) { AssetKind.HOME -> "act.add_home"; AssetKind.CAR -> "act.add_car"; AssetKind.THING -> "act.add_thing" }
    val edit = when (kind) { AssetKind.HOME -> "act.edit_home"; AssetKind.CAR -> "act.edit_car"; AssetKind.THING -> "act.edit_thing" }
    val icon = when (kind) { AssetKind.HOME -> "home"; AssetKind.CAR -> "car"; AssetKind.THING -> "box" }
    val name = model.t(when (kind) { AssetKind.HOME -> "tab.home"; AssetKind.CAR -> "tab.car"; AssetKind.THING -> "more.things" })
    Page {
        PageHead(name, if (kind == AssetKind.THING) "more" else kind.key, onBack, model.t("tab.more"), extra = if (list.isEmpty()) null else ({
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = 2.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for ((id, n) in list) Chip(n, id == current?.first) { selected = id }
                Chip(model.t(add), false, "plus", dashed = true) { sheet = "add" }
            }
        }))
        if (current == null) {
            EmptyNote(icon, model.t("empty.${kind.key}"), big = true) { WideButton(model.t(add), icon = "plus", block = false) { sheet = "add" } }
        } else {
            if (kind == AssetKind.CAR) {
                state.cars.firstOrNull { it.id == current.first }?.let { car ->
                    Row(Modifier.fillMaxWidth().clip(CardShape).background(p.surface).border(1.dp, p.line, CardShape).padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Column(Modifier.weight(1f)) {
                            Text(model.t("car.odo"), style = body(13, FontWeight.SemiBold, 1.5), color = p.ink3)
                            Text(kmOn(car.odometer, model.today)?.let { w.km(it) } ?: model.t("car.odo_unknown"), style = title(28), color = p.ink)
                            Text(lastReading(car.odometer)?.let { r -> Day.parse(r.date)?.let { model.t("car.odo_last", mapOf("km" to w.km(r.km), "date" to w.date(it, model.today))) } }
                                ?: model.t("car.odo_none"), style = body(13, lineHeight = 1.5), color = p.ink2)
                        }
                        WideButton(model.t("act.update_odo"), primary = false, icon = "gauge", block = false) { sheet = "odo" }
                    }
                }
            }
            if (kind == AssetKind.CAR) RenewalCard(model, current.first)
            if (tasks.isEmpty()) EmptyNote(icon, model.t("empty.${kind.key}")) else GroupedRows(model, tasks, areas)
            Box(Modifier.padding(top = 16.dp)) {
                ButtonPair(model.t("act.add_task"), { sheet = "task" }, model.t(edit), { sheet = "edit" }, aIcon = "plus", bIcon = "edit", bQuiet = true)
            }
        }
    }
    when (sheet) {
        "add" -> AssetSheet(model, kind, null) { sheet = null }
        "edit" -> current?.let { AssetSheet(model, kind, it.first) { sheet = null } }
        "task" -> current?.let { AddTaskSheet(model, it.first) { sheet = null } }
        "odo" -> current?.let { OdoSheet(model, it.first) { sheet = null } }
    }
}

// ---------------------------------------------------------------- subscriptions

@Composable
fun SubsScreen(model: AppModel) {
    val p = pal()
    val b = model.brain()
    val w = model.words
    val totals = b.totals()
    val main = model.state?.settings?.currency?.takeIf { totals.containsKey(it) } ?: totals.keys.sorted().firstOrNull()
    val subs = b.subs().sortedWith(compareBy<SubView> { if (it.sub.cancelled == true) 1 else 0 }.thenBy { it.next.n })
    var editing by remember { mutableStateOf<Sub?>(null) }
    var adding by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { if (model.autoSheet == "sub") { model.autoSheet = null; editing = subs.firstOrNull()?.sub } }
    Page {
        PageHead(model.t("tab.subs"), "subs")
        if (subs.isEmpty()) {
            EmptyNote("repeat", model.t("empty.subs"), big = true) { WideButton(model.t("act.add_sub"), icon = "plus", block = false) { adding = true } }
        } else {
            if (main != null) {
                val t = totals.getValue(main)
                CardBox(padding = 18.dp) {
                    Text(model.t("subs.month"), style = body(13.5, FontWeight.SemiBold, 1.5), color = p.ink3)
                    Text(w.money(t.month, main), style = title(40, 1.15), color = p.ink)
                    Text(model.t("subs.year", mapOf("amount" to w.money(t.year, main))), style = body(14, lineHeight = 1.5), color = p.ink2)
                    for (c in totals.keys.sorted().filter { it != main }) {
                        Text(w.money(totals.getValue(c).month, c) + " " + model.t("cycle.monthly"), style = body(14, FontWeight.SemiBold, 1.5), color = p.ink2)
                    }
                }
            }
            for (s in subs.filter { it.ask || it.planned }) Box(Modifier.padding(top = 14.dp)) { AskCard(model, s) }
            SectionTitle(model.t("subs.all"), subs.count { it.sub.cancelled != true })
            ListCard {
                subs.forEachIndexed { i, s ->
                    if (i > 0) RowLine()
                    val off = s.sub.cancelled == true
                    val status = if (off) "off" else s.status
                    Row(Modifier.fillMaxWidth().clickable { editing = s.sub }.padding(start = 14.dp, end = 12.dp, top = 14.dp, bottom = 14.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        RowIcon(subCatIcons[s.sub.category] ?: "repeat", p.tint(status), p.tintBg(status))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                                Text(s.sub.name, style = body(15.5, FontWeight.SemiBold, 1.45), color = if (off) p.ink3 else p.ink,
                                    textDecoration = if (off) TextDecoration.LineThrough else null)
                                if (s.trial && !off) Box(Modifier.size(7.dp).clip(CircleShape).background(p.soon))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text(
                                    when {
                                        off -> model.t("sub.cancelled")
                                        s.trial && s.days == 0 -> model.t("sub.trial_today")
                                        s.trial -> model.t("sub.trial", mapOf("rel" to w.rel(s.days)))
                                        s.days == 0 -> model.t("sub.renews_today")
                                        else -> model.t("sub.renews", mapOf("rel" to w.rel(s.days)))
                                    },
                                    style = body(13.5, FontWeight.SemiBold, 1.5), color = p.tint(status),
                                )
                                if (!off && !s.trial) Text(w.date(s.next, model.today), style = body(13.5, lineHeight = 1.5), color = p.ink3)
                            }
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(w.money(s.sub.amount, s.sub.currency), style = body(15, FontWeight.Bold, 1.3), color = p.ink, maxLines = 1)
                            Text(model.t("cycle." + s.sub.cycle), style = body(12, lineHeight = 1.3), color = p.ink3)
                        }
                    }
                }
            }
            Box(Modifier.padding(top = 16.dp)) { WideButton(model.t("act.add_sub"), primary = false, icon = "plus") { adding = true } }
        }
    }
    editing?.let { SubSheet(model, it) { editing = null } }
    if (adding) SubSheet(model, null) { adding = false }
}

// ---------------------------------------------------------------- first run

@Composable
fun WelcomeScreen(model: AppModel) {
    val p = pal()
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 22.dp, vertical = 36.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
    ) {
        Spacer(Modifier.height(24.dp))
        Image(painterResource(R.drawable.mark), null, Modifier.size(96.dp))
        Text(model.t("app.name"), style = display(56), color = p.ink, modifier = Modifier.padding(top = 6.dp))
        Text(model.t("welcome.tag"), style = title(21), color = p.overdue)
        Text(model.t("welcome.body"), style = body(16, lineHeight = 1.8), color = p.ink2, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 12.dp, bottom = 6.dp))
        Seg(listOf("ar" to "عربي", "en" to "English"), model.lang, Modifier.width(176.dp).padding(top = 6.dp, bottom = 4.dp)) { model.setLang(it) }
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("welcome.start")) { model.beginSetup() }
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("welcome.demo"), quiet = true) { model.startWithSample() }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Ico("lock", p.ink3, 16.dp)
            Text(model.t("welcome.private"), style = body(13.5), color = p.ink3, textAlign = TextAlign.Center)
        }
    }
}

@Composable
fun SetupScreen(model: AppModel) {
    val p = pal()
    val d = remember { Brain.Setup().apply { country = AppModel.guessCountry() } }
    var tick by remember { mutableStateOf(0) }
    fun touch() { tick++ }
    var extraName by remember { mutableStateOf("") }
    var extraMonths by remember { mutableStateOf("6") }
    var homeName by remember { mutableStateOf("") }
    var carName by remember { mutableStateOf("") }
    var km by remember { mutableStateOf("") }
    var other by remember { mutableStateOf("") }
    BackHandler { model.onboarding = null }
    key(tick) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 22.dp).padding(top = 30.dp, bottom = 40.dp)) {
            Text(model.t("setup.step", mapOf("n" to "1", "of" to "2")), style = body(13, FontWeight.Bold), color = p.overdue)
            Text(model.t("setup.title"), style = title(30, 1.25), color = p.ink)
            FieldLabel(model.t("setup.country"))
            ChoiceGrid(Brain.countries.keys.toList(), 3, { d.country == it }, { model.t("country.$it") }) { d.country = it; touch() }
            FieldLabel(model.t("setup.type"))
            ChoiceGrid(listOf("house", "flat", "chalet", "farm", "jakhoor"), 3, { d.homeType == it }, { model.t("type.$it") }) {
                d.homeType = it; d.features["tank"] = it != "flat"; touch()
            }
            FieldLabel(model.t("setup.name"))
            Input(homeName, { homeName = it }, model.t("type.${d.homeType}"))
            FieldLabel(model.t("setup.has"))
            SwitchCard(listOf("central_ac", "tank", "filter").map { f -> Triple(model.t("feat.$f"), d.features[f] == true) { v: Boolean -> d.features[f] = v; touch() } })
            FieldLabel(model.t("setup.extra"))
            if (d.extras.isNotEmpty()) {
                Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    d.extras.forEachIndexed { i, (t, m) -> Chip("$t  ${model.t("setup.every_$m")}", true, "close") { d.extras.removeAt(i); touch() } }
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Input(extraName, { extraName = it }, model.t("setup.extra_ph"), modifier = Modifier.weight(1f))
                Select(extraMonths, listOf(1, 3, 6, 12).map { it.toString() to model.t("setup.every_$it") }, Modifier.width(118.dp)) { extraMonths = it }
                Box(Modifier.size(48.dp).clip(RoundedCornerShape(14.dp)).background(p.surface).border(1.dp, p.line, RoundedCornerShape(14.dp)).clickable(role = Role.Button) {
                    val t = extraName.trim()
                    if (t.isNotEmpty()) { d.extras.add(t to extraMonths.toInt()); extraName = ""; touch() }
                }, contentAlignment = Alignment.Center) { Ico("plus", p.ink, 20.dp) }
            }
            FieldLabel(model.t("setup.car"))
            SwitchCard(listOf(Triple(model.t("setup.has_car"), d.hasCar) { v: Boolean -> d.hasCar = v; touch() }))
            if (d.hasCar) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(Modifier.weight(1f)) { FieldLabel(model.t("car.name")); Input(carName, { carName = it }, model.t("car.default")) }
                    Column(Modifier.weight(1f)) { FieldLabel(model.t("car.km_now")); Input(km, { km = it }, "84000", numbers = true) }
                }
            }
            FieldLabel(model.t("setup.things"))
            ChoiceGrid(model.catalog.thingTypes, 3, { d.things.contains(it.id) }, { it.name(model.lang) }, { it.icon }) {
                if (d.things.contains(it.id)) d.things.remove(it.id) else d.things.add(it.id); touch()
            }
            if (d.things.contains("other")) {
                FieldLabel(model.t("setup.other"))
                Input(other, { other = it }, model.t("setup.other_ph"))
            }
            Spacer(Modifier.height(18.dp))
            WideButton(model.t("act.next")) {
                d.homeName = homeName; d.carName = carName; d.km = wholeNumber(km); d.otherName = other
                model.runSetup(d)
            }
        }
    }
}

@Composable
fun LastTimeScreen(model: AppModel, created: List<String>) {
    val p = pal()
    val answers = remember { mutableStateMapOf<String, String>() }
    val questions = model.brain().lastQuestions(created)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(horizontal = 22.dp).padding(top = 30.dp, bottom = 40.dp)) {
        Text(model.t("setup.step", mapOf("n" to "2", "of" to "2")), style = body(13, FontWeight.Bold), color = p.overdue)
        Text(model.t("last.title"), style = title(30, 1.25), color = p.ink)
        Lede(model.t("last.body"))
        for (q in questions) {
            Column(Modifier.fillMaxWidth().padding(vertical = 14.dp)) {
                Text(q.tpl?.let { model.catalog.template[it]?.name(model.lang) } ?: "", style = body(16, FontWeight.SemiBold), color = p.ink, modifier = Modifier.padding(bottom = 10.dp))
                ChoiceGrid(Brain.lastOptions.map { it.first }, 3, { (answers[q.id] ?: "unknown") == it }, { model.t("last.$it") }, small = true) { answers[q.id] = it }
            }
            RowLine()
        }
        Spacer(Modifier.height(20.dp))
        WideButton(model.t("act.finish")) { model.finishSetup(created, answers.toMap()) }
    }
}

/** The web's .wx card: dust, rain, wind, heat and cold for the chosen area, from the cache the app keeps. */
@Composable
fun WeatherCard(model: AppModel) {
    if (!model.weatherShown) return
    val p = pal()
    val list = model.weatherAlerts().take(2)
    val calm = list.isEmpty()
    val shape = RoundedCornerShape(18.dp)
    Box(Modifier.padding(top = 4.dp, bottom = 14.dp).fillMaxWidth().clip(shape).background(if (calm) p.surface else p.rutab.copy(alpha = 0.12f))
        .border(1.dp, if (calm) p.line else p.rutab.copy(alpha = 0.3f), shape).padding(start = 16.dp, end = 16.dp, top = 14.dp, bottom = 26.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (calm) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Ico("sun", p.ok, 20.dp, Modifier.padding(top = 3.dp))
                    Text(model.t("wx.calm", mapOf("place" to model.wxPlaceName())), style = body(14.5, lineHeight = 1.7), color = p.ink2)
                }
            } else {
                for (a in list) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        val tone = when (a.kind) { "dust_heavy", "rain", "wind" -> p.overdue; "cold" -> p.ok; else -> p.soonInk }
                        Ico(Weather.icons[a.kind] ?: "sun", tone, 20.dp, Modifier.padding(top = 3.dp))
                        Text(model.t("wx.${a.kind}", mapOf("day" to model.t(if (a.day == 0) "wx.day0" else "wx.day1"), "t" to (a.value?.toString() ?: ""))),
                            style = body(14.5, FontWeight.SemiBold, 1.7), color = p.ink)
                    }
                }
            }
        }
        Text("Open-Meteo", style = body(11), color = p.ink3, modifier = Modifier.align(Alignment.BottomEnd).offset(y = 20.dp).clickable { model.openUrl("https://open-meteo.com") })
    }
}

/** The web's renewal path: the steps for the chosen country with their links, the term, and the button that sets the next dates. */
@Composable
fun RenewalCard(model: AppModel, carId: String) {
    val b = model.brain()
    if (!b.renewalShown(carId)) return
    val p = pal()
    val plan = model.catalog.renewPlan(model.country) ?: return
    val car = model.state?.cars?.firstOrNull { it.id == carId } ?: return
    val done = car.renewal?.done ?: emptyList()
    val years = car.renewal?.years ?: plan.years.first()
    Column(Modifier.padding(top = 14.dp, bottom = 4.dp).fillMaxWidth().clip(CardShape).background(p.surface).border(1.dp, p.line, CardShape).padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Ico("id", p.ink2, 20.dp)
            Text(model.t("renew.title"), style = title(19), color = p.ink)
        }
        Spacer(Modifier.height(4.dp))
        Lede(model.t("renew.lede", mapOf("portal" to plan.portal(model.lang))), small = true)
        ListCard {
            plan.steps.forEachIndexed { i, s ->
                if (i > 0) RowLine()
                val on = done.contains(s.id)
                Row(Modifier.fillMaxWidth().clickable(role = Role.Checkbox) { model.update { it.setRenewStep(carId, s.id, !on) } }
                    .padding(start = 16.dp, end = 8.dp, top = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Box(Modifier.size(24.dp).clip(RoundedCornerShape(7.dp)).background(if (on) p.ok else androidx.compose.ui.graphics.Color.Transparent).border(1.6.dp, if (on) p.ok else p.line, RoundedCornerShape(7.dp)),
                        contentAlignment = Alignment.Center) { if (on) Ico("done", p.onInk, 16.dp) }
                    Text(s.name(model.lang), style = body(16, lineHeight = 1.55), color = if (on) p.ink3 else p.ink, textDecoration = if (on) TextDecoration.LineThrough else null, modifier = Modifier.weight(1f))
                    if (s.link != null) {
                        Box(Modifier.size(34.dp).clip(RoundedCornerShape(10.dp)).clickable(role = Role.Button) { model.openUrl(s.link) }, contentAlignment = Alignment.Center) { Ico("link", p.ink3, 18.dp) }
                    }
                }
            }
        }
        if (plan.years.size > 1) {
            FieldLabel(model.t("renew.years"))
            Seg(plan.years.map { it.toString() to model.words.yearCount(it) }, years.toString()) { v -> model.update { it.setRenewYears(carId, v.toInt()) } }
        }
        Spacer(Modifier.height(12.dp))
        WideButton(model.t("renew.done"), icon = "done") { model.update("renew.done_toast") { it.finishRenewal(carId) } }
    }
}
