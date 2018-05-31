#!/bin/bash -e
#
# $Id$
#

HACKNAME="KUALBooklet"
PKGNAME="${HACKNAME}"
PKGVER="${1%%-g*}"

# We need kindletool (https://github.com/NiLuJe/KindleTool) in $PATH
if (( $(kindletool version | wc -l) == 1 )) ; then
	HAS_KINDLETOOL="true"
fi

if [[ "${HAS_KINDLETOOL}" != "true" ]] ; then
	echo "You need KindleTool (https://github.com/NiLuJe/KindleTool) to build this package."
	exit 1
fi

if ! svn --version --quiet &>/dev/null ; then
	echo "You need SubVersioN to build this package."
	exit 1
fi

# We'll want to pull libotautils5 from my SVN tree (to avoid code duplication)
svn cat http://svn.ak-team.com/svn/Configs/trunk/Kindle/Touch_Hacks/Common/lib/libotautils5 > ../booklet/install/libotautils5
svn cat http://svn.ak-team.com/svn/Configs/trunk/Kindle/Touch_Hacks/Common/lib/libotautils5 > ../booklet/uninstall/libotautils5

# Also, we kind of need the Booklet itself ;).
cp -f ../../../../../../../KUALBooklet.jar ../booklet/install/KUALBooklet.jar

# Install (>= 5.1.2)
kindletool create ota2 -d kindle5 -s 1679530004 -C ../booklet/install Update_${PKGNAME}_${PKGVER}_install.bin
# Uninstall
kindletool create ota2 -d kindle5 -C ../booklet/uninstall Update_${PKGNAME}_${PKGVER}_uninstall.bin

# Move our updates
rm -f ../dist/*.bin
mv -f *.bin ../dist/

# Cleanup behind us
rm -f ../booklet/install/libotautils5  ../booklet/uninstall/libotautils5 ../booklet/install/KUALBooklet.jar
