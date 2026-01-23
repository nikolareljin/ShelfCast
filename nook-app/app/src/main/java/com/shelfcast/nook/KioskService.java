package com.shelfcast.nook;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

/**
 * Background service to keep ShelfCast running and handle connection management.
 * Monitors USB connection status and server availability.
 */
public class KioskService extends Service {

    private static final String TAG = "KioskService";

    @Override
    public void onCreate() {
        super.onCreate();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Return sticky to restart service if killed
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }
}
