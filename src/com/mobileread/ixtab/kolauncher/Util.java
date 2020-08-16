package com.mobileread.ixtab.kolauncher;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;

public class Util {

	public static void copy(InputStream is, OutputStream os) throws IOException {
		byte[] buffer = new byte[4096];
		int bytesRead;
		while ((bytesRead = is.read(buffer)) != -1) {
			os.write(buffer, 0, bytesRead);
		}
		os.flush();
		os.close();
	}

	public static BufferedReader execute(String scriptName) throws IOException,
			InterruptedException {
		//String[] cmd = new String[] { "/bin/ash", scriptName };
		String[] cmd = new String[] { "/usr/bin/awk", "-f", scriptName };
		// If it is installed, use our own gawk binary, it's much faster.
		if (new File("/mnt/us/extensions/gawk/bin/gawk").exists()) {
			cmd = new String[] { "/mnt/us/extensions/gawk/bin/gawk", "-O", "--non-decimal-data", "-f", scriptName };
		}

		Process process = Runtime.getRuntime().exec(cmd, null);
		//process.waitFor(); //stepk

		BufferedReader input = new BufferedReader(new InputStreamReader(
				process.getInputStream()));

		// The parser is waiting for either a list of json files or
		// the null list, which tells the parser to generate its own list.
		// Closing input to the parser means the null list.
		process.getOutputStream().close();

		return input;
	}

	public static BufferedReader sureFileReader(String filePath) {
		BufferedReader input = null;
		File file = new File(filePath);
		if (file.isFile()) {
			try {
				input = new BufferedReader(new FileReader(filePath));
			} catch (Throwable t) {
				input = null;
			}
		}
		return input;
	}
}
