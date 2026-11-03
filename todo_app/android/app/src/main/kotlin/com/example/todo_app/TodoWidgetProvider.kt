package com.example.todo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class TodoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val pending = widgetData.getInt("all_pending_count", 0)
        val today = widgetData.getInt("today_count", 0)

        val openAppIntent = HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("todoapp://home"),
        )
        val addTaskIntent = HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("todoapp://add-task"),
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.todo_widget).apply {
                setTextViewText(R.id.widget_pending_count, "Pendientes: $pending")
                setTextViewText(R.id.widget_today_count, "Tareas de hoy: $today")
                setOnClickPendingIntent(R.id.widget_root, openAppIntent)
                setOnClickPendingIntent(R.id.widget_add_task, addTaskIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
