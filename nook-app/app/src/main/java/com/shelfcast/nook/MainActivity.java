package com.shelfcast.nook;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.view.KeyEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

/**
 * Main activity for ShelfCast Nook client.
 * Displays the dashboard in a fullscreen WebView optimized for e-ink.
 */
public class MainActivity extends Activity {

    private static final String TAG = "ShelfCastNook";

    // Default server URL - connects via ADB reverse port forwarding
    private static final String DEFAULT_SERVER_URL = "http://localhost:8080";

    // Refresh interval for dashboard updates (5 minutes)
    private static final long REFRESH_INTERVAL_MS = 5 * 60 * 1000;

    private WebView webView;
    private Handler refreshHandler;
    private Runnable refreshRunnable;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Fullscreen setup
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        );
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        setContentView(R.layout.activity_main);

        webView = (WebView) findViewById(R.id.webview);
        setupWebView();

        // Load the dashboard
        loadDashboard();

        // Setup periodic refresh for e-ink optimization
        setupPeriodicRefresh();
    }

    private void setupWebView() {
        WebSettings settings = webView.getSettings();

        // Enable JavaScript for dashboard interactivity
        settings.setJavaScriptEnabled(true);

        // Optimize for e-ink display
        settings.setBuiltInZoomControls(false);
        settings.setSupportZoom(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);

        // Cache settings for offline capability
        settings.setCacheMode(WebSettings.LOAD_CACHE_ELSE_NETWORK);
        settings.setAppCacheEnabled(true);
        settings.setDomStorageEnabled(true);

        // Disable plugins if supported (method removed on newer SDKs)
        disableWebViewPlugins(settings);

        webView.setScrollBarStyle(View.SCROLLBARS_INSIDE_OVERLAY);
        webView.setBackgroundColor(0xFFFFFFFF);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onReceivedError(WebView view, int errorCode,
                    String description, String failingUrl) {
                // Show error and retry
                showConnectionError(description);
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                // Trigger e-ink refresh after page load
                triggerEinkRefresh();
            }
        });
    }

    private void loadDashboard() {
        String serverUrl = getServerUrl();
        webView.loadUrl(serverUrl);
    }

    private void disableWebViewPlugins(WebSettings settings) {
        try {
            java.lang.reflect.Method method =
                    settings.getClass().getMethod("setPluginsEnabled", boolean.class);
            method.invoke(settings, false);
        } catch (Exception ignored) {
            // Method not available on newer SDKs.
        }
    }

    private String getServerUrl() {
        android.content.Intent intent = getIntent();
        if (intent != null) {
            android.net.Uri data = intent.getData();
            if (data != null) {
                String override = data.toString();
                if (override.startsWith("http://") || override.startsWith("https://")) {
                    return override;
                }
            }
            String extra = intent.getStringExtra("SHELFCAST_URL");
            if (extra != null && (extra.startsWith("http://") || extra.startsWith("https://"))) {
                return extra;
            }
        }
        // Default to localhost (expects port forwarding when available)
        return DEFAULT_SERVER_URL;
    }

    private void setupPeriodicRefresh() {
        refreshHandler = new Handler();
        refreshRunnable = new Runnable() {
            @Override
            public void run() {
                webView.reload();
                refreshHandler.postDelayed(this, REFRESH_INTERVAL_MS);
            }
        };
        refreshHandler.postDelayed(refreshRunnable, REFRESH_INTERVAL_MS);
    }

    private void triggerEinkRefresh() {
        // Force a full e-ink refresh to clear ghosting
        // This is done by briefly toggling visibility
        webView.postDelayed(new Runnable() {
            @Override
            public void run() {
                webView.invalidate();
            }
        }, 100);
    }

    private void showConnectionError(String message) {
        Toast.makeText(this,
            "Connection error: " + message + "\nRetrying...",
            Toast.LENGTH_LONG).show();

        // Retry after 10 seconds
        refreshHandler.postDelayed(new Runnable() {
            @Override
            public void run() {
                loadDashboard();
            }
        }, 10000);
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        // Handle hardware buttons
        switch (keyCode) {
            case KeyEvent.KEYCODE_MENU:
                // Menu button - force refresh
                webView.reload();
                return true;
            case KeyEvent.KEYCODE_BACK:
                // Disable back button in kiosk mode
                return true;
            case KeyEvent.KEYCODE_VOLUME_UP:
            case KeyEvent.KEYCODE_VOLUME_DOWN:
                // Use volume buttons for manual e-ink refresh
                triggerEinkRefresh();
                return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onResume() {
        super.onResume();
        webView.reload();
    }

    @Override
    protected void onPause() {
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (refreshHandler != null && refreshRunnable != null) {
            refreshHandler.removeCallbacks(refreshRunnable);
        }
    }
}
