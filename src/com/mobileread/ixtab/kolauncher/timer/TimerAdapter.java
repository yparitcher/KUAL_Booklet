package com.mobileread.ixtab.kolauncher.timer;

public abstract class TimerAdapter {
	public static final TimerAdapter INSTANCE = createInstance();

	private static TimerAdapter createInstance() {
		try {
			Class.forName("com.amazon.kindle.kindlet.ui.KPanel");
			return new KTimerAdapter();
		} catch (Throwable t) {
			return new JTimerAdapter();
		}
	}

	public abstract Object newTimer();
	public abstract Object newTimerTask(final Runnable runnable);
	public abstract void schedule(Object timerObject, Object timerTaskObject, long delay, long period);
	public abstract void cancel(Object timerObject);
}
