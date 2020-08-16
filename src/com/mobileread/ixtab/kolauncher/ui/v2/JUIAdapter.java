package com.mobileread.ixtab.kolauncher.ui.v2;

import java.awt.Component;
import java.awt.Container;
import java.awt.Font;
import java.awt.LayoutManager;
import java.awt.event.ActionListener;
import java.awt.event.KeyListener;

import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;


import com.mobileread.ixtab.kolauncher.ui.UIAdapter;
import com.amazon.kindle.booklet.BookletContext;
import com.mobileread.ixtab.kolauncher.resources.KualEntry;

public class JUIAdapter extends UIAdapter {

	private static Font defaultFont;
	private static Font userFont;

	// Die in a fire, Helvetica!
	public void setupUserFont(Container root, String fontFamily, int fontStyle) {
		defaultFont = root.getFont();
		userFont = new Font(fontFamily, fontStyle, defaultFont.getSize());
		// Restore default font if the requested font isn't supported...
		if (userFont.getFamily().equals(defaultFont.getFamily()))
			userFont = defaultFont;
	}

	public Container newPanel(LayoutManager layout) {
		return layout != null ? new JPanel(layout) : new JPanel();
	}

	public Component newLabel(String text) {
		JLabel label = new JLabel(text);
		label.setFont(userFont);
		return label;
	}

	public Component newButton(String text, ActionListener listener, KeyListener keyListener, KualEntry kualEntry) {
		JButton button = new KualButton(text, kualEntry);
		button.setFont(userFont);
		if (listener != null) {
			button.setName(text);
			button.addActionListener(listener);
		}
		// No physical keys on these devices, don't do anything with the KeyListener...
		return button;
	}

	public void setText(Component component, String text) {
		if (component instanceof JLabel) {
			((JLabel) component).setText(text);
		}
		if (component instanceof JButton) {
			((JButton) component).setText(text);
		}
	}

	public void suicide(BookletContext context) {
		try {
			// Until something better turns up...
			Runtime.getRuntime()
					.exec("lipc-set-prop com.lab126.appmgrd stop app://com.lab126.booklet.kindlet");
		} catch (Throwable ex) {
		}
	}

	public int getDefaultPageSize() {
		// these are Touch models, so having more information on one page seems reasonable.
		return 10;
	}

	public KualEntry getKualEntry(Component component) {
		if (component instanceof KualButton)
			return ((KualButton) component).getKualEntry();
		return null;
	}
}
