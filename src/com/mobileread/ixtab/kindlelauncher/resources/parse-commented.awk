#!/usr/bin/awk -f
# parse-commented.awk
#!/bin/busybox awk -f on kindle e-ink devices .or. /usr/bin/awk
#!/bin/awk on puppy linux
#
# Includes portions of JSON.awk - a practical JSON parser written in awk
#   Version: 1.10
#   Author: stepk
#   License: MIT or Apache 2, see github project repository
#   https://github.com/step-/JSON.awk
#
# Usage {{{
# alias PRE='rm -f /var/tmp/KUAL.cache'
# PRE; awk [--non-decimal-data] [-v OPT_FMT=tbl|tab|%s|multiline] [-v OPT_SORT=ABC|ABC!|123] -f parse-commented.awk </dev/null
#    OPT_SORT overrides KUAL.cfg:KUAL_sort_mode for the current run.
#}}}
# Limitations {{{
# . Supports JSON menus only
# . Character codes > 127 may lead to non-parsable menu entries, just try if it works.
# . Does not expand the JSON \uHHHH character escape - xref WHEN_TO_UNESCAPE
#}}}
# Gotchas {{{ READ THIS
# . Control characters are not allowed in JSON strings (invalid syntax, see www.json.org).
#   In particular, a tab character (ctrl+I) is invalid and returns a parsing error; use \t instead.
#
#}}}
# Testing aids {{{
# alias FND='y=`find /mnt/us/extensions -follow -name \*.json`'
# test cmd 1: PRE;awk -v OPT_FMT=tbl -f parse-commented.awk 2>/dev/stdout </dev/null ; echo $?
# test cmd 2: PRE;FND;{ echo "$y"; echo; } | awk -v OPT_FMT=tbl -v OPT_SORT=ABC -f parse-commented.awk 2>/dev/stdout ; echo $?
#}}}
# Overview {{{
# 1. From menu syntax (JSON) {{{
# Note that the outer object prescribes a single key, "items".
# => This engine deliberately ignores any top-level key but "items".
# {
#   "items": [
#      {"name": "KUAL menu, Item 1", "action": "act1.sh"},
#      {
#        "name": "KUAL menu, Submenu 1",
#        "items": [
#          {"name": "Submenu 1, Item 1", "action": "act11.sh"},
#          {"name": "Submenu 1, Item 2", "action": "act12.sh"}
#        ]
#      }
#   ]
# }
#}}}

# 2. To parsed items (jpaths) {{{
# JSON menu is transformed into a series of jpaths:
# ["items",0,"name"]	"Top menu, Item 1"
# ["items",0,"action"]	"act1.sh"
# ["items",1,"name"]	"Top menu, Submenu 1"
# ["items",1,"items",0,"name"]	"Submenu 1, Item 1"
# ["items",1,"items",0,"action"]	"act11.sh"
# ["items",1,"items",1,"name"]	"Submenu 1, Item 2"
# ["items",1,"items",1,"action"]	"act12.sh"
#}}}

# 3. To computable items (npaths) {{{
# Jpaths are transformed into hex numbers, which are
# more suitable to express structural relationships
# and to enable transformations, like sorting, etc.
#  ffff00ff0005    =   "Top menu, Item 1"
#}}}

# 4. To kindlet menu (records) {{{
# Npaths are transformed in various ways, like sorting etc.
# then finally sent to the Kindlet as multiline data.
# The Kindlet suitably displays andprocesses menu data...
#}}}

# 5. Background tasks  {{{
# This engine stays alive while the Kindlet does its job.
# In this phase it can attend useful chores, like
# cache synchronization, etc.
#}}}
#}}}

BEGIN { #{{{
	# Append the first character of the awk binary used to interpret this script.
	# This gives the user an indication of whether he's using busybox awk or GNU awk.
	callern=split(ARGV[0], callerary, "/")
	VERSION="@repository.version@ (@repository.date@," substr(callerary[callern], 0 , 1) ")"

	# usage 1: scan EXTENSIONDIR {{{
	#      awk -f parse-commented.awk < /dev/null
	# usage 2: filepathnames from stdin
	# ex.a { echo -e "file1\nfile2\n\n"; cat file1 file2 ... ;}| awk -f parse-commented.awk
	#}}}

	ERRORS = BAILOUT = CACHE_SENT = IN_MEMORY_CACHE_INVALID = PARSED_OK_COUNTER = 0
	SELF_BUTTONS_INSERT = SELF_BUTTONS_FILTER = SELF_BUTTONS_APPEND = ""
	if (1 < ARGC) {
		print "usage!" > "/dev/stderr"
		BAILOUT=1
		exit # skip the main loop
	}

	while (0 < getline < "/dev/stdin") {
		if (NF) { ARGV[++ARGC]=$0 } else break
	}

	# set file slurping mode - before init()
	srand() # also used elsewhere
	RS="n/o/m/a/t/c/h" substr(rand(),3)
	init()

	if (0 == cache_send(CACHEPATH)) { # try sending cached config+menu
		# why closing stdout ? {{{ xref UNBLOCK_KINDLET
		# Closing stdout unblocks the kindlet from its read loop, so it
		# can initializeUI() and meet its 5000 ms timeout before java
		# throws an exception. After closing stdout this script can
		# hang around and run errands as necessary.
		# Prove it: uncomment the sleep command below and ensure that
		# KUAL.cache exists; then run the kindlet; it should show the
		# menu while this script is sleeping.
		#
		# However, for the kindlet to I/O unblock and show the menu, java
		# needs to runtime.exec() this script directly from AWK.
		# Runtime.exec()ing /bin/ash to spawn /usr/bin/awk leaves
		# the kindlet blocked while this script is sleeping.
		#
		# xref NON_GNU_AWK:
		# By default, GNU Awk doesn't allow closing stdout...
		# We use a dirty patch in our gawk build to workaround that.
		# }}}
		close("/dev/stdout")
		CACHE_SENT=1 # (CACHE_SENT == 1) <=> (! Kindlet is I/O blocked)
		#
		#system("sleep 20")
		#
		# Asynchronous: Kindlet is not I/O blocked, continue through main loop while kindlet is showing GUI
	} else {
		config_send("/dev/stdout")
		# Synchronous: Kindlet is I/O blocked, continue through main loop while kindlet is waiting for menu records
	}


#: BSTR too ugly NOT USED
if(0) {
	KUAL_sh_deploy() # deploy SCRIPTPATH
}
#: ESTR

	if (1 >= ARGC) {
		ARGC = find_menu_fullpathnames(EXTENSIONDIR, ARGV, ARGC-1)
		if (1 > ARGC && "" != SCRIPTPATH) {
			ARGV[ARGC] = ""
			++ERRORS
			++IN_MEMORY_CACHE_INVALID
			# post a message button to emit_self_menu()
			SELF_BUTTONS_INSERT = SELF_BUTTONS_INSERT ",+add_ext"
			SELF_BUTTONS_FILTER = SELF_BUTTONS_FILTER ",-sort_menu"
		}
		if("" != ARGV[ARGC]) ++ARGC # trigger main loop
	}

	# config parser {{{
	# option_BRIEF(1) - parse() omits printing non-leaf nodes
	BRIEF=1; #
	# option_STREAM(0) - parse() omits stdout and stores jpaths in JPATHS[]
	STREAM=0;
	# for each input file:
	#   TOKENS[], NTOKENS, ITOKENS - tokens after tokenize()
	#   JPATHS[], NJPATHS - parsed data (when STREAM=0)
	# at script exit:
	#   FAILS[] - maps names of invalid files to logged error lines
	delete FAILS
	#}}}
}
#}}}

{ # main loop: parse each file in turn {{{
	reset() # customized to allow appending to JPATHS[]
	SVNJPATHS = 0+NJPATHS
	tokenize($0) # while(get_token()) {print TOKEN}

#printf "main.parse.NJPATHS "NJPATHS">" > "/dev/stderr"
	if (0 == (status = parse())) { # appends to JPATHS[]
#print ">"NJPATHS > "/dev/stderr"; for (i=1;i<=NJPATHS;i++) print JPATHS[i]>"/dev/stderr"
		++VALID_PARSED_FILES # ++VALID_PARSED_FILES leaves serial 0 free for the KUAL menu
#printf "main.jp2np.NNPATHS "NNPATHS">" > "/dev/stderr"
		status = jp2np(JPATHS, NJPATHS, VALID_PARSED_FILES, FILENAME) # appends to NPATHS[]
#print ">"NNPATHS > "/dev/stderr"; for (i=1;i<=NNPATHS;i++) print NPATHS[i]>"/dev/stderr"
		match(FILENAME, /(\/[^\/]+){2,2}$/)
		x = substr(FILENAME, RSTART+1, RLENGTH)
		LOADED_EXTENSIONS[substr(x, 1, index(x, "/") - 1)] = 1 # folder name
	} else { # unwind partial JPATHS (invalid json)
#print "NJPATHS("NJPATHS")" > "/dev/stderr"
		while(NJPATHS > SVNJPATHS) {
#print "delete JPATHS["NJPATHS"]=("JPATHS[NJPATHS]")" > "/dev/stderr"
			delete JPATHS[NJPATHS--]
		}
	}
	if (status) ++ERRORS
	# processing continues in END block
}
#}}}

# JPATHS[] vs NPATHS[] arrays {{{ - A note
# After the main loop the JPATHS[] array holds read-only records, unlike
# the NPATHS[] array which holds read/write/deleted records.
# Although AWK provides "delete ary[i]" to delete an array element.
# The code to scan an array with deleted elements looks like this
#   for (i = 1; i <= nary; i++) if (i in ary) { do_something_with(ary[i]) }
# After several experiments I decided not to use "delete" but to more simply
# set ary[i] = 0 to mark an array element deleted. The code changes to:
#   for (i = 1; i <= nary; i++) if (ary[i]) { do_something_with(ary[i]) }
# Note that we need asserting that no record == 0 - this is the case.
# This scan technique is slightly less efficient than the previous one,
# but it offers greater benefits:
# * It works unchanged also when ary[i] is the null string; this applies
#   to the output of function sort().
#   Note that we need asserting that no record == "" - this is the case.
# * When we need to read array element values we use this code:
#     for (i = 1; i <= nary; i++) if (rec = ary[i]) { process(rec) }
#   Compare it with code designed for the "delete ary[i]" case:
#     for (i = 1; i <= nary; i++) if (i in ary) {rec = ary[i]; process(rec)}
#   The first code performs N key lookup + N read operations, while the
#   second code performs 2N lookups + N' <= N read operations. When
#   the number of deleted elements is small, N ~ N' holds, and the first
#   code is faster. Note that its advantage decreases as the number of
#   deleted elements increases. For KUAL we need not worry, because
#   very few array elements ever get deleted.
# * When coding for "(i in ary)" tests one needs to be extra careful not
#   to inadvertently create spurious array keys, which are hard to find
#   in the testing phase. For instance, this code
#     if (value != ary[i])  creates key i if it does not exist. Then
#   the test (i in ary) would return true but the value of ary[i]
#   would be null!
# It goes without saying - but I'm saying it - that NPATHS[] is
# never compacted; the number range of its keys is fixed [1..NNPATHS]
# But some keys may index null/0 values, that is, deleted elements.
#}}}

END { #{{{ process parsed data and emit menu to kindlet

	# early exit cases did not go through the main loop {{{
	# BAILOUT - usage/configuration error
	#}}}
	if (BAILOUT) {
		teardown()
		exit(BAILOUT)
	}

	if (CACHE_SENT) { # kindlet is not I/O blocked
		if (0 != cache_update()) {
			scream(SenCantUpdateCache)
			++ERRORS
		}
		teardown()
		exit(ERRORS)
	}

	# the kindlet is I/O blocked...
	json_emit_self_menu_and_parsing_errors(0+PARENT_ERRORS) # appends to NPATHS[]

	delete MENUS; NMENUS=0
	if (0 != np2mn(NPATHS, NNPATHS)) {
		scream("error (np2mn)")
		++ERRORS
	} else {
		# out to kindlet
		if (0 != formatter(MENUS, NMENUS, OPT_FMT, "/dev/stdout")) {
			scream(SenCantSendToKindlet)
			++ERRORS
		}
	        # unblock kindlet from read loop, xref UNBLOCK_KINDLET
		close("/dev/stdout")

		if (0 != cache_save()) {
			scream(SenCantWriteCache)
			++ERRORS
		}

		#delete NPATHS; NNPATHS=0
	}

	teardown()
	exit(ERRORS)
}
#}}}

function init(   x) { #{{{ constants
# in this order
if ("" == EXTENSIONDIR) EXTENSIONDIR="/mnt/us/extensions" # single dirpath
if ("" == PRODUCTNAME) PRODUCTNAME="KUAL"
if ("" == CONFIGFILE) CONFIGFILE=PRODUCTNAME".cfg" # first found in EXTENSIONDIR
if ("" == (CONFIGPATH = config_full_path("create"))) CONFIGPATH = "/dev/null" # sic
config_read(CONFIGPATH)
CONFIG["model"] = get_model()
# config_send() skips sending keys that start with NC
x = "/bin/busybox "
CONFIG["NCbbawk"] = x"awk"
CONFIG["NCbbfind"] = x"find"
CONFIG["NCbbmd5sum"] = x"md5sum"
CONFIG["NCbbsort"] = x"sort"

if (""==OPT_FMT) OPT_FMT="multiline"
if (""==OPT_SORT) OPT_SORT= "" != (x = config_get("sort_mode")) ? x : "ABC"

delete COUNTER
COUNTER["nameNull"]=0

SEP="\x01"

CACHEPATH = (x = "/var/tmp/" PRODUCTNAME) ".cache"
if (""==SCREAM_LOG) SCREAM_LOG = x ".log"
SCRIPTPATH = x ".sh" # sic
MBXPATH = x ".mbx" # asynchronous mailbox to the kindlet, xref UNBLOCK_KINDLET
system("rm -f '"MBXPATH"'")
SELF_MENU_NAME = PRODUCTNAME

# valid keys within a menu.json file (ALPHA sortable)
# add new keys here and also throughout near bookmark VALID_KEYS
# see also npath_from_jpath()
#    *** LOWERCASE *** hex digits!  0x0a  *** NOT 0x0A ***
VALID_KEYS["action"]=K_action=0x00  # K_action < K_name ! xref IS_SUBMENU
VALID_KEYS["internal"]=K_internal=0x01
VALID_KEYS["params"]=K_params=0x02
VALID_KEYS["priority"]=K_priority=0x03 # K_priority < K_name ! xref SORTABLE
VALID_KEYS["if"]=K_if=0x04
VALID_KEYS["exitmenu"]=K_exitmenu=0x05
VALID_KEYS["checked"]=K_checked=0x06
VALID_KEYS["refresh"]=K_refresh=0x07
VALID_KEYS["status"]=K_status=0x08
VALID_KEYS["date"]=K_date=0x09
VALID_KEYS["hidden"]=K_hidden=0x0a # IMPLEMENTED but the Kindlet has NOT USED
VALID_KEYS["name"]=K_name=0x0b # ... by the same argument K_* < K_name ! xref SORTABLE
VALID_KEYS["items"]=K_items=0xff # do not change
VALID_KEYS["ERROR"]="??"

# npath stuff
sK_name=sprintf("%02x", K_name)
sK_items=sprintf("%02x", K_items)
xRESERVED=0xff
sRESERVED="ff"
sRESERVED_len=2
NPATH_len=48
FFS="ffffffffffffffffffffffffffffffffffffffffffffffff" #48  xref LIMITS

# Non-breaking space - use to force sorting menu entries at bottom DEPRECATED
NBSP0="&nbsp;"
NBSP1="\xC2\xA0" # 2-byte UTF-8 encoded
# Black right-pointing triangle - submenu marker
#  echo -n ">" | hexdump  # replace ">" with the actual unicode character
#  0000000 96e2 00b6
#  0000003
#Let the Kindlet mark submenus#MMRK=" \xE2\x96\xB6" # > full
CROSS="\xC3\x97" # x
#ATTN="\xE2\x96\xB7" # > hollow
#ATTN="\xE2\x88\x97" # *
ATTN="\xE2\x97\x8F" # O

# Kindlet button messages - these must fit in a button label - see fit_button()
MAX_LABEL_LEN=40
#XenErrConfig="Config"
XenErrSyntax="Syntax"
#XenErrUsage="Usage"
XenParentErrors="Startup error"
XenNoExtensionsFound=ATTN" No extensions found"

# SCREAM_LOG error string constants
SenCantChangeSortMode="can't change sorting mode"
SenCantFindMenuFiles="can't find menu files"
SenCantHashCache="can't hash cache file"
SenCantSendToKindlet="can't send menu to Kindlet"
SenCantSort="can't sort"
SenCantUpdateCache="can't update cached menu"
SenCantWriteCache="can't cache menu"

TFL="/var/tmp/--" PRODUCTNAME "--" # use a fixed stem, not rand() nor alt PROCINFO[pid]

# map keyword => kindlet function id
# id must be a single alphabetic character > 32 (0..32 reserved to kindlet)
# see format_action_item()
INTERNAL_ACTIONS["breadcrumb"]="A"
INTERNAL_ACTIONS["status"]="B"
}
#}}}

function teardown(   i) { # {{{
	system("cd /var/tmp && rm -f \"" TFL "\"* 2>/dev/null")
	# cleans up for this session and for any previously crashed sessions
}
#}}}

function cache_file_delete() { # {{{
	system("rm -f '"CACHEPATH"'")
}
#}}}

function cache_save(    errors,hash1,hash2,cmd) { # {{{ << globals IN_MEMORY_CACHE_INVALID,CACHEPATH,MENUS[],NMENUS,CONFIG[]; return  no. of errors
	errors = 0
	if (IN_MEMORY_CACHE_INVALID) {
		cache_file_delete() # for good measure
		return 0
	}

	# hash current cache {{{
	cmd = CONFIG["NCbbmd5sum"]" '"CACHEPATH"' 2>/dev/null"
	if (-1 < getline hash1 < CACHEPATH) { # exist else hash1=``
		close(CACHEPATH)
		cmd | getline hash1
		if (close(cmd)) {
			scream(SenCantHashCache)
			hash1 = 0
		}
	}
	#}}}

	printf "" >CACHEPATH
	# assert first two cache lines: number'\n'version! xref cache_send(), config_send()
	errors += config_send(CACHEPATH)
	errors += formatter(MENUS, NMENUS, "multiline", CACHEPATH)

	if (-1 == close(CACHEPATH)) {
		++errors
	} else {
		# hash new cache {{{
		cmd | getline hash2
		if (close(cmd)) {
			scream(SenCantHashCache)
			hash2 = 0
		}
		# }}}
	}

	if (hash1 && hash2 && hash1 != hash2) {
		# user needs to refresh the menu to see the latest changes
		if (! errors) {
			# so tell the kindlet that it can refresh from the new cache file
			print "1 "CACHEPATH >MBXPATH
			close(MBXPATH)
		}

	}
	return errors
}
#}}}

function cache_send(cachepath,   # {{{ << globals MENUS[],NMENUS,CONFIG[]; >>global IN_MEMORY_CACHE_INVALID; return  no. of errors
	slurp,version) {

	if (0 <= (getline slurp < cachepath))
		close(cachepath)
	if ("" != slurp) {
		# version upgrade check {{{
		# assert first two cache lines: number'\n'version! xref cache_save()
		version = substr(slurp, index(slurp, "\n") + 1)
		version = substr(version, 1, index(version, "\n") - 1)
		if (version != VERSION) {
			cache_file_delete()
			return 1
		}
		#}}}
		printf "%s", slurp
		return 0
	}
	return 1
}
#}}}

function cache_update(   errors) { # {{{ >> globals NPATHS[],NNPATHS,IN_MEMORY_CACHE_INVALID,MENUS[],NMENUS,CONFIG[]; cache_save(); return  no. of errors

	errors = 0
	json_emit_self_menu_and_parsing_errors(0+PARENT_ERRORS) # appends to NPATHS[]

	delete MENUS; NMENUS=0
	if (0 != np2mn(NPATHS, NNPATHS)) {
		scream("error (np2mn)")
		++errors
	} else {
		IN_MEMORY_CACHE_INVALID = 0
		if (0 != cache_save()) {
			scream(SenCantWriteCache)
			++errors # YES!
		}
	}

	return errors
}
#}}}

function config_full_path(create, # {{{
	i,ary,nary,x) {
# [create="create"] creates first(EXTENSIONDIR)/CONFIGFILE if it does not exist
# return full path of CONFIGFILE if one exists or can be created else return ""
	nary = split(EXTENSIONDIR, ary, /;/)
	for (i = 1; i <= nary; i++) {
		cfp = ary[i]"/"CONFIGFILE
		if (0 <= (getline x < cfp)) {
			close(cfp)
			break
		}
	}
	if ("" != x)
		return cfp
	if ("create" == create) {
		# Make sure EXTENSIONDIR exists first
		system("mkdir -p " ary[1])
		cfp=ary[1]"/"CONFIGFILE
		"date" | getline x
		close("date")
		print "# "CONFIGFILE" - created on "x > cfp
		close(cfp)
		return cfp
	}
	return ""
}
#}}}

function config_get(key) { # {{{
	return key in CONFIG ? CONFIG[key] : ""
}
#}}}

function config_read(configfullpath, # {{{ >> global map CONFIG[], return number of new CONFIG[] items
	ary,nary,slurp,k,v,p,count) {
# assumes slurping mode @ BEGIN
# we only consider keys that start with "KUAL_" and we drop prefix "KUAL_"
# extensions may save their own data into KUAL.cfg provided they don't prefix by "KUAL_"
	if (0 <= (getline slurp < configfullpath))
		close(configfullpath)
	if ("" != slurp) {
		nary = split(slurp, ary, /\n/)
		if (nary) --nary # trim \n$
		for (i = 1; i <= nary; i++) {
			if (ary[i] ~ "^\\s*"PRODUCTNAME"_\\w+=") {
				k = ary[i]
				gsub(/^\s+|\s+$/, "", k) # trim
				k = substr(k,1+index(k,"_"))
				p = index(k, "=")
				v = substr(k,p+1)
				if (match(v, /^".*"$/))
					v = substr(v, 2, RLENGTH - 2) # unquote
				CONFIG[substr(k,1,p-1)] = v
				++count # minor bug: counts identical keys multiple times (no need to fix)
			}
		}
	}
	return 0+count
}
#}}}

function config_send(outfile,   k,n) { # {{{ << globals VERSION,MBXPATH,CONFIG[]; append settings to outfile, leave outfile open
	for (k in CONFIG)
		if(k !~ /^NC/)
			++n
	# VERSION MUST immediately follow the FIRST NUMBER xref cache_save()
	printf "%d\n%s\n%s\n%d\n", 2, VERSION, MBXPATH, n >>outfile
	for (k in CONFIG)
		if(k !~ /^NC/)
			print k"="CONFIG[k] >>outfile
}
#}}}

##: BSTR COLLATE
function collate(ary, nary,   # {{{ >>ary; merge same-name sub-menus in ary[]
	maxdepth,depth,i,saved_self_menu_name,
	rec_lvlsnpath,rec_level,rec_snpath,rec_name,rec_type,
	key,seen,seenary,new_root,
	childrenary,nchildrenary,
	x,xary,nxary,y,z,trace) {

	# We start by splitting ary (MENUS) into a more manageable 2D array.
	maxdepth = menu2Dsplit(0, ary, nary)
	# Now in addition to MENUS[i] as the whole record we also have MENUS[i"sn"], etc. as selected fields.

#for (x=1; x<=nary; x++) if(x in ary) {xary[x] = ary[x]} # xary <= copy of 1D MENUS[]
#NMENUS = menu2Dimplode(0, ary, nary) # 1D MENUS[] <= imploded 2D MENUS[]
#if (nary != NMENUS) print "2Dimplode something's wrong" >"/dev/stderr"
#for (x=1; x<=NMENUS; x++) if (x in MENUS) if (MENUS[x] != xary[x]) print MENUS[x], "\n" xary[x], "\n2Dimplode did not reverse" >"/dev/stderr"

	# Ensure the self-menu has a well-know name.
	# This enables collating the self-menu even when its name includes the ATTN marker.
	saved_self_menu_name = ary[1"nm"]
	ary[1"nm"] = SELF_MENU_NAME
	menu2Dimplode(1, ary, nary)

	# Map childrenary[] lists the children of each node.
	nchildrenary = children_map(ary, nary, 0, childrenary)
	# Childrenary[] gets updated through the loop below.

	for (depth = 0; depth <= maxdepth; depth++) {
#print "depth",depth,"-------------------------------------------------">"/dev/stderr"
		for (i = 1; i <= nary; i++) if (i"ls" in ary) {
			rec_level = ary[i"lv"]

			# We work on a single level at the time.
			if (depth != rec_level)
				continue

			rec_lvlsnpath = x = ary[i"ls"]
			rec_snpath = ary[i"sn"]
			rec_type = ary[i"ty"]

			# We don't want to consider collisions of plain items.
			#if (0 == rec_type) { # plain item
			# ;
			#} else

			if (1 == rec_type) { # sub-menu
			#
			# Does this sub-menu (a.k.a. rec) collide with an already-seen sub-menu (a.k.a. seen)?
			#
				rec_name = ary[i"nm"]
				key = rec_level "_" rec_name
#trace = "^1_A A1$"
#if (key ~ trace) {print " key",key,rec_snpath >"/dev/stderr"}

				# Test the necessary collision condition: rec's level & name == some seen sub-menu's
				if (! (key in seenary)) {
					seenary[key] = i # track it
					continue
				}

				new_root = 0
				nxary = split(seenary[key], xary, " ")
				for (z = 1; z <= nxary; z++) {
					seen = xary[z]
					seen_lvlsnpath = ary[seen"ls"]
					seen_level = ary[seen"lv"]
					seen_snpath = ary[seen"sn"]
#if (key ~ trace) {print "seen",key,seen_snpath,"- "seenary[key]" -","?collide?",rec_name,rec_snpath >"/dev/stderr"}

					# Test the sufficient collision condition: the two nodes have the same parent. {{{
					# With -6 below we discard the snpath suffix "items",y,"name". Then with 5 we
					# discard the serial prefix "items",serial  which corresponds to top menu items.
					# In other words for each level we ignore the serial and select the parent's snpath
					# prefix of the two snpaths that are being considered.
					#}}}
					if ((x = substr(substr(rec_snpath, 1, length(rec_snpath)-6), 5)) \
						!= (y = substr(substr(seen_snpath, 1, length(seen_snpath)-6), 5))) {
#if (key ~ trace) {print " NO common parent for","<"x">","<"y">",rec_snpath,seen_snpath>"/dev/stderr"}
						seenary[key] = seenary[key]" "i # track it
					} else {
						new_root = seen
					}
				}
				if (0 == new_root) {
					continue
				}
#if (key ~ trace) {print "YES common parent","<"x"> for",rec_snpath,ary[new_root"sn"]>"/dev/stderr"}

				# Recursively move rec's children under new_root.
				# We don't need to move rec itself, as it's going to be deleted as a duplicate of new_root.
				move_node(i, new_root, "", ary, nary, childrenary , key ~ trace)

				# Update new_root's children map.
				#children_map(ary, nary, new_root, childrenary)
				childrenary[new_root] = childrenary[new_root] " " childrenary[i]

				# Append collation cue to the menu name.
				x = ary[new_root"nm"]
				y = substr(x, length(x))
				if ("+" != y) {
					ary[new_root"nm"] = x "+"
					menu2Dimplode(seen, ary, nary)
				}

				# Delete the references to the record of the sub-menu whose descendants we have relocated under seen.
				ary[i] = ary[i"sn"] = childrenary[i] = 0
			}
		}
	}

	# Restore the self-menu name.
	x = ary[1"nm"]
	y = substr(x, length(x))
	ary[1"nm"] = (saved_self_menu_name) ("+" == y ? "+" : "")
	menu2Dimplode(1, ary, nary)
}
#}}}
function move_node(src_i, dst_i, dst_path, ary, nary, childrenary, trace,   # {{{ >>ary[]
	offset,sst,dst_snpath, ncary,cary,child, c,x,y,to,len, dbgind) {
# move the tree of records rooted in node src_i under the new root node dst_i {{{
# preserve existing nodes under dst_i
# ASSERT src_i and dst_i are sub-menu nodes at the same level
#}}}

#dbgind = substr("                    ", 1, (length(dst_path) - 8)/2) # debug
#if (trace) {print dbgind"move_node("src_i,ary[src_i"nm"],childrenary[src_i]", "dst_i", "dst_path,childrenary[dst_i]")" >"/dev/stderr"}

	# Find the offset of src_i's children when they will be moved under dst_i. {{{
	# Such offset is the "items" index of dst_i's last child.
	# The "items" index is embedded in the child's snpath.
	#}}}
	offset = calc_snpath_offset(childrenary[dst_i], ary)

	# We will need to replace src_i's children's sortable_tag with dst_i's children's. {{{
	# So we compute the sortable_tag by following the same algorithm that np2mn() uses,
	# which consists in transforming dst_i's snpath into a same-level "items" snpath.
	# While the following expression yields the fully-padded sortable_tag
	# npath_wo_reserved(npath_padded(npath_reserved() npath_s_this_(K_items, ary[dst_i"sn"]))) # xref SORTABLE
	# here we just need an unpadded (short) sortable tag (sst).
	#}}}
	sst =	npath_s_this_(K_items, ary[dst_i"sn"]) # xref SORTABLE

	# Recursively move src_i's children.
	ncary = split(childrenary[src_i], cary, " ")
	for (c = 1; c <= ncary; c++) {
		child = cary[c]

		# Calculate the new destination snpath.
		dst_snpath = dst_path ? dst_path : ary[dst_i"sn"]
		x = substr(dst_snpath, 1, length(dst_snpath) - 2) # chop `name`
		to = x sK_items sprintf("%02x", offset + c) # to = dst_snpath*,`items`,new_index
		len = length(to)

		if (0 == ary[child"ty"]) { # child is a plain item
			# move child under dst_i's sub-path
#if (trace) {x=ary[child];sub(/fff+/,"",x);print dbgind"A before",ary[child"nm"],x >"/dev/stderr"}
			ary[child"st"] = sst substr(ary[child"st"], length(sst) + 1) # sortable_tag
			ary[child"ls"] = ary[child"lv"] ":" (ary[child"sn"] = to substr(ary[child"sn"], len + 1)) # lvlsnpath
			menu2Dimplode(child, ary, nary)
#if (trace) {x=ary[child];sub(/fff+/,"",x);print dbgind"A  after",ary[child"nm"],x >"/dev/stderr"}
		} else { # child is sub-menu
			# move child's children under dst_i's path with offset
			move_node(child, dst_i, to sK_name, ary, nary, childrenary, trace)
		}
	}

	# Finally move src_i itself inside the destination tree with a new snpath equal to the snpath {{{
	# of the top destination node + call argument 'path', which grows with the recursion level.
	# Note that initially collate() calls move_node() with a null 'path' because there is no need
	# (nor a slot) to move the top source node under the top destination node.
	#}}}
	if (dst_path) {
		# Path already includes src_i's pre-computed offset.
		to = substr(dst_snpath, 1, length(dst_snpath) - 2) # chop `name`
		len = length(to)

#if (trace) {x=ary[src_i];sub(/fff+/,"",x);print dbgind"B before",ary[src_i"nm"],x >"/dev/stderr"}
		sst = substr(sst, 1, length(sst) - 4) # chop one `items` level
		ary[src_i"st"] = sst substr(ary[src_i"st"], length(sst) + 1) # sortable_tag
		ary[src_i"ls"] = ary[src_i"lv"] ":" (ary[src_i"sn"] = to substr(ary[src_i"sn"], len + 1)) # lvlsnpath
		if (1 == ary[src_i"ty"]) { # sub-menu
			y = ary[src_i"ac"]
			ary[src_i"ac"] = substr(y, 1, x = index(y,":")) to substr(y, x + len + 1) # action
		}
		menu2Dimplode(src_i, ary, nary)
#if (trace) {x=ary[src_i];sub(/fff+/,"",x);print dbgind"B  after",ary[src_i"nm"],x >"/dev/stderr"}
	}
}
#}}}
function menu2Dsplit(idx, ary, nary,   #{{{ >> ary[]*, return deepest item level; add 2D fields to 1D ary[] a.k.a. MENUS[]
	imin,imax,i,x,y,z,lump,rec,xary,nxary,maxlevel) {
# *If idx != 0 apply menu2Dsplit to ary[idx] only
# See work_record() for structure of MENUS[] records.
# When accessing the result array test for non-existent records like this:
#      for (i = 1; i <= NMENUS; i++) if (ary[i"sn"]) ... # use "sn" only!
# When modifying menu2Dsplit change menu2Dimplode accordingly.
# Below we lump together 'read-only' fields; by read-only we mean fields that
# the collation process will not modify whereas it may modify fields that
# we marks here as 'writable'.
	if (idx) {
		imin = imax = idx
	} else {
		imin = 1; imax = nary
	}
	maxlevel = 0
	for (i = imin; i <= imax; i++) if (i in ary) {
		nxary = split(ary[i], xary, SEP)
		ary[i"st"] = xary[1] # sortable_record 1st field (sortable_tag), writable
		lump = xary[2] # sortable_record 2nd field, read-only
		lump = (lump SEP) (x = xary[3]) # variable record size, read-only
		lump = (lump) (x == 3 ? "" : SEP xary[4]) # options ro, xref VARIABLE_REC
		ary[i"l1"] = lump
		ary[i"ls"] = x = xary[nxary - 2] # level:snpath
		ary[i"lv"] = z = substr(x, 1, (y = index(x, ":")) - 1) # level, ro
		if (z > maxlevel) maxlevel = z
		ary[i"sn"] = substr(x, y + 1) # snpath, writable
		ary[i"nm"] = xary[nxary - 1] # name, ro
		ary[i"ac"] = x = xary[nxary] # action, writable
		# meta info
		ary[i"ty"] = submenu_actionQ(x) ? 1 : 0 # 1(is sub-menu) : 0(isn`t => it`s plain item)
	}
	return maxlevel
	# Use menu2Dimplode([idx!=0]) to put record(s) back together.
}
#}}}
function menu2Dimplode(idx, ary, nary,   #{{{ >> ary[] return nary/idx*; implode 2D fields of ary[] into 1D ary[] a.k.a. MENUS[]
	imin,imax,i) {
# *If idx != 0 apply to ary[idx] and return idx
# See work_record() for structure of MENUS[] records.
	if (idx) {
		imin = imax = idx
	} else {
		imin = 1; imax = nary
	}
	for (i = imin; i <= imax; i++) if (ary[i"sn"]) {
		ary[i] = ary[i"st"] SEP ary[i"l1"] SEP ary[i"lv"] ":" ary[i"sn"] SEP ary[i"nm"] SEP ary[i"ac"]
	}
	return imax
}
#}}}
function children_map(ary, nary, idx, map, # {{{ >>map[*], return nmap == nary
	i,min,max) {
# for each sub-menu in ary[min...max] map a list of its children records as indexes of ary[]
# *min..max == 1..nary iff idx==0 else min==max==idx
	if (0 == idx) {
		min = 1
		max = nary
	} else {
		mix = max = idx
	}
	for (i = min; i <= max; i++) if (i"lv" in ary) {
		if (1 == ary[i"ty"])
			map[i] = menu_children(ary[i"ac"], ary, nary)
	}
	return nary
}

#}}}
function menu_children(matcher, ary, nary,  # {{{ return ordered list of menu children - ary[] indexes
	i,list) {
# ary is 1D MENUS[], matcher comes from format_action_submenu()
	for (j = 1; j <= nary; j++) {
		if (ary[j"ls"] ~ matcher) {
			list = list " " j
		}
	}
	return substr(list, 2)
}
#}}}
function calc_snpath_offset(list, ary,  # {{{ return snpath index of last element of list of indexes of 2D ary[]
	x,nxary,xary) {
# list can be null; generally it is the ordered list of children of some node in ary[]
# snpath index derives directly from JSON ..."items",index,"key"
	if (list) {
		# get last child's index
		nxary = split(list, xary, " ")
		x = get_items_index(xary[nxary], ary)
	} else {
		x = -1
	}
	return x
}
#}}}
function get_items_index(i, ary,  # {{{ return current index of 2D ary[i] which represents JSON `items`,index,`key`
	x,y) {
	if (! i in ary)
	    return -1 #ERROR
	y = ary[i"ls"] # i`s lvlsnpath
	# calculating the index {{{ xref NON_GNU_AWK
	# y ::= level ':' snpath, viz.,
	#   as jpath: ..."items",index,"key"
	#   in hex:   ... K_items  hh  K_<key>
	# so hh is the hex index we want
	#
	# xref NON_GNU_AWK:
	# Note that the hex-string-to-decimal conversion expression works on kindle's AWK
	# OOTB but doesn't work on GNU AWK - for that you need to start GNU AWK with
	# option --non-decimal-data (or use built-in function strtonum() which isn't
	# available in kindle's busybox awk
	x = length(y)
	x = 0 + ("0x" substr(y, x-3, 2))
	#}}}
#print "get_items_index ("i") lvlsnpath("y") = ("x")">"/dev/stderr"
	return x
}
#}}}
##: ESTR COLLATE

function escs2chars(s) { # {{{ expand JSON escapes - FIXME \uHHHH not expanded
	# valid escapes as per www.json.org
	# xref WHEN_TO_UNESCAPE - see also https://github.com/step-/JSON.awk/issues/2
	# invalid escapes silently ignored for now ? FIXME ?
	if (!match(s,/\\/)) return s
	# " \ / b f n r t u - u not supported FIXME
	gsub(/\\\\/,"\x01",s) # FIXME
	gsub(/\\\"/,"\"",s)
	gsub(/\\b/,"\b",s)
	gsub(/\\f/,"\f",s)
	gsub(/\\n/,"\n",s)
	gsub(/\\r/,"\r",s)
	gsub(/\\t/,"\t",s)
	gsub(/\x01/,"\\",s) # FIXME
	return s
}
#}}}

function find_menu_fullpathnames(dirs, return_ary, base,  # {{{ >>SELF_BUTTONS_INSERT; return new base with >>return_ary[++base], <<dirs like EXTENSIONDIR
	pj,nj,follow,depth,paths,slurp,i,ary,nary,menu,cmd) {
# assumes slurping mode @ BEGIN
# find all config.xml files and their corresponding json menu files
	# build find command {{{
	follow = "true" == config_get("nofollow") ? "" : "-follow"
	depth = config_get("search_depth")
	depth =	"-maxdepth " (""==depth ? 2 : 0+depth)
	paths = config_get("search_exclude_paths")
	# gsub(/;/, " ", dirs) # semicolon separated list would need iterating find
	paths = "-path "dirs"/" (""==paths ? "system" : paths)
	gsub(/;/," -o -path "dirs"/",paths) # semicolon-separated list
	cmd = config_get("NCbbfind")" "dirs" "follow" "depth" \\( "paths" \\) \\( -prune -type f \\) -o \\( -name config.xml -type f \\) 2>/dev/null"
	#}}}
	cmd | getline slurp
	if (close(cmd)) {
		scream(SenCantFindMenuFiles)
		return base
	}
	nary = split(slurp, ary, /\n/)
	if (nary) --nary # trim \n$
	for (i=1; i <= nary; i++) {
		menu = pathjson = pathxml = ""
		if (0 <= (getline slurp < ary[i])) # config.xml
			close(ary[i])
		if (slurp ~ /<extension>.+<\/extension>/) { # extension xml file
			if (match(slurp, /<menu\>[^>]+\<type="json"[^>]*>[^<]+<\/menu>/)) { # ignore non-json menu types
				slurp = substr(slurp,RSTART,RLENGTH-7) # <menu ...>name
				menu = substr(slurp,1+index(slurp,">")) # name
			}
		}
		if ("" != menu) {
			if ("^/" !~ menu) { # relative
				match(ary[i], /^.*\//)
				menu = substr(ary[i],RSTART,RLENGTH) menu # try absolute wrt config.xml
			}
			if (0 <= (getline x < menu)) {
				return_ary[++base] = menu
				close(menu)
			}
		}
	}
	return base
}
#}}}

function format_action_internal(internal,  # {{{ return formatted internal action, if any
	p,keyword,cmd) {
# internal ::= <keyword> [<args>]
	cmd = ""
	p = index(internal" "," ")
	keyword = substr(internal, 1, p - 1)
	if (keyword in INTERNAL_ACTIONS) {
		cmd = INTERNAL_ACTIONS[keyword] # <internal id char>
		internal = substr(internal, p + 1) # <args>
		cmd = cmd length(internal) "#" internal # <internal id char> <length> `<sharp>` [<args>]
	}
	return cmd
}
#}}}

function format_action_item(action, params, internal,   # {{{ return formatted item action
	p,cmd,x) {
	# action ::= <apath> ';' <shell cmd>
	p = index(action, ";")
	cmd = substr(action, p+1)
	if (x = format_action_internal(internal)) {
		# piggyback internal kindlet function
		action = "#" x action
	}
	return (action) ("" != params ? " " : "") (params)
	# [ '#' <internal id char> <length> '<sharp>' [ <args> ] ] <apath> ';' <shell cmd> [' ' <params>]
}
#}}}

#: BSTR crappy experiment with absolute paths
function format_action_item_absolute(action, params, internal,   # {{{ return formatted item action
	p,cmd,x) {
	# action ::= <apath> ';' <shell cmd>
	split(action, action_ary, ";")
	pwd = action_ary[1]
	cmd = action_ary[2]
	# Strip leading dot-slash, if need be
	if (cmd ~ /^\.\/.*?$/) {
		# Strip leading two chars...
		cmd = substr(cmd, 3)
	}
	# Fix broken action calls that don't set params properly, and instead include params in the action call...
	if (":" != cmd && "/var/tmp" != pwd) {
		cmd_nary = split(cmd, cmd_ary, " ")
		if (cmd_nary > 1) {
			# Append the params one by one...
			for (i=2; i<=cmd_nary; i++)
			{
				if (i == 2) {
					# First param
					cmd_params = cmd_ary[i]
				} else {
					cmd_params = cmd_params " " cmd_ary[i]
				}
			}
			# Reset cmd to just the cmd itself
			cmd = cmd_ary[1]
			# And rebuild the full action string with that proper cmd
			action = pwd ";" cmd
			# Append params if the entry is really, really broken and had also set params...
			if ("" != params) {
				params = cmd_params " " params
			} else {
				params = cmd_params
			}
		}
	}
	# Replace a real non-absolute cmd by its absolute path if it's living inside the extension folder... We've just made sure that it should be a single word ;).
	if (":" != cmd && "/var/tmp" != pwd && index(cmd, "/") != 1 && (getline junk < (pwd "/" cmd)) > 0) {
		close((pwd "/" cmd))
		cmd = pwd "/" cmd
		# And replace the command in the full action string
		action = pwd ";" cmd
		# NOTE: Kill DOS line endings?
	}
	if (x = format_action_internal(internal)) {
		# piggyback internal kindlet function
		action = "#" x action
	}
	return (action) ("" != params ? " " : "") (params)
	# [ '#' <internal id char> <length> '<sharp>' [ <args> ] ] <apath> ';' <shell cmd> [' ' <params>]
}
#}}}
#: ESTR crappy experiment with absolute paths

function format_action_submenu(level, items_path) { # {{{ return formatted sub-menu action
# The action is a regex that selects all direct descendant "name" items of the sub-menu's "items" node
	# A : drill down one level
	# B : into this."items"
	# C : match 0-254 (hex) possible elements of "items" (255=ff means "items" and isn't possible - "items"."items")
	# D : match the "name" therein
	#       ^  /'''A'''\     /''''B'''\ /'C\ /''D''\  $
	return "^" (level+1) ":" npath_wo_reserved(items_path) ".." sK_name "$"
	# xref MANGLE_MATCHER
}
# }}}

function json_emit_self_menu_and_parsing_errors(parent_errors,     # {{{ after ALL jp2np calls, appends to NPATHS[]
	json,name,sname,msg,ary,nary) {
# the KUAL menu is always placed topmost regardless of its "priority" key - see sort_for_user()
# if FAILS and/or self_menu add a json wrapper for the KUAL menu {{{
# json:
#	{ 	"items":[ { 	"name" : "KUAL/messages",
#				"items" : [
# this line for each FAIL x =>		{"name": "FAILS[x]", "action": "[ \"$KUAL\" ] && $KUAL 2"} ,
# this line for a KUAL entry =>		{"name": "entry", "action": "action"} ,
#				]
#			} ]
#	}
#}}}
	json=json_self_menu(SELF_BUTTONS_INSERT, SELF_BUTTONS_FILTER, SELF_BUTTONS_APPEND) # could return null

	if (parent_errors) {
		++ERRORS
		json=json "," json_error_button(fit_button(ATTN" "XenParentErrors, ""))
	}

	for(name in FAILS) {
		# do NOT include FAILS[name] in json string - FAILS[] could be multiline and break syntax
		json=json "," json_error_button(fit_button(ATTN" "XenErrSyntax" ", shortpathname(name)))
		# ++ERRORS # already done outside
	}

	if (json) { # send it to the kindlet
		name = SELF_MENU_NAME
		if (ERRORS)
			name = name " " ATTN " " ERRORS
		json="{\"items\":[{\"name\":\"" name \
			"\",\"items\":[" \
			substr(json,2) "]}]}"
		delete TOKENS; NTOKENS = ITOKENS = 0
		tokenize(json)
#print "tokenized json <(">"/dev/stderr";for(i=1;i<=NTOKENS;i++)printf TOKENS[i] >"/dev/stderr";print")>" > "/dev/stderr"
#printf "emit.parse.NJPATHS "NJPATHS">" > "/dev/stderr"
		parse()
#print ">"NJPATHS > "/dev/stderr"
		# serial 0 reserved for menu 'messages'
#printf "emit.jp2np.NNPATHS "NNPATHS">" > "/dev/stderr"
		jp2np(JPATHS, NJPATHS, 0, "/var/tmp/.")
#print ">"NNPATHS > "/dev/stderr"
	}
}
#}}}

function json_error_button(message) {  # {{{ after ALL jp2np calls, APPENDS to NPATHS[]
# return JSON-formatted error entry to be displayed as a menu button
	return "{\"priority\": -1000, \"name\": \"" \
		message \
		"\", \"action\": \":\", \"internal\": \"breadcrumb [more info in "PRODUCTNAME" log]\", \"exitmenu\": false}"
}
#}}}

function json_self_menu(extra_insert, standard_filter, extra_append,   # {{{ return KUAL menu of extra_insert+standard(filtered)+extra_append buttons as json data
	json,show,b,ary,nary,verb,btnpath,bak,x,y,slurp) {
# see blueprint in json_emit_self_menu_and_parsing_errors
# see also ash exec_self_menu()
	if (0 == (show = config_get("show_KUAL_buttons"))) # i j k... | 0 | nil
		return ""
	if ("" == show) show="2 3 99" # all currently defined standard buttons
show = "0 " show # FIXME temporary until a cache expiration policy is in place
	# standard buttons can be dynamically filtered by including {{{
	# a reference call argument standard_filter and processing it here
	# see BEGIN @ SELF_BUTTONS_FILTER and button "2" a.k.a. "sort_menu" below
	standard_filter = ","standard_filter","
	#}}}

	ORIGIN = PRODUCTNAME " menu" # report()
	json = ""
	# {{{ add extra_insert
	if (nary = split(extra_insert, ary, /,/)) {
		for (b = 1; b <= nary; b++) {
			if ("+add_ext" == ary[b]) {
				# {{{ breadcrumb message button: add extensions
				json = json "," json_self_menu_button( \
				     XenNoExtensionsFound, \
				     # www.mobileread.com/forums/showthread.php?t=203326
				     ":", "", "breadcrumb help @ http://bit.ly/kualit", \
				     -200, "", "e")
				#}}}
			}
		}
	}
	#}}}
	# {{{ add standard buttons
	if (nary = split(show, ary, /\s+/)) {
		for (b = 1; b <= nary; b++) {
			if (1 == ary[b]) {
			} else if (2 == ary[b] && ! index(standard_filter,",-sort_menu," ) ) {
				# {{{ menu entry #2, change KUAL sort order
				verb = OPT_SORT ~ /^ABC|abc$/ ? "123" : "ABC"
				# ABC! allowed in KUAL.cfg:KUAL_sort_mode only; here it gets reset

				# x <= AWK+sh script that replaces KUAL_sort_mode {{{
# How to escape escapes {{{
# By the time the shell executes a menu action, x, the original action string that we set here,
# has gone through three escaping mechanisms; AWK, JSON and the shell. Pay attention to quotes
# and shell metacharacters. Remember that:
# . You can quote-protect shell strings with single-quote delimiters, but AWK and JSON only
#   allow double-quote delimiters
# . You need to escape back-slash and double-quote characters for AWK
# . You need to escape them for JSON too
# . JSON does not allow control characters in strings, i.e., for TAB you must use \t and
#   you need to escape the back-slash character appropriately
# . etc. - escaping escapes can be confusing
# Some patterns
#   AWK string x 	enters JSON parser as 	becomes in menu entry
#   \\\\s 		\\s 			\s
#   \\\" 		\" 			"
#   \\\\\\\"		\\\" 			\"
#}}}

	# we want menu entry
# [ -r '/mnt/us/extensions/KUAL.cfg' ] || echo "# /mnt/us/extensions/KUAL.cfg - created on `date`" >'/mnt/us/extensions/KUAL.cfg';s=$(awk 'BEGIN{nf=1} /^\s*KUAL_sort_mode=/{sub(/=.*/,"=\"123\"");nf=0} {print} END{if(nf) print "KUAL_sort_mode=\"123\""}' '/mnt/us/extensions/KUAL.cfg') && [ 0 != ${#s} ] && echo "$s" >'/mnt/us/extensions/KUAL.cfg'

	# awk script
x = "BEGIN{nf=1} /^\\\\s*KUAL_sort_mode=/{sub(/=.*/,\\\"=\\\\\\\""verb"\\\\\\\"\\\");nf=0} {print} END{if(nf) print \\\"KUAL_sort_mode=\\\\\\\""verb"\\\\\\\"\\\"}"

	# sh wrapper
x = "awk '"x"' '"CONFIGPATH"'"
x = "s=$("x") && [ 0 != ${#s} ] && echo \\\"$s\\\" >'"CONFIGPATH"'"
x = "[ -r '"CONFIGPATH"' ] || echo \\\"# "CONFIGPATH" - created on `date`\\\" >'"CONFIGPATH"';" x
#}}}
				json=json "," json_self_menu_button( \
					"Sort menu "verb"", \
					x, "", \
					"", 2, "", "ecrs")
				#}}}
			} else if (3 == ary[b]) {
				# {{{ menu entry #3, copy SCREAM_LOG to documents
				# x <= sh script that saves KUAL.log {{{
x = "mv '"SCREAM_LOG"' \\\"/mnt/us/documents/"PRODUCTNAME"-`date -u -Iminutes | sed s/:/./g`.txt\\\";dbus-send --system /default com.lab126.powerd.resuming int32:1"
				#}}}
				json=json "," json_self_menu_button( \
					"Save and reset "PRODUCTNAME" log", \
					x, "", \
					"", 3, "\"\\\""SCREAM_LOG"\\\" -z!\"", "ecsd")
				#}}}
			} else if (99 == ary[b]) {
				# {{{ menu entry #99, quit KUAL
				json=json "," json_self_menu_button( \
					CROSS" Quit", \
					":", "", \
					"", 99)
				#}}}
			}
#: BSTR
#			else if (0 == ary[b]) {
#				# FIXME temporary - clear CACHEPATH # {{{
#				json=json "," json_self_menu_button( \
#					"Clear cache on restart (temp)", \
#					"rm -f '"CACHEPATH"'", "", \
#					"", 0, "", "ecsd")
#				#}}}
#			}
#: ESTR
		}
	}
	#}}}
	# {{{ add extra_append - TODO future expansion
	#}}}
	return json
}
#}}}

function json_self_menu_button(name, action, params, internal, priority, xif, non_default_options) { # {{{
	return "{\"name\": \"" name "\"" \
	", \"action\": \"" action "\"" \
	("" != params ? ", \"params\": \"" params "\"" : "") \
	("" != internal ? ", \"internal\": \"" internal "\"" : "") \
	("" != priority ? ", \"priority\": " priority : "") \
	("" != xif ? ", \"if\": " xif : "") \
	(index(non_default_options, "e") ? ", \"exitmenu\": false" : "") \
	(index(non_default_options, "c") ? ", \"checked\": true" : "") \
	(index(non_default_options, "r") ? ", \"refresh\": true" : "") \
	(index(non_default_options, "s") ? ", \"status\": false" : "") \
	(index(non_default_options, "d") ? ", \"date\": true" : "") \
	(index(non_default_options, "h") ? ", \"hidden\": true" : "") \
	"}"
}
#}}}

function jp2np(ary, size, serial, menufilepathname,   # {{{ appends to NPATHS[], NNPATHS
	i,x,npath,apath,jpath,key,value,level,errors) {
# description: convert jpaths to npaths {{{
# convert jpaths (parsed json) into qualified output records (with npaths):
#   level, npath, k_key, value
# IMPORTANT: np2mn() will sort qualified records ALPHAbetically - NOT numerically
#}}}
	# here we could also output an 'enter new file' marker to aid np2mn(), xref NEW_FILE_MARKER_AID
	errors=0

	# KUAL changes directory to menufilepath w/o name) before running commands
	apath=menufilepathname; sub(/\/[^\/]+$/, "", apath)

	while (jp2np_LAST_SEEN <= size) { # using LAST_SEEN enables building NPATHS[] incrementally
		line=ary[jp2np_LAST_SEEN++]  # { editor
		if (line ~ /[]}]$/) {
			# ignore array/object (when BRIEF=0)
			continue
		}
		#output level,npath,key,value
		x=index(line,"\t")
		jpath=substr(line, 1, x-1)
		value=substr(line, x+1)
		key = match(jpath, /"[^"]+"]$/) ? substr(jpath, 1+RSTART,RLENGTH-3) : "ERROR"
			# VALID_KEYS *without* items
		if (key !~ /^(name|action|params|internal|priority|if|exitmenu|hidden|checked|refresh|status|date)$/) {
			# silently skip invalid keys and "ERROR"
#print "SKIPPED key("key") in jpath("jpath")" >"/dev/stderr"
			continue
		}
		key=VALID_KEYS[key]

		x = jpath
		level = gsub(/"items",/, "&", x)
		if (0 == level) {
			# ignore leaf keys in top level menu (structurally invalid menu.json)
			continue
		}
		--level # base 0
		npath = npath_new(jpath, serial)

		# Unescape JSON escapes {{{
		if (2 == gsub(/^"|"$/, "", value)) { # it`s a string!
			# parse() does not expand JSON escapes, so we need to fix it here
			value = escs2chars(value) # xref WHEN_TO_UNESCAPE
		}
		#}}}
		if (K_name == key) {
			# expand &nbsp;
			gsub(NBSP0, NBSP1, value)
		} else if (K_action == key) {
			# prepend working dir ';' for temp launcher script to cd to
			# unescape json \"
			#gsub(/\\\"/, "\"", value)
			value=apath ";" value
		#} else if (K_params == key) {
			# unescape json \"
			#gsub(/\\\"/, "\"", value)
		}
		NPATHS[++NNPATHS]=level SEP npath SEP key SEP value
	}
	return errors
}
#}}}

function np2mn(ary, size,    # {{{ appends to MENUS[], NMENUS
	# name, action, params, internal, priority, if, exitmenu, checked, refresh, status, date, hidden => ITEM[] # VALID_KEYS w/o items
	i,x,slurp,lines,nlines,iline,errors,
	npary,level,npath,key,value,options,
	npath_s_this_items,select_level,needle,snpath,last_action  ) {
# description: convert npaths to internal menu data structure {{{
# convert N input qualified_records into M output menu_records, N <= M (= if no submenus exist)
# qualified_record (from jp2np) ::= level SEP npath SEP key SEP value
# menu_record ::= #lines [ \n kindlet_options ] \n level:snpath \n sortable_tag \n name \n action+params \n priority
#}}}
	errors=0

	# this is an internal sorting stage - it has nothing to do with user's prefs
	sort(ary, size, "-k2."(1+sRESERVED_len)",2 -k1,1 -k3,3") # by npath (ignoring reserved block) then level then key
	if ("" == SORTED_DATA) {
		scream("np2mn can't sort 1")
		++errors
	} else {

		sort_criteria_init(OPT_SORT) # affects sortable_record() and sort_for_user()
		new_item()
		new_submenu()

		select_level[0] = npath_wo_reserved(npath_new("",0))
		# init ^^ for level-0 sortable_tag items/menus - xref SORTABLE

		if (0 < (nlines = split(SORTED_DATA,lines, /\n/))) {
			for(iline = 1; iline < nlines; iline++) {
				split(lines[iline], npary, SEP)
				level = npary[1]; npath = npary[2]; key = npary[3]; value = npary[4]
				snpath = npath_get_short(npath)
				if (K_action == key) {
					ITEM[key] = value
					last_action = snpath
				} else if (K_name == key) {
					if ("" == value) # prevent null labels - allow white space labels
						value = "??"(++COUNTER["nameNull"])
					if (submenu_pathQ(snpath, last_action)) { # xref IS_SUBMENU
		# PLAIN ITEM
						ITEM[key]=value # item
						x = substr(ITEM[K_action], 1, index(ITEM[K_action],";")-1) # extension directory path
						if (RPN_if(ITEM[K_if], x)) {

							sortable_tag=select_level[level] # does not include the reserved block
							# ^^ xref SORTABLE, select_level[] set in else branch on previous iteration

							MENUS[++NMENUS] = work_record( \
								sortable_record(sortable_tag, OPT_SORT),
								kindlet_options(),
								level,npath_s_this_(K_name, snpath), # refers to this.`name`
								# here snpath refers to this."action" since K_action==0x00 by design
								ITEM[K_name],
								format_action_item(ITEM[K_action], ITEM[K_params], ITEM[K_internal]))
						}

						new_item()
					} else { # value is a submenu
		# SUBMENU
						ITEM[key]=value MMRK # sub-menu

						# 20130719: NiLuJe added RPN_if() support for sub-menus
						x = ITEM[K_name]
						if (RPN_if(ITEM[K_if], x)) {


# xref SORTABLE : tag a "name" with sortable data {{{
# We want to tag each item/submenu name with enough data fields that a
# sorting stage can take place according to user-defined criteria (123, ABC, ABC!).
#
# Sorting stage criteria: 'priority', 'lexicographic'.
# 'priority': by design K_priority < K_name therefore priority comes
#    into this loop before name, hence we know its value when it is time
#    to emit the item/submenu name.
# 'lexicographic': it means alpha-sorting the names that belong to the
#    same level of a sub-menu, that is, the drill-down level of that sub-menu;
#    so we can identify the 'items of the same level' with the sub-menu snpath
#    (with its "name" removed). We call it the select_level[i] operator.
#    Its value is an snpath and is right-padded, like an npath, to
#    enable correct lexicographic sorting.
#    Note: by design a submenu."name" comes before all its sub-items.
#
# Sorting algorith:
# . 'priority' : sort by <select_level> then by <"priority">
# . 'lexicographic' : sort by <select_level> then by <"name">
#
# Conclusion: Tag each record with <select_level> a.k.a sortable_tag.
#}}}
							npath_s_this_items = npath_s_this_(K_items, snpath) # refers to this.`items`
							# init sort tag elements for all sub-items/menus of this submenu {{{ # xref SORTABLE
							# push next drill-down items/sub-menus
							select_level[level+1] = npath_wo_reserved(npath_padded(npath_s_this_items))
							#}}}
							sortable_tag = select_level[level] # set for this menu - xref SORTABLE

							MENUS[++NMENUS] = work_record( \
								sortable_record(sortable_tag, OPT_SORT),
								kindlet_options(),
								level,snpath,
								# here snpath refers to this."action" since K_action==0x00 by design
								ITEM[K_name],
								format_action_submenu(level, npath_s_this_items))

						}
						new_submenu()
					}
				} else if (K_priority == key || K_params == key || K_internal == key || K_if == key || K_exitmenu == key || K_checked == key || K_refresh == key || K_status == key || K_date == key || K_hidden == key) {
					ITEM[key] = value
				} else {
					scream("unexpected key <"key"> (np2mu)")
					++errors
				}
			}
		}
	}

##: BSTR COLLATE
	if ("false" != config_get("collate"))
		collate(MENUS, NMENUS)
##: ESTR COLLATE

	sort_for_user(MENUS, NMENUS, OPT_SORT)
	if ("" == SORTED_DATA) {
		scream("np2mn can't sort 2")
		++errors
	}

	delete MENUS; NMENUS=0
	NMENUS = sort_criteria_cut(MENUS, OPT_SORT) # unpacks SORTED_DATA
	# shouldn't happen, but sort_criteria_cut() could ++ERRORS global (in case of non-implemented SORT_CRITERIA)

	return errors
}
#}}}

function kindlet_options(   x) {  # {{{ return string of option flags of <<ITEM[]
	x = (ITEM[K_exitmenu] ~ /^(0|false)$/ ? "e" : "") \
		(ITEM[K_checked] ~ /^(1|true)$/ ? "c" : "") \
		(ITEM[K_refresh] ~ /^(1|true)$/ ? "r" : "") \
		(ITEM[K_status] ~ /^(0|false)$/ ? "s" : "") \
		(ITEM[K_date] ~ /^(1|true)$/ ? "d" : "") \
		(ITEM[K_hidden] ~ /^(1|true)$/ ? "h" : "")
	return "" == x ? "" : x SEP
}
#}}}

#: BSTR too ugly, NOT USED
function KUAL_sh_deploy() { # {{{ deploy KUAL application library
# Users are allowed to hack the library, we create it only if it doesn't exist
	if (-1 == (getline < SCRIPTPATH)) {
KUAL_LIB_SH ="<insert KUAL.sh here>"
# /^#: SSTR KUAL.sh BEGIN/ r KUAL.sh |.,/^#: RSTR KUAL.sh END/-1 ! ./tool/strip.awk -v WARN=0 -v PROMPT=0
# /^#: SSTR KUAL.sh BEGIN/+1,/^#: RSTR KUAL.sh END/-1 s/"/»/g
# /^#: SSTR KUAL.sh BEGIN/+1,/^#: RSTR KUAL.sh END/-1 s/\n/«/g
# /^#: SSTR KUAL.sh BEGIN/+1,/^#: RSTR KUAL.sh END/-1 s/\\/°/g
#: SSTR KUAL.sh BEGIN
#: RSTR KUAL.sh END
		gsub(/»/, "\"", KUAL_LIB_SH) # >>
		gsub(/«/, "\n", KUAL_LIB_SH) # <<
		gsub(/°/, "\\", KUAL_LIB_SH) # DG
		print KUAL_LIB_SH >SCRIPTPATH
	}
	close(SCRIPTPATH)
}
#}}}
#: ESTR

function new_item() { # {{{ global map ITEM
	# VALID_KEYS w/o "items"
	ITEM[K_name] = ITEM[K_action] = ITEM[K_params] = ITEM[K_internal] =  ITEM[K_if] = ITEM[K_exitmenu] = ITEM[K_checked] = ITEM[K_refresh] = ITEM[K_status] = ITEM[K_date] = ITEM[K_hidden] = ""; ITEM[K_priority] = 0;
}
#}}}

function new_submenu() { # {{{ global map ITEM
	# VALID_KEYS of a submenu w/o "items"
	ITEM[K_name] = ITEM[K_if] = ITEM[K_hidden] = ""; ITEM[K_priority] = 0;
}
#}}}

function npath_from_jpath(jpath, serial,   # {{{ convert jpath to a unique numeric path
	items,key,snpath,ary,nary,i) {
# jpath ::= [ARRAY,idx,OBJECT,key,...] from parse()   {{{ Theory
#      e.g. for KUAL
# in input file #1:
#   ...
#   ["items",0,"name"] 	"Item 1 in Top-level Menu"
#   ["items",1,"name"] 	"Item 2 in Top-level Menu"
#   ...
#   ["items",n,"items",0,"name"]   "Item 1 in Sub-menu n+1"
# in input file #2:
#   ...
#   ["items",0,"items",0,"name"]   => "Item 1 in Sub-menu 1"
#   ...
# Ad-hoc simplification: We know these facts of the input data:
#    "items",m,...
# [a] jpaths are not unique, since each menu.json file is parsed
#     separately from the others. Issue: need to make jpaths unique.
# [c] "items" is the only compound object; keep its item index.
# [d] all remaining keys are leaf keys.
# [e] no leaf keys are allowed at the top level (see README-dev.txt)
#     (this is taken care of in jp2np())
#
# Simplified npath generation:
# . By [c] we encode each index as a 2-digit hex number, for a limit of
#   256 entries per each menu level. However we reserve value 0xff.
#   This leaves [0,254] as the allowed range for the menu entry index.
# . By [d] we encode each key name with a 2-digit hex number and assign
#   0xff to key "items". This is important for sorting.
# . We address issue [a] by prepending a serialization index that makes
#   each jpath unique. This index can be thought of as the index of
#   an outer "items" array that corresponds to the KUAL top menu itself.
#   Choosing "items" ensures that "items" remains the only possible
#   compound object that we need to encode.
#   In practice we prepend 0xff(items) 0xXX(serial) to each encoded jpath.
#   Note also that the serialization index starts at 1, so index 0 is
#   reserved for KUAL menu.
#
# Npath size: xref LIMITS
# . The longest jpath for 10 levels (1 top menu + 9 nested sub-menus)
#   consists of 20 elements = 20 bytes; add 1 element the key (1 byte); prepend
#   the "items",N serialization index (2 bytes), and reserved block (1 byte).
#     length(npath) = 24 bytes or 48 hex digits (NPATH_len).
# items_internal,N,items,0,items,1,items,2,items,3,items,4,items,5,items,6,items,7,items,8,items,9,KEY
#
# Sorting npaths: xref SORTABLE
# IMPORTANT: np2mn() sorts npaths ALPHAbetically - NOT numerically
# In any given jpath level, it is convenient to sort elements of array "items"
# *after* other keys of that level, e.g. after "name", the label of that level.
# We can achieve this by encoding key "items" as 0xff, and by right-
# padding npaths with 0xff. Recall that we also encode "items" indeces:
#     JPATH            CODE   NOTES
#   ..."name"         00ffff  00 is "name", next ffff is padding
#   ..."items"        ffffff  left ff is "items", next ffff is padding
#   ..."items".0      ff00ff  ff00 is "items".0, next ff is padding
#   ..."priority"     01ffff  01 is "priority", next ffff is padding
# Sorting the codes yields the following sequence:
# "name", "priority", "items".0, "items"
# which places the object container "items" last where it can be
# conveniently ignored. Note that in any given level "name" comes before
# all other elements and sub-elements of that level.
#
# CAVEAT: if A is a set of npaths and As the same set converted to short npaths,
#    sort(A) <> sort(As)   in general
# }}}
	items = sprintf("%02x", K_items)
	# build snapath: start with reserved block+"items",serial
	snpath = npath_reserved() sprintf("%s%02x", items, serial)

	# now append jpath elements, i.e.,
	#   ["items",0,"items",0,"items",1,"items",2,"key"]
	jpath=substr(jpath,2,length(jpath)-2) # drop []
	nary=split(jpath, ary, /\"items\"/)
	# <null> <,0,> <,0,> <,1,> <,2,"key">
	key=ary[nary]
	sub(/^.+,/, "", key);
	key=substr(key, 2, length(key)-2) # key
	sub(/\".+$/, "", ary[nary]) # ,2,
	# <null> <,0,> <,0,> <,1,> <,2,>
	for(i=2; i<=nary; i++) { # drop <null>
		snpath = snpath items sprintf("%02x", substr(ary[i],2,length(ary[i])-2))
	}
	# snpath ::= <reserved>ff01f02 key
	snpath = snpath sprintf("%02x", VALID_KEYS[key])
	return npath_padded(snpath)
}
# }}}
function npath_new(jpath, serial, # {{{ make single npath instance from jpath; call _new before _get functions - IDEMPOTENT
	key,npath,snpath) {
	key = jpath SEP serial
	if (key in NPATH_MAP)
		return NPATH_MAP[key]
	npath = snpath = npath_from_jpath(jpath, serial)
	sub(/(ff)+$/, "", snpath) # format snpath
	# enable look-up by jpath+serial, npath w/o reserved block and snpath w/o reserved block
	return NPATH_MAP[key] = NPATH_MAP[npath_wo_reserved(npath)] = NPATH_MAP[npath_wo_reserved(snpath)] = npath
}
#}}}
function npath_get(path, # {{{ lookup path (snpath or npath) and return npath
	upath,npath) {
	upath = npath_wo_reserved(path)
	return upath in NPATH_MAP ? NPATH_MAP[upath] : (npath_reserved() "NON-EXISTENT:npath_get("path")")
}
#}}}
function npath_get_short(path, # {{{ lookup path (snpath or npath) and return snpath
	upath,snpath) {
	upath = npath_wo_reserved(path)
	if (upath in NPATH_MAP) {
		snpath = NPATH_MAP[upath]
		sub(/(ff)+$/, "", snpath)
		return snpath
	}
	return (npath_reserved() "NON-EXISTENT:npath_get_short("path")")
}
#}}}
function npath_padded(path) { # {{{ return right-padded npath from input npath/snpath
	return substr(path FFS, 1, NPATH_len)
}
#}}}
#: BSTR - NOT USED
function npath_put(path, # {{{ replace NPATH_MAP[path] (path as snpath or npath) with path (formatted as npath); return previous npath
	npath,snpath,upath,prev) {
# npath_put() allows for replacing the reserved block of an existing npath

	npath = snpath = npath_padded(path) # format npath
	sub(/(ff)+$/, "", snpath) # format snpath
	upath = npath_wo_reserved(path)
	prev = upath in NPATH_MAP ? NPATH_MAP[prev] : ""
	# replace look-up by npath w/o reserved block and snpath w/o reserved block
	NPATH_MAP[npath_wo_reserved(npath)] = NPATH_MAP[npath_wo_reserved(snpath)] = npath
	return prev
}
#}}}
#: ESTR
function npath_reserved(path) { # {{{ if path return its reserved block else return a generic reserved block
#uncomment below to TEST whether the reserved block is handled transparently as it should be
#return "" == path ? sprintf("%02x",rand()*254) : substr(path, 1, sRESERVED_len)
	return "" == path ? sRESERVED : substr(path, 1, sRESERVED_len)
}
#}}}
function npath_wo_reserved(path,   x) { # {{{ return path (snpath or npath) without reserved block
	return substr(path,1+sRESERVED_len)
	# same idea's also applied in np2mn() by the call to sort()
}
#}}}
function npath_s_KUAL_menu() { # {{{
	# snpath of (level 0 "name", serial 0) a.k.a. the KUAL menu
	return npath_get_short(npath_new("[\"[items\",0,\"items\",0,\"name\"]", 0))
}
#}}}
function npath_s_this_(key, snpath) { # {{{
	# make this."key"'s snpath at current level
	return substr(snpath,1,length(snpath)-2) sprintf("%02x", key) # key ::= K_key constant, i.e., K_name, K_items, etc.
}
#}}}

function RPN_if(expr, source,   # {{{ return value of RPN conditional expression in JSON `if`:`expr` key/value pair
	x,token,nxary,xary) {
	if ("" == expr) return 1 # JSON `if` is optional and true when left unspecified
	RPN_sp = 0
	RPN_err = ""

	nxary = RPN_tokenize(expr, xary)
	for(x = 1; x <= nxary; x++) {
		token = xary[x]
		if (match(token, /^\".*\"$/))
			token = substr(token, 2, RLENGTH - 2) # dequote
		RPN_eval_bool(token)
		if(RPN_err) {
			scream(RPN_msg(expr, source, RPN_err))
			return 1
		}
	}
	if (1 != RPN_sp) {
		scream(RPN_msg(expr, source, "invalid expression"))
		return 1
	}
	return RPN_top()
}
#}}}
function RPN_eval_bool(token,   # {{{ >> RPN_stack
	x,y,z) {
	if (token !~ /^(-e|-ext|-f|-gg?!?|-m|-o|-z!|!|&&|\|\|)$/) { # add here and in RPN_tokenize()
		RPN_push(token)
	} else {
		x = RPN_stack[RPN_sp]
		RPN_pop();
		if (token == "!") {
			RPN_push(! x)
		} else if (token == "-f" || token == "-z!") { # does regular file x exist? isn`t empty?
			z = isRegularFileEmpty(x)
			RPN_push(token == "-f" && -1 != z || token == "-z!" && 0 < z)
		} else if (token == "-e") { # does path x exist? (special/regular/dir)
			RPN_push(!system("test -e \""x"\""))
		} else if (token == "-ext") {
			RPN_push(x in LOADED_EXTENSIONS)
		} else if (token == "-m") {
			RPN_push((z = config_get("model")) == x)
		} else {
			y = RPN_stack[RPN_sp]
			RPN_pop()
			if (token == "&&") {
				RPN_push(x && y)
			} else if (token == "||") {
				RPN_push(x || y)
			} else if (token ~ "-gg?!?") {
				if ( -1 == (z = RPN_grep(x, y, index(token, "!")))) {
				# file y doesn't exist
					if (index(token, "gg")) {
					# -gg!? becomes -f
						RPN_push(0)
					} else {
						RPN_err = "not found: \""y"\""
					}
				} else {
					RPN_push(z)
				}
			} else if (token == "-o") {
				RPN_push((z = config_get(y)) == x)
			} else {
				RPN_err = "invalid operator: " + token
			}
		}
	}
}
#}}}
# RPN_push/pop/top {{{
function RPN_push(x) { RPN_stack[++RPN_sp] = x }
function RPN_pop() { if(RPN_sp > 0) {RPN_sp--} else {RPN_err = "Stack underflow"} }
function RPN_top() { return RPN_sp > 0 ? RPN_stack[RPN_sp] : "--empty stack--" }
#}}}
function RPN_grep(pattern, file, vflag,   #{{{ grep [-v] pattern file; return 0/1/-1(file error)
	x, xary, nxary, found) {
# assumes SLURP mode
	if (0 < (getline x < file)) {
		close(file)
		nxary = split(x, xary, /\n/)
		if (vflag) {
			found = 0
			for (x = 1; x <= nxary; x++) {
				if (xary[x] ~ pattern) {
					found = 1
				}
			}
			return ! found
		} else {
			for (x = 1; x <= nxary; x++) {
				if (xary[x] ~ pattern) {
					return 1
				}
			}
			return 0
		}
	} else {
		return -1
	}
	return split(a1, ary, /\n/)
}
#}}}
function RPN_msg(expr, source, text) {  #{{{ return formatted error message
	return "\""source"\": JSON \"if\": "expr" : "text
}
#}}}
function RPN_tokenize(a1, ary,   #{{{ tokenize expression a1; >> ary[]; return sizeof(ary)
	SPACE) {
# tokenizes JSON syntax with RPN operators replacing JSON keywords
	SPACE="[[:space:]]+"

# see also tokenize()
#	gsub(STRING "|" NUMBER "|" KEYWORD "|" SPACE "|.", "\n&", a1)
	gsub(/\"[^[:cntrl:]\"\\]*((\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})[^[:cntrl:]\"\\]*)*\"|-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?|-e|-ext|-f|-gg?!?|-m|-o|-z!|!|&&|\|\||[[:space:]]+|./, "\n&", a1)
	gsub("\n" SPACE, "\n", a1)
	sub(/^\n/, "", a1)
	return split(a1, ary, /\n/)
}
#}}}
#: BSTR should we ever need an RPN calculator
function RPN_eval_calc(token,   # {{{ >> RPN_stack
	x,y) {
# adapted from http://www.stacken.kth.se/~foo/rpn/#AWK
	if (token != "-" && (token ~ /^[-.0-9][0-9]*[.0-9]?[0-9]*$/))
		RPN_push(token)
	else {
		y = RPN_stack[RPN_sp]; RPN_pop()
		x = RPN_stack[RPN_sp]; RPN_pop()
		if (token == "+") RPN_push(x + y)
		else if (token == "-") RPN_push(x - y)
		else if (token == "*") RPN_push(x * y)
		else if (token == "/") RPN_push(x / y)
		else RPN_err = "Invalid operator: " + token
	}
}
#}}}
#: ESTR

function sort(ary, nary, sort_options,   # {{{ >> global string SORTED_DATA
	tfl,i,cmd,rec) {
# assumes "slurping" RS (@ BEGIN)

	SORTED_DATA = ""
	if (0 == nary) return

	tfl=TFL"-sort" substr(rand(),3)

	# write input file
	for (i=1; i<=nary; i++) {
		if (rec = ary[i]) print rec > tfl
	}
	close(tfl)

	cmd = config_get("NCbbsort")" -t \""SEP"\" "sort_options" < \""tfl"\""
	cmd | getline SORTED_DATA
	if (close(cmd))
		scream(SenCantSort)
}
#}}}

function sort_criteria_init(opt_sort) { # {{{ initialize SORT_CRITERIA* globals
# Post-sorting stage will CUT out the first SORT_FIELDS fields when sending records to the Kindlet

	if ("ABC" == toupper(opt_sort)) {
		SORT_CRITERIA=1
		SORT_FIELDS=2
	} else if ("ABC!" == toupper(opt_sort)) {
		SORT_CRITERIA=2
		SORT_FIELDS=2
	} else if ("123" == toupper(opt_sort)) {
		SORT_CRITERIA=3
		SORT_FIELDS=2
	} else {
		SORT_CRITERIA = SORT_FIELDS = 0
	}
}
#}}}

function sortable_record(sortable_tag, opt_sort) { # {{{ << global SORT_CRITERIA; return SORT_FIELDS fields to be prepended to work record
# sortable_tag: FIXED number of record fields consisting of the sorting keys
# . no sorting keys are allowed AFTER the sortable_tag fields
# . sortable_tag MUST be the in position 1 - xref VARIABLE_REC
	if (1 == SORT_CRITERIA || 2 == SORT_CRITERIA ) { # ABC or ABC!
		return sortable_tag SEP ITEM[K_name] SEP # -k1,1 -k2,2
	} else if (3 == SORT_CRITERIA) { # 123
		return sortable_tag SEP ITEM[K_priority] SEP # -k1,1 -k2,2n
	}

	return ""
}
#}}}

function sort_criteria_cut(ary, opt_sort,   # {{{ << global SORTED_DATA,SORT_CRITERIA,SORT_FIELDS >> ary, return: nary
	nary,p,x,i) {
# reverse the application of sortable_record() by chopping off the sorting keys
	i = nary = split(SORTED_DATA, ary, /\n/)
	if (0 < SORT_CRITERIA) {
	       if(2 == SORT_FIELDS) {
			# cut -d SEP -f3-
			while (i > 0) {
				x = ary[i]
				p = index(x, SEP)
				p += index(substr(x, p+1), SEP)
				ary[i] = substr(x, p+1)
				--i
			}
		} else {
			scream("SORT_FIELDS != 2 not implemented")
			++ERRORS
		}
	} else { # least likely usage
		# nothing to cut
	}
	return nary
}
#}}}

function sort_for_user(ary, nary, opt_sort,    # {{{ << global SORT_CRITERIA, >> global string SORTED_DATA
	cherry,i,ary0,nary0,non_zero,rec) {
	# cherry pick the KUAL menu and place it topmost {{{
	cherry = SEP "0:" npath_wo_reserved(npath_s_KUAL_menu()) SEP
	for (i = 1; i <= nary; i++) {
		if (index(ary[i], cherry)) {
			cherry = ary[i]
			ary[i] = 0 # delete ary[i]
			break
		}
	}
	if (i > nary) {
		cherry="" # not found
		scream("can't select "PRODUCTNAME" menu entry")
	}
	#}}}

	SORTED_DATA=""
	if (1 == SORT_CRITERIA) { # ABC
		# sort level 0 entries only {{{

		# separate out level 0 vs level>0 entries
		nary0 = 0
		non_zero = "" # index list
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i]) {
				if (rec ~ SEP"0:")
					ary0[++nary0] = rec
				else
					non_zero = non_zero "/" i
			}
		}
		sort(ary0, nary0, "-s -f -k1,1 -k2,2")

		# append level>0 entries to level 0 sort results
		non_zero = non_zero "/"
		for (i = 1; i <= nary; i++) {
			if (index(non_zero, "/"i"/"))
				SORTED_DATA = SORTED_DATA "\n" ary[i]
		}
	#}}}
	} else if (3 == SORT_CRITERIA) { # 123
		sort(ary, nary, "-s -k1,1 -k2,2n")
	} else if (2 == SORT_CRITERIA) { # ABC!
		sort(ary, nary, "-s -f -k1,1 -k2,2")
	} else { # least likely usage, `fake` SORTED_DATA {{{
		SORTED_DATA=MENUS[1]
		for(i=2; i<=NMENUS; i++) {
			SORTED_DATA = SORTED_DATA "\n" MENUS[i]
		}
	}
	#}}}

	if ("" != cherry) {
		SORTED_DATA = cherry "\n" SORTED_DATA
	}
}
#}}}

function submenu_actionQ(action) { # {{{ is action a sub-menu action ?
	return "^" == substr(action, 1, 1) && "$" == substr(action, length(action))
	# xref MANGLE_MATCHER
}
#}}}

function submenu_pathQ(snpath, last_action,     x,y) { # {{{ does snpath refer to a sub-menu?
# last_action refers to the value of the most recent "action" key saved in the outer loop
# The following discussion applies to the processing sequence in np2mn.
# xref IS_SUBMENU : How to tell incoming "name" is a sub-menu vs. a plain item? {{{
# Ignore the value of the reserved block and consider the following points:
# 1. Name's snpath and action's snpath differ by just their rightmost byte (key);
#    Iff name and last_action belong to the same object then name refers to a plain item.
# 2. By design K_action < K_name therefore "action" is always known before "name"
#    in the outer loop and last_action <= snpath(action), so:
# 2.1. When a new name comes in, compare its snpath with last_action's and
# 2.2. If #1 holds between the current name and last_action then name is a plain item
#      otherwise name is a sub-menu.
#}}}
	x = npath_wo_reserved(snpath)
	y = npath_wo_reserved(last_action)
	return substr(x,1,length(x)-2) == substr(y,1,length(y)-2)
}
#}}}

function work_record(a_sortable_record, options, level,snpath, name, action, # {{{
	lvlsnpath) {
	lvlsnpath = level ":" npath_wo_reserved(snpath)
	return sprintf("%s%s"SEP"%s%s"SEP"%s"SEP"%s",
		a_sortable_record, # fixed in 1st position!
		"" == options ? 3 : 4, # variable record size
		options,
		lvlsnpath, name, action)
		# collate()/menu2Dsplit() access these fields from the end, i.e. last, last-1, last-2, etc. xref VARIABLE_REC
}
# }}}

# utilities {{{
function fit_button(left, right,   len,rlen,cut) { # {{{
# left-cut right_string so that left_string+right_string fits into a button label
	len=MAX_LABEL_LEN - length(left)
	if (len < (rlen=length(right))) {
		right=substr(right,rlen-len+1)
		right=" .."substr(right,4)
	}
	return left right
}

#}}}

function formatter(ary, nary, fmt_name, outfile,   # {{{ append ary to outfile and leave outfile open; return error count
	fmt,i,rec,x,n,errors) {
	errors = 0
	if ("multiline" == fmt_name) {
	# \n for kindlet
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i]) {
				gsub(SEP,"\n",rec)
				print rec >>outfile
			}
		}
	} else if ("tbl" == fmt_name) {
	# table DEV NOTE: recommended using this fmt_name from time to time to check for bad record structure
		fmt="%-4.4s|%-24.24s|%-20.20s|%-33.33s\n"
		for (i = 1; i <= nary; i++) {
		       	if (rec = ary[i]) {
				n = split(rec, x, SEP)
				if (n-1 != x[1]) {
					scream("wrong record size <"x[1]"> in record # "i" (formatter)")
					++errors
					print rec >>outfile # kindlet never gets this format
				}
				if (4 == n) {
					printf fmt,   "", x[2], x[3], x[4]
				} else if (5 == n) {
					printf fmt, x[2], x[3], x[4], x[5]
				} else {
					scream("wrong argument count "n" in record # "i" (formatter)")
					++errors
					print rec >>outfile # kindlet never gets this format
				}
			}
		}
	} else if ("tab" == fmt_name) {
	# tab-separated
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i]) {
				gsub(SEP,"\t",rec)
				print rec >>outfile
			}
		}
	} else {
	# passthrough
		for (i = 1; i <= nary; i++) {
			if (rec = ary[i])
				print rec >>outfile
		}
	}
	return errors
}
#}}}

function shortpathname(pathname,   ary,nary) { # {{{ shorten /a/b/.../z/file to z/file
	return (nary = split(pathname, ary, /\//)) \
		? ary[nary-1] "/" ary[nary] : pathname
}
#}}}

#: BSTR not used
function store_button_filepath(   KT532,ret) { # {{{ >> global FILEPATH_STORE_BUTTON
	if ("-" == FILEPATH_STORE_BUTTON) {
		return ""
	} else if ("" != FILEPATH_STORE_BUTTON) {
		return FILEPATH_STORE_BUTTON
	}
	KT532="/usr/share/webkit-1.0/pillow/javascripts/search_bar.js"
	if (0 <= (getline < KT532)) {
		ret = FILEPATH_STORE_BUTTON = KT532
		close(KT532)
	} else {
		FILEPATH_STORE_BUTTON = "-"
		ret = ""
	}
	return ret
}
#}}}
#: ESTR

#NiLuJe, then commented and slightly adapted by stepk
function get_model(    file,line,device) {#{{{ >>global MODEL; return MODEL or ``
# assumes SLURP mode
	if (MODEL) return MODEL
	MODEL = "Unknown"
	# Devise the model from the device code, which we get from the S/N. See KindleTool's kindle_tool.h for the list of device codes.
	file = "/proc/usid"
	if ((getline line < file) > 0) { # if, since we slurp anyway
		close(file) # you may close only what got actually opened, else awk errors out
		# Strip the B0/90 (leading 2 chars)...
		device = substr(line, 3, 2)
		MODEL =   device ~ /^(02)|(03)$/ ? "Kindle2" \
			: device ~ /^(04)|(05)$/ ? "KindleDX" \
			: device ~ /^(09)$/ ? "KindleDXG" \
			: device ~ /^(08)|(06)|(0A)$/ ? "Kindle3" \
			: device ~ /^(0E)|(23)$/ ? "Kindle4" \
			: device ~ /^(0F)|(11)|(10)|(12)$/ ? "KindleTouch" \
			: device ~ /^(24)|(1B)|(1D)|(1F)|(1C)|(20)$/ ? "KindlePaperWhite" \
			: device ~ /^(D4)|(5A)|(D5)|(D6)|(D7)|(D8)|(F2)|(17)|(60)|(F4)|(F9)|(62)|(61)|(5F)$/ ? "KindlePaperWhite2" \
			: device ~ /^(C6)|(DD)$/ ? "KindleBasic" \
			: device ~ /^(13)|(54)|(2A)|(4F)|(52)|(53)$/ ? "KindleVoyage" \
			: "Unknown"
		# Handle the new device ID scheme...
		if ( MODEL == "Unknown" ) {
			device = substr(line, 4, 3)
			MODEL =   device ~ /^(0G1)|(0G2)|(0G4)|(0G5)|(0G6)|(0G7)|(0KB)|(0KC)|(0KD)|(0KE)|(0KF)|(0KG)|(0LK)|(0LL)$/ ? "KindlePaperWhite3" \
				: device ~ /^(0GC)|(0GD)|(0GR)|(0GS)|(0GT)|(0GU)$/ ? "KindleOasis" \
				: device ~ /^(0DU)|(0K9)|(0KA)$/ ? "KindleBasic2" \
				: device ~ /^(0LM)|(0LN)|(0LP)|(0LQ)|(0P1)|(0P2)|(0P6)|(0P7)|(0P8)|(0S1)|(0S2)|(0S3)|(0S4)|(0S7)|(0SA)$/ ? "KindleOasis2" \
				: "Unknown"
		}
	}
	return MODEL
}
#}}}
#: BSTR old method
function get_model_old(    x, #{{{ >>global MODEL; return MODEL or ``
	y,z,xary,nxary,cpu_mod) {
# assumes SLURP mode
# adapted from https://github.com/koreader/koreader/blob/master/frontend/ui/device.lua#L9
# see also http://www.mobileread.com/forums/showthread.php?t=212988
	if (MODEL) return MODEL
	MODEL = "Unknown"
	cpu_mod = ""
	y = "/proc/cpuinfo"
	if (0 <= (getline x < y)) {
		close(y)
		if (nxary = split(x, xary, /\n/)) {
			for (x = 1; x <= nxary; x++) {
				z = xary[x]
				if (match(z, /MX[0-9]+/)) {
					cpu_mod = substr(z, RSTART, RLENGTH)
					break
				}
				if (z ~ "Hardware : Mario Platform") {
					MODEL = "KindleDXG"
					break
				}
			}
		}
	}
	if (cpu_mod == "MX50") {
		if (! system("test -e \"/sys/devices/system/fl_tps6116x/fl_tps6116x0/fl_intensity\""))
			MODEL = "KindlePaperWhite"
		else if (! system("test -e \"/sys/devices/platform/whitney-button\""))
			MODEL = "KindleTouch"
			# another special file for KT is Neonode zForce touchscreen:
			# /sys/devices/platform/zforce.0/
		else
			MODEL = "Kindle4"
	} else if (cpu_mod == "MX35") {
		MODEL = "Kindle3"
	} else if (cpu_mod == "MX3") {
		MODEL = "Kindle2"
	}
	return MODEL
}
#}}}
#: ESTR old method

function isRegularFileEmpty (x,   #{{{ return -1(x is special file or non-existent) 0(x exists and is empty) 1(exists and isn`t empty)
	y,z) {
	z = (getline y < x)
	if (0 <= z) close(x)
	return z
}
#}}}

#}}}

# Parser core {{{
function get_token() { #{{{
# usage: {tokenize($0); while(get_token()) {print TOKEN}}
	## return getline TOKEN number for external tokenizer
	TOKEN = TOKENS[++ITOKENS] # for internal tokenize()
	return ITOKENS < NTOKENS
}
#}}}

function parse_array(a1,   idx,ary,ret) { #{{{
	idx=0
	ary=""
	get_token()
#scream("parse_array(" a1 ") TOKEN=" TOKEN)
	if (TOKEN != "]") {
		while (1) {
			if (ret = parse_value(a1, idx)) {
				return ret
			}
			idx=idx+1
			ary=ary VALUE
			get_token()
			if (TOKEN == "]") {
				break
			} else if (TOKEN == ",") {
				ary = ary ","
			} else {
				report(", or ]", TOKEN ? TOKEN : "EOF")
				return 2
			}
			get_token()
		}
	}
	if (1 != BRIEF) {
		VALUE=sprintf("[%s]", ary)
	} else {
		VALUE=""
	}
	return 0
}
#}}}

function parse_object(a1,   key,obj) { #{{{
	obj=""
	get_token()
#scream("parse_object(" a1 ") TOKEN=" TOKEN)
	if (TOKEN != "}") {
		while (1) {
			if (TOKEN ~ /^".*"$/) {
				key=TOKEN
			} else {
				report("string", TOKEN ? TOKEN : "EOF")
				return 3
			}
			get_token()
			if (TOKEN != ":") {
				report(":", TOKEN ? TOKEN : "EOF")
				return 4
			}
			get_token()
			if (parse_value(a1, key)) {
				return 5
			}
			obj=obj key ":" VALUE
			get_token()
			if (TOKEN == "}") {
				break
			} else if (TOKEN == ",") {
				obj=obj ","
			} else {
				report(", or }", TOKEN ? TOKEN : "EOF")
				return 6
			}
			get_token()
		}
	}
	if (1 != BRIEF) {
		VALUE=sprintf("{%s}", obj)
	} else {
		VALUE=""
	}
	return 0
}
#}}}

function parse_value(a1, a2,   jpath,ret,x) { #{{{
	jpath=(a1!="" ? a1 "," : "") a2
#scream("parse_value(" a1 "," a2 ") TOKEN=" TOKEN ", jpath=" jpath)
	if (TOKEN == "{") {
		if (parse_object(jpath)) {
			return 7
		}
	} else if (TOKEN == "[") {
		if (ret = parse_array(jpath)) {
			return ret
	}
	} else if (TOKEN ~ /^(|[^0-9])$/) {
		# At this point, the only valid single-character tokens are digits.
		report("value", TOKEN!="" ? TOKEN : "EOF")
		return 9
	} else {
		VALUE=TOKEN
	}
	if (! (1 == BRIEF && ("" == jpath || "" == VALUE))) {
		x=sprintf("[%s]\t%s", jpath, VALUE)
		if(0 == STREAM) {
			JPATHS[++NJPATHS] = x
		} else {
			print x
		}
	}
	return 0
}
#}}}

function parse(   ret) { #{{{
	get_token()
	if (ret = parse_value()) {
		return ret
	}
	if (get_token()) {
		report("EOF", TOKEN)
		return 11
	}
	return 0
}
#}}}

function report(expected, got,   i,from,to,context) { #{{{ <<global ORIGIN, report parsing errors
	from = ITOKENS - 10; if (from < 1) from = 1
	to = ITOKENS + 10; if (to > NTOKENS) to = NTOKENS
	for (i = from; i < ITOKENS; i++)
		context = context sprintf("%s ", TOKENS[i])
	context = context "<<" got ">> "
	for (i = ITOKENS + 1; i <= to; i++)
		context = context sprintf("%s ", TOKENS[i])
	scream("expected <" expected "> but got <" got "> at input token " ITOKENS "\n" context,
	       "" != ORIGIN ? ORIGIN : FILENAME)
}
#}}}

function reset() { #{{{ *** CUSTOMIZED *** to allow appending to JPATHS[]
# Since we build JPATHS[] incrementally from multiple input files we
# comment out below:        delete JPATHS; NJPATHS=0
# otherwise each new input json file would reset JPATHS[]. The main input
# loop includes code to delete partial JPATHS[] elements that can
# result from parse() errors upon processing malformed json input.
	TOKEN=""; delete TOKENS; NTOKENS=ITOKENS=0
	# delete JPATHS; NJPATHS=0
	VALUE=""
}
#}}}

function scream(msg, origin, #{{{
	x) {
	if ("" == origin)
		origin=PRODUCTNAME
	if (! SCREAMED_BEFORE) {
		++SCREAMED_BEFORE
		"date" | getline x
		close("date")
		printf "\n%s: ***** started %s on %s", PRODUCTNAME, VERSION, x >> SCREAM_LOG
	}
	FAILS[origin] = FAILS[origin] (FAILS[origin]!="" ? "\n" : "") msg
	msg = origin ": " msg
#: BSTR writing to stderr/stdout may block java runtime.exec() if unread, so don't!
	print msg > "/dev/stderr"
#: ESTR
	print msg >> SCREAM_LOG
}
#}}}

function tokenize(a1,   pq,pb,ESCAPE,CHAR,STRING,NUMBER,KEYWORD,SPACE) { #{{{
# usage A: {for(i=1; i<=tokenize($0); i++) print TOKENS[i]}
# see also get_token()

	# POSIX character classes (gawk) - contact me for non-[:class:] notation
	# Replaced regex constant for string constant, see https://github.com/step-/JSON.awk/issues/1
#	ESCAPE="(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})"
#	CHAR="[^[:cntrl:]\"\\]"
#	STRING="\"" CHAR "*(" ESCAPE CHAR "*)*\""
#	NUMBER="-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?"
#	KEYWORD="null|false|true"
	SPACE="[[:space:]]+"

#	gsub(STRING "|" NUMBER "|" KEYWORD "|" SPACE "|.", "\n&", a1)
	gsub(/\"[^[:cntrl:]\"\\]*((\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})[^[:cntrl:]\"\\]*)*\"|-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?|null|false|true|[[:space:]]+|./, "\n&", a1)
	gsub("\n" SPACE, "\n", a1)
	sub(/^\n/, "", a1)
	ITOKENS=0 # get_token() helper
	return NTOKENS = split(a1, TOKENS, /\n/)
}
#}}}
#}}}

# vim:fdm=marker:
