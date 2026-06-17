package com.gueter.cszm

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class GueterTodayWidget : AppWidgetProvider() {
    companion object {
        const val PREFS = "gueter_today_widget"
        const val KEY_TODO_COUNT = "gueter_widget_todo_count"
        const val KEY_REVIEW_COUNT = "gueter_widget_review_due_count"
        const val KEY_NEAREST_TODO = "gueter_widget_nearest_todo_title"
        const val KEY_NOTIFICATION_ENABLED = "gueter_widget_notification_enabled"
        const val KEY_UPDATED_AT = "gueter_widget_updated_at"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, GueterTodayWidget::class.java)
            )
            val provider = GueterTodayWidget()
            ids.forEach { provider.updateWidget(context, manager, it) }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        val widgetData = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val todoCount = widgetData.getInt(KEY_TODO_COUNT, 0)
        val reviewCount = widgetData.getInt(KEY_REVIEW_COUNT, 0)
        val nearestTodo = widgetData.getString(KEY_NEAREST_TODO, "暂无待办")
            ?: "暂无待办"
        val notificationEnabled = widgetData.getBoolean(
            KEY_NOTIFICATION_ENABLED,
            true
        )
        val updatedAt = widgetData.getString(KEY_UPDATED_AT, "--:--") ?: "--:--"

        val launchIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val views = RemoteViews(context.packageName, R.layout.gueter_today_widget).apply {
            setTextViewText(R.id.widget_todo_count, "待办 $todoCount")
            setTextViewText(R.id.widget_review_count, "复习 $reviewCount")
            setTextViewText(R.id.widget_nearest_todo, nearestTodo)
            val notificationText = if (notificationEnabled) "通知可用" else "通知关闭"
            setTextViewText(R.id.widget_footer, "$notificationText · $updatedAt")
            setOnClickPendingIntent(R.id.gueter_today_widget_root, pendingIntent)
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
