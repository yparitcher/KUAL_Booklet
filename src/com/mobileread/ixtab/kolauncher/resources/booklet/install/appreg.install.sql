INSERT OR IGNORE INTO "handlerIds" VALUES('com.mobileread.ixtab.kolauncher');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','lipcId','com.mobileread.ixtab.kolauncher');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','jar','/opt/amazon/ebook/booklet/KOLBooklet.jar');

INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','maxUnloadTime','45');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','maxGoTime','60');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','maxPauseTime','60');

INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','default-chrome-style','NH');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','unloadPolicy','unloadOnPause');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','extend-start','Y');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','searchbar-mode','transient');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kolauncher','supportedOrientation','U');

INSERT OR IGNORE INTO "mimetypes" VALUES('kol','MT:image/x.kol');
INSERT OR IGNORE INTO "extenstions" VALUES('kol','MT:image/x.kol');
INSERT OR IGNORE INTO "properties" VALUES('archive.displaytags.mimetypes','image/x.kol','KOReader');
INSERT OR IGNORE INTO "associations" VALUES('com.lab126.generic.extractor','extractor','GL:*.kol','true');
INSERT OR IGNORE INTO "associations" VALUES('com.mobileread.ixtab.kolauncher','application','MT:image/x.kol','true');
