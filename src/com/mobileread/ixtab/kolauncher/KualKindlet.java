package com.mobileread.ixtab.kindlelauncher;

import ixtab.jailbreak.Jailbreak;
import ixtab.jailbreak.SuicidalKindlet;

import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Container;
import java.awt.EventQueue;
import java.awt.Font;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Date;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;

import com.amazon.kindle.kindlet.KindletContext;
import com.amazon.kindle.kindlet.event.KindleKeyCodes;
import com.mobileread.ixtab.kindlelauncher.resources.KualEntry;
import com.mobileread.ixtab.kindlelauncher.resources.KualLog;
import com.mobileread.ixtab.kindlelauncher.resources.KualMenu;
import com.mobileread.ixtab.kindlelauncher.resources.MailboxCommand;
import com.mobileread.ixtab.kindlelauncher.resources.MailboxProcessor;
import com.mobileread.ixtab.kindlelauncher.resources.ResourceLoader;
import com.mobileread.ixtab.kindlelauncher.timer.TimerAdapter;
import com.mobileread.ixtab.kindlelauncher.ui.GapComponent;
import com.mobileread.ixtab.kindlelauncher.ui.UIAdapter;

public class KualKindlet extends SuicidalKindlet implements ActionListener {

	public static final String RESOURCE_PARSER_SCRIPT = "parse.awk"; // "parse.sh";
	private static final String EXEC_PREFIX_PARSE = "klauncher_parse-";
	private static final String EXEC_PREFIX_BACKGROUND = "klauncher_background-";
	private static final String EXEC_EXTENSION_SH = ".sh";
	private static final String EXEC_EXTENSION_AWK = ".awk";
	private static final long serialVersionUID = 1L;
	// Handle the privilege hint prefix...
	private static String PRIVILEGE_HINT_PREFIX = "?";

	private static final int VK_KEYBOARD = 17; /* K4: We should be using getKeyboardKeyCode() here, but it's KDK 1.3 only */

	private static final int PAGING_PREVIOUS = -1;
	private static final int PAGING_NEXT = 1;
	private static final int LEVEL_PREVIOUS = -1;
	private static final int LEVEL_NEXT = 1;
	private KualMenu kualMenu;
	// Viewport on kualMenu at current depth
	// . set in updateDisplayedLauncher()
	// . used in getEntriesCount()
	private final ArrayList viewList = new ArrayList();

	private KindletContext context;
	private boolean started = false;
	private String commandToRunOnExit = null;
	private String dirToChangeToOnExit = null;

	final String CROSS = "\u00D7"; // × - match parser script
	final String ATTN = "\u25CF"; // ● - match parser script
	final String RARROW = "\u25B6"; // ▶
	final String LARROW = "\u25C0"; // ◀
	final String UARROW = "\u25B2"; // ▲
	final String BULLET = "\u25AA"; // ▪
	final String PATH_SEP = "/";

	private KeyListener keyListener = new KeyAdapter() {
		public void keyPressed(KeyEvent e) {
			switch (e.getKeyCode()) {
			case KindleKeyCodes.VK_RIGHT_HAND_SIDE_TURN_PAGE:
			case KindleKeyCodes.VK_LEFT_HAND_SIDE_TURN_PAGE:
				handlePaging(PAGING_NEXT, depth, true);
				break;
			case KindleKeyCodes.VK_TURN_PAGE_BACK: /* 61450 */
			case 61452: /* K4: KindleKeyCodes.VK_LEFT_HAND_SIDE_TURN_PAGE_BACK in KDK 1.3. See also *DistinctTurnPageBackKeyCodes*() */
				handleLevel(LEVEL_PREVIOUS, true);
				break;
			case KeyEvent.VK_1:
			case KeyEvent.VK_Q:
				handleButtonSelect(1, true);
				break;
			case KeyEvent.VK_2:
			case KeyEvent.VK_W:
				handleButtonSelect(2, true);
				break;
			case KeyEvent.VK_3:
			case KeyEvent.VK_E:
				handleButtonSelect(3, true);
				break;
			case KeyEvent.VK_4:
			case KeyEvent.VK_R:
				handleButtonSelect(4, true);
				break;
			case KeyEvent.VK_5:
			case KeyEvent.VK_T:
				handleButtonSelect(5, true);
				break;
			case KeyEvent.VK_6:
			case KeyEvent.VK_Y:
				handleButtonSelect(6, true);
				break;
			case KeyEvent.VK_7:
			case KeyEvent.VK_U:
				handleButtonSelect(7, true);
				break;
			case KeyEvent.VK_8:
			case KeyEvent.VK_I:
				handleButtonSelect(8, true);
				break;
			case KeyEvent.VK_9:
			case KeyEvent.VK_O:
				handleButtonSelect(9, true);
				break;
			case KeyEvent.VK_0:
			case KeyEvent.VK_P:
				handleButtonSelect(10, true);
				break;
			case KeyEvent.VK_ENTER:
			case KeyEvent.VK_SPACE:
				handleLauncherButton((Component) e.getSource(), depth);
				break;
			case KindleKeyCodes.VK_TEXT:
			case VK_KEYBOARD:
				handleButtonSelect(-1, false);
				break;
			case KindleKeyCodes.VK_MENU:
				handleButtonSelect(99, false);
				break;
			}
			// Always check for news, because apparently we bypass actionPerformed...
			new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), 0, 0, 0);
		}
	};

	private Container entriesPanel;
	private Component status = null;
	private Component nextPageButton = getUI().newButton("  " + RARROW + "  ",
			this, keyListener, null);
	private Component prevPageButton = getUI().newButton("  " + UARROW + "  ",
			this, keyListener, null);
	private Component breadcrumb;

	private KualEntry toTopEntry;
	private Component toTopButton;
	private KualEntry quitEntry;
	private Component quitButton;

	private int[] offset = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }; // 10
	private KualEntry[] keTrail = { null, null, null, null, null, null, null,
			null, null, null }; // 10
	private int depth = 0;

	protected Jailbreak instantiateJailbreak() {
		return new LauncherKindletJailbreak();
	}

	public void onCreate(KindletContext context) {
		super.onCreate(context);
		this.context = context;
	}

	public void onStart() {
		/*
		 * This method might be called multiple times, but we only need to
		 * initialize once. See Kindlet lifecycle diagram:
		 */
		// https://kdk-javadocs.s3.amazonaws.com/2.0/com/amazon/kindle/kindlet/Kindlet.html

		// Go as quickly as possible through here.
		// The kindlet is given 5000 ms maximum to start.

		if (started) {
			return;
		}
		super.onStart();
		started = true;

		String error = getJailbreakError();
		if (error != null) {
			displayErrorMessage(error);
			return;
		}

		// postpone longer initialization for quicker return
		Runnable runnable = new Runnable() {
			public void run() {
				KualKindlet.this.longStart();
			}
		};
		EventQueue.invokeLater(runnable);
	}

	private void longStart() {
		/*
		 * High-level description of KUAL flow
		 *
		 * 1. kindlet: spawn the parser then block waiting for input from the
		 * parser. 2. parser: send the kindlet cached data so the kindlet can
		 * quickly move on to initialize the UI. 3. kindlet: initialize UI and
		 * display the menu. 4. kindlet: schedule a 20-time-repeat 500ms
		 * timer task which checks for messages from the parser. 5. parser:
		 * (while the kindlet is initializing the UI) parse menu files and
		 * refresh the cache. 6: parser: if the fresh cache differs from the
		 * cache sent in step 2 then post the kindlet a message 7: parser: exit
		 * 8: kindlet: if the timer found a message in the mailbox update the
		 * menu from the fresh cache and re-display UI. 9: kindlet: loop: wait
		 * for user interaction; handle interaction.
		 */
		try {
			initializeState(); // step 1
			initializeUI(); // step 3
			// Monitor messages from backgrounded script. Monitoring ends in 10
			// s. (20 * 500ms)
			// Thereafter check the mailbox on each button event in
			// actionPerformed().
			new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(),
					1000, 500, 20); // steps 4,8
		} catch (Throwable t) {
			throw new RuntimeException(t);
		}
	}

	private void setStatus(String text) {
		if (null == status)
			setBreadcrumb(text, null);
		else
			getUI().setText(status, text);
	}

	private void setBreadcrumb(String left, String center) {
		String text = null == left ? "" : left + " ";
		if (null != center) {
			text += center;
		} else if (0 == depth) {
			text += PATH_SEP;
		} else {
			String label = keTrail[depth - 1].getBareLabel();
			int width = getTrailMaxWidth() - text.length();
			for (int i = depth - 2; i >= 0 && label.length() <= width; i--) {
				label = keTrail[i].getBareLabel() + PATH_SEP + label;
			}
			label = PATH_SEP + label;
			int len = label.length();
			if (len > width)
				label = "..." + label.substring(len - width + 3);
			text += label;
		}
		// Add the privilege hint...
		text = PRIVILEGE_HINT_PREFIX + " " + BULLET + " " + text;
		getUI().setText(breadcrumb, text);
	}

	private static UIAdapter getUI() {
		return UIAdapter.INSTANCE;
	}

	private void initializeUI() {
		Container root = context.getRootContainer();
		int gap = getUI().getGap();
		root.removeAll();

		// Check current privileges...
		String currentUsername = System.getProperty("user.name");
		if ("root".equals(currentUsername)) {
			PRIVILEGE_HINT_PREFIX = "#";
		} else {
			if (new File("/var/local/mkk/gandalf").exists()) {
				PRIVILEGE_HINT_PREFIX = "$";
			} else {
				PRIVILEGE_HINT_PREFIX = "%";
			}
		}

		// Setup custom fonts now
		String userReqFamily = kualMenu.getConfig("font_family");
		if (null == userReqFamily) {
			// Defaults to Futura
			// I wish we could use Futura DemiBold, but Amazon's fontconfig setup smushes it into the Futura family, with a custom demibold style...
			// Meaning we can't access it in Java, and apparently we can't do it ourselves either because createFont isn't supported... :/
			userReqFamily = "Futura";
		}
		String userReqStyle = kualMenu.getConfig("font_style");
		if (null == userReqStyle) {
			// Defaults to Regular
			userReqStyle = "Regular";
		}
		// Fugly way to make that style into something Java actually handles...
		int userFontStyle;
		if (userReqStyle.equals("BoldItalic")) {
			userFontStyle = Font.BOLD + Font.ITALIC;
		} else if (userReqStyle.equals("Bold")) {
			userFontStyle = Font.BOLD;
		} else if (userReqStyle.equals("Italic")) {
			userFontStyle = Font.ITALIC;
		} else {
			// Defaults to Regular
			userFontStyle = Font.PLAIN;
		}
		getUI().setupUserFont(root, userReqFamily, userFontStyle);

		// Only initialize that now to honor the user's font...
		breadcrumb = getUI().newLabel(PATH_SEP);
		// Same deal with those default buttons...
		toTopEntry = new KualEntry(1, PATH_SEP);
		toTopButton = getUI().newButton(PATH_SEP, this, keyListener, toTopEntry);
		quitEntry = new KualEntry(2, CROSS + " Quit");
		quitButton = getUI().newButton(CROSS + " Quit", this, keyListener, quitEntry);

		root.setLayout(new BorderLayout(gap, gap));
		Container main = getUI().newPanel(new BorderLayout(gap, gap));

		// this is a horrible workaround to simulate adding a border around
		// the main container. It has to be done this way because we have
		// to support different framework versions.

		root.add(main, BorderLayout.CENTER);
		root.add(new GapComponent(0), BorderLayout.NORTH);
		root.add(new GapComponent(0), BorderLayout.EAST);
		root.add(new GapComponent(0), BorderLayout.SOUTH);
		root.add(new GapComponent(0), BorderLayout.WEST);

		main.add(prevPageButton, BorderLayout.WEST);
		main.add(nextPageButton, BorderLayout.EAST);

		String show = kualMenu.getConfig("no_show_status");
		if (null != show && show.equals("true")) {
			status = null;
		} else {
			status = getUI().newLabel("Status");
			main.add(status, BorderLayout.SOUTH);
		}
		main.add(breadcrumb, BorderLayout.NORTH);

		GridLayout grid = new GridLayout(getPageSize(), 1, gap, gap);
		entriesPanel = getUI().newPanel(grid);

		main.add(entriesPanel, BorderLayout.CENTER);

		// FOR TESTING ONLY, if a specific number of entries is needed.
		// for (int i = 0; i < 25; ++i) {
		// leveleMap[depth].put("TEST-" + i, "touch /tmp/test-" + i + ".tmp");
		// }

		updateDisplayedLaunchers(depth = 0, true, null);
	}

	private void initializeState() throws IOException, InterruptedException,
			Exception {

		cleanupTemporaryDirectory();
		runParser();
	}

	private void runParser() throws IOException, InterruptedException,
			Exception {
		// run the parser script and read its output (we may get cached data)
		File parseFile = extractParseFile();
		BufferedReader reader = Util.execute(parseFile.getAbsolutePath());
		readParser(reader);
		reader.close();

		// Do not delete the script file because it is updating the cache
		// in the background.
		// Let cleanupTemporaryDirectory() take care of it next time.
	}

	private void readParser(BufferedReader reader) throws IOException,
			InterruptedException, Exception {

		// Read menu records to initialize menu entries.
		kualMenu = new KualMenu(reader);

		// Reset navigation helpers.
		// keTrail[] - stack of menu entries, one for each node of the current
		// menu path
		// depth - keTrail top index
		for (int i = 0; i < 10; i++) {
			keTrail[i] = null;
		}
		depth = 0;
	}

	private File extractParseFile() throws IOException, FileNotFoundException {
		InputStream script = ResourceLoader.load(RESOURCE_PARSER_SCRIPT);
		File parseInput = File.createTempFile(EXEC_PREFIX_PARSE,
				EXEC_EXTENSION_AWK);// EXEC_EXTENSION_SH);

		OutputStream cmd = new FileOutputStream(parseInput);
		Util.copy(script, cmd);
		return parseInput;
	}

	private void displayErrorMessage(String error) {
		Container root = context.getRootContainer();
		root.removeAll();

		Component message = getUI().newLabel(error);
		message.setFont(new Font(message.getFont().getName(), Font.BOLD,
				message.getFont().getSize() + 6));
		root.setLayout(new GridBagLayout());

		GridBagConstraints gbc = new GridBagConstraints();
		gbc.gridx = 0;
		gbc.fill = GridBagConstraints.HORIZONTAL;
		gbc.fill |= GridBagConstraints.VERTICAL;
		gbc.weightx = 1.0;
		gbc.weighty = 1.0;

		root.add(message, gbc);
	}

	private void killKnownOffenders(Runtime rtime) {
		// Let's tidy up some known offenders...
		// Call this right before executing a menu action
		String offenders = "matchbox-keyboard kterm skipstone cr3";
		try {
			rtime.exec("/usr/bin/killall " + offenders, null); // gently
			rtime.exec("/usr/bin/killall -9 " + offenders, null); // forcefully
		} catch (Throwable t) {
			new KualLog().append(t.toString());
			setStatus("Exception logged.");
		}
	}

	private void cleanupTemporaryDirectory() {
		File tmpDir = new File("/tmp");

		File[] files = tmpDir.listFiles();

		for (int i = 0; i < files.length; i++) {
			if (files[i].isFile()) {
				String file = files[i].getName();
				if (file.startsWith(EXEC_PREFIX_BACKGROUND)
						|| file.startsWith(EXEC_PREFIX_PARSE)) {
					files[i].delete();
				}
			}
		}
	}

	private String getJailbreakError() {
		if (!jailbreak.isAvailable()) {
			return "Mobileread Kindlet Kit is not installed";
		}
		if (!jailbreak.isEnabled()) {
			return "MKK could not enable Kindlet Jailbreak";
		}
		return null;
	}

	public void actionPerformed(ActionEvent e) {
		Component button = (Component) e.getSource();
		if (button == prevPageButton) {
			handleLevel(LEVEL_PREVIOUS, false);
			// changes offset[] and depth
		} else if (button == nextPageButton) {
			handlePaging(PAGING_NEXT, depth, false);
			// changes offset[]
		} else {
			handleLauncherButton(button, depth);
			// on submenu button it calls handleLevel()
		}

		// foreground, non-blocking check for background menu updates
		new MailboxProcessor(kualMenu, '1', new ReloadMenuFromCache(), 0, 0, 0);
	}

	private void handlePaging(int direction, int level, boolean resetFocus) {
		// direction is supposed to be -1 (backward) or +1 (forward),
		int newOffset = offset[level] + getPageSize() * direction;
		// DEBUG del//setBreadcrumb("olv("+offset[level]+")new("+newOffset+")");
		if (newOffset < 0) {
			// the largest possible multiple of the page size.
			newOffset = getEntriesCount(level);
			newOffset -= newOffset % getPageSize();
			// boundary case
			if (newOffset == getEntriesCount(level)) {
				newOffset -= getPageSize();
			}
		} else if (newOffset >= getEntriesCount(level)) {
			newOffset = 0;
		}
		if (newOffset == offset[level]) {
			return;
		}
		offset[level] = newOffset;
		updateDisplayedLaunchers(level, false, resetFocus ? null
				: (PAGING_PREVIOUS == direction ? prevPageButton
					: nextPageButton));
	}

	private void handleButtonSelect(int buttonIndex, boolean clickIt) {
		// All our shiny buttons!
		Component[] buttons = entriesPanel.getComponents();
		int maxButtons = buttons.length;

		// Arrays are 0 indexed
		buttonIndex--;
		maxButtons--;

		// Clamp to the number of buttons on the current page
		buttonIndex = buttonIndex > maxButtons ? maxButtons : (buttonIndex < 0 ? 0 : buttonIndex);

		// Request focus on the selected button
		buttons[buttonIndex].requestFocus();
		// And click it if we asked
		if (clickIt) {
			handleLauncherButton(buttons[buttonIndex], depth);
		}
	}

	private void handleLevel(int direction, boolean resetFocus) {
		int goToLevel;
		int goToOffset;
		if (-1 == direction) { // return from submenu
			goToLevel = depth > 0 ? depth - 1 : 0;
			goToOffset = offset[goToLevel];
		} else { // drill into sub-menu
			KualEntry ke = keTrail[depth]; // origin
			goToLevel = ke.getGoToLevel();
			goToOffset = 0;
		}
		depth = goToLevel;
		offset[depth] = goToOffset;
		updateDisplayedLaunchers(depth, false, resetFocus ? null
				: (LEVEL_PREVIOUS == direction ? (0 >= depth ? null
					: prevPageButton)
						: null));
	}

	private static int viewLevel = -1;
	private static int viewOffset = -1;

	private void updateDisplayedLaunchers(int level, boolean resetViewport,
			Component focusRequestor) {

		if (resetViewport) {
			viewLevel = viewOffset = -1;
			for (int i = 0; i < 10; i++)
				offset[i] = 0;
			viewList.clear();
		}

		// load entries of the current level into the viewport
		if (viewLevel != level || viewOffset != offset[level]) {
			viewLevel = level;
			viewOffset = offset[level];
			viewList.clear();
			if (0 == level) {
				viewList.addAll(kualMenu.getLevel(0).keySet());
			} else {
				KualEntry ke = keTrail[level - 1];
				String parentLink = ke.getParentLink();
				Iterator it = kualMenu.getLevel(level).entrySet().iterator();
				while (it.hasNext()) {
					Map.Entry entry = (Entry) it.next();
					ke = (KualEntry) entry.getValue();
					if (ke.isLinkedUnder(parentLink))
						viewList.add(entry.getKey());
				}
			}
			// Hacky workaround to always count the extra toTop/quit button we
			// add at the end...
			viewList.add("inject_last_button");
		}

		Iterator it = viewList.iterator();

		// skip entries up to offset
		for (int i = 0; i < viewOffset; ++i) {
			if (it.hasNext()) {
				it.next();
			}
		}
		entriesPanel.removeAll();
		int end = viewOffset;

		// This button is appended at the end of the list.
		// Component nullButton = getUI().newButton("", null, null);
		// nullButton.setEnabled(false);
		toTopButton.setEnabled(true);
		quitButton.setEnabled(true);

		Component button;
		for (int i = getPageSize(); i > 0; --i) {
			if (it.hasNext()) {
				KualEntry ke = kualMenu.getEntry(level, it.next());
				// Handle our injected last button...
				if (null == ke) {
					button = 0 == level ? quitButton : toTopButton;
				} else {
					button = getUI().newButton(ke.label, this, keyListener, ke); // then
																					// getUI().getKualEntry(button)
																					// =>
																					// ke
				}
				if (null == focusRequestor) {
					focusRequestor = button;
				}
				++end;
				entriesPanel.add(button);

				// If we just added our injected last button, we're done.
				if (null == ke) {
					break;
				}
			} else {
				// Component button = getUI().newButton("", null, null, null);
				// // fills whole column
				// Component button = nullButton; // shortens column after last
				// entry
				button = 0 == level ? quitButton : toTopButton;
				++end;
				entriesPanel.add(button);

				// Add a dummy entry to the list to make viewList.size()
				// consistent...
				viewList.add("foo_last_button");

				// Don't needlessly add the last button 'til the bottom of the
				// page.
				break;
			}
		}

		// weird shit: it's actually the setStatus() which prevents the Kindle
		// Touch from simply showing an empty list. WTF?!
		boolean enableButtons = getPageSize() < viewList.size();
		if (null != status) {
			setStatus("Entries " + (viewOffset + 1) + " - " + end + " of "
					+ viewList.size() + " " + BULLET + " " + kualMenu.getVersion() + " " + BULLET + " "
					+ kualMenu.getModel());
		}
		setBreadcrumb(null == status && enableButtons ? (viewOffset + 1) + "-"
				+ end + "/" + viewList.size() : null, null);
		prevPageButton.setEnabled(level > 0);
		nextPageButton.setEnabled(enableButtons);

		// just to be on the safe side
		entriesPanel.invalidate();
		entriesPanel.repaint();
		context.getRootContainer().invalidate();
		context.getRootContainer().repaint();

		// This is for 5-way controller devices.
		// It is essential to request focus _after_ the button has been
		// displayed!
		if (null != focusRequestor) {
			focusRequestor.requestFocus();
		}
	}

	private int getEntriesCount(int level) {
		return viewList.size() > 0 ? viewList.size() : kualMenu.getLevel(level)
				.size();
	}

	private static int onStartPageSize = -1; // tracks onStart() size, so
												// ReloadMenuFromCache can't
												// interfere

	private int getPageSize() {
		if (0 < onStartPageSize) {
			return onStartPageSize;
		}
		onStartPageSize = 0;
		String size = kualMenu.getConfig("page_size");
		if (null != size)
			try {
				onStartPageSize = Integer.parseInt((String) size);
			} catch (Throwable ignored) {
			}
		;
		if (0 == onStartPageSize) {
			onStartPageSize = getUI().getDefaultPageSize();
		}
		return onStartPageSize;
	}

	private int getTrailMaxWidth() {
		// A fixed value will never work in all situations because kindle uses
		// a proportional font; this is a best guess
		return 60; // FIXME
	}

	private void handleLauncherButton(Component button, int level) {
		boolean internalStatus = false;
		KualEntry ke = getUI().getKualEntry(button);
		if (ke.isSubmenu) { // drill into sub-menu
			keTrail[level] = ke;
			try {
				handleLevel(LEVEL_NEXT, false);
			} catch (Throwable t) {
				new KualLog().append(t.toString());
				setStatus("Exception logged.");
			}
		} else {
			// run internal action, if any, then action, if any
			if (ke.isInternalAction) {
				switch (ke.internalAction) {
				// 0-32 reserved for KualEntry(int, String) constructor
				// 'A', etc. defined in parser script
				case 0:
				case 'A': // extension displays message in breadcrumb line
					setBreadcrumb(ke.internalArgs + " | ", null);
					break;
				case 'B': // extension displays message in status line
					setStatus(ke.internalArgs);
					// Remember this, so we don't overwrite it if we ask for a refresh later...
					internalStatus = true;
					break;
				case 1: // go to top menu
					depth = 0;
					handleLevel(LEVEL_PREVIOUS, false);
					break;
				case 2: // quit
					// falls into ! option 'e'
					break;
				}
			}
			if (null != ke.action) {
				// run shell cmd. null may come from KualEntry(int, String)
				// constructor only
				// now is the right time to get rid of known offenders
				killKnownOffenders(Runtime.getRuntime());
				if (!ke.hasOption('s')) {
					// JSON "status":false
					setStatus(ke.action);
				}
				try {
					int beforeAction = 0; // TODO
					if (0 < beforeAction) {
						Thread.sleep(beforeAction);
					}

					if (!ke.hasOption('e')) {
						// JSON "exitmenu":true
						// suicide
						commandToRunOnExit = ke.action;
						dirToChangeToOnExit = ke.dir;
						getUI().suicide(context);
					} else {
						// survive
						execute(ke.action, ke.dir, true);
						int afterAction = 0; // TODO
						if (0 < afterAction) {
							Thread.sleep(afterAction);
						}
					}
				} catch (Throwable t) {
					new KualLog().append(t.toString());
					setStatus("Exception logged.");
				}
			}
		}

		//
		// placeholder for post-action internal actions
		//

		// process post-action options
		if (ke.hasOption('c')) {
			// JSON "checked":true - add checkmark to button label
			ke.setChecked(true);
			getUI().setText(button, ke.label);
		}
		if (ke.hasOption('r')) {
			// JSON "refresh":true - refresh and reload the menu
			// Default value for afterParser, cf. refreshMenu().
			long afterParser = 750L;
			// Add 750ms for legacy devices with slower CPU
			String model = kualMenu.getModel();
			if ("K2".equals(model) || "DX".equals(model) || "DXG".equals(model) || "K3".equals(model)) {
				afterParser += 750L;
			}
			// If we showed a custom status message, don't overwrite it!
			if (internalStatus) {
				refreshMenu(250L, afterParser, null);
			} else {
				refreshMenu(250L, afterParser, ke.label);
			}
		}
		if (ke.hasOption('d')) {
			// JSON "date":true - show date/time in status line
			Date now = new Date();
			setStatus(now.toString());
			// SimpleDateFormatter fmt = new SimpleDateFormatter();
			// setStatus(fmt.format("HH:mm:ss", now));
		}
		if (ke.hasOption('h')) {
			// "hidden" not implemented
		}
	}

	private Process execute(String cmd, String dir, boolean background)
			throws IOException, InterruptedException {

		File workingDir = new File(dir);
		if (!workingDir.isDirectory()) {
			new KualLog().append("directory '" + dir + "' not found");
			return null;
		}
		File launcher = createLauncherScript(cmd, background, "");
		// Call Gandalf for help if need be...
		if ("$".equals(PRIVILEGE_HINT_PREFIX)) {
			return Runtime.getRuntime().exec(
					new String[] { "/var/local/mkk/su", "-s", "/bin/ash", "-c", launcher.getAbsolutePath() }, null,
					workingDir);
		} else {
			return Runtime.getRuntime().exec(
					new String[] { "/bin/sh", launcher.getAbsolutePath() }, null,
					workingDir);
		}
	}

	protected void onStop() {
		/*
		 * This should really be run on the onDestroy() method, because onStop()
		 * might be invoked multiple times. But in the onDestroy() method, it
		 * just won't work. Might be related with what the life cycle
		 * documentation says about not holding files open etc. after stop() was
		 * called. Anyway: seems to work, since we only set commandToRunOnExit at
		 * very specific times, where we'll always exit right after, so we can't really
		 * fire a random command during an unexpected stop event ;).
		 */
		if (commandToRunOnExit != null) {
			try {
				execute(commandToRunOnExit, dirToChangeToOnExit, true);
				// FIXME: This is apparently sometimes (?) a bit racy with onDestroy(), so sleep for a teeny tiny bit...
				Thread.sleep(175);
			} catch (Exception ignored) {
				// can't do much, really. Too late for that :-)
			}
			commandToRunOnExit = dirToChangeToOnExit = null;
		}
		super.onStop();
	}

	public void onDestroy() {
		// Try to cleanup behind us on exit...
		try {
			// FIXME: This is apparently sometimes (?) a bit racy with onStop(), so sleep for a tiny bit...
			Thread.sleep(175);
			cleanupTemporaryDirectory();
		} catch (Exception ignored) {
			// Avoid the framework shouting at us...
		}

		super.onDestroy();
	}

	private File createLauncherScript(String cmd, boolean background,
			String init) throws IOException {
		File tempFile = java.io.File.createTempFile(EXEC_PREFIX_BACKGROUND,
				EXEC_EXTENSION_SH);

		BufferedWriter bw = new BufferedWriter(new FileWriter(tempFile));
		bw.write("#!/bin/ash");
		bw.newLine();

		// wrap cmd inside {} to support backgrounding multiple commands and
		// redirecting stderr
		bw.write("{ " + init + cmd + " ; } 2>>/var/tmp/KUAL.log"
				+ (background ? " &" : ""));

		bw.newLine();
		bw.close();

		// Make it executable... And of course, we can't use setExecutable(), so do it the fugly way...
		Runtime.getRuntime().exec("chmod +x " + tempFile.getAbsolutePath(), null);
		return tempFile;
	}

	public class ReloadMenuFromCache implements MailboxCommand {
		public void execute(Object data) {
			setBreadcrumb("Loading new menu " + ATTN + " Please wait...", "");
			setStatus("Loading...");
			try {
				readParser((BufferedReader) data);
				updateDisplayedLaunchers(depth = 0, true, null);
				setStatus("New menu loaded. Please go to top.");
			} catch (Throwable t) {
				new KualLog().append(t.toString());
				setStatus("Exception logged.");
			}
		}
	}

	public void refreshMenu(final long beforeParser, final long afterParser,
			String requestor) throws RuntimeException {
		setBreadcrumb("Refreshing the menu " + ATTN + " Please wait...", "");
		if (null != requestor)
			setStatus(requestor);

		final TimerAdapter tmi = TimerAdapter.INSTANCE;
		final Object timer = tmi.newTimer();
		Runnable runnable = new Runnable() {
			public void run() {

				// Here we *refresh* the menu by instantiating the parser then
				// reloading a
				// fresh cache. This enables extensions to dynamically change
				// the menu.
				try {
					// An extension that needs some time to stage the new menu
					// may set JSON
					// TODO JSON
					// sleep:"after_action,before_action,after_refresh,before_refresh"
					// in milliseconds, where
					// before_action/after_action refer to the time KUAL
					// *backgrounds* the user's action
					// before_refresh/refresh (default 250 ms) it's the delay
					// before tearing down the
					// current menu (a <250 value is allowed but not
					// recommended)
					// after_refresh (default 750 ms) is the time that the
					// parser takes to
					// build a new cache (750 ms is an average value)

					/*
					 * Goal: display a fresh menu with just one screen update.
					 * If we allowed more screen updates it would be enough to
					 * just say: initializeState(); initializeUI(): new
					 * MailboxProcessor(..., 1000, 500, 20). But since we aim
					 * at a single screen update more steps are involved.
					 */

					// Yield 250 ms to allow an extension to stage its menu
					// change.
					// Extension developers may set beforeParser to achieve a
					// longer pause.
					Thread.sleep(beforeParser > 0 ? beforeParser : 250);

					runParser(); // still sends the old cache while
									// background-building a new one

					// Wait long enough for the parser to complete building the
					// new cache then consume it.
					// Since we can't know how long that will take, we delay
					// consuming data from the parser
					// by afterParser ms (default 750). That's long enough for
					// a medium-sized extension folder.
					// Users with very large folders may need to increase
					// afterParser.
					new MailboxProcessor(kualMenu, '1',
							new ReloadMenuFromCache(), afterParser, 0, 0);

					/*
					initializeState(); // now the parser is even more likely to
										// send a fresh cache
					// initializeState() also cleans up temporary files
					*/
					// NOTE: AFAICT, there's no need to run a second parser, especially
					// since there's a good chance it will run concurrently with the
					// still running previous one from runParser(), which makes things
					// even slower...
					// Just clear tempfiles, the previous ReloadMenuFromCache() already
					// has consumed the new cache, or at worse the next one will.
					cleanupTemporaryDirectory();

					initializeUI(); // enables "hard" configuration changes such
									// as number of items per page
					// reaps a new cache one way or another - when it does the
					// user sees another screen update
					// Try that for 5s (20 * 250ms), after that, we'll rely on
					// actionPerformed or a keypress to trigger a refresh...
					new MailboxProcessor(kualMenu, '1',
							new ReloadMenuFromCache(), 0, 250, 20);
				} catch (Throwable t) {
					new KualLog().append(t.toString());
					setStatus("Exception logged.");
					throw new RuntimeException(t);
				}
				String text = "Menu refreshed.";
				setStatus(text);
				setBreadcrumb(text, null);
				tmi.cancel(timer);
			}
		};
		Object task = tmi.newTimerTask(runnable);
		tmi.schedule(timer, task, 0L, 250L);
	}
}
