package com.mobileread.ixtab.kolauncher.ui;

import java.awt.Component;
import java.awt.Container;
import java.awt.LayoutManager;
import java.awt.event.ActionListener;
import java.awt.event.KeyListener;

import com.amazon.kindle.booklet.BookletContext;
import com.mobileread.ixtab.kolauncher.resources.KualEntry;
import com.mobileread.ixtab.kolauncher.ui.v1.KUIAdapter;
import com.mobileread.ixtab.kolauncher.ui.v2.JUIAdapter;

/**
 * Generic Factory class for creating UI components. Since versions 1.x and 2.x
 * of the Kindlet specification radically differ (version 2.x supports standard
 * Java Swing components, while version 1.x uses home-brew substitutes for some
 * - and by far not all - components), this is the only way to create software
 * which runs on all devices.
 *
 * Fortunately, for this project, we don't need all that many types of UI
 * components. The idea of the methods in this class is to initialize the
 * components with everything that is required, so that standard AWT methods can
 * be used afterwards to wire everything up. IOW: implementation-specific
 * behavior should stay in this class, and its subclasses.
 */
public abstract class UIAdapter {
	public static final UIAdapter INSTANCE = createInstance();

	private static UIAdapter createInstance() {
		try {
			Class.forName("com.amazon.kindle.kindlet.ui.KPanel");
			return new KUIAdapter();
		} catch (Throwable t) {
			return new JUIAdapter();
		}
	}

	/**
	 * creates a new Panel with the given LayoutManager. The layout manager may
	 * be <tt>null</tt>, in which case the parameter is ignored.
	 *
	 * @param layout
	 *            the LayoutManager to use, or <tt>null</tt> if no layout
	 *            manager is to be used.
	 * @return a Container object compatible with the current runtime
	 *         environment, i.e., either a KPanel or a JPanel.
	 */
	public abstract Container newPanel(LayoutManager layout);

	public abstract Component newLabel(String text);

	public abstract Component newButton(String text, ActionListener listener, KeyListener keyListener, KualEntry kualEntry);

	public abstract void setText(Component component, String text);

	public abstract void suicide(BookletContext context);

	public abstract int getDefaultPageSize();

	public abstract KualEntry getKualEntry(Component component);

	public int getGap() {
		return 5;
	}

	public abstract void setupUserFont(Container root, String fontFamily, int fontStyle);
}
