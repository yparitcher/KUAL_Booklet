package com.mobileread.ixtab.kolauncher.ui.v1;

import java.awt.Color;
import java.awt.Component;
import java.awt.Graphics;

public interface KualPaintable {
	Color COLOR_FOREGROUND = Color.BLACK;
	Color COLOR_BACKGROUND = Color.WHITE;
	Color COLOR_DISABLED = Color.LIGHT_GRAY;

	void paintBorder(Graphics g);

	Color getTextColor();

	String getText();

	/**
	 * Horizontal text alignment. Note that <b>ONLY</b>
	 * {@link Component#LEFT_ALIGNMENT} and {@link Component#CENTER_ALIGNMENT}
	 * are supported right now, anything else will probably misbehave.
	 * 
	 * @return constant indicating horizontal text alignment.
	 */
	float getTextAlignmentX();

	/**
	 * Vertical text alignment. Note that <b>ONLY</b>
	 * {@link Component#CENTER_ALIGNMENT} is supported right now, anything else
	 * will probably misbehave.
	 * 
	 * @return constant indicating vertical text alignment.
	 */
	float getTextAlignmentY();

}
