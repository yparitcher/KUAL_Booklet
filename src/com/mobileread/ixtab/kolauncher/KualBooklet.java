/*** Eclipse Class Decompiler plugin, copyright (c) 2016 Chen Chao (cnfree2000@hotmail.com) ***/
package com.mobileread.ixtab.kolauncher;


import java.io.File;
import java.io.IOException;
import java.util.Date;
import java.lang.reflect.Method;

import org.json.simple.JSONArray;
import org.json.simple.JSONObject;

import com.amazon.kindle.booklet.AbstractBooklet;
import com.amazon.kindle.restricted.content.catalog.ContentCatalog;
import com.amazon.kindle.restricted.runtime.Framework;
import com.mobileread.ixtab.kolauncher.resources.KualLog;

public class KualBooklet extends AbstractBooklet {

	public KualBooklet() {
		try {
			execute();
			//suicide();
		} catch (Throwable t) {
			throw new RuntimeException(t);
		}
	}
	// And this was always obfuscated...
	// NOTE: Pilfered from KPVBooklet (https://github.com/koreader/kpvbooklet/blob/master/src/com/github/chrox/kpvbooklet/ccadapter/CCAdapter.java)
	/**
	 * Perform CC request of type "query" and "change"
	 * @param req_type request type of "query" or "change"
	 * @param req_json request json string
	 * @return return json object
	 */
	private JSONObject ccPerform(String req_type, String req_json) {
		ContentCatalog CC = (ContentCatalog) Framework.getService(ContentCatalog.class);
		try {
			Method perform = null;

			// Enumeration approach
			Class[] signature = {String.class, String.class, int.class, int.class};
			Method[] methods = ContentCatalog.class.getDeclaredMethods();
			for (int i = 0; i < methods.length; i++) {
				Class[] params = methods[i].getParameterTypes();
				if (params.length == signature.length) {
					int j;
					for (j = 0; j < signature.length && params[j].isAssignableFrom( signature[j] ); j++ ) {}
					if (j == signature.length) {
						perform = methods[i];
						break;
					}
				}
			}

			if (perform != null) {
				JSONObject json = (JSONObject) perform.invoke(CC, new Object[] { req_type, req_json, new Integer(200), new Integer(5) });
				return json;
			}
			else {
				new KualLog().append("Failed to find perform method, last access time won't be set on exit!");
				return new JSONObject();
			}
		} catch (Throwable t) {
			throw new RuntimeException(t.toString());
		}
	}

	// NOTE: Again, adapted from KPVBooklet ;)
	private void updateCCDB() {
		long lastAccess = new Date().getTime() / 1000L;
		String tag = "KOReader";	// Fancy sash in the top right corner of the thumbnail ;)
		// NOTE: Hard-code the path, as no-one should be using a custom .kual trigger...
		String path = JSONObject.escape("/mnt/us/documents/KOReader.kol");
		String json_query = "{\"filter\":{\"Equals\":{\"value\":\"" + path + "\",\"path\":\"location\"}},\"type\":\"QueryRequest\",\"maxResults\":1,\"sortOrder\":[{\"order\":\"descending\",\"path\":\"lastAccess\"},{\"order\":\"ascending\",\"path\":\"titles[0].collation\"}],\"startIndex\":0,\"id\":1,\"resultType\":\"fast\"}";
		JSONObject json = ccPerform("query", json_query);
		JSONArray values = (JSONArray) json.get("values");
		JSONObject value = (JSONObject) values.get(0);
		String uuid = (String) value.get("uuid");
		String json_change = "{\"commands\":[{\"update\":{\"uuid\":\"" + uuid + "\",\"lastAccess\":" + lastAccess + ",\"displayTags\":[\"" + tag + "\"]" + "}}],\"type\":\"ChangeRequest\",\"id\":1}";
		ccPerform("change", json_change);
		//new KualLog().append("Set KUAL's lastAccess ccdb entry to " + lastAccess);
	}

	private void suicide() {
		try {
			// Send a BACKWARD lipc event to background the app (-> stop())
			// NOTE: This has a few side-effects, since we effectively skip create & longStart
			//	 on subsequent start-ups, and we (mostly) never go to destroy().
			// NOTE: Incidentally, this is roughly what the [Home] button does on the Touch, so, for the same reason,
			//	 it's recommended not to tap Home on that device ;).
			// NOTE: Setting the unloadPolicy to unloadOnPause in the app's appreg properties takes care of that,
			//	 stop() then *always* leads to destroy() :).
			//Runtime.getRuntime().exec("lipc-set-prop com.lab126.appmgrd backward 0");
			// Send a STOP lipc event to exit the app (-> stop() -> destroy()). More closely mirrors the Kindlet lifecycle.
			Runtime.getRuntime().exec("lipc-set-prop com.lab126.appmgrd stop app://com.mobileread.ixtab.kolauncher");
		} catch (IOException e) {
			new KualLog().append(e.toString());
		}
	}

	private Process execute()
			throws IOException, InterruptedException {

		// Check current privileges...
		// Call Gandalf for help if need be...
		String currentUsername = System.getProperty("user.name");
		if ("root".equals(currentUsername)) {} else {
			if (new File("/var/local/mkk/gandalf").exists()) {
				return Runtime.getRuntime().exec(
					new String[] { "/var/local/mkk/su", "-s", "/bin/ash", "-c", "{ /usr/bin/setsid /mnt/us/koreader/koreader.sh --kual --asap ; } 2>>/var/tmp/KOL.log &" }, null,
					new File("/mnt/us/koreader/"));
			}
		}
		return Runtime.getRuntime().exec(
			new String[] { "/bin/sh", "-c", "{ /usr/bin/setsid/mnt/us/koreader/koreader.sh --kual --asap ; } 2>>/var/tmp/KOL.log &" }, null,
			new File("/mnt/us/koreader/"));
	}

	public void stop() {
		/*
		 * This should really be run on the destroy() method, because stop()
		 * might be invoked multiple times. But in the destroy() method, it
		 * just won't work. Might be related with what the life cycle
		 * documentation says about not holding files open etc. after stop() was
		 * called. Anyway: seems to work, since we only set commandToRunOnExit at
		 * very specific times, where we'll always exit right after, so we can't really
		 * fire a random command during an unexpected stop event ;).
		 */
		//new KualLog().append("stop()");

		try {
			// NOTE: This can be a bit racey with destroy(),
			//	 so sleep for a teeny tiny bit so that our execute() call actually goes through...
			Thread.sleep(175);
		} catch (Exception ignored) {
			// can't do much, really. Too late for that :-)
		}

		super.stop();
	}

	public void destroy() {
		//new KualLog().append("destroy()");
		// Try to cleanup behind us on exit...
		try {
			// NOTE: This can be a bit racey with stop(),
			//	 so sleep for a tiny bit so our commandToRunOnExit actually has a chance to run...
			Thread.sleep(175);
			//cleanupTemporaryDirectory();
			updateCCDB();
		} catch (Exception ignored) {
			// Avoid the framework shouting at us...
		}

		super.destroy();
	}
}
