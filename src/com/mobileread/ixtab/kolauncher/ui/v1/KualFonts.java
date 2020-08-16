package com.mobileread.ixtab.kolauncher.ui.v1;

import java.awt.Component;
import java.awt.Font;
import java.awt.FontMetrics;
import java.io.File;
import java.util.HashMap;
import java.util.Map;

public class KualFonts {

	public final Font defaultFont;
	public final FontMetrics defaultFontMetrics;
	public final Font unicodeFont;
	public final FontMetrics unicodeFontMetrics;

	private static final Map INSTANCES = new HashMap();

	private KualFonts(Font defaultFont, FontMetrics defaultFontMetrics,
			Font unicodeFont, FontMetrics unicodeFontMetrics) {
		super();
		this.defaultFont = defaultFont;
		this.defaultFontMetrics = defaultFontMetrics;
		this.unicodeFont = unicodeFont;
		this.unicodeFontMetrics = unicodeFontMetrics;
	}

	public static KualFonts getInstance(Component caller) {

		KualFonts result = (KualFonts) INSTANCES.get(caller.getClass());
		if (result == null) {
			synchronized (KualFonts.class) {
				Font callerFont = caller.getFont();
				// Try to use the user requested font...
				Font defaultFont = new Font(KUIAdapter.getUserFontFamily(), KUIAdapter.getUserFontStyle(), callerFont.getSize());
				// Restore default (caller) font if the requested font isn't supported... (Which will happen w/ default settings, since we ask for Futura)
				// Note that we detect this in a slightly more convoluted way than on KDK-2... If family is dialog but name isn't, then it's a bogus font.
				if (defaultFont.getFamily().equals("dialog") && !defaultFont.getName().equals("dialog")) {
					defaultFont = callerFont;
				}
				FontMetrics defaultFontMetrics = caller
						.getFontMetrics(defaultFont);
				Font unicodeFont = null;
				FontMetrics unicodeFontMetrics = null;

				try {
					/*
					 * FW 2.x doesn't ship with code2000. Use symbol instead, or
					 * we lose the pretty unicode arrows.
					 */
					if (new File("/usr/java/lib/fonts/code2000.ttf").exists()) {
						unicodeFont = new Font("code2000",
								defaultFont.getStyle(), defaultFont.getSize());
					} else {
						unicodeFont = new Font("symbol",
								defaultFont.getStyle(), defaultFont.getSize());
					}
					unicodeFontMetrics = caller.getFontMetrics(unicodeFont);
				} catch (Throwable t) {
					// if anything went wrong, we can't do much about it.
					unicodeFont = null;
					unicodeFontMetrics = null;
				}
				result = new KualFonts(defaultFont, defaultFontMetrics,
						unicodeFont, unicodeFontMetrics);
				INSTANCES.put(caller.getClass(), result);
			}
		}
		return result;
	}

	public boolean isNonUnicode(char[] chars) {
		return unicodeFont == null || isAsciiText(chars);
	}

	public boolean isAsciiText(char[] chars) {
		for (int i = 0; i < chars.length; ++i) {
			if (isUnicode(chars[i])) {
				return false;
			}
		}
		return true;
	}

	private boolean isUnicode(char c) {
		return c > 255;
	}

	public int[] calculateOffsets(char[] chars) {
		int[] offsets = new int[chars.length + 1];
		FontMetrics fm;
		for (int i = 1; i <= chars.length; ++i) {
			char c = chars[i - 1];
			fm = isUnicode(c) ? unicodeFontMetrics : defaultFontMetrics;
			offsets[i] = offsets[i - 1] + fm.charWidth(c);
		}
		return offsets;
	}

	public Font getFontFor(char c) {
		return isUnicode(c) ? unicodeFont : defaultFont;
	}

}
