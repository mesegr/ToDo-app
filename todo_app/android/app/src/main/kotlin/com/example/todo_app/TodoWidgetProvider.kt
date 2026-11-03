package com.example.todo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TodoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val pending = widgetData.getInt("all_pending_count", 0)
        val today = widgetData.getInt("today_count", 0)

        val openAppIntent = widgetPendingIntent(context, "todoapp://home", 0)
        val addTaskIntent = widgetPendingIntent(context, "todoapp://add-task", 1)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.todo_widget).apply {
                setTextViewText(R.id.widget_pending_count, pending.toString())
                setTextViewText(R.id.widget_today_count, today.toString())
                setOnClickPendingIntent(R.id.widget_root, openAppIntent)
                setOnClickPendingIntent(R.id.widget_add_task, addTaskIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun widgetPendingIntent(context: Context, uri: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "es.antonborri.home_widget.action.LAUNCH"
            data = android.net.Uri.parse(uri)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
