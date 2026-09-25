// More, as on the web: a list of pages, each one a screen of its own.
package com.eworldq8.nokhatha.ui

import android.Manifest
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.eworldq8.nokhatha.AppModel
import com.eworldq8.nokhatha.R
import com.eworldq8.nokhatha.Toast
import com.eworldq8.nokhatha.engine.*
import kotlinx.coroutines.launch

@Composable
fun MoreScreen(model: AppModel) {
    val s = model.state ?: AppState()
    val entries = listOf(
        Triple("things", "box", s.things.size.takeIf { it > 0 }?.toString()),
        Triple("warranties", "seal", s.warranties.size.takeIf { it > 0 }?.toString()),
        Triple("techs", "wrench", s.techs.size.takeIf { it > 0 }?.toString()),
        Triple("travel", "plane", if (s.travelDone.isNotEmpty()) "${s.travelDone.size}/${model.catalog.travel.size}" else null),
        Triple("spend", "wallet", null),
        Triple("settings", "sliders", null),
        Triple("about", "info", null),
    )
    Page {
        Header(model)
        Text(model.t("tab.more"), style = title(30), color = pal().ink)
        Spacer(Modifier.height(10.dp))
        ListCard {
            entries.forEachIndexed { i, (page, icon, count) ->
                if (i > 0) HorizontalDivider(color = pal().line)
                NavRow(icon, model.t("more.$page"), count) { model.page = page }
            }
        }
    }
}

// ---------------------------------------------------------------- settings

@Composable
fun SettingsScreen(model: AppModel) {
    val p = pal()
    val s = model.state?.settings ?: Settings()
    val w = model.words
    val scope = rememberCoroutineScope()
    var sheet by remember { mutableStateOf<String?>(null) }
    var confirm by remember { mutableStateOf<String?>(null) }
    val ics = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/calendar")) { uri ->
        if (uri != null) model.exportIcs(uri)
    }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        model.update { b -> b.state = b.state.copy(settings = b.state.settings.copy(notify = granted)) }
        if (!granted) model.say("notify.denied")
    }
    fun set(f: (Settings) -> Settings) = model.update { b -> b.state = b.state.copy(settings = f(b.state.settings)) }
    Page {
        PageHead(model.t("more.settings")) { model.page = null }
        Spacer(Modifier.height(8.dp))
        ListCard {
            SettingRow("chat", model.t("settings.lang")) { Seg(listOf("ar" to "عربي", "en" to "English"), model.lang) { model.setLang(it) } }
            HorizontalDivider(color = p.line)
            SettingRow("sun", model.t("settings.theme")) {
                Seg(listOf("auto" to model.t("settings.auto"), "light" to model.t("settings.light"), "dark" to model.t("settings.dark")), s.theme) { v -> set { it.copy(theme = v) } }
            }
            HorizontalDivider(color = p.line)
            SettingRow("globe", model.t("settings.country")) {
                Select(s.country, Brain.countries.keys.map { it to model.t("country.$it") }) { c ->
                    set { st ->
                        val before = Brain.countries[st.country]?.third
                        st.copy(country = c, currency = if (st.currency == before) Brain.countries[c]?.third ?: "KWD" else st.currency)
                    }
                }
            }
            HorizontalDivider(color = p.line)
            SettingRow("wallet", model.t("settings.currency")) {
                Select(s.currency, currencies.keys.map { it to "$it ${model.t("cur.$it")}" }) { c -> set { it.copy(currency = c) } }
            }
            HorizontalDivider(color = p.line)
            SettingRow("snooze", model.t("settings.lead")) {
                Seg(listOf(3, 7, 14).map { it.toString() to w.dayCount(it) }, s.lead.toString()) { v -> set { it.copy(lead = v.toInt()) } }
            }
        }

        SmallHead(model.t("settings.calendar"))
        Lede(model.t("settings.calendar_body"), small = true)
        Spacer(Modifier.height(8.dp))
        WideButton(model.t("act.ics"), primary = false, icon = "calendar") { ics.launch("nokhatha.ics") }

        SmallHead(model.t("settings.notify"))
        Lede(if (s.notify == true) model.t("notify.state_on") else model.t("notify.android_ready"), small = true)
        Spacer(Modifier.height(8.dp))
        if (s.notify == true) {
            WideButton(model.t("notify.off"), primary = false, icon = "snooze") { set { it.copy(notify = false) } }
        } else {
            WideButton(model.t("notify.on"), icon = "bell") {
                if (Build.VERSION.SDK_INT >= 33) ask.launch(Manifest.permission.POST_NOTIFICATIONS) else set { it.copy(notify = true) }
            }
        }

        SmallHead(model.t("settings.weather"))
        Lede(model.t("wx.explain"), small = true)
        Spacer(Modifier.height(8.dp))
        val wxOn = s.weather?.on == true
        val places = model.wxPlaces()
        ListCard {
            SettingRow("globe", model.t("wx.place")) {
                Select(s.weather?.place ?: places.firstOrNull()?.id ?: "", places.map { it.id to it.name(model.lang) }) { model.setWeatherPlace(it) }
            }
        }
        Spacer(Modifier.height(10.dp))
        if (wxOn) WideButton(model.t("wx.off"), primary = false, icon = "close") { model.setWeather(false) }
        else WideButton(model.t("wx.on"), icon = "sun") { model.setWeather(true); scope.launch { model.refreshWeather(true) } }
        LaunchedEffect(wxOn, s.weather?.place) { if (wxOn) model.refreshWeather() }
        model.wx?.takeIf { wxOn && it.lat == s.weather?.lat }?.let { c ->
            Text(model.t("wx.updated", mapOf("date" to model.clock(c.at))), style = body(13), color = p.ink3, modifier = Modifier.padding(top = 8.dp))
        }
        Text(model.t("wx.source"), style = body(13), color = p.ink3, modifier = Modifier.padding(top = 6.dp))

        SmallHead(model.t("settings.backup"))
        Lede(model.t("settings.backup_body"), small = true)
        Row(Modifier.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Ico(if (s.lastBackup != null) "done" else "info", if (s.lastBackup != null) p.ok else p.ink3, 18.dp)
            Spacer(Modifier.width(8.dp))
            Text(Day.parse(s.lastBackup)?.let { model.t("settings.last_backup", mapOf("date" to w.date(it, model.today))) } ?: model.t("settings.no_backup"),
                style = body(14), color = p.ink2)
        }
        ButtonPair(model.t("act.backup"), { sheet = "backup" }, model.t("act.restore"), { sheet = "restore" })

        SmallHead(model.t("settings.data"))
        ButtonPair(model.t("welcome.demo"), { confirm = "sample" }, model.t("act.wipe"), { confirm = "wipe" }, bDanger = true)
    }
    when (sheet) {
        "backup" -> BackupSheet(model) { sheet = null }
        "restore" -> RestoreSheet(model) { sheet = null }
    }
    when (confirm) {
        "sample" -> ConfirmDialog(model.t("confirm.sample"), model.t("welcome.demo"), model.t("act.cancel"), { model.startWithSample(); model.page = null; model.tab = "today" }) { confirm = null }
        "wipe" -> ConfirmDialog(model.t("confirm.wipe"), model.t("act.wipe"), model.t("act.cancel"), { scope.launch { model.eraseAll() } }) { confirm = null }
    }
}

@Composable
fun BackupSheet(model: AppModel, onClose: () -> Unit) {
    val scope = rememberCoroutineScope()
    var pass by remember { mutableStateOf("") }
    var pass2 by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val save = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        busy = true
        scope.launch {
            val ok = model.writeBackup(uri, pass)
            busy = false
            model.say(if (ok) "backup.done" else "backup.failed")
            if (ok) onClose()
        }
    }
    Sheet(model, model.t("act.backup"), onClose) {
        Lede(model.t("backup.body"), small = true)
        FieldLabel(model.t("backup.pass"))
        Input(pass, { pass = it }, "", password = true)
        FieldLabel(model.t("backup.pass2"))
        Input(pass2, { pass2 = it }, "", password = true)
        Spacer(Modifier.height(18.dp))
        if (busy) BusyButton() else WideButton(model.t("backup.go"), icon = "lock") {
            when {
                pass.length < 8 -> model.say("backup.short")
                pass != pass2 -> model.say("backup.mismatch")
                else -> save.launch("nokhatha-backup-${model.today.iso}.json")
            }
        }
    }
}

@Composable
fun RestoreSheet(model: AppModel, onClose: () -> Unit) {
    val scope = rememberCoroutineScope()
    var file by remember { mutableStateOf<Uri?>(null) }
    var pass by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if (uri != null) file = uri }
    Sheet(model, model.t("act.restore"), onClose) {
        Lede(model.t("restore.body"), small = true)
        Spacer(Modifier.height(8.dp))
        WideButton(file?.let { model.fileName(it) } ?: model.t("restore.pick"), primary = false, icon = "upload") { pick.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) }
        FieldLabel(model.t("backup.pass"))
        Input(pass, { pass = it }, "", password = true)
        Spacer(Modifier.height(18.dp))
        if (busy) BusyButton() else WideButton(model.t("restore.go"), icon = "upload") {
            val f = file ?: return@WideButton model.say("restore.nofile")
            busy = true
            scope.launch {
                val err = model.readBackup(f, pass)
                busy = false
                when (err) {
                    null -> { model.say("restore.done"); onClose(); model.page = null; model.tab = "today" }
                    "pass" -> model.say("restore.badpass")
                    else -> model.say("restore.badfile")
                }
            }
        }
    }
}

@Composable
fun BusyButton() {
    val p = pal()
    Box(Modifier.fillMaxWidth().height(50.dp).clip(RoundedCornerShape(14.dp)).background(p.ink.copy(alpha = 0.75f)), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = p.onInk, strokeWidth = 2.5.dp, modifier = Modifier.size(24.dp))
    }
}

// ---------------------------------------------------------------- about

@Composable
fun AboutScreen(model: AppModel) {
    val p = pal()
    Page {
        PageHead(model.t("more.about")) { model.page = null }
        Column(Modifier.fillMaxWidth().padding(vertical = 14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Image(painterResource(R.drawable.mark), null, Modifier.size(84.dp))
            Text(model.t("app.name"), style = title(30), color = p.ink)
            Text(model.t("about.version", mapOf("v" to model.version)), style = body(14), color = p.ink3)
        }
        Lede(model.t("about.name"))
        SmallHead(model.t("about.privacy_h"))
        Lede(model.t("about.privacy"))
        Lede(model.t("about.keep"))
        SmallHead(model.t("about.open_h"))
        Lede(model.t("about.open"))
        Spacer(Modifier.height(10.dp))
        ButtonPair(model.t("about.source"), { model.openUrl("https://github.com/SiteQ8/Nokhatha") }, "nokhatha.3li.info", { model.openUrl("https://nokhatha.3li.info") })
        Text(model.t("about.copyright"), style = body(12), color = p.ink3, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 16.dp))
    }
}

// ---------------------------------------------------------------- warranties

@Composable
fun WarrantiesScreen(model: AppModel) {
    val ws = model.brain().warranties()
    val active = ws.filter { it.status != "overdue" }
    val ended = ws.filter { it.status == "overdue" }
    var adding by remember { mutableStateOf(false) }
    Page {
        PageHead(model.t("more.warranties")) { model.page = null }
        Lede(model.t("w.lede"))
        if (ws.isEmpty()) EmptyNote("seal", model.t("empty.warranties"))
        if (active.isNotEmpty()) { Spacer(Modifier.height(8.dp)); WarrantyList(model, active) }
        if (ended.isNotEmpty()) { SmallHead(model.t("w.ended_h")); WarrantyList(model, ended) }
        Spacer(Modifier.height(14.dp))
        WideButton(model.t("act.add_warranty"), icon = "plus") { adding = true }
    }
    if (adding) WarrantySheet(model, null) { adding = false }
}

@Composable
fun WarrantyList(model: AppModel, list: List<WarrantyView>) {
    ListCard {
        list.forEachIndexed { i, x ->
            if (i > 0) HorizontalDivider(color = pal().line)
            key(x.w.id) { WarrantyRow(model, x) }
        }
    }
}

@Composable
fun WarrantyRow(model: AppModel, x: WarrantyView) {
    val p = pal()
    val w = model.words
    var open by remember { mutableStateOf(false) }
    val rel = when (x.status) {
        "overdue" -> model.t("w.ended", mapOf("rel" to w.rel(x.days)))
        "today" -> model.t("w.today")
        else -> model.t("w.ends", mapOf("rel" to w.rel(x.days)))
    }
    Row(Modifier.fillMaxWidth().clickable { open = true }.padding(horizontal = 14.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(p.tint(x.status).copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
            Ico("seal", p.tint(x.status), 20.dp)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(x.w.name, style = body(15, FontWeight.SemiBold), color = p.ink)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(rel, style = body(13, FontWeight.SemiBold), color = p.tint(x.status), maxLines = 1)
                Text(w.date(x.end, model.today), style = body(13), color = p.ink3, maxLines = 1)
            }
            if (!x.w.store.isNullOrBlank()) Text(x.w.store, style = body(12), color = p.ink2, maxLines = 1)
        }
        if (x.w.receipt != null) Ico("receipt", p.ink3, 18.dp)
    }
    if (open) WarrantySheet(model, x.w) { open = false }
}

@Composable
fun WarrantySheet(model: AppModel, existing: Warranty?, onClose: () -> Unit) {
    val p = pal()
    val w = model.words
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var store by remember { mutableStateOf(existing?.store ?: "") }
    var bought by remember { mutableStateOf(Day.parse(existing?.bought) ?: model.today) }
    var months by remember { mutableStateOf(existing?.months ?: 24) }
    var photo by remember { mutableStateOf<ByteArray?>(null) }
    var confirm by remember { mutableStateOf(false) }
    val shown = remember(photo, existing?.receipt) { photo?.let { model.bitmap(it) } ?: existing?.receipt?.let { model.receiptBitmap(it) } }
    val shot = remember { model.cameraUri() }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok) photo = model.compressImage(shot) ?: run { model.say("err.photo"); null }
    }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) photo = model.compressImage(uri) ?: run { model.say("err.photo"); null }
    }
    Sheet(model, existing?.name ?: model.t("act.add_warranty"), onClose) {
        FieldLabel(model.t("w.name"))
        Input(name, { name = it }, model.t("w.name_ph"))
        FieldLabel(model.t("w.store"))
        Input(store, { store = it }, "")
        DayPicker(model.t("w.bought"), bought) { bought = it }
        FieldLabel(model.t("w.months"))
        Seg(listOf(12, 24, 36, 60).map { it.toString() to w.monthCount(it) }, months.toString()) { months = it.toInt() }
        FieldLabel(model.t("w.receipt"))
        if (shown != null) {
            Image(shown, null, contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(14.dp)).border(1.dp, p.line, RoundedCornerShape(14.dp)))
            Spacer(Modifier.height(8.dp))
        }
        ButtonPair(if (shown != null) model.t("w.receipt_change") else model.t("w.receipt_add"), {
            runCatching { camera.launch(shot) }.onFailure { model.say("err.photo") }
        }, model.t("w.receipt_pick"), {
            gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
        })
        Spacer(Modifier.height(18.dp))
        WideButton(model.t("act.save")) {
            if (name.isBlank()) { model.say("err.title"); return@WideButton }
            model.saveWarranty(existing, name.trim(), store.trim(), bought, months, photo)
            onClose()
        }
        if (existing != null) {
            Spacer(Modifier.height(8.dp))
            WideButton(model.t("act.delete"), primary = false, danger = true, icon = "trash") { confirm = true }
        }
    }
    if (confirm && existing != null) {
        ConfirmDialog(model.t("confirm.warranty"), model.t("act.delete"), model.t("act.cancel"), { model.deleteWarranty(existing); onClose() }) { confirm = false }
    }
}

// ---------------------------------------------------------------- technicians

@Composable
fun TechsScreen(model: AppModel) {
    val s = model.state ?: AppState()
    var adding by remember { mutableStateOf(false) }
    Page {
        PageHead(model.t("more.techs")) { model.page = null }
        Lede(model.t("tech.lede"))
        if (s.techs.isEmpty()) EmptyNote("wrench", model.t("empty.techs"))
        for (tr in model.catalog.trades) {
            val list = s.techs.filter { it.trade == tr.id }
            if (list.isEmpty()) continue
            SmallHead(tr.name(model.lang))
            ListCard {
                list.forEachIndexed { i, x ->
                    if (i > 0) HorizontalDivider(color = pal().line)
                    key(x.id) { TechRow(model, x) }
                }
            }
        }
        Spacer(Modifier.height(14.dp))
        WideButton(model.t("act.add_tech"), icon = "plus") { adding = true }
    }
    if (adding) TechSheet(model, null, "ac") { adding = false }
}

@Composable
fun TechRow(model: AppModel, x: Tech) {
    val p = pal()
    var open by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp)) {
        Row(Modifier.fillMaxWidth().clickable { open = true }, verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(42.dp).clip(RoundedCornerShape(13.dp)).background(p.ink.copy(alpha = 0.06f)), contentAlignment = Alignment.Center) { Ico("wrench", p.ink, 20.dp) }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(x.name, style = body(15, FontWeight.SemiBold), color = p.ink)
                Text("\u2066${x.phone}\u2069", style = body(13), color = p.ink3)
                if (!x.note.isNullOrBlank()) Text(x.note, style = body(12), color = p.ink2)
            }
            Chevron(p.ink3)
        }
        Spacer(Modifier.height(10.dp))
        TechButtons(model, x)
    }
    if (open) TechSheet(model, x, x.trade) { open = false }
}

@Composable
fun TechButtons(model: AppModel, x: Tech) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        WideButton(model.t("tech.call"), primary = false, icon = "phone", modifier = Modifier.weight(1f)) { model.dial(x.phone) }
        WideButton(model.t("tech.whatsapp"), primary = false, icon = "chat", modifier = Modifier.weight(1f)) { model.whatsapp(x.phone) }
    }
}

@Composable
fun TechSheet(model: AppModel, existing: Tech?, trade0: String, onClose: () -> Unit) {
    var name by remember { mutableStateOf(existing?.name ?: "") }
    var trade by remember { mutableStateOf(existing?.trade ?: trade0) }
    var phone by remember { mutableStateOf(existing?.phone ?: "") }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    var confirm by remember { mutableStateOf(false) }
    Sheet(model, existing?.name ?: model.t("act.add_tech"), onClose) {
        FieldLabel(model.t("tech.name"))
        Input(name, { name = it }, "")
        FieldLabel(model.t("tech.trade"))
        ChoiceGrid(model.catalog.trades, 3, { it.id == trade }, { it.name(model.lang) }) { trade = it.id }
        FieldLabel(model.t("tech.phone"))
        Input(phone, { phone = it }, "+" + (Brain.countries[model.state?.settings?.country ?: "KW"]?.first ?: "965"), phone = true)
        FieldLabel(model.t("tech.note"))
        Input(note, { note = it }, "")
        Spacer(Modifier.height(18.dp))
        WideButton(model.t("act.save")) {
            if (name.isBlank()) { model.say("err.title"); return@WideButton }
            model.update("toast.saved") { b ->
                val t = Tech(existing?.id ?: newID(), name.trim(), trade, phone.trim(), note.trim().ifEmpty { null })
                b.state = b.state.copy(techs = if (existing != null) b.state.techs.map { if (it.id == existing.id) t else it } else b.state.techs + t)
            }
            onClose()
        }
        if (existing != null) {
            Spacer(Modifier.height(8.dp))
            WideButton(model.t("act.delete"), primary = false, danger = true, icon = "trash") { confirm = true }
        }
    }
    if (confirm && existing != null) {
        ConfirmDialog(model.t("confirm.tech"), model.t("act.delete"), model.t("act.cancel"), {
            model.update("toast.deleted") { b -> b.state = b.state.copy(techs = b.state.techs.filter { it.id != existing.id }) }
            onClose()
        }) { confirm = false }
    }
}

// ---------------------------------------------------------------- travel

@Composable
fun TravelScreen(model: AppModel) {
    val p = pal()
    val done = (model.state?.travelDone ?: emptyList()).toSet()
    val list = model.catalog.travel
    Page {
        PageHead(model.t("more.travel")) { model.page = null }
        Lede(model.t("travel.lede"))
        Text(model.t("travel.progress", mapOf("n" to done.size.toString(), "of" to list.size.toString())), style = body(14, FontWeight.Bold), color = p.ok,
            modifier = Modifier.padding(vertical = 8.dp))
        ListCard {
            list.forEachIndexed { i, x ->
                if (i > 0) HorizontalDivider(color = p.line)
                val on = done.contains(x.id)
                Row(Modifier.fillMaxWidth().clickable(role = Role.Checkbox) {
                    model.update { b -> b.state = b.state.copy(travelDone = if (on) b.state.travelDone - x.id else b.state.travelDone + x.id) }
                }.padding(horizontal = 16.dp, vertical = 13.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(26.dp).clip(RoundedCornerShape(8.dp)).background(if (on) p.ok else Color.Transparent).border(1.6.dp, if (on) p.ok else p.line, RoundedCornerShape(8.dp)),
                        contentAlignment = Alignment.Center) { if (on) Ico("done", p.onInk, 16.dp) }
                    Spacer(Modifier.width(12.dp))
                    Text(x.name(model.lang), style = body(15), color = if (on) p.ink3 else p.ink, textDecoration = if (on) TextDecoration.LineThrough else null)
                }
            }
        }
        Spacer(Modifier.height(14.dp))
        WideButton(model.t("travel.reset"), primary = false, icon = "repeat") { model.update { b -> b.state = b.state.copy(travelDone = emptyList()) } }
    }
}

// ---------------------------------------------------------------- spend

@Composable
fun SpendScreen(model: AppModel) {
    val p = pal()
    val w = model.words
    val thisYear = model.today.ymd.first
    var year by remember { mutableStateOf(thisYear) }
    val r = model.brain().spend(year, model.lang)
    Page {
        PageHead(model.t("more.spend")) { model.page = null }
        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            WideButton((year - 1).toString(), primary = false, modifier = Modifier.weight(1f)) { year-- }
            Text(year.toString(), style = title(24), color = p.ink, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
            if (year < thisYear) WideButton((year + 1).toString(), primary = false, modifier = Modifier.weight(1f)) { year++ } else Spacer(Modifier.weight(1f))
        }
        if (r.blocks.isEmpty()) EmptyNote("wallet", model.t("empty.spend"))
        for (b in r.blocks) {
            Spacer(Modifier.height(8.dp))
            CardBox {
                Text(model.t("spend.total", mapOf("year" to year.toString())), style = body(13, FontWeight.SemiBold), color = p.ink3)
                Text(w.money(b.total, b.currency), style = title(38), color = p.ink)
                if (year == thisYear) Text(model.t("spend.projected", mapOf("amount" to w.money(b.projected + b.home + b.car + b.things, b.currency))), style = body(14), color = p.ink2)
                Spacer(Modifier.height(10.dp))
                val max = maxOf(b.home, b.car, b.things, b.subs, 1)
                for ((key, icon, v) in listOfNotNull(Triple("home", "home", b.home), Triple("car", "car", b.car), if (b.things > 0) Triple("things", "box", b.things) else null, Triple("subs", "repeat", b.subs))) {
                    Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Ico(icon, p.ink2, 18.dp)
                        Spacer(Modifier.width(8.dp))
                        Text(model.t("spend.$key"), style = body(14, FontWeight.SemiBold), color = p.ink, modifier = Modifier.weight(1f))
                        Text(w.money(v, b.currency), style = body(14, FontWeight.Bold), color = p.ink)
                    }
                    Box(Modifier.padding(top = 5.dp).fillMaxWidth().height(7.dp).clip(CircleShape).background(p.ink.copy(alpha = 0.08f))) {
                        Box(Modifier.fillMaxWidth(v.toFloat() / max).fillMaxHeight().clip(CircleShape).background(p.ok))
                    }
                }
            }
        }
        Lede(model.t("spend.note"), small = true)
        if (r.logs.isNotEmpty()) {
            SmallHead(model.t("spend.logged"))
            ListCard {
                r.logs.forEachIndexed { i, l ->
                    if (i > 0) HorizontalDivider(color = p.line)
                    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(l.title, style = body(15, FontWeight.SemiBold), color = p.ink)
                            Text(listOfNotNull(w.date(l.date, model.today), l.asset).joinToString("  "), style = body(13), color = p.ink3)
                        }
                        Text(w.money(l.cost, l.currency), style = body(14, FontWeight.Bold), color = p.ink)
                    }
                }
            }
        }
    }
}
