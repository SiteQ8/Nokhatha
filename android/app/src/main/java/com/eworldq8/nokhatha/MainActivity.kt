// نُوخذة on Android: the app model, reminders scheduled on the phone itself, and the root screen.
package com.eworldq8.nokhatha

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalView
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.eworldq8.nokhatha.engine.*
import com.eworldq8.nokhatha.ui.*
import kotlinx.coroutines.delay
import org.json.JSONObject
import java.io.File
import java.util.Calendar
import java.util.Locale

data class Toast(val text: String, val undo: AppState?, val id: Long = System.nanoTime())

data class WxCache(val at: Long, val lat: Double, val lon: Double, val sum: Weather.Summary) {
    fun save(prefs: android.content.SharedPreferences) {
        prefs.edit().putString("cache", JSONObject().put("at", at).put("lat", lat).put("lon", lon).put("sum", Weather.toJson(sum)).toString()).apply()
    }

    companion object {
        fun load(prefs: android.content.SharedPreferences): WxCache? = runCatching {
            val o = JSONObject(prefs.getString("cache", null) ?: return null)
            WxCache(o.getLong("at"), o.getDouble("lat"), o.getDouble("lon"), Weather.fromJson(o.getJSONObject("sum")))
        }.getOrNull()
    }
}

sealed class Onboarding {
    object Setup : Onboarding()
    data class Last(val created: List<String>) : Onboarding()
}

class AppModel(private val ctx: Context, intent: Intent?) {
    val catalog = Catalog.load { name -> ctx.assets.open(name).bufferedReader().use { it.readText() } }
    var state by mutableStateOf<AppState?>(null)
    var today by mutableStateOf(Day.today())
    var toast by mutableStateOf<Toast?>(null)
    var tab by mutableStateOf("today")
    var onboarding by mutableStateOf<Onboarding?>(null)
    /** The page open from More: things, warranties, techs, travel, spend, settings or about. */
    var page by mutableStateOf<String?>(null)
    /** A sheet to open on launch, for the screenshot run: task, sub, addtask, edit, odo. */
    var autoSheet by mutableStateOf<String?>(null)
    private val file = File(ctx.filesDir, "nokhatha.json")
    private val receipts = File(ctx.filesDir, "receipts")
    private val wxPrefs = ctx.getSharedPreferences("weather", Context.MODE_PRIVATE)
    /** The last weather fetched for the chosen area, kept for three hours. */
    var wx by mutableStateOf(WxCache.load(wxPrefs))
    private var wxBusy = false

    init {
        val lang0 = intent?.getStringExtra("lang")
        tab = intent?.getStringExtra("tab") ?: "today"
        page = intent?.getStringExtra("page")
        autoSheet = intent?.getStringExtra("sheet")
        when {
            intent?.getStringExtra("screen") == "setup" -> {
                state = AppState(settings = Settings(lang = lang0 ?: deviceLang))
                onboarding = Onboarding.Setup
            }
            intent?.getBooleanExtra("sample", false) == true -> state = Brain.sample(catalog, lang0 ?: deviceLang, today)
            file.exists() -> state = runCatching { AppState.fromJson(JSONObject(file.readText())) }.getOrNull()
            lang0 != null -> state = AppState(settings = Settings(lang = lang0))
        }
    }

    val lang: String get() = state?.settings?.lang ?: deviceLang
    val isArabic get() = lang == "ar"
    val country: String get() = state?.settings?.country ?: "KW"
    val words get() = Words(catalog.strings, lang)
    fun brain() = Brain(catalog, state ?: AppState(settings = Settings(lang = lang)), today)
    fun t(key: String, vars: Map<String, String> = emptyMap()) = words.t(key, vars)

    fun refreshDay() { Day.today().let { if (it != today) today = it } }

    fun save() {
        val s = state ?: return
        runCatching { file.writeText(s.toJson().toString()) }
        Reminders.schedule(ctx)
        runCatching { NokhathaWidget.refresh(ctx) }
    }

    fun update(toastKey: String? = null, vars: Map<String, String> = emptyMap(), f: (Brain) -> Unit) {
        val before = state
        val b = brain()
        f(b)
        state = b.state
        save()
        if (toastKey != null) toast = Toast(t(toastKey, vars), before)
    }

    fun say(key: String) { toast = Toast(t(key), null) }

    fun done(e: Evaluated) = update("toast.done", mapOf("title" to e.title(lang))) { it.markDone(e.item.id) }
    fun snooze(e: Evaluated) = update("toast.snoozed", mapOf("date" to words.date(today.plus(7), today))) { it.snooze(e.item.id) }
    fun renew(e: Evaluated) = update("toast.saved") { it.renew(e.item.id) }

    fun undo() {
        val before = toast?.undo ?: return
        state = before
        toast = null
        save()
    }

    fun setLang(l: String) {
        state = (state ?: AppState()).let { it.copy(settings = it.settings.copy(lang = l)) }
        save()
    }

    fun beginSetup() {
        if (state == null) state = AppState(settings = Settings(lang = lang))
        onboarding = Onboarding.Setup
    }

    fun runSetup(s: Brain.Setup) {
        val b = brain()
        val created = b.setUp(s, t("type." + s.homeType), t("car.default")) { type -> catalog.thingTypes.firstOrNull { it.id == type }?.name(lang) ?: type }
        state = b.state
        onboarding = Onboarding.Last(created)
    }

    fun finishSetup(created: List<String>, answers: Map<String, String>) {
        update { it.finishSetUp(created, answers) }
        onboarding = null
    }

    fun startWithSample() {
        state = Brain.sample(catalog, lang, today)
        onboarding = null
        save()
    }

    fun eraseAll() {
        file.delete()
        receipts.deleteRecursively()
        runCatching { NokhathaWidget.refresh(ctx) }
        state = null
        onboarding = null
        page = null
        tab = "today"
        Reminders.schedule(ctx)
    }

    // ---------------------------------------------------------------- receipts

    fun receiptBitmap(id: String): ImageBitmap? = runCatching { File(receipts, id).readBytes() }.getOrNull()?.let { bitmap(it) }

    fun bitmap(bytes: ByteArray): ImageBitmap? = runCatching { BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap() }.getOrNull()

    /** A photo from the camera or the gallery, scaled to 1600 pixels at most and saved as JPEG, as the web app does. */
    fun compressImage(uri: Uri): ByteArray? = runCatching {
        val r = ctx.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        r.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 1600) sample *= 2
        val raw = r.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) } ?: return null
        val scale = minOf(1f, 1600f / maxOf(raw.width, raw.height))
        val bmp = if (scale < 1f) Bitmap.createScaledBitmap(raw, (raw.width * scale).toInt(), (raw.height * scale).toInt(), true) else raw
        java.io.ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.JPEG, 82, it) }.toByteArray()
    }.getOrNull()

    /** Where the camera writes a receipt photo, shared through the app's file provider. */
    fun cameraUri(): Uri {
        val dir = File(ctx.cacheDir, "camera").apply { mkdirs() }
        return FileProvider.getUriForFile(ctx, ctx.packageName + ".files", File(dir, "receipt.jpg"))
    }

    fun saveWarranty(existing: Warranty?, name: String, store: String, bought: Day, months: Int, photo: ByteArray?) {
        var rid = existing?.receipt
        if (photo != null) {
            val id = rid ?: newID()
            if (runCatching { receipts.mkdirs(); File(receipts, id).writeBytes(photo) }.isSuccess) rid = id else say("err.photo")
        }
        update("toast.saved") { b ->
            val w = Warranty(existing?.id ?: newID(), name, store.ifEmpty { null }, bought.iso, months, rid)
            b.state = b.state.copy(warranties = if (existing != null) b.state.warranties.map { if (it.id == existing.id) w else it } else b.state.warranties + w)
        }
    }

    fun deleteWarranty(w: Warranty) {
        w.receipt?.let { File(receipts, it).delete() }
        update("toast.deleted") { b -> b.state = b.state.copy(warranties = b.state.warranties.filter { it.id != w.id }) }
    }

    // ---------------------------------------------------------------- files

    fun exportIcs(uri: Uri) {
        val events = brain().calendarEvents(words)
        val ok = runCatching { ctx.contentResolver.openOutputStream(uri)?.use { it.write(toICS(events, utcStamp(), t("app.name")).toByteArray()) } }.isSuccess
        say(if (ok) "toast.ics" else "backup.failed")
    }

    suspend fun writeBackup(uri: Uri, pass: String): Boolean = withContext(Dispatchers.Default) {
        runCatching {
            val s = state ?: AppState()
            val rs = JSONObject()
            s.warranties.mapNotNull { it.receipt }.forEach { id ->
                runCatching { File(receipts, id).readBytes() }.getOrNull()?.let { rs.put(id, JSONObject().put("type", "image/jpeg").put("data", B64.encode(it))) }
            }
            val text = Backup.encrypt(JSONObject().put("state", s.toJson()).put("receipts", rs).toString(), pass)
            ctx.contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) } ?: error("no file")
        }.isSuccess
    }.also { ok ->
        if (ok) { state = state?.let { it.copy(settings = it.settings.copy(lastBackup = today.iso)) }; save() }
    }

    /** Null when the backup was restored, otherwise "pass" or "format". */
    suspend fun readBackup(uri: Uri, pass: String): String? {
        val result = withContext(Dispatchers.Default) {
            try {
                val text = ctx.contentResolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) } ?: return@withContext Pair<String?, JSONObject?>("format", null)
                Pair<String?, JSONObject?>(null, JSONObject(Backup.decrypt(text, pass)))
            } catch (e: BackupError) {
                Pair<String?, JSONObject?>(e.reason, null)
            } catch (e: Exception) {
                Pair<String?, JSONObject?>("format", null)
            }
        }
        val payload = result.second ?: return result.first
        val restored = runCatching { AppState.fromJson(payload.getJSONObject("state")) }.getOrNull() ?: return "format"
        receipts.deleteRecursively()
        receipts.mkdirs()
        payload.optJSONObject("receipts")?.let { rs ->
            for (id in rs.keys()) runCatching { File(receipts, id).writeBytes(B64.decode(rs.getJSONObject(id).getString("data"))) }
        }
        state = restored.copy(settings = restored.settings.copy(onboarded = true))
        onboarding = null
        save()
        return null
    }

    fun fileName(uri: Uri): String? = runCatching {
        ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    }.getOrNull()

    // ---------------------------------------------------------------- links

    private fun open(intent: Intent) {
        runCatching { ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }.onFailure { say("err.open") }
    }

    fun openUrl(url: String) = open(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    fun dial(phone: String) = open(Intent(Intent.ACTION_DIAL, Uri.parse("tel:+" + phoneDigits(phone, state?.settings?.country ?: "KW"))))
    fun whatsapp(phone: String) = open(Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/" + phoneDigits(phone, state?.settings?.country ?: "KW"))))

    val version: String get() = runCatching { ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName }.getOrNull() ?: "1.0"

    // ---------------------------------------------------------------- weather

    fun clock(millis: Long): String {
        val c = java.util.Calendar.getInstance().apply { timeInMillis = millis }
        val d = Day.of(c.get(java.util.Calendar.YEAR), c.get(java.util.Calendar.MONTH) + 1, c.get(java.util.Calendar.DAY_OF_MONTH))
        fun p(n: Int) = if (n < 10) "0$n" else n.toString()
        return "${words.date(d, today)} ${p(c.get(java.util.Calendar.HOUR_OF_DAY))}:${p(c.get(java.util.Calendar.MINUTE))}"
    }

    fun wxPlaces(): List<Place> = catalog.places.filter { it.country == (state?.settings?.country ?: "KW") }

    fun wxPlaceName(): String = state?.settings?.weather?.place?.let { id -> catalog.places.firstOrNull { it.id == id }?.name(lang) } ?: ""

    fun setWeatherPlace(id: String) {
        val p = catalog.places.firstOrNull { it.id == id } ?: return
        update { b -> b.state = b.state.copy(settings = b.state.settings.copy(weather = (b.state.settings.weather ?: WeatherSetting()).copy(place = id, lat = p.lat, lon = p.lon))) }
    }

    fun setWeather(on: Boolean) {
        val w = state?.settings?.weather
        if (on && (w?.place == null || w.lat == null)) wxPlaces().firstOrNull()?.let { setWeatherPlace(it.id) }
        update { b -> b.state = b.state.copy(settings = b.state.settings.copy(weather = (b.state.settings.weather ?: WeatherSetting()).copy(on = on))) }
    }

    /** Alerts for today and tomorrow when the weather is on and the cache is for the chosen area. */
    fun weatherAlerts(): List<Weather.Alert> {
        val w = state?.settings?.weather ?: return emptyList()
        val c = wx ?: return emptyList()
        if (!w.on || c.lat != w.lat || c.lon != w.lon) return emptyList()
        return Weather.alerts(c.sum, today)
    }

    val weatherShown: Boolean get() = state?.settings?.weather?.let { it.on && wx?.lat == it.lat && wx?.lon == it.lon } == true

    suspend fun refreshWeather(force: Boolean = false) {
        val w = state?.settings?.weather ?: return
        val lat = w.lat ?: return
        val lon = w.lon ?: return
        if (!w.on || wxBusy) return
        val c = wx
        if (!force && c != null && c.lat == lat && c.lon == lon && System.currentTimeMillis() - c.at < 3 * 3600_000L) return
        wxBusy = true
        try {
            val (fu, au) = Weather.urls(lat, lon)
            val sum = withContext(Dispatchers.IO) { Weather.summarize(JSONObject(fetchText(fu)), JSONObject(fetchText(au))) }
            wx = WxCache(System.currentTimeMillis(), lat, lon, sum).also { it.save(wxPrefs) }
        } catch (e: Exception) {
            if (force) say("wx.failed")
        } finally {
            wxBusy = false
        }
    }

    private fun fetchText(url: String): String {
        val c = java.net.URL(url).openConnection() as java.net.HttpURLConnection
        c.connectTimeout = 12_000
        c.readTimeout = 12_000
        c.setRequestProperty("Accept", "application/json")
        try {
            if (c.responseCode != 200) error("weather ${c.responseCode}")
            return c.inputStream.bufferedReader().use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    companion object {
        val deviceLang: String get() = if (Locale.getDefault().language == "ar") "ar" else "en"

        fun guessCountry(): String {
            val zones = mapOf("Asia/Kuwait" to "KW", "Asia/Riyadh" to "SA", "Asia/Dubai" to "AE", "Asia/Qatar" to "QA", "Asia/Bahrain" to "BH", "Asia/Muscat" to "OM")
            zones[java.util.TimeZone.getDefault().id]?.let { return it }
            val r = Locale.getDefault().country
            return if (Brain.countries.containsKey(r)) r else "KW"
        }
    }
}

/** Reminders scheduled on the phone itself: one check a day at 9:00, no server, nothing leaves the device. */
object Reminders {
    private const val CHANNEL = "due"

    fun schedule(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(ctx, 1, Intent(ctx, ReminderReceiver::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        am.cancel(pi)
        val on = runCatching { JSONObject(File(ctx.filesDir, "nokhatha.json").readText()).getJSONObject("settings").optBoolean("notify", false) }.getOrDefault(false)
        if (!on) return
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 9); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_MONTH, 1)
        }
        am.setInexactRepeating(AlarmManager.RTC_WAKEUP, next.timeInMillis, AlarmManager.INTERVAL_DAY, pi)
    }

    fun notifyDue(ctx: Context) {
        val f = File(ctx.filesDir, "nokhatha.json")
        if (!f.exists()) return
        val state = runCatching { AppState.fromJson(JSONObject(f.readText())) }.getOrNull() ?: return
        if (state.settings.notify != true) return
        val today = Day.today()
        val prefs = ctx.getSharedPreferences("reminders", Context.MODE_PRIVATE)
        if (prefs.getString("notified", null) == today.iso) return
        val catalog = Catalog.load { name -> ctx.assets.open(name).bufferedReader().use { it.readText() } }
        val brain = Brain(catalog, state, today)
        val words = Words(catalog.strings, state.settings.lang)
        val lines = ArrayList<String>()
        var late = false
        for (e in brain.tasks()) {
            val due = e.due ?: continue
            if (due > today) continue
            if (due < today) late = true
            lines += "${e.title(state.settings.lang)}${words.comma}${e.asset.name}"
        }
        for (s in brain.subs()) if (s.ask && s.days <= 2) lines += words.t("ask.q", mapOf("name" to s.sub.name))
        for (x in brain.docs()) if (x.days <= x.type.lead) {
            if (x.days < 0) late = true
            lines += words.t("ics.doc", mapOf("name" to brain.docTitle(x.d, state.settings.lang)))
        }
        state.settings.weather?.let { w ->
            val c = WxCache.load(ctx.getSharedPreferences("weather", Context.MODE_PRIVATE))
            if (w.on && c != null && c.lat == w.lat && c.lon == w.lon && System.currentTimeMillis() - c.at < 20 * 3600_000L) {
                Weather.alerts(c.sum, today).firstOrNull { it.day == 0 }?.let { a ->
                    lines += words.t("wx.${a.kind}", mapOf("day" to words.t("wx.day0"), "t" to (a.value?.toString() ?: "")))
                }
            }
        }
        if (lines.isEmpty()) return
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel(CHANNEL, ctx.getString(R.string.channel_due), NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(ctx, 2, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_IMMUTABLE)
        val text = lines.take(3).joinToString("\n") + if (lines.size > 3) "\n" + words.t("notify.more") else ""
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_notify)
            .setContentTitle(words.t(if (late) "notify.title_now" else "notify.title_today"))
            .setContentText(lines.first())
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(ctx).notify(1, n) }
        prefs.edit().putString("notified", today.iso).apply()
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.notifyDue(context)
        runCatching { NokhathaWidget.refresh(context) }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) { Reminders.schedule(context); runCatching { NokhathaWidget.refresh(context) } }
    }
}

class MainActivity : ComponentActivity() {
    private lateinit var model: AppModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        model = AppModel(applicationContext, intent)
        if (intent?.getBooleanExtra("widget", false) == true) {
            // the screenshot run: the widget drawn inside the app, with the sample saved so it has dates to show
            model.state?.let { s -> runCatching { java.io.File(applicationContext.filesDir, "nokhatha.json").writeText(s.toJson().toString()) } }
            val frame = android.widget.FrameLayout(this).apply { setBackgroundColor(android.graphics.Color.parseColor("#EEF1F4")); setPadding(40, 200, 40, 0) }
            val views = NokhathaWidget.render(applicationContext).apply(applicationContext, frame)
            frame.addView(views, android.widget.FrameLayout.LayoutParams(android.widget.FrameLayout.LayoutParams.MATCH_PARENT, 520))
            setContentView(frame)
            return
        }
        setContent { Root(model) }
    }

    override fun onResume() {
        super.onResume()
        if (::model.isInitialized) model.refreshDay()
    }
}

@Composable
fun Root(model: AppModel) {
    val dark = when (model.state?.settings?.theme) {
        "light" -> false
        "dark" -> true
        else -> androidx.compose.foundation.isSystemInDarkTheme()
    }
    val view = LocalView.current
    SideEffect {
        (view.context as? Activity)?.window?.let { WindowCompat.getInsetsController(it, view).apply { isAppearanceLightStatusBars = !dark; isAppearanceLightNavigationBars = !dark } }
    }
    CompositionLocalProvider(LocalDark provides dark) { RootBody(model) }
}

@Composable
fun RootBody(model: AppModel) {
    val p = pal()
    CompositionLocalProvider(LocalLayoutDirection provides if (model.isArabic) LayoutDirection.Rtl else LayoutDirection.Ltr) {
        MaterialTheme(colorScheme = if (LocalDark.current == true) darkColorScheme(primary = p.ink, surface = p.surface, background = p.bg)
            else lightColorScheme(primary = p.ink, surface = p.surface, background = p.bg)) {
            Box(Modifier.fillMaxSize().background(p.bg)) {
                val ob = model.onboarding
                when {
                    ob is Onboarding.Setup -> SetupScreen(model)
                    ob is Onboarding.Last -> LastTimeScreen(model, ob.created)
                    model.state?.settings?.onboarded == true -> Tabs(model)
                    else -> WelcomeScreen(model)
                }
                ToastBar(model, Modifier.align(Alignment.BottomCenter))
            }
        }
    }
}

@Composable
fun Tabs(model: AppModel) {
    val p = pal()
    BackHandler(enabled = model.page != null || model.tab != "today") { if (model.page != null) model.page = null else model.tab = "today" }
    Scaffold(
        containerColor = p.bg,
        topBar = { TopBar(model, season = model.tab != "today") },
        bottomBar = { TabBar(model) { model.page = null } },
    ) { pad ->
        Box(Modifier.padding(top = pad.calculateTopPadding()).fillMaxSize()) {
            when (model.tab) {
                "today" -> TodayScreen(model)
                "home" -> AssetsScreen(model, AssetKind.HOME)
                "car" -> AssetsScreen(model, AssetKind.CAR)
                "subs" -> SubsScreen(model)
                else -> when (model.page) {
                    "things" -> AssetsScreen(model, AssetKind.THING) { model.page = null }
                    "docs" -> DocsScreen(model)
                    "warranties" -> WarrantiesScreen(model)
                    "techs" -> TechsScreen(model)
                    "travel" -> TravelScreen(model)
                    "spend" -> SpendScreen(model)
                    "settings" -> SettingsScreen(model)
                    "about" -> AboutScreen(model)
                    else -> MoreScreen(model)
                }
            }
        }
    }
}

/** The web's tab bar: five equal columns, a 24px icon over an 11.5px label, a red dot over the one that is on. */
@Composable
fun TabBar(model: AppModel, onPick: () -> Unit) {
    val p = pal()
    Column(Modifier.fillMaxWidth().background(p.surface.copy(alpha = 0.96f))) {
        HorizontalDivider(color = p.line)
        Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 6.dp, vertical = 6.dp)) {
            for ((key, icon) in listOf("today" to "today", "home" to "home", "car" to "car", "subs" to "repeat", "more" to "more")) {
                val on = model.tab == key
                val label = model.t("tab.$key")
                Column(
                    Modifier.weight(1f).clip(RoundedCornerShape(12.dp))
                        .clickable(role = Role.Tab) { model.tab = key; onPick() }
                        .semantics { selected = on; contentDescription = label }
                        .padding(top = 9.dp, bottom = 5.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Box(contentAlignment = Alignment.TopCenter) {
                        Ico(icon, if (on) p.ink else p.ink3, 24.dp, Modifier.padding(top = 4.dp))
                        if (on) Box(Modifier.size(6.dp).clip(CircleShape).background(p.sadu).offset(y = (-7).dp))
                    }
                    FitText(label, body(11.5, FontWeight.SemiBold, 1.2), if (on) p.ink else p.ink3, Modifier.fillMaxWidth().padding(horizontal = 2.dp).clearAndSetSemantics { })
                }
            }
        }
    }
}

@Composable
fun FitText(text: String, style: TextStyle, color: Color, modifier: Modifier = Modifier) {
    val measurer = rememberTextMeasurer()
    BoxWithConstraints(modifier, contentAlignment = Alignment.Center) {
        val max = constraints.maxWidth
        val natural = remember(text, style) { measurer.measure(text, style, softWrap = false, maxLines = 1).size.width }
        val size = if (natural <= max || natural == 0) style.fontSize else (style.fontSize * (max.toFloat() / natural) * 0.98f).let { if (it.value < 8f) 8.sp else it }
        Text(text, style = style.copy(fontSize = size, lineHeight = size * 1.3f), color = color, maxLines = 1, softWrap = false, textAlign = TextAlign.Center)
    }
}

@Composable
fun ToastBar(model: AppModel, modifier: Modifier) {
    val p = pal()
    val toast = model.toast ?: return
    LaunchedEffect(toast.id) {
        delay(5000)
        if (model.toast?.id == toast.id) model.toast = null
    }
    Row(
        modifier.padding(start = 14.dp, end = 14.dp, bottom = 100.dp).fillMaxWidth().heightIn(min = 50.dp)
            .clip(RoundedCornerShape(16.dp)).background(p.ink).padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(toast.text, style = body(14, FontWeight.Medium), color = p.onInk, modifier = Modifier.weight(1f), maxLines = 1)
        if (toast.undo != null) {
            Text(model.t("act.undo"), style = body(14, FontWeight.Bold), color = p.soon, modifier = Modifier.clickable { model.undo() }.padding(8.dp))
        }
    }
}
