package com.example.todo_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
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
        val taskCount = widgetData.getInt("task_count", 0)
        val pendingCount = widgetData.getInt("pending_count", 0)
        val completedCount = widgetData.getInt("completed_count", 0)

        // Actualizar los TextViews
        views.setTextViewText(R.id.task_count, taskCount.toString())
        views.setTextViewText(R.id.pending_count, pendingCount.toString())
        views.setTextViewText(R.id.completed_count, completedCount.toString())

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
