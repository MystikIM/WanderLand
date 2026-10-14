package com.mystikim.plural_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FrontWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.front_widget).apply {
                setTextViewText(
                    R.id.front_text,
                    widgetData.getString("front_text", "Open to set who is out")
                )
                val pending = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("plural://switch")
                )
                setOnClickPendingIntent(R.id.front_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
