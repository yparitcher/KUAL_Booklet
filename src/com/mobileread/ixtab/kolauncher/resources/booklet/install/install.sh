#!/bin/sh
#
# KOL Booklet installer
#
# $Id$
#
##

# Pull libOTAUtils for logging & progress handling
[ -f ./libotautils5 ] && source ./libotautils5


otautils_update_progressbar

logmsg "I" "install" "" "installing booklet"
cp -f "KOLBooklet.jar" "/opt/amazon/ebook/booklet/KOLBooklet.jar"

otautils_update_progressbar

logmsg "I" "install" "" "registering booklet"
sqlite3 "/var/local/appreg.db" < "appreg.install.sql"

otautils_update_progressbar

# Enable WhisperTouch on the Voyage (c.f., https://github.com/koreader/koreader/issues/6038#issuecomment-612564693)
# Use the FBInk binary chosen by libOTAUtils (if any)
if has_fbink ; then
    logmsg "I" "install" "" "Checking device ID via ${FBINK_BIN}"
    eval $(${FBINK_BIN} -e)
    if [ "${deviceName}" = "Voyage" ] ; then
        logmsg "I" "install" "" "enabling whispertouch"
        sqlite3 "/var/local/appreg.db" < "whispertouch.install.sql"
    fi
fi

otautils_update_progressbar


logmsg "I" "install" "" "creating application"
touch "/mnt/us/documents/KOReader.kol"

otautils_update_progressbar

logmsg "I" "install" "" "cleaning up"
rm -f "KOLBooklet.jar" "appreg.install.sql"

logmsg "I" "install" "" "done"

otautils_update_progressbar

return 0
