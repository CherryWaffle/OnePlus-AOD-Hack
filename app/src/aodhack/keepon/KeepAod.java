package aodhack.keepon;

import android.Manifest;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Sets and reads SystemUI's keep_aod_on flag by running the same dumpsys command as
 * aod.ps1, but as this app. That needs android.permission.DUMP, granted once over ADB.
 */
final class KeepAod {
    static final String TAG = "AodKeepOn";
    static final int UNKNOWN = -1;

    private static final String KEYGUARD_SERVICE = "com.android.systemui/.keyguard.KeyguardService";
    private static final Pattern FLAG = Pattern.compile("keepAodOn:\\s*(\\d+)");

    private KeepAod() {}

    static boolean hasDumpPermission(Context context) {
        return context.checkSelfPermission(Manifest.permission.DUMP) == PackageManager.PERMISSION_GRANTED;
    }

    /** Sets the flag, then returns what SystemUI reports (1, 0 or UNKNOWN). */
    static int set(boolean on) {
        dumpsys("debug", "keep_aod_on", on ? "1" : "0");
        return parse(dumpsys("aod_display"));
    }

    /** Reads "keepAodOn: N" from SystemUI's aod_display dump. */
    static int parse(String aodDisplayDump) {
        Matcher m = FLAG.matcher(aodDisplayDump);
        return m.find() ? Integer.parseInt(m.group(1)) : UNKNOWN;
    }

    /** Output of `dumpsys activity service <KeyguardService> args...`. Errors come back as text. */
    static String dumpsys(String... args) {
        String[] cmd = new String[4 + args.length];
        cmd[0] = "/system/bin/dumpsys";
        cmd[1] = "activity";
        cmd[2] = "service";
        cmd[3] = KEYGUARD_SERVICE;
        System.arraycopy(args, 0, cmd, 4, args.length);
        try {
            Process process = new ProcessBuilder(cmd).redirectErrorStream(true).start();
            String output = readAll(process.getInputStream());
            if (!process.waitFor(15, TimeUnit.SECONDS)) {
                process.destroy();
            }
            return output;
        } catch (Exception e) {
            Log.w(TAG, "dumpsys failed", e);
            return e.toString();
        }
    }

    private static String readAll(InputStream in) throws java.io.IOException {
        try (InputStream input = in) {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int n;
            while ((n = input.read(buffer)) > 0) {
                out.write(buffer, 0, n);
            }
            return out.toString(StandardCharsets.UTF_8.name());
        }
    }

    // The user's last choice. Kept in device-protected storage so the boot receiver
    // can read it before the phone is unlocked.
    private static SharedPreferences prefs(Context context) {
        return context.createDeviceProtectedStorageContext()
                .getSharedPreferences("state", Context.MODE_PRIVATE);
    }

    static boolean wanted(Context context) {
        return prefs(context).getBoolean("keep_on", true);
    }

    static void setWanted(Context context, boolean on) {
        prefs(context).edit().putBoolean("keep_on", on).apply();
    }
}
