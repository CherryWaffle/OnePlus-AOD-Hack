package aodhack.keepon;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.SystemClock;
import android.util.Log;

/**
 * Puts the switch where the user's choice says it should be, then sets the next alarms.
 * Runs after a restart, at each schedule start/end, every 30 minutes as a check, after the
 * clock or time zone changes, and after the app is updated.
 */
public final class ApplyReceiver extends BroadcastReceiver {
    private static final long RETRY_MS = 3000;
    // An exact alarm can arrive a moment early; judge it as if it were on time.
    private static final long ALARM_SLACK_MS = 30_000;

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = String.valueOf(intent.getAction());
        boolean boot = action.endsWith("BOOT_COMPLETED");
        boolean change = Schedule.ACTION_APPLY.equals(action);
        boolean check = Schedule.ACTION_CHECK.equals(action);
        PendingResult result = goAsync();
        new Thread(() -> {
            try {
                long now = System.currentTimeMillis() + (change ? ALARM_SLACK_MS : 0);
                boolean on = Schedule.wantedAt(context, now);
                int want = on ? 1 : 0;

                if (check) {
                    // Only repair: leave SystemUI alone when the switch is already right.
                    int actual = KeepAod.parse(KeepAod.dumpsys("aod_display"));
                    if (actual == want || actual == KeepAod.UNKNOWN) {
                        return;
                    }
                    Log.i(KeepAod.TAG, "check: keep_aod_on was " + actual + ", setting " + want);
                }

                // After a restart SystemUI starts with the switch off, and may still be starting.
                if (on || !boot) {
                    int attempts = boot ? 10 : 2;
                    for (int attempt = 1; attempt <= attempts; attempt++) {
                        if (KeepAod.set(on) == want) {
                            Log.i(KeepAod.TAG, action + ": keep_aod_on = " + want);
                            break;
                        }
                        SystemClock.sleep(RETRY_MS);
                    }
                }
                if (!on && !boot) {
                    // A full-screen AOD that is already lit would otherwise stay lit.
                    KeepAod.requestHideCheck(context);
                }
            } finally {
                Schedule.scheduleNext(context);
                result.finish();
            }
        }).start();
    }
}
