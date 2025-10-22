package com.example.todo_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import android.util.Log

class TodoWidgetProvider : AppWidgetProvider() {
    
    companion object {
        private const val TAG = "TodoWidgetProvider"
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called with ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            Log.d(TAG, "updateAppWidget called for widget $appWidgetId")
            val views = RemoteViews(context.packageName, R.layout.todo_widget)
            
            val widgetData = HomeWidgetPlugin.getData(context)
            val alarmTasksJson = widgetData.getString("alarm_tasks", "[]") ?: "[]"
            val pendingTasksJson = widgetData.getString("pending_tasks", "[]") ?: "[]"
            val taskCount = widgetData.getInt("task_count", 0)
            
            Log.d(TAG, "Task count: $taskCount")

            val alarmTasks = JSONArray(alarmTasksJson)
            val pendingTasks = JSONArray(pendingTasksJson)

            // Configurar visibilidad de las secciones
            if (taskCount == 0) {
                views.setViewVisibility(R.id.empty_message, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.alarm_tasks_section, android.view.View.GONE)
                views.setViewVisibility(R.id.pending_tasks_section, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.empty_message, android.view.View.GONE)
                
                // Sección de tareas con alarma
                if (alarmTasks.length() > 0) {
                    views.setViewVisibility(R.id.alarm_tasks_section, android.view.View.VISIBLE)
                    updateTaskList(context, views, R.id.alarm_tasks_list, alarmTasks)
                } else {
                    views.setViewVisibility(R.id.alarm_tasks_section, android.view.View.GONE)
                }

                // Sección de tareas pendientes
                if (pendingTasks.length() > 0) {
                    views.setViewVisibility(R.id.pending_tasks_section, android.view.View.VISIBLE)
                    updateTaskList(context, views, R.id.pending_tasks_list, pendingTasks)
                } else {
                    views.setViewVisibility(R.id.pending_tasks_section, android.view.View.GONE)
                }
            }

            // Actualizar contador de tareas
            val summaryText = if (taskCount == 1) {
                "$taskCount tarea para hoy"
            } else {
                "$taskCount tareas para hoy"
            }
            views.setTextViewText(R.id.task_summary, summaryText)

            // Intent para abrir la app al hacer clic en el botón de añadir
            val addIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "add_task")
            }
            val addPendingIntent = android.app.PendingIntent.getActivity(
                context,
                0,
                addIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.add_button, addPendingIntent)

            // Intent para abrir la app al hacer clic en el widget
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPendingIntent = android.app.PendingIntent.getActivity(
                context,
                1,
                openIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_header, openPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)

        } catch (e: Exception) {
            Log.e(TAG, "Error updating widget", e)
            // Si hay error, mostrar widget vacío básico
            val views = RemoteViews(context.packageName, R.layout.todo_widget)
            views.setViewVisibility(R.id.empty_message, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.alarm_tasks_section, android.view.View.GONE)
            views.setViewVisibility(R.id.pending_tasks_section, android.view.View.GONE)
            views.setTextViewText(R.id.task_summary, "0 tareas para hoy")
            views.setTextViewText(R.id.empty_message, "Error al cargar tareas")
            
            // Intent básico para abrir la app
            val openIntent = Intent(context, MainActivity::class.java)
            openIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val openPendingIntent = android.app.PendingIntent.getActivity(
                context,
                1,
                openIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.add_button, openPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_header, openPendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun updateTaskList(
        context: Context,
        views: RemoteViews,
        listViewId: Int,
        tasks: JSONArray
    ) {
        // Crear RemoteViews para cada tarea
        val taskText = StringBuilder()
        for (i in 0 until tasks.length()) {
            val task = tasks.getJSONObject(i)
            val title = task.getString("title")
            val time = task.optString("time", "")
            
            taskText.append("• $title")
            if (time.isNotEmpty()) {
                taskText.append(" - $time")
            }
            if (i < tasks.length() - 1) {
                taskText.append("\n")
            }
        }
        
        // Nota: Para una implementación más compleja con listas reales,
        // se necesitaría usar RemoteViewsService. Por ahora, mostramos
        // todas las tareas en un TextView.
        views.setTextViewText(listViewId, taskText.toString())
    }

    override fun onEnabled(context: Context) {
        // Widget habilitado por primera vez
    }

    override fun onDisabled(context: Context) {
        // Último widget deshabilitado
    }
}
