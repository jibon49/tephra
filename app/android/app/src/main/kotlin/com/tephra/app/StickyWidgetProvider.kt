package com.tephra.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class StickyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_sticky)
            val rawJson = widgetData.getString("sticky_widget_$appWidgetId", null)
            WidgetRender.renderSingleSticky(context, views, appWidgetId, rawJson)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val prefs = HomeWidgetPlugin.getData(context)
        val editor = prefs.edit()
        for (id in appWidgetIds) {
            editor.remove("sticky_widget_$id")
        }
        editor.apply()
    }
}
