BEGIN TRANSACTION;
INSERT OR IGNORE INTO "handlerIds" VALUES('com.mobileread.ixtab.kindlelauncher');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','lipcId','com.mobileread.ixtab.kindlelauncher');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','jar','/opt/amazon/ebook/booklet/KUALBooklet.jar');

INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','maxUnloadTime','45');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','maxGoTime','60');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','maxPauseTime','60');

INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','default-chrome-style','NH');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','unloadPolicy','unloadOnPause');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','extend-start','Y');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','searchbar-mode','transient');
INSERT OR IGNORE INTO "properties" VALUES('com.mobileread.ixtab.kindlelauncher','supportedOrientation','U');

INSERT OR IGNORE INTO "mimetypes" VALUES('kual','MT:image/x.kual');
INSERT OR IGNORE INTO "extenstions" VALUES('kual','MT:image/x.kual');
INSERT OR IGNORE INTO "properties" VALUES('archive.displaytags.mimetypes','image/x.kual','KUAL');
INSERT OR IGNORE INTO "associations" VALUES('com.lab126.generic.extractor','extractor','GL:*.kual','true');
INSERT OR IGNORE INTO "associations" VALUES('com.mobileread.ixtab.kindlelauncher','application','MT:image/x.kual','true');
COMMIT;
