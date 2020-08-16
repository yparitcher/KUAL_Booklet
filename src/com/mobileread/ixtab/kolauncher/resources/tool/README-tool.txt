Tools in this folder:

strip.awk
	strips white space and code blocks from awk scripts to make them smaller.
	In particular, use strip.awk to build parse.awk from parse-commented.awk <<<<
	Note that it's parse.awk which gets compiled into KUAL - not parse.commented.awk
	Here's the drill:
		1. edit all your parser changes and comments into resources/parse-commented.awk
		2. ./strip.awk -v AWK=1 parse-commented.awk > parse.awk
		3. compile the project
	For tool help run strip.awk with no options.
	Adopt the best practice listed therein.

NB: This is now automatically done during the build :).

stripit.sh
	Used by the buildsystem to strip the commented parser.

build-updates.sh:
	Used by the buildsystem to package the Booklet for release.

shipit.sh
	Used by the buildsystem to package the project for release.

