package com.mobileread.ixtab.kolauncher.ui.v2;

import javax.swing.JButton;
import com.mobileread.ixtab.kolauncher.resources.KualEntry;

public class KualButton extends JButton {
	private static final long serialVersionUID = 1L;
	
	private KualEntry kualEntry = null;

	public KualButton(String text, KualEntry kualEntry) {
		super(text);
		this.kualEntry = kualEntry;
	}

	public KualEntry getKualEntry() {
		return this.kualEntry;
	}
}
