package com.mobileread.ixtab.kolauncher.timer;

import com.mobileread.ixtab.kolauncher.timer.TimerAdapter;

public class JTimerAdapter extends TimerAdapter {

	public Object newTimer() {
		return new java.util.Timer();
	}

	public Object newTimerTask(final Runnable runnable) {
		return new java.util.TimerTask() {
			public void run() {
				runnable.run();
			}
		};
	}

	public void schedule(Object timerObject, Object timerTaskObject, long delay, long period) {
		java.util.Timer timer = (java.util.Timer) timerObject;
		java.util.TimerTask timerTask = (java.util.TimerTask) timerTaskObject;
		timer.schedule(timerTask, delay, period);
	}

	public void cancel(Object timerObject) {
		java.util.Timer timer = (java.util.Timer) timerObject;
		timer.cancel();
	}
}
