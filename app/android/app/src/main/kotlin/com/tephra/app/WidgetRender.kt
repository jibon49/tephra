package com.tephra.app

import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONObject

object WidgetRender {
    private val LINE_IDS = intArrayOf(
        R.id.line_0, R.id.line_1, R.id.line_2, R.id.line_3, R.id.line_4,
        R.id.line_5, R.id.line_6, R.id.line_7, R.id.line_8, R.id.line_9
    )

    private val ITEM_IDS = intArrayOf(
        R.id.item_0, R.id.item_1, R.id.item_2,
        R.id.item_3, R.id.item_4, R.id.item_5
    )

    private val ITEM_COLOR_IDS = intArrayOf(
        R.id.item_0_color, R.id.item_1_color, R.id.item_2_color,
        R.id.item_3_color, R.id.item_4_color, R.id.item_5_color
    )

    private val ITEM_TITLE_IDS = intArrayOf(
        R.id.item_0_title, R.id.item_1_title, R.id.item_2_title,
        R.id.item_3_title, R.id.item_4_title, R.id.item_5_title
    )

    private val ITEM_PREVIEW_IDS = intArrayOf(
        R.id.item_0_preview, R.id.item_1_preview, R.id.item_2_preview,
        R.id.item_3_preview, R.id.item_4_preview, R.id.item_5_preview
    )

    fun renderSingleSticky(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        rawJson: String?
    ) {
        if (rawJson == null) {
            renderUnconfigured(context, views, widgetId)
            return
        }

        try {
            val json = JSONObject(rawJson)
            val configured = json.optBoolean("configured", false)
            if (!configured) {
                renderUnconfigured(context, views, widgetId)
                return
            }

            val missing = json.optBoolean("missing", false)
            if (missing) {
                renderMissing(context, views, widgetId)
                return
            }

            val vaultId = json.optString("vaultId", "")
            val path = json.optString("path", "")
            val title = json.optString("title", "")
            val bg = json.optLong("bg", 0xFFFFF9C4L).toInt()
            val fg = json.optLong("fg", 0xFF1F1F1FL).toInt()
            val locked = json.optBoolean("locked", false)
            val hash = json.optString("hash", "")
            val more = json.optInt("more", 0)

            // Tint background
            views.setInt(R.id.bg, "setColorFilter", bg)

            // Title
            views.setTextViewText(R.id.title, title)
            views.setTextColor(R.id.title, fg)
            val openUri = Uri.parse("tephra://open?vault=${Uri.encode(vaultId)}&path=${Uri.encode(path)}")
            val openPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                openUri
            )
            views.setOnClickPendingIntent(R.id.title, openPendingIntent)

            val linesArray = json.optJSONArray("lines")
            val linesCount = linesArray?.length() ?: 0

            for (i in 0 until 10) {
                val lineViewId = LINE_IDS[i]
                if (i < linesCount) {
                    val lineObj = linesArray!!.getJSONObject(i)
                    val text = lineObj.optString("t", "")
                    val kind = lineObj.optString("k", "text")
                    val checked = lineObj.optBoolean("c", false)
                    val sourceLine = lineObj.optInt("l", 0)

                    views.setViewVisibility(lineViewId, View.VISIBLE)
                    views.setTextColor(lineViewId, fg)

                    val displayText = if (kind == "task") {
                        (if (checked) "☑ " else "☐ ") + text
                    } else {
                        text
                    }
                    views.setTextViewText(lineViewId, displayText)

                    if (kind == "task" && !locked) {
                        val toggleUri = Uri.parse(
                            "tephra-widget://toggle?widgetId=$widgetId&line=$sourceLine&hash=${Uri.encode(hash)}"
                        )
                        val togglePendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                            context,
                            toggleUri
                        )
                        views.setOnClickPendingIntent(lineViewId, togglePendingIntent)
                    } else {
                        views.setOnClickPendingIntent(lineViewId, openPendingIntent)
                    }
                } else {
                    views.setViewVisibility(lineViewId, View.GONE)
                }
            }

            if (more > 0) {
                views.setViewVisibility(R.id.more, View.VISIBLE)
                views.setTextViewText(
                    R.id.more,
                    context.getString(R.string.widget_more_lines, more)
                )
                views.setTextColor(R.id.more, fg)
                views.setOnClickPendingIntent(R.id.more, openPendingIntent)
            } else {
                views.setViewVisibility(R.id.more, View.GONE)
            }
        } catch (_: Exception) {
            renderUnconfigured(context, views, widgetId)
        }
    }

    private fun renderUnconfigured(context: Context, views: RemoteViews, widgetId: Int) {
        views.setInt(R.id.bg, "setColorFilter", 0xFFFFF9C4.toInt())
        views.setTextViewText(R.id.title, context.getString(R.string.widget_choose_sticky))
        views.setTextColor(R.id.title, 0xFF1F1F1F.toInt())

        for (id in LINE_IDS) {
            views.setViewVisibility(id, View.GONE)
        }
        views.setViewVisibility(R.id.more, View.GONE)

        val configUri = Uri.parse("tephra://widget-config?widgetId=$widgetId")
        val configIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            configUri
        )
        views.setOnClickPendingIntent(R.id.root, configIntent)
        views.setOnClickPendingIntent(R.id.title, configIntent)
    }

    private fun renderMissing(context: Context, views: RemoteViews, widgetId: Int) {
        views.setInt(R.id.bg, "setColorFilter", 0xFFE0E0E0.toInt())
        views.setTextViewText(R.id.title, context.getString(R.string.widget_not_found))
        views.setTextColor(R.id.title, 0xFF424242.toInt())

        for (id in LINE_IDS) {
            views.setViewVisibility(id, View.GONE)
        }
        views.setViewVisibility(R.id.more, View.GONE)

        val configUri = Uri.parse("tephra://widget-config?widgetId=$widgetId")
        val configIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            configUri
        )
        views.setOnClickPendingIntent(R.id.root, configIntent)
        views.setOnClickPendingIntent(R.id.title, configIntent)
    }

    fun renderStack(context: Context, views: RemoteViews, rawJson: String?) {
        views.setInt(R.id.bg, "setColorFilter", 0xFFFFFFFF.toInt())
        views.setTextColor(R.id.header, 0xFF1F1F1F.toInt())

        if (rawJson == null) {
            views.setViewVisibility(R.id.empty, View.VISIBLE)
            views.setTextColor(R.id.empty, 0xFF757575.toInt())
            val newStickyIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tephra://new-sticky")
            )
            views.setOnClickPendingIntent(R.id.empty, newStickyIntent)
            for (i in 0 until 6) {
                views.setViewVisibility(ITEM_IDS[i], View.GONE)
            }
            views.setViewVisibility(R.id.footer, View.GONE)
            return
        }

        try {
            val json = JSONObject(rawJson)
            val vaultId = json.optString("vaultId", "")
            val total = json.optInt("total", 0)
            val items = json.optJSONArray("items")
            val itemsCount = items?.length() ?: 0

            val boardUri = Uri.parse("tephra://board?vault=${Uri.encode(vaultId)}")
            val boardIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                boardUri
            )
            views.setOnClickPendingIntent(R.id.header, boardIntent)

            if (total == 0 || itemsCount == 0) {
                views.setViewVisibility(R.id.empty, View.VISIBLE)
                views.setTextColor(R.id.empty, 0xFF757575.toInt())
                val newStickyUri = Uri.parse("tephra://new-sticky?vault=${Uri.encode(vaultId)}")
                val newStickyIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    newStickyUri
                )
                views.setOnClickPendingIntent(R.id.empty, newStickyIntent)

                for (i in 0 until 6) {
                    views.setViewVisibility(ITEM_IDS[i], View.GONE)
                }
                views.setViewVisibility(R.id.footer, View.GONE)
                return
            }

            views.setViewVisibility(R.id.empty, View.GONE)

            for (i in 0 until 6) {
                val itemId = ITEM_IDS[i]
                if (i < itemsCount) {
                    val item = items!!.getJSONObject(i)
                    val path = item.optString("path", "")
                    val title = item.optString("title", "")
                    val bg = item.optLong("bg", 0xFFFFF9C4L).toInt()
                    val preview = item.optString("preview", "")

                    views.setViewVisibility(itemId, View.VISIBLE)
                    views.setInt(ITEM_COLOR_IDS[i], "setColorFilter", bg)
                    views.setTextViewText(ITEM_TITLE_IDS[i], title)
                    views.setTextColor(ITEM_TITLE_IDS[i], 0xFF1F1F1F.toInt())
                    views.setTextViewText(ITEM_PREVIEW_IDS[i], preview)
                    views.setTextColor(ITEM_PREVIEW_IDS[i], 0xFF757575.toInt())

                    val openUri = Uri.parse("tephra://open?vault=${Uri.encode(vaultId)}&path=${Uri.encode(path)}")
                    val openIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        openUri
                    )
                    views.setOnClickPendingIntent(itemId, openIntent)
                } else {
                    views.setViewVisibility(itemId, View.GONE)
                }
            }

            if (total > 6) {
                val remaining = total - 6
                views.setViewVisibility(R.id.footer, View.VISIBLE)
                views.setTextViewText(
                    R.id.footer,
                    context.getString(R.string.widget_more_stickies, remaining)
                )
                views.setTextColor(R.id.footer, 0xFF757575.toInt())
                views.setOnClickPendingIntent(R.id.footer, boardIntent)
            } else {
                views.setViewVisibility(R.id.footer, View.GONE)
            }
        } catch (_: Exception) {
            views.setViewVisibility(R.id.empty, View.VISIBLE)
            views.setTextColor(R.id.empty, 0xFF757575.toInt())
        }
    }
}
