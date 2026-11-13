package aodhack.keepon;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.util.Log;

import java.util.Calendar;

/**
 * The user's choice (always / on a schedule / off) and the alarm that flips the switch
 * at the schedule's start and end times. Stored in device-protected storage so it can be
 * read right after a restart, before the phone is unlocked.
 */
final class Schedule {
    static final int MODE_OFF = 0;
    static final int MODE_ALWAYS = 1;
    static final int MODE_SCHEDULED = 2;

    static final String ACTION_APPLY = "aodhack.keepon.APPLY";
    static final String ACTION_CHECK = "aodhack.keepon.CHECK";
    private static final long CHECK_INTERVAL_MS = 30 * 60 * 1000L;

    // Minutes after midnight. Same defaults as ColorOS's own AOD schedule.
    private static final int DEFAULT_START = 7 * 60;
    private static final int DEFAULT_END = 23 * 60;

    private Schedule() {}

    private static SharedPreferences prefs(Context context) {
        return context.createDeviceProtectedStorageContext()
                .getSharedPreferences("state", Context.MODE_PRIVATE);
    }

    static int mode(Context context) {
        SharedPreferences p = prefs(context);
        if (p.contains("mode")) {
            return p.getInt("mode", MODE_ALWAYS);
        }
        // Version 1.0 stored a simple on/off choice.
        return p.getBoolean("keep_on", true) ? MODE_ALWAYS : MODE_OFF;
    }

    static int start(Context context) {
        return prefs(context).getInt("start", DEFAULT_START);
    }

    static int end(Context context) {
        return prefs(context).getInt("end", DEFAULT_END);
    }

    static void save(Context context, int mode, int start, int end) {
        prefs(context).edit().putInt("mode", mode).putInt("start", start).putInt("end", end).apply();
    }

    /** Whether the switch should be on at the given time. */
    static boolean wantedAt(Context context, long timeMillis) {
        switch (mode(context)) {
            case MODE_ALWAYS:
                return true;
            case MODE_SCHEDULED:
                return inWindow(minuteOfDay(timeMillis), start(context), end(context));
            default:
                return false;
        }
    }

    /** start == end means all day. A start after the end wraps past midnight (22:00-07:00). */
    static boolean inWindow(int minute, int start, int end) {
        if (start == end) {
            return true;
        }
        if (start < end) {
            return minute >= start && minute < end;
        }
        return minute >= start || minute < end;
    }

    /** The next time the schedule starts or ends, after the given time. */
    static long nextChange(Context context, long nowMillis) {
        long next = Long.MAX_VALUE;
        for (int minute : new int[] {start(context), end(context)}) {
            Calendar at = Calendar.getInstance();
            at.setTimeInMillis(nowMillis);
            at.set(Calendar.HOUR_OF_DAY, minute / 60);
            at.set(Calendar.MINUTE, minute % 60);
            at.set(Calendar.SECOND, 0);
            at.set(Calendar.MILLISECOND, 0);
            if (at.getTimeInMillis() <= nowMillis) {
                at.add(Calendar.DAY_OF_YEAR, 1);
            }
            next = Math.min(next, at.getTimeInMillis());
        }
        return next;
    }

    /**
     * Sets the alarms that keep the switch where the user wants it:
     * an exact one at the next schedule start/end, and an inexact check every
     * CHECK_INTERVAL_MS that puts the switch back if something reset it
     * (a SystemUI restart, for example). Cancels both when the choice is Off.
     */
    static void scheduleNext(Context context) {
        AlarmManager alarms = context.getSystemService(AlarmManager.class);
        PendingIntent change = pending(context, 0, ACTION_APPLY);
        PendingIntent check = pending(context, 1, ACTION_CHECK);
        int mode = mode(context);
        long now = System.currentTimeMillis();

        if (mode == MODE_OFF) {
            alarms.cancel(change);
            alarms.cancel(check);
            return;
        }
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, now + CHECK_INTERVAL_MS, check);

        if (mode != MODE_SCHEDULED || start(context) == end(context)) {
            alarms.cancel(change);
            return;
        }
        long at = nextChange(context, now);
        if (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, change);
        } else {
            // Without exact-alarm access Android may deliver it a few minutes late.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, change);
        }
        Log.i(KeepAod.TAG, "next schedule change at " + at);
    }

    private static PendingIntent pending(Context context, int requestCode, String action) {
        Intent intent = new Intent(context, ApplyReceiver.class).setAction(action);
        return PendingIntent.getBroadcast(context, requestCode, intent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }

    static int minuteOfDay(long timeMillis) {
        Calendar now = Calendar.getInstance();
        now.setTimeInMillis(timeMillis);
        return now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE);
    }
}
