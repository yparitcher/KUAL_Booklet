package com.mobileread.ixtab.kolauncher.resources;

import java.io.InputStream;

public class ResourceLoader {
	public static InputStream load(String name) {
		return ResourceLoader.class.getResourceAsStream(name);
	}
}
