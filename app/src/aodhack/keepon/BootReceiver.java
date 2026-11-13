package aodhack.keepon;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;
import android.util.Log;

/** Turns keep_aod_on back on after a restart, if the user left it on. */
public final class BootReceiver extends BroadcastReceiver {
    private static final int ATTEMPTS = 10;
    private static final long RETRY_MS = 3000;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (!KeepAod.wanted(context)) {
            Log.i(KeepAod.TAG, intent.getAction() + ": left off (user turned it off)");
            return;
        }
        PendingResult result = goAsync();
        new Thread(() -> {
            try {
                // SystemUI may still be starting, so retry for up to ~30 s.
                for (int attempt = 1; attempt <= ATTEMPTS; attempt++) {
                    if (KeepAod.set(true) == 1) {
                        Log.i(KeepAod.TAG, intent.getAction() + ": keep_aod_on = 1 (attempt " + attempt + ")");
                        return;
                    }
                    SystemClock.sleep(RETRY_MS);
                }
                Log.w(KeepAod.TAG, intent.getAction() + ": could not set keep_aod_on; is DUMP granted?");
            } finally {
                result.finish();
            }
        }).start();
    }
}
