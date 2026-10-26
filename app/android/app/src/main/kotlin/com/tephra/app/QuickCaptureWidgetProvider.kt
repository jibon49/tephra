package com.tephra.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class QuickCaptureWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_capture)

            val captureIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tephra://capture")
            )
            views.setOnClickPendingIntent(R.id.root, captureIntent)
            views.setOnClickPendingIntent(R.id.quick_capture_bar, captureIntent)

            val dailyIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tephra://daily")
            )
            views.setOnClickPendingIntent(R.id.btn_today, dailyIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
