package com.mobileread.ixtab.kolauncher.resources;

import java.io.BufferedReader;
import java.io.IOException;
import java.util.LinkedHashMap;

public class KualMenu {

	// levelMap[i] <= ordered map of all entries at menu level i
	// levelMap[i][id] <= entry of class KualEntry, entry.id is unique and isn't a label

	private final static int MAXLEVEL = 10;
	private final LinkedHashMap[] levelMap = new LinkedHashMap[MAXLEVEL]; // all menu entries by level
	private KualConfig kualConfig;

	// constructor
	public KualMenu(BufferedReader reader) throws IOException,
	       InterruptedException {
		KualEntry ke;

		for (int i = 0; i < MAXLEVEL; i++) {
			levelMap[i] = new LinkedHashMap();
		}

		try {
			// read meta info and user configuration
			kualConfig = new KualConfig(reader);

			// read menu entries
			for (String line = reader.readLine(); line != null; line = reader
					.readLine()) {
				String options = "";
				int level = -1;
				ke = null;
				switch (line.charAt(0)) {
					case '4':
						options = reader.readLine();
					case '3':
						try {
							ke = new KualEntry(options, reader.readLine(),
							reader.readLine(), reader.readLine());
							break;
						} catch(Throwable t) {
							throw new Exception("record format "
									+ t.getMessage());
						}
					default:
						throw new Exception("input format");
				}
				levelMap[ke.level].put(ke.id, ke);
			}
		} catch (Throwable t) {
			// show exception as a menu button
			String report = "error: " + t.getMessage();
			ke = new KualEntry(0, report);
			levelMap[0].put(ke.id, ke);
			// and append report to KUAL.log TODO
		}
	}

	// methods
	public String getConfig(String name) {
		return kualConfig.get(name);
	}

	public String getVersion() {
		return kualConfig.getVersion();
	}

	public String getModel() {
		return kualConfig.getModel();
	}

	public String getMailboxPath() {
		return kualConfig.getMailboxPath();
	}

	public LinkedHashMap getLevel(int level) {
		if (0 <= level && level <= MAXLEVEL)
			return levelMap[level];
		return null;
	}

	public KualEntry getEntry(int level, Object id) {
		if (0 <= level && level <= MAXLEVEL)
			return (KualEntry) levelMap[level].get(id);
		return null;
	}

	// preferably use getEntry(level, id) over this signature
	public KualEntry getEntry(String id) {
		int level;
		try {
			level = Integer.parseInt(id.substring(0, id.indexOf(":")));
		} catch (Throwable t) {
			return null;
		}
		return getEntry(level, id);
	}
}
