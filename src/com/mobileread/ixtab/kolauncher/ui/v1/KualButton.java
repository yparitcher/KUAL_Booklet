package com.mobileread.ixtab.kolauncher.ui.v1;

import java.awt.Button;
import java.awt.Color;
import java.awt.Component;
import java.awt.Graphics;

import com.mobileread.ixtab.kolauncher.resources.KualEntry;

public class KualButton extends Button implements KualPaintable {

	private static final long serialVersionUID = 1L;

	private static final int BORDER_PX = 2;
	private static final int GAP_PX = 0;
	private static final int ARC_PX = 15;

	private KualEntry kualEntry = null;

	public KualButton(String text, KualEntry kualEntry) {
		super(text);
		this.kualEntry = kualEntry;
	}

	public KualEntry getKualEntry() {
		return this.kualEntry;
	}

	public void paint(Graphics g) {
		KualPainter.paint(g, this);
	}

	public Color getTextColor() {
		return isEnabled() ? hasFocus() ? COLOR_BACKGROUND : COLOR_FOREGROUND : COLOR_DISABLED;
	}

	public void paintBorder(Graphics g) {
		Color foreground = isEnabled() ? COLOR_FOREGROUND : COLOR_DISABLED;
		Color background = COLOR_BACKGROUND;
		int width = getWidth();
		int height = getHeight();
		g.setColor(foreground);
		g.fillRoundRect(GAP_PX, GAP_PX, width - GAP_PX * 2,
				height - GAP_PX * 2, ARC_PX, ARC_PX);

		if (!hasFocus()) {
			g.setColor(background);
			g.fillRoundRect(GAP_PX + BORDER_PX, GAP_PX + BORDER_PX, width
					- (GAP_PX + BORDER_PX) * 2, height - (GAP_PX + BORDER_PX)
					* 2, ARC_PX, ARC_PX);
		}
	}

	public String getText() {
		return getLabel();
	}

	public float getTextAlignmentX() {
		return Component.CENTER_ALIGNMENT;
	}

	public float getTextAlignmentY() {
		return Component.CENTER_ALIGNMENT;
	}
}
