// The home screen widget: the season and the next few dates, drawn from the same saved state the app
// reads, refreshed whenever the app saves and every morning with the reminders.
package com.eworldq8.nokhatha

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.eworldq8.nokhatha.engine.*
import org.json.JSONObject
import java.io.File

class NokhathaWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, render(context))
    }

    companion object {
        /** Redraws every placed widget. */
        fun refresh(ctx: Context) {
            val manager = AppWidgetManager.getInstance(ctx) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(ctx, NokhathaWidget::class.java))
            if (ids.isEmpty()) return
            val views = render(ctx)
            for (id in ids) manager.updateAppWidget(id, views)
        }

        fun render(ctx: Context): RemoteViews {
            val state = runCatching { AppState.fromJson(JSONObject(File(ctx.filesDir, "nokhatha.json").readText())) }.getOrNull()
            val lang = state?.settings?.lang ?: AppModel.deviceLang
            // the widget reads in the app's language, whatever the phone's
            val rtl = lang == "ar"
            val v = RemoteViews(ctx.packageName, if (rtl) R.layout.widget_rtl else R.layout.widget)
            val catalog = Catalog.load { name -> ctx.assets.open(name).bufferedReader().use { it.readText() } }
            val w = Words(catalog.strings, lang)
            val today = Day.today()
            val season = seasonAt(today, catalog.seasons)
            v.setTextViewText(R.id.brand, w.t("app.name"))
            v.setTextViewText(R.id.season, catalog.season(season.id)?.name(lang) ?: "")
            v.setTextViewText(R.id.left, w.t("dial.left", mapOf("n" to w.dayCount(season.daysLeft), "next" to (catalog.season(season.nextId)?.name(lang) ?: ""))))
            v.removeAllViews(R.id.rows)
            val rows = if (state == null) emptyList() else Brain(catalog, state, today).tasks().filter { it.due != null }.take(3)
            for (e in rows) {
                val row = RemoteViews(ctx.packageName, if (rtl) R.layout.widget_row_rtl else R.layout.widget_row)
                row.setTextViewText(R.id.title, e.title(lang))
                row.setTextViewText(R.id.due, w.due(e, today).first)
                row.setTextColor(R.id.due, ContextCompat.getColor(ctx, when (e.status) {
                    "overdue" -> R.color.widget_overdue
                    "today", "soon" -> R.color.widget_soon
                    else -> R.color.widget_ok
                }))
                v.addView(R.id.rows, row)
            }
            v.setViewVisibility(R.id.empty, if (rows.isEmpty()) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.empty, w.t(if (state == null) "welcome.start" else "today.clear"))
            v.setOnClickPendingIntent(R.id.root, PendingIntent.getActivity(ctx, 3, Intent(ctx, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
            return v
        }
    }
}
