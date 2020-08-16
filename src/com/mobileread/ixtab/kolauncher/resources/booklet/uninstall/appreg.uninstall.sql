DELETE FROM "handlerIds" WHERE handlerId='com.mobileread.ixtab.kolauncher';
DELETE FROM "properties" WHERE handlerId='com.mobileread.ixtab.kolauncher';
DELETE FROM "associations" WHERE handlerId='com.mobileread.ixtab.kolauncher';

DELETE FROM "mimetypes" WHERE ext='kol';
DELETE FROM "extenstions" WHERE ext='kol';
DELETE FROM "properties" WHERE value='KOL';
DELETE FROM "associations" WHERE contentId='GL:*.kol';
