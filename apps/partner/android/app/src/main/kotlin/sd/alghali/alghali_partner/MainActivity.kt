package sd.alghali.alghali_partner

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel every push uses (`channel_id: alerts`, D-109); high importance so
        // alerts show as banners. Creating it again is harmless.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "alerts",
                getString(R.string.alerts_channel),
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.description = getString(R.string.alerts_channel_description)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
