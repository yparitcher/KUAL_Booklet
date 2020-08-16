package com.mobileread.ixtab.kolauncher.ui.v1;

import java.awt.Component;
import java.awt.FontMetrics;
import java.awt.Graphics;

public class KualPainter {
	private KualPainter() {
	};

	public static void paint(Graphics graphics, KualPaintable paintable) {
		Component component = (Component) paintable;
		KualFonts fonts = KualFonts.getInstance(component);
		paintable.paintBorder(graphics);
		graphics.setColor(paintable.getTextColor());

		String text = paintable.getText();
		char[] chars = text.toCharArray();

		float alignX = paintable.getTextAlignmentX();
		float alignY = paintable.getTextAlignmentY();

		/*
		 * Implementation note: why do we go through all of this? Because
		 * Graphics.drawString() is still the preferred method of drawing
		 * strings. The documentation of the JDK itself says that painting
		 * characters one after another is discouraged, because it may not
		 * always yield perfect results. However, if we have to mix non-unicode
		 * and unicode characters, we normally have to do this, because code2000
		 * looks rather ugly for plain ASCII characters, whereas other fonts
		 * can't display Unicode characters properly. So, "choose your poison" -
		 * or go with the slightly suboptimal, but satisfactory, solution below.
		 */
		if (fonts.isNonUnicode(chars)) {
			// simple case: no Unicode needed or available, so we just do
			// everything with the default font.
			int textX = 0;
			if (alignX == Component.CENTER_ALIGNMENT) {
				textX = (component.getWidth() / 2)
						- (fonts.defaultFontMetrics.stringWidth(text) / 2);
			}

			int textY = 0;
			if (alignY == Component.CENTER_ALIGNMENT) {
				textY = getCenteredTextYPosition(fonts.defaultFontMetrics,
						component.getHeight());
			}
			graphics.setFont(fonts.defaultFont);
			graphics.drawString(text, textX, textY);
		} else {
			// general case: Unicode available, and at least one Unicode
			// character in text
			int textX = 0;
			int[] offsets = fonts.calculateOffsets(chars);
			if (alignX == Component.CENTER_ALIGNMENT) {
				textX = (component.getWidth() / 2)
						- (offsets[chars.length] / 2);
			}
			int textY = 0;
			if (alignY == Component.CENTER_ALIGNMENT) {
				textY = getCenteredTextYPosition(fonts.unicodeFontMetrics,
						component.getHeight());
			}
			for (int i = 0; i < chars.length; ++i) {
				graphics.setFont(fonts.getFontFor(chars[i]));
				graphics.drawChars(chars, i, 1, textX + offsets[i], textY);
			}
		}
	}

	private static int getCenteredTextYPosition(FontMetrics fm, int height) {
		// http://stackoverflow.com/questions/1055851/how-do-you-draw-a-string-centered-vertically-in-java
		return height + ((0 + 1 - height) / 2) - 1
				- (fm.getAscent() + fm.getDescent()) / 2 + fm.getAscent();
	}

}
