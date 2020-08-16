package com.mobileread.ixtab.kolauncher.ui;

import java.awt.Component;
import java.awt.Dimension;

/**
 * This is a really ugly way of defining a UI component which doesn't do
 * anything, but wants some space on the screen. It's a workaround for not being
 * able to use borders -- essentially, putting one of these on every side
 * (NORTH, EAST, SOUTH, WEST) of a BorderLayout'ed container is roughly the same
 * as surrounding the CENTER'ed component with an appropriate border.
 * 
 * @author ixtab
 * 
 */
public class GapComponent extends Component {
	private static final long serialVersionUID = 1L;

	private final Dimension size;

	public GapComponent(int size) {
		this.size = new Dimension(size, size);
		this.setEnabled(false);
		this.setFocusable(false);
	}

	public Dimension getSize() {
		return size;
	}

	public Dimension getSize(Dimension rv) {
		return size;
	}

	public Dimension getPreferredSize() {
		return size;
	}

	public Dimension getMinimumSize() {
		return size;
	}

	public Dimension getMaximumSize() {
		return size;
	}
}
