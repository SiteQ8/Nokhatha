// Weather alerts, the one thing the app fetches from outside the device, and only when the person
// turns it on: dust, rain, wind, heat and cold for the area they chose, from Open-Meteo. The
// same thresholds as docs/app/weather.js, so the web and the phone warn on the same days.
package com.eworldq8.nokhatha.engine

import org.json.JSONArray
import org.json.JSONObject

object Weather {
    const val FORECAST = "https://api.open-meteo.com/v1/forecast"
    const val AIR = "https://air-quality-api.open-meteo.com/v1/air-quality"
    const val DUST_FLOOR = 150.0 // never call a day dusty below this PM10 daily maximum
    const val RAIN_MM = 0.5
    const val RAIN_CHANCE = 50.0
    const val HEAT = 48.0
    const val COLD = 4.0
    const val GUST = 60.0
    private val order = listOf("dust_heavy", "rain", "wind", "dust", "heat", "cold")

    data class DayWx(val date: String, val tmax: Double?, val tmin: Double?, val rain: Double?, val chance: Double?, val gust: Double?, val dust: Int?)
    data class Summary(val days: List<DayWx>, val dusty: Int, val heavy: Int, val history: Int)
    data class Alert(val kind: String, val day: Int, val value: Int? = null)

    fun urls(lat: Double, lon: Double): Pair<String, String> {
        val at = "latitude=${num(lat)}&longitude=${num(lon)}&timezone=auto"
        return Pair(
            "$FORECAST?$at&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_gusts_10m_max&forecast_days=3",
            "$AIR?$at&hourly=pm10&past_days=60&forecast_days=3",
        )
    }

    /** Numbers as JavaScript prints them: 29.4 stays 29.4 and 48.0 becomes 48. */
    private fun num(v: Double): String = if (v == Math.floor(v) && !v.isInfinite()) v.toLong().toString() else v.toString()

    private fun percentile(sorted: List<Double>, f: Double): Double? =
        if (sorted.isEmpty()) null else sorted[minOf(sorted.size - 1, Math.floor(f * (sorted.size - 1)).toInt())]

    private fun JSONArray?.num(i: Int): Double? = if (this == null || i >= length() || isNull(i)) null else optDouble(i)

    /** The daily maximum PM10 per day, the forecast days, and the dust thresholds from the last 60 days. */
    fun summarize(forecast: JSONObject?, air: JSONObject?): Summary {
        val dust = LinkedHashMap<String, Double>()
        val hourly = air?.optJSONObject("hourly")
        val times = hourly?.optJSONArray("time")
        val pm10 = hourly?.optJSONArray("pm10")
        if (times != null) for (i in 0 until times.length()) {
            val v = pm10.num(i) ?: continue
            val day = times.getString(i).take(10)
            dust[day] = maxOf(dust[day] ?: 0.0, v)
        }
        val f = forecast?.optJSONObject("daily")
        val dates = f?.optJSONArray("time")
        val days = ArrayList<DayWx>()
        if (dates != null) for (i in 0 until dates.length()) {
            val date = dates.getString(i)
            days += DayWx(date, f.optJSONArray("temperature_2m_max").num(i), f.optJSONArray("temperature_2m_min").num(i),
                f.optJSONArray("precipitation_sum").num(i), f.optJSONArray("precipitation_probability_max").num(i),
                f.optJSONArray("wind_gusts_10m_max").num(i), dust[date]?.let { Math.round(it).toInt() })
        }
        val first = days.firstOrNull()?.date ?: "9999-12-31"
        val history = dust.filterKeys { it < first }.values.sorted()
        val p90 = percentile(history, 0.9)
        val p97 = percentile(history, 0.97)
        val dusty = maxOf(DUST_FLOOR, p90 ?: Double.POSITIVE_INFINITY)
        val heavy = maxOf(dusty * 1.25, p97 ?: Double.POSITIVE_INFINITY)
        return Summary(days, roundOrMax(dusty), roundOrMax(heavy), history.size)
    }

    private fun roundOrMax(v: Double) = if (v.isInfinite()) Int.MAX_VALUE else Math.round(v).toInt()

    /** Alerts for today and tomorrow, most serious first. */
    fun alerts(s: Summary?, today: Day): List<Alert> {
        if (s == null) return emptyList()
        val out = ArrayList<Alert>()
        for ((dayIndex, date) in listOf(0 to today.iso, 1 to today.plus(1).iso)) {
            val d = s.days.firstOrNull { it.date == date } ?: continue
            if (d.dust != null && s.history >= 20) {
                if (d.dust >= s.heavy) out += Alert("dust_heavy", dayIndex)
                else if (d.dust >= s.dusty) out += Alert("dust", dayIndex)
            }
            if ((d.rain != null && d.rain >= RAIN_MM) || (d.chance != null && d.chance >= RAIN_CHANCE)) out += Alert("rain", dayIndex)
            if (d.gust != null && d.gust >= GUST) out += Alert("wind", dayIndex)
            if (d.tmax != null && d.tmax >= HEAT) out += Alert("heat", dayIndex, Math.round(d.tmax).toInt())
            if (d.tmin != null && d.tmin <= COLD) out += Alert("cold", dayIndex, Math.round(d.tmin).toInt())
        }
        return out.sortedWith(compareBy<Alert> { it.day }.thenBy { order.indexOf(it.kind) })
    }

    // The summary is cached on the device as JSON, so alerts can be shown without the network.

    fun toJson(s: Summary): JSONObject = JSONObject().put("dusty", s.dusty).put("heavy", s.heavy).put("history", s.history)
        .put("days", JSONArray(s.days.map { d ->
            JSONObject().put("date", d.date).put("tmax", d.tmax ?: JSONObject.NULL).put("tmin", d.tmin ?: JSONObject.NULL).put("rain", d.rain ?: JSONObject.NULL)
                .put("chance", d.chance ?: JSONObject.NULL).put("gust", d.gust ?: JSONObject.NULL).put("dust", d.dust ?: JSONObject.NULL)
        }))

    fun fromJson(o: JSONObject): Summary {
        fun JSONObject.d(k: String): Double? = if (has(k) && !isNull(k)) getDouble(k) else null
        val days = o.optJSONArray("days") ?: JSONArray()
        return Summary((0 until days.length()).map { i ->
            val d = days.getJSONObject(i)
            DayWx(d.getString("date"), d.d("tmax"), d.d("tmin"), d.d("rain"), d.d("chance"), d.d("gust"), d.d("dust")?.toInt())
        }, o.getInt("dusty"), o.getInt("heavy"), o.getInt("history"))
    }

    val icons = mapOf("dust" to "dust", "dust_heavy" to "dust", "rain" to "rain", "wind" to "air", "heat" to "thermo", "cold" to "snow")
}

/** The weather setting, part of settings.weather in the shared JSON. */
data class WeatherSetting(val on: Boolean = false, val place: String? = null, val lat: Double? = null, val lon: Double? = null) {
    fun toJson(): JSONObject = JSONObject().put("on", on).apply {
        if (place != null) put("place", place)
        if (lat != null) put("lat", lat)
        if (lon != null) put("lon", lon)
    }

    companion object {
        fun fromJson(o: JSONObject?): WeatherSetting? = o?.let {
            WeatherSetting(it.optBoolean("on", false), if (it.has("place") && !it.isNull("place")) it.getString("place") else null,
                if (it.has("lat") && !it.isNull("lat")) it.getDouble("lat") else null, if (it.has("lon") && !it.isNull("lon")) it.getDouble("lon") else null)
        }
    }
}
