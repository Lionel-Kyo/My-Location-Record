package com.example.my_location_record

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

class LocationService : Service() {

    companion object {
        @Volatile
        var isRecording: Boolean = false
            private set
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private lateinit var dbHelper: DatabaseHelper

    override fun onCreate() {
        super.onCreate()

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        dbHelper = DatabaseHelper(this)

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(
                locationResult: LocationResult
            ) {
                for (location in locationResult.locations) {
                    try {
                        dbHelper.insertLocation(
                            location.latitude,
                            location.longitude,
                            location.time
                        )
                    } catch (e: Exception) {
                        android.util.Log.e(
                            "LocationService",
                            "Failed to save location",
                            e
                        )
                    }
                }
            }
        }
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        val intervalSeconds = (intent?.getLongExtra("interval_seconds", 15L) ?: 15L).coerceIn(15L, 86400L)

        createNotificationChannel()

        val notification: Notification =
            NotificationCompat.Builder(this, "LocationChannel")
                .setContentTitle("Location Recorder Active")
                .setContentText("Recording locations in background...")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setOngoing(true)
                .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(1, notification)
        }

        startLocationUpdates(intervalSeconds * 1_000L)

        return START_STICKY
    }

    private fun startLocationUpdates(intervalMillis: Long) {
        // Prevent duplicate callbacks if startService is called again.
        fusedLocationClient.removeLocationUpdates(locationCallback)

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            intervalMillis
        )
            .setMinUpdateDistanceMeters(10.0f) // Only trigger if moved 10 meters
            .setMinUpdateIntervalMillis(intervalMillis)
            .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                request,
                locationCallback,
                Looper.getMainLooper()
            )
                .addOnSuccessListener {
                    isRecording = true
                }
                .addOnFailureListener { error ->
                    isRecording = false

                    android.util.Log.e(
                        "LocationService",
                        "Failed to request location updates",
                        error
                    )

                    stopSelf()
                }
        } catch (e: SecurityException) {
            isRecording = false

            android.util.Log.e(
                "LocationService",
                "Location permission is missing",
                e
            )

            stopSelf()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "LocationChannel",
                "Background Location Service",
                NotificationManager.IMPORTANCE_LOW
            )

            val manager =
                getSystemService(NotificationManager::class.java)

            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRecording = false

        if (::fusedLocationClient.isInitialized &&
            ::locationCallback.isInitialized
        ) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }

        if (::dbHelper.isInitialized) {
            dbHelper.close()
        }

        super.onDestroy()
    }
}