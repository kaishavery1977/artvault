package com.artvault.artvault

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

class PaintingWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.painting_widget)

            val prefs: SharedPreferences = context.getSharedPreferences(
                "HomeWidgetPreferences", Context.MODE_PRIVATE
            )

            val title = prefs.getString("painting_title", "ArtVault") ?: "ArtVault"
            val artist = prefs.getString("painting_artist", "") ?: ""

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_artist, artist)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
