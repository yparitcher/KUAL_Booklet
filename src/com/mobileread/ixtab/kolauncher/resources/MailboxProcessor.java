package com.mobileread.ixtab.kolauncher.resources;

import java.io.BufferedReader;
import java.io.File;

import com.mobileread.ixtab.kolauncher.Util;
import com.mobileread.ixtab.kolauncher.timer.TimerAdapter;

public class MailboxProcessor {

	private KualMenu km;
	private int eventId;
	private MailboxCommand command;
	private long delay;
	private long period;
	private int countdown;

	private String mailboxPath;
	private final TimerAdapter tmi = getTimer();
	private final Object timer = tmi.newTimer();
	private String message = null;
	private BufferedReader mailbox = null;

	// constructors
	public MailboxProcessor(KualMenu km, int eventId, MailboxCommand command,
			long delay, long period, int countdown) {
		this.km = km;
		this.eventId = eventId; //eventId range ['0'..'9'] !
		this.command = command;
		this.delay = delay;
		this.period = period;
		this.countdown = countdown;
		this.mailboxPath = km.getMailboxPath();

		if (0 < countdown) { //backgrounded
			monitor();
		} else { //foregrounded
			if (0 < delay) { // this only blocks
				try {
					Thread.sleep(delay);
				} catch(InterruptedException t){
					//
				}
			}
			if (isRinging()) {
				if (null != message)
					process(command);
				resetMailbox();
			}
		}
	}

	// methods
	private static TimerAdapter getTimer() {
		return TimerAdapter.INSTANCE;
	}

	private void monitor() {
		Runnable runnable = new Runnable() {
			public void run() {
				boolean gotMail = isRinging();
				if (gotMail || --countdown <= 0)
					tmi.cancel(timer);
				if (null != message)
					process(command);
				if (gotMail)
					resetMailbox();
			}
		};

		// Monitoring ends upon finding a message in the mailbox
		// or when the mailbox check countdown runs to zero.
		Object task = tmi.newTimerTask(runnable);
		tmi.schedule(timer, task, delay, period);
	}

	private void resetMailbox() throws RuntimeException {
		try {
			mailbox.close();
			File f = new File(mailboxPath);
			f.delete();
		} catch (Throwable t) {
			throw new RuntimeException(t);
		}
	}

	private boolean isRinging() {
		// did the backgrounded parser script send me mail?
		mailbox = Util.sureFileReader(mailboxPath);
		if (null != mailbox) {
			try {
				message = mailbox.readLine();
				// caller must check for null message on return
			} catch (Throwable t) {
				message = null;
			}
			return true;
			// mailbox intentionally left open
		}
		return false;
	}

	public void callCommand(MailboxCommand command, Object data) {
		command.execute(data);
	}

	private void process(MailboxCommand command) {
		try {
			if (null != mailbox)
				mailbox.close();
		} catch (Throwable t) {
		}
		if (null == message)
			return;
		int id = message.charAt(0);
		if (eventId == id) {
			switch (id) {
			case '1': // read new cache from this fullpathname
				BufferedReader cacheReader = Util.sureFileReader(message.substring(2));
				if (null != cacheReader) {
					callCommand(command, cacheReader);
					//cacheReader.close();
				}
				break;
			}
		}
	}
}
