package aodhack.keepon;

import android.app.Activity;
import android.app.TimePickerDialog;
import android.os.Bundle;
import android.text.format.DateFormat;
import android.util.TypedValue;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.Calendar;

/** One screen: live state, the choice (always / on a schedule / off) and the schedule times. */
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
    private static final String TIPS =
            "Your choice is kept after a restart: the app applies it again by itself, even "
            + "before you unlock.\n\nIf it stops working after a restart or at the scheduled "
            + "times, allow this app to auto-launch / run in the background in its app "
            + "settings, then open it once.";

    private TextView status;
    private TextView details;
    private RadioButton always;
    private RadioButton scheduled;
    private RadioButton off;
    private Button from;
    private Button to;
    private boolean binding;

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

        TextView label = new TextView(this);
        label.setText("Keep full-screen AOD on:");

        RadioGroup choice = new RadioGroup(this);
        always = radio(choice, "Always");
        scheduled = radio(choice, "On a schedule");
        off = radio(choice, "Off (stock: turns off after a few seconds)");
        choice.setOnCheckedChangeListener((group, id) -> {
            if (!binding) {
                saveChoice();
            }
        });

        LinearLayout times = new LinearLayout(this);
        times.setOrientation(LinearLayout.HORIZONTAL);
        from = new Button(this);
        to = new Button(this);
        from.setOnClickListener(v -> pickTime(true));
        to.setOnClickListener(v -> pickTime(false));
        times.addView(from, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        times.addView(to, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));

        details = new TextView(this);
        details.setTextIsSelectable(true);
        details.setPadding(0, dp(16), 0, 0);

        root.addView(title);
        root.addView(status);
        root.addView(label);
        root.addView(choice);
        root.addView(times);
        root.addView(details);

        ScrollView scroll = new ScrollView(this);
        scroll.setFitsSystemWindows(true);
        scroll.addView(root);
        setContentView(scroll);
    }

    @Override
    protected void onResume() {
        super.onResume();
        bind();
        // Applying on every open also repairs a lost alarm or a SystemUI restart.
        apply();
    }

    private RadioButton radio(RadioGroup group, String text) {
        RadioButton button = new RadioButton(this);
        button.setId(View.generateViewId());
        button.setText(text);
        group.addView(button);
        return button;
    }

    /** Shows the saved choice without triggering the change listener. */
    private void bind() {
        binding = true;
        int mode = Schedule.mode(this);
        always.setChecked(mode == Schedule.MODE_ALWAYS);
        scheduled.setChecked(mode == Schedule.MODE_SCHEDULED);
        off.setChecked(mode == Schedule.MODE_OFF);
        updateTimeButtons();
        binding = false;
    }

    private void updateTimeButtons() {
        from.setText("From " + format(Schedule.start(this)));
        to.setText("To " + format(Schedule.end(this)));
        boolean onSchedule = Schedule.mode(this) == Schedule.MODE_SCHEDULED;
        from.setEnabled(onSchedule);
        to.setEnabled(onSchedule);
    }

    private void saveChoice() {
        int mode = always.isChecked() ? Schedule.MODE_ALWAYS
                : scheduled.isChecked() ? Schedule.MODE_SCHEDULED : Schedule.MODE_OFF;
        Schedule.save(this, mode, Schedule.start(this), Schedule.end(this));
        updateTimeButtons();
        apply();
    }

    private void pickTime(boolean isStart) {
        int current = isStart ? Schedule.start(this) : Schedule.end(this);
        new TimePickerDialog(this, (view, hour, minute) -> {
            int picked = hour * 60 + minute;
            Schedule.save(this, Schedule.mode(this),
                    isStart ? picked : Schedule.start(this),
                    isStart ? Schedule.end(this) : picked);
            updateTimeButtons();
            apply();
        }, current / 60, current % 60, DateFormat.is24HourFormat(this)).show();
    }

    /** Puts the switch where the choice says, sets the next alarm, then shows the result. */
    private void apply() {
        status.setText("Checking...");
        boolean on = Schedule.wantedAt(this, System.currentTimeMillis());
        new Thread(() -> {
            KeepAod.dumpsys("debug", "keep_aod_on", on ? "1" : "0");
            if (!on) {
                KeepAod.requestHideCheck(this);
            }
            Schedule.scheduleNext(this);
            String dump = KeepAod.dumpsys("aod_display");
            runOnUiThread(() -> show(dump, on));
        }).start();
    }

    private void show(String aodDisplayDump, boolean wantedOn) {
        int flag = KeepAod.parse(aodDisplayDump);
        StringBuilder text = new StringBuilder();
        if (flag == 1) {
            text.append("ON now: full-screen AOD won't time out.");
        } else if (flag == 0) {
            text.append("OFF now: full-screen AOD turns off after a few seconds.");
        } else {
            text.append("Unknown: couldn't read the switch from SystemUI.");
        }
        if (Schedule.mode(this) == Schedule.MODE_SCHEDULED) {
            int start = Schedule.start(this);
            int end = Schedule.end(this);
            if (start == end) {
                text.append("\nStart and end are the same, so it's on all day.");
            } else {
                long next = Schedule.nextChange(this, System.currentTimeMillis());
                text.append(wantedOn ? "\nTurns off at " : "\nTurns on at ")
                        .append(format(Schedule.minuteOfDay(next))).append('.');
            }
        }
        status.setText(text);

        if (!KeepAod.hasDumpPermission(this)) {
            details.setText(SETUP);
        } else if (flag == KeepAod.UNKNOWN) {
            String said = aodDisplayDump.trim();
            details.setText(NO_SWITCH + "\n\nSystemUI said:\n"
                    + (said.length() > 600 ? said.substring(0, 600) + "..." : said));
        } else if (wantedOn && flag == 0) {
            details.setText(IGNORED);
        } else {
            details.setText(TIPS);
        }
    }

    private String format(int minuteOfDay) {
        Calendar at = Calendar.getInstance();
        at.set(Calendar.HOUR_OF_DAY, minuteOfDay / 60);
        at.set(Calendar.MINUTE, minuteOfDay % 60);
        return DateFormat.getTimeFormat(this).format(at.getTime());
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
