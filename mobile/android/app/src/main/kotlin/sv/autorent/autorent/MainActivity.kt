package sv.autorent.autorent

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sv.autorent.autorent/push")
            .setMethodCallHandler { call, result ->
                if (call.method != "rememberFirebaseOptions") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val fields = listOf("appId", "apiKey", "projectId", "messagingSenderId")
                    .associateWith { call.argument<String>(it) }
                if (fields.values.any { it.isNullOrBlank() }) {
                    result.error("INVALID_OPTIONS", "Configuración de avisos incompleta.", null)
                    return@setMethodCallHandler
                }
                val editor = getSharedPreferences(AutoRentApplication.PREFERENCES, MODE_PRIVATE).edit()
                fields.forEach { (name, value) -> editor.putString(name, value) }
                editor.apply()
                result.success(null)
            }
    }
}
