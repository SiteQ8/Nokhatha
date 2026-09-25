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
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
    private val file = File(ctx.filesDir, "nokhatha.json")

    init {
        val lang0 = intent?.getStringExtra("lang")
        tab = intent?.getStringExtra("tab") ?: "today"
        when {
            intent?.getStringExtra("screen") == "setup" -> {
                state = AppState(settings = Settings(lang = lang0 ?: deviceLang))
                onboarding = Onboarding.Setup
            }
            intent?.getBooleanExtra("sample", false) == true -> state = Brain.sample(catalog, lang0 ?: deviceLang, today)
            file.exists() -> state = runCatching { AppState.fromJson(JSONObject(file.readText())) }.getOrNull()
        }
    }

    val lang: String get() = state?.settings?.lang ?: deviceLang
    val isArabic get() = lang == "ar"
    val words get() = Words(catalog.strings, lang)
    fun brain() = Brain(catalog, state ?: AppState(settings = Settings(lang = lang)), today)
    fun t(key: String, vars: Map<String, String> = emptyMap()) = words.t(key, vars)

    fun refreshDay() { Day.today().let { if (it != today) today = it } }

    fun save() {
        val s = state ?: return
        runCatching { file.writeText(s.toJson().toString()) }
        Reminders.schedule(ctx)
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
        save()
    }

    fun eraseAll() {
        file.delete()
        state = null
        onboarding = null
        Reminders.schedule(ctx)
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
    override fun onReceive(context: Context, intent: Intent) = Reminders.notifyDue(context)
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Reminders.schedule(context)
    }
}

class MainActivity : ComponentActivity() {
    private lateinit var model: AppModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        model = AppModel(applicationContext, intent)
        setContent { Root(model) }
    }

    override fun onResume() {
        super.onResume()
        if (::model.isInitialized) model.refreshDay()
    }
}

@Composable
fun Root(model: AppModel) {
    val p = pal()
    CompositionLocalProvider(LocalLayoutDirection provides if (model.isArabic) LayoutDirection.Rtl else LayoutDirection.Ltr) {
        MaterialTheme(colorScheme = if (androidx.compose.foundation.isSystemInDarkTheme()) darkColorScheme(primary = p.ink, surface = p.surface, background = p.bg)
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
    var sub by remember { mutableStateOf<String?>(null) }
    BackHandler(enabled = sub != null || model.tab != "today") { if (sub != null) sub = null else model.tab = "today" }
    Scaffold(
        containerColor = p.bg,
        bottomBar = {
            NavigationBar(containerColor = p.surface) {
                for ((key, icon) in listOf("today" to "today", "home" to "home", "car" to "car", "subs" to "repeat", "more" to "more")) {
                    NavigationBarItem(
                        selected = model.tab == key,
                        onClick = { model.tab = key; sub = null },
                        icon = { Ico(icon, if (model.tab == key) p.ink else p.ink3, 24.dp) },
                        label = { Text(model.t("tab.$key"), style = body(12, if (model.tab == key) FontWeight.Bold else FontWeight.Normal)) },
                        colors = NavigationBarItemDefaults.colors(indicatorColor = p.ink.copy(alpha = 0.08f), selectedTextColor = p.ink, unselectedTextColor = p.ink3),
                    )
                }
            }
        },
    ) { pad ->
        Box(Modifier.padding(pad).fillMaxSize()) {
            when {
                model.tab == "more" && sub == "things" -> AssetsScreen(model, AssetKind.THING)
                model.tab == "today" -> TodayScreen(model)
                model.tab == "home" -> AssetsScreen(model, AssetKind.HOME)
                model.tab == "car" -> AssetsScreen(model, AssetKind.CAR)
                model.tab == "subs" -> SubsScreen(model)
                else -> MoreScreen(model) { sub = it }
            }
        }
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
        modifier.padding(start = 14.dp, end = 14.dp, bottom = 96.dp).fillMaxWidth().height(50.dp)
            .clip(RoundedCornerShape(16.dp)).background(p.ink).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(toast.text, style = body(14, FontWeight.Medium), color = p.onInk, modifier = Modifier.weight(1f), maxLines = 1)
        if (toast.undo != null) {
            Text(model.t("act.undo"), style = body(14, FontWeight.Bold), color = p.soon, modifier = Modifier.clickable { model.undo() }.padding(8.dp))
        }
    }
}
