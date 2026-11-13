package aodhack.keepon;

import android.app.Activity;
import android.os.Bundle;
import android.util.TypedValue;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.concurrent.Callable;

/** One screen: current state, Turn on, Turn off. */
public final class MainActivity extends Activity {
    private static final String SETUP =
            "One-time setup needed: this app needs the DUMP permission, which only a PC can "
            + "grant. With USB debugging on, run install-app.cmd from this project on your PC "
            + "(or: adb install -r -g AodKeepOn.apk). Opening the APK on the phone can't grant it.";
    private static final String NO_SWITCH =
            "SystemUI didn't report keepAodOn, so this phone's software probably doesn't have "
            + "the hidden switch this app uses (or an update removed it). It can't work here.";
    private static final String IGNORED =
            "SystemUI ignored the request, so the switch doesn't work on this phone or "
            + "software version.";

    private TextView status;
    private TextView details;
    private Button onButton;
    private Button offButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(20);
        root.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("Full-screen AOD keep-on");
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);

        status = new TextView(this);
        status.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        status.setPadding(0, dp(16), 0, dp(16));

        onButton = new Button(this);
        onButton.setText("Turn on");
        onButton.setOnClickListener(v -> apply(true));

        offButton = new Button(this);
        offButton.setText("Turn off");
        offButton.setOnClickListener(v -> apply(false));

        details = new TextView(this);
        details.setTextIsSelectable(true);
        details.setPadding(0, dp(16), 0, 0);

        root.addView(title);
        root.addView(status);
        root.addView(onButton);
        root.addView(offButton);
        root.addView(details);

        ScrollView scroll = new ScrollView(this);
        scroll.setFitsSystemWindows(true);
        scroll.addView(root);
        setContentView(scroll);
    }

    @Override
    protected void onResume() {
        super.onResume();
        run(false, () -> KeepAod.dumpsys("aod_display"));
    }

    private void apply(boolean on) {
        KeepAod.setWanted(this, on);
        run(on, () -> {
            KeepAod.dumpsys("debug", "keep_aod_on", on ? "1" : "0");
            return KeepAod.dumpsys("aod_display");
        });
    }

    /** @param turnedOn true when this run is a Turn on tap, to spot phones that ignore it. */
    private void run(boolean turnedOn, Callable<String> work) {
        onButton.setEnabled(false);
        offButton.setEnabled(false);
        status.setText("Checking...");
        new Thread(() -> {
            String output;
            try {
                output = work.call();
            } catch (Exception e) {
                output = e.toString();
            }
            String result = output;
            runOnUiThread(() -> show(result, turnedOn));
        }).start();
    }

    private void show(String aodDisplayDump, boolean turnedOn) {
        onButton.setEnabled(true);
        offButton.setEnabled(true);
        int flag = KeepAod.parse(aodDisplayDump);
        boolean wanted = KeepAod.wanted(this);

        if (flag == 1) {
            status.setText("ON: full-screen AOD won't time out.");
        } else if (flag == 0) {
            status.setText("OFF: full-screen AOD uses the stock timeout.");
        } else {
            status.setText("Unknown: couldn't read the flag from SystemUI.");
        }

        if (!KeepAod.hasDumpPermission(this)) {
            details.setText(SETUP);
        } else if (flag == KeepAod.UNKNOWN) {
            String text = aodDisplayDump.trim();
            details.setText(NO_SWITCH + "\n\nSystemUI said:\n"
                    + (text.length() > 600 ? text.substring(0, 600) + "..." : text));
        } else if (turnedOn && flag == 0) {
            details.setText(IGNORED);
        } else {
            details.setText((wanted
                    ? "After a restart this app turns it back on by itself."
                    : "It stays off after a restart until you tap Turn on.")
                    + "\n\nIf it doesn't come back after a restart, allow this app to auto-launch "
                    + "in its app settings (battery / auto launch).");
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
