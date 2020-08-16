#!/bin/sh
#
# KOL Booklet uninstaller
#
# $Id$
#
##

# Pull libOTAUtils for logging & progress handling
[ -f ./libotautils5 ] && source ./libotautils5


otautils_update_progressbar

logmsg "I" "uninstall" "" "uninstalling booklet"
rm -f "/opt/amazon/ebook/booklet/KOLBooklet.jar"

otautils_update_progressbar

logmsg "I" "uninstall" "" "deregistering booklet"
sqlite3 "/var/local/appreg.db" < "appreg.uninstall.sql"

otautils_update_progressbar

logmsg "I" "uninstall" "" "removing application"
rm -f "/mnt/us/documents/KOL.kol"

otautils_update_progressbar

logmsg "I" "uninstall" "" "cleaning up"
rm -f "appreg.uninstall.sql"

logmsg "I" "uninstall" "" "done"

otautils_update_progressbar

return 0
