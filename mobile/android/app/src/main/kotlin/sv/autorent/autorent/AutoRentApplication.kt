package sv.autorent.autorent

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

class AutoRentApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("autorent_reservations", "Avisos de AutoRent", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        if (FirebaseApp.getApps(this).isNotEmpty()) return

        val prefs = getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val appId = prefs.getString("appId", null) ?: return
        val apiKey = prefs.getString("apiKey", null) ?: return
        val projectId = prefs.getString("projectId", null) ?: return
        val sender = prefs.getString("messagingSenderId", null) ?: return
        // Firebase must also initialize when Android starts the process for an incoming push.
        FirebaseApp.initializeApp(this, FirebaseOptions.Builder()
            .setApplicationId(appId)
            .setApiKey(apiKey)
            .setProjectId(projectId)
            .setGcmSenderId(sender)
            .build())
    }

    companion object {
        const val PREFERENCES = "autorent_firebase_options"
    }
}
