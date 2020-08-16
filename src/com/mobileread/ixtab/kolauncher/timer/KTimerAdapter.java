package com.mobileread.ixtab.kolauncher.timer;

import java.util.Timer;
import java.util.TimerTask;

import com.mobileread.ixtab.kolauncher.timer.TimerAdapter;

public class KTimerAdapter extends TimerAdapter {

	public Object newTimer() {
		return new Timer();
	}

	public Object newTimerTask(final Runnable runnable) {
		return new TimerTask() {
			public void run() {
				runnable.run();
			}
		};
	}

	public void schedule(Object timerObject, Object timerTaskObject, long delay, long period) {
		Timer timer = (Timer) timerObject;
		TimerTask timerTask = (TimerTask) timerTaskObject;
		timer.schedule(timerTask, delay, period);
	}

	public void cancel(Object timerObject) {
		Timer timer = (Timer) timerObject;
		timer.cancel();
	}
}
