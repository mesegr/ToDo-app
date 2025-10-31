package com.example.todo_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TodoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Actualizar todos los widgets activos
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // Crear el RemoteViews
        val views = RemoteViews(context.packageName, R.layout.todo_widget)

        // Obtener datos desde SharedPreferences (guardados por Flutter)
        val widgetData = HomeWidgetPlugin.getData(context)
        val tasksWithoutAlarm = widgetData.getInt("tasks_without_alarm", 0)
        val tasksWithAlarmToday = widgetData.getInt("tasks_with_alarm_today", 0)
        val allTasksWithAlarm = widgetData.getInt("all_tasks_with_alarm", 0)

        // Actualizar los TextViews
        views.setTextViewText(R.id.tasks_without_alarm, tasksWithoutAlarm.toString())
        views.setTextViewText(R.id.tasks_with_alarm_today, tasksWithAlarmToday.toString())
        views.setTextViewText(R.id.all_tasks_with_alarm, allTasksWithAlarm.toString())

        // Configurar el click del widget para abrir la app
        val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (openAppIntent != null) {
            val openAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)
        }

        // Configurar el botón de añadir tarea
        val addTaskIntent = Intent(context, MainActivity::class.java).apply {
            action = "ADD_TASK"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val addTaskPendingIntent = PendingIntent.getActivity(
            context,
            1,
            addTaskIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.add_task_button, addTaskPendingIntent)

        // Actualizar el widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onEnabled(context: Context) {
        // Se llama cuando se añade el primer widget
        super.onEnabled(context)
    }

    override fun onDisabled(context: Context) {
        // Se llama cuando se elimina el último widget
        super.onDisabled(context)
    }
}
