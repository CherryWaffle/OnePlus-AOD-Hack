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
            "One-time setup: this app needs the DUMP permission to run dumpsys. With the "
            + "phone on USB debugging, install it from a PC with:\n\n"
            + "adb install -r -g AodKeepOn.apk\n\n"
            + "(-g grants the permission during install; .\\app\\build.ps1 -Install does this.)";

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
        run(() -> KeepAod.dumpsys("aod_display"));
    }

    private void apply(boolean on) {
        KeepAod.setWanted(this, on);
        run(() -> {
            KeepAod.dumpsys("debug", "keep_aod_on", on ? "1" : "0");
            return KeepAod.dumpsys("aod_display");
        });
    }

    private void run(Callable<String> work) {
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
            runOnUiThread(() -> show(result));
        }).start();
    }

    private void show(String aodDisplayDump) {
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
            details.setText("SystemUI said:\n" + (text.length() > 600 ? text.substring(0, 600) + "..." : text));
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
