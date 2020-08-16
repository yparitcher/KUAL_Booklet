#!/bin/ash -
# aloop.sh - version 20130226,b,stepk
# a.k.a. parse.sh in KUAL git
# Tested on KT 5.1.2 /bin/busybox ash (it's ash not (ba)sh!), version banner:
#   BusyBox v1.17.1 (2012-07-17 16:29:54 PDT) multi-call binary
# and on K3 /bin/busybox sh running on KT 5.1.2, version banner:
#   BusyBox v1.7.2 (2012-09-01 14:15:22 PDT) multi-call binary.
# UTF-8 support untested.

usage () {
local -
: BSTR
echo "Usage: ${0##*/} [options]
  parse menu files in $EXTENSIONDIR
  options may also be set in {$EXTENSIONDIR}/$CONFIGFILE as
    KUAL_options=\"-f=twolevel -s\" # (default options)
  when both KUAL_options and command-line options are present they are combined
  in this order, and if conflicts arise the last option wins.

Options: *=active when no options or just -l found in command-line or $CONFIGFILE"
cat << 'EOT'
 -h | --help
 -c=MAX   add modular color index in [0..MAX] when -f=twolevel
 -e=N[,ARGS]   exec backdoor entry N with ,-separated ARGS
*-f=NAME   select output format, NAME is one of:
   onelevel    action name, sortable
   debuginfo   dump xml_* and json_* variables
   touchrunner compatible with TouchRunner launcher, sortable
*  twolevel    group name + action name, sortable, see also -c
 -l   enable logging to stderr (ignored in $CONFIGFILE)
 -p=FMT    output format specifier (a debugging aid), FMT is one of:
   tbl     tabular
   tab     tab-separated
   "..."   a printf format specification string
   =       passthrough
*-s=ORDER   sort output, ORDER is one of:
*  abc  lexicographic by group, names within each group do not move
   ABC  lexicographic by group and by action name, same name groups coalesce
   123  by priority, group's first then action's (json)

Limitations:
. Supports json menus only
. Supports one- or two-level menus only
. A menu entry must not extend across multiple lines. Example of valid entry:
  {"name": "a label", "priority": 3, "action" : "foo.sh", "params": "p1,p2"}
  with or without a trailing comma
. Character codes > 127 can lead to unparsable menu entries
EOT
: ESTR
}

set -f # prevent pathname expansion

# dev can adjust these four variables:
CONFIGFILE="KUAL.cfg" # first found in $EXTENSIONDIR
PRODUCTNAME="KUAL"
#EXTENSIONDIR="/mnt/us/extensions:./extensions" # colon-separated list
EXTENSIONDIR="/mnt/us/extensions" # colon-separated list
SEPARATOR=`printf "\x01"`

# --- --- --- #
COLORMAX=0 # for -f=twolevel -c=
EXITSTATUS=0
FORMATTER="formatter" # $1:''(\n,default) 'tbl'(table) 'tab'(\t)

case " $* " in
  *" -l "*)
     opt_log=1;
     alias log='echo >&2'" ${0##*/}: " # enabled
  ;;
  *) alias log='echo >/dev/null ' # disabled
  ;;
esac

# knc1's magic with minimal busybox syntax:
# IFS settings used for string parsing and auto-fixing DOS line endings.
# Whitespace == :Space:Tab:Line Feed:Carriage Return:
WSP_IFS=`printf "\x20\x09\x0A\x0D"`
# No Whitespace == :Line Feed:Carriage Return:
NO_WSP=`printf "\x0A\x0D"`
# Whitespace == :Space:Tab:
WSP=`printf "\x20\x09"`

# Double quote
QUOTE=`printf "\x22"`
SPACE=' '
LT='<'
GT='>'

# Character entities that work around limitations of sed:
# Non-breaking space - use to force sorting menu entries at bottom
NBSP0='&nbsp;' ; NBSP1=`printf "\xC2\xA0"` # 2-byte UTF-8 encoded

alias sort='/bin/busybox sort' # GNU sort needs setting LC_ALL to work like BB
alias SORT="/bin/busybox sort -t '$SEPARATOR'"
alias find='/bin/busybox find'
alias sed='/bin/busybox sed'
alias grep='/bin/busybox grep'
alias CUT="/bin/busybox cut -d '$SEPARATOR'"

# Kindle Screen messages - see screen_msg()
: SSTR
enTestApplet="              WELCOME TO $PRODUCTNAME

$PRODUCTNAME IS INSTALLED. PLEASE ADD SOME EXTENSIONS"
enStoreButtonReplaced="
STORE BUTTON REPLACED
PLEASE RESTART YOUR KINDLE
FOR CHANGES TO TAKE EFFECT"
enStoreButtonRestored="
STORE BUTTON RESTORED
PLEASE RESTART YOUR KINDLE
FOR CHANGES TO TAKE EFFECT"
enStoreButtonUnchanged="
STORE BUTTON UNCHANGED
ANOTHER APP ALREADY HOLDS IT"
: RSTR

# eips messages - these must fit in a screen line (48 chars)
XenErrNotInstalled="$PRODUCTNAME incomplete install."

# Kindlet button messages - these must fit in a button label - see emit_error()
XenErrConfig="config"
XenErrUsage="usage"
XenErrNoTestApplet="can't install the test applet"
XenErrTestAppletStuck="can't uninstall the test applet"

# display up to four lines on the kindle screen
# usage (note where the quotes go): screen_msg [-lm=COL] [-wo] "$line1
#line2
#line3
#line4"
# Default left margin is column 5. Insert -lm=N, with N=0..48, to change
# Add -wo (after -lm, if any) to write OVER a previous screen_msg (skips blanking the reporting area)
screen_msg () {
  local - IFS=${WSP_IFS} msg caps col row=8 line i wo=0
  case "$1" in -lm=[0-9]|-lm=[0-9][0-9]) col=${1#-lm=} ; shift ;; esac
  case "$1" in -wo) wo=1 ; shift ;; esac
  msg="$@"
  caps=`eips -i 2>/dev/null` || return # not a Kindle or a Kindle w/o eips
  set -- ${caps#*Variable framebuffer info}
#local i=0; while [[ $((++i)) -le $# ]]; do printf "%2d " $i; eval echo "\${$i}"; done
  if [[ 0 = $wo ]]; then
    local xres=$2 # yres=$4
    eips -d l=00,w=$xres,h=104 -x 0 -y 148 2>/dev/null 1>&2
    eips -d l=ff,w=$xres,h=100 -x 0 -y 150 2>/dev/null 1>&2
  fi
  IFS=${NO_WSP}
  i=0
  printf "%s\n" "$msg" | while read line; do
    [[ $((++i)) -le 4 ]] || break
    case "$line" in
      -*) line=${line##-} ;; # delete leading dash(es), eips goes crazy
    esac
    eips ${col:-5} $((row++)) "${line}" 2>/dev/null 1>&2
  done
}

# let other scripts execute some of my functions
unset XSECT
case " $* " in
*" -x "*) while [[ "$1" != -x ]]; do shift; done; shift;
case "$1" in
0) shift; #XSECT=`env`
;;
1) shift; screen_msg "$@"; exit
;;
esac
esac

# usage: script_full_path [-p]
script_full_path () {
  # symlinks not considered
  local pth=$(2>/dev/null cd "${0%/*}" >&2; pwd -P)
  [[ "-p" = "$1" ]] || pth=$pth/${0##*/}
  echo -n "$pth"
}

# return full path of $CONFIGFILE if one exists or can be created
# usage: config_full_path [create]
# 'create' creates $CONFIGFILE if it doesn't exist
config_full_path () {
  local - IFS=: p cfp= a1=$1
  for p in $EXTENSIONDIR; do
    [[ -e "$p/$CONFIGFILE" ]] && { cfp="$p/$CONFIGFILE"; break; }
  done
  if [[ -n "$cfp" ]]; then
    echo -n "$cfp"
  elif [[ create = "$a1" ]]; then
    set -- $EXTENSIONDIR
    cfp="$1/$CONFIGFILE"
    echo "# $CONFIGFILE - created on `date`" > "$cfp" && echo -n "$cfp"
  fi
}

#usage: clean_up_previous_runs SCRIPTPATH (fullpaths only)
#delete SCRIPTPATH's like-named siblings provided their paths match a typical kindle jre 'tmp filepath' pattern
clean_up_previous_runs () {
  local - IFS pth=${1%/*}
  set +f
  case "$pth/" in */tmp/*|*/temp/*) true ;; *) return ;; esac
  local x me=$1 name=${1##*/} suf glob
  suf="${name##*.}"; [[ -n "$suf" ]] && suf=".$suf"
  glob="$pth/${name%-*}-*${suf}" # -* matches for -PIDs
  log "clean-up glob($glob)=\"`echo ${glob}`\""
  IFS=${NO_WSP}
  for x in `printf "%s\n" ${glob}`; do [[ "$x" = "$me" ]] || rm "$x"; done
}

# usage: result=`str_repl_chars "SRC" "CHARS" CHR`
# replace all occurrences of characters of CHARS in SRC with character CHR
str_repl_chars () {
  local - IFS src=$1 chars=$2 chr=$3
  set -f
  IFS=$chars
  set -- $src
  IFS=$chr
  echo -n "$*"
}

# Usage: json_parse /path/to/menu.json [PROC]
# Stdout: PROC's formatted menu items
# Return: # of successful PROC calls
# Note: json_parse unsets+sets global variables json_*.
# For each input line that matches "action" this function creates a set of sh
# variables named json_N1, json_N2, ... where N1, N2, etc. are json key names.
# And for the input line that matches "name" but not "action" json_parse sets
# variable json_name0, which is the top level menu name, a.k.a. the group.
# And for the input line that matches "priority" but not "action" json_parse
# sets variable json_priority0.
# Finally json_parse calls function PROC, which outputs a formatted combination
# for json_* (and previously-defined) xml_* variables.
# Note: json_parse() modifies the values of json_name and json_name0 by
# removing $SEPARATOR and squeezing spaces in preparation for making labels.
# Unmodified values are saved in jsonU_name and jsonU_name0 (-f=debuginfo).
json_parse () {
  local - IFS=${WSP_IFS} line menu=$1 proc=$2 count=0
  local CountNulls=0 # $proc may increment it
  shift 2
  local _w='[0-9a-zA-Z_]' _s=`printf "[\x20\x09]"`
  local dquot=`printf "\x22"` x01=`printf "\x01"` lf="`printf '\x0D'`" esc='\\\\\\'
  local json_name0 jsonU_name0 json_name jsonU_name json_action json_params json_priority json_priority0
  unset vars json_name0 jsonU_name0 json_priority0
  log $menu
: SSTR
  sed -ne "# convert json key:value to shell var=value
	# dispatch
	/\"action\"/b magic # includes keys 'name' and 'priority'
	/\"\(name\|priority\)\"/b magic0  # top-level keys 'name' or 'priority'
	b
: magic0
	s/\(name\|priority\)/\10/ # rename key
	# assert: name0 and priority0 come before all other sub-keys
: magic
	# trim opening {[, and closing ]},
	s/^${_s}*[[{,]*${_s}*//
	s/${_s}*[]},]*${_s}*\$//
#p;b
	# mark id:value pairs
	s/\([^${x01}]\+\)/${x01}\1${x01}/
	s/,${_s}*${dquot}/${x01}${x01}${dquot}/g
#p;b
	# split them onto separate lines (formatter pattern space)
	s/${x01}\([^${x01}]\+\)${x01}/\n\1/g
#p;b
	# morph each line into ash variable syntax
	s/${dquot}${_s}*:${_s}*/=/g
	s/\n${dquot}/\njson_/g
#p;b
	p # done
	a EVAL
  " < $menu \
  | sed -ne "# apply escapes and clean-ups
	{
		# translate json-escaped interior double quotes
		s/${dquot}/${x01}/ ; s/${dquot}\$/${x01}/ # suspend exterior quotes
		s/${dquot}/\\\\${x01}/g
		s/${x01}/${dquot}/g # restore exterior quotes
	#p;b
	}
	/json_name.\?=/{ # for each json_name? variable
		# save copy as jsonU_name?
		h; s/^\(.*json\)_\([^=]\+\)=\(.*\)$/\1U_\2=\3/g; p;x
		# clean up original to prepare for making labels
		s/[${SEPARATOR}]//g; s/[${WSP}]\+/ /g}
	}
	# shell-escape special characters that affect doublequoted strings
	s/\([$]\)/${esc}\1/g
#p;b
	# expand known character entities
	s/${NBSP0}/${NBSP1}/g
#p;b
	p # done
  " \
  | {
    while read line; do
: RSTR
#(before 2nd sed above)  | { while read line; do echo >&2 ">$line<"; echo "$line"; done; }
#echo >&2 ">>$line<<"; continue
      if [[ EVAL = "$line" ]]; then
        unset json_name jsonU_name json_action json_params json_priority
        eval $vars
        unset vars
        [[ -z "$json_action" ]] && continue
        $proc $* && count=$((++count))
      else
        vars="$vars${lf}$line"
      fi
    done
    return $count
  }
}

# Usage: xml_var /path/to/config.xml NAME [NAME ...]
# Note: xml_var unsets+sets all requested global variables xml_NAME...
# xml_var creates one or more variables xml_NAME from an extension's config.xml
# file - the file must include tag "<extension>". Example:
#  xml_var config.xml author menu => xml_author(Mad Hatter) xml_menu(menu.json)
# Limitations:
# . opening and closing XML tags must be on the same line
# . XML values with embedded double quotes not supported
xml_var () {
  local v line xml=$1 valid=0
  shift
  for v in $*; do eval "unset xml_$v"; done
  while read line; do
    case $line in
    *"<extension>"*) valid=1 ;; # extension xml file
    *) for v in $*; do
         case $line in
         *${LT}$v${GT}* | *${LT}$v${SPACE}*)
           line=${line#*${LT}$v}
           line=${line#*${GT}}
           line=${line%${LT}/$v${GT}*}
           [[ 1 = $valid ]] && eval "xml_$v=\$(printf %s \"$line\")"
           break
         ;;
         esac
       done
    ;;
    esac
  done < $xml
}

# dump xml_* and json_* variables
debug_info () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local - IFS=${WSP_IFS} v c=0 vars jsonpath=$1 jsonfile=$2
  echo $jsonpath/$jsonfile
#bash only: supports varname expansion and varname reference
#      echo -n "${0##*/} parsed:"
#      for v in ${!xml_*};  do echo -n " $v='${!v}'"; done
#      for v in ${!json_*}; do echo -n " $v='${!v}'"; done
#      for v in ${!jsonU_*}; do echo -n " $v='${!v}'"; done

#ash: hardwired variable names
 vars="xml_name json_name0 jsonU_name0 json_priority0
 json_name jsonU_name
 json_action json_params
 json_priority"
 for v in $vars; do
   eval "[[ \"\$$v\" ]] && printf \"%4d $v='%s'\\n\" \$((++c)) \"\$$v\""
 done
}

# usage by one_level() et al.: shift; set_backdoor_args "$@"
set_backdoor_args() {
  json_name0=$3
  json_priority0=$4
  json_priority=$5
  json_name=$6
  json_action=$7
  json_params=$8
}

# one_level emits 2,json_name,action' 'json_params
# args when backdoor==$1: 'backdoor',action_path,json_filename,json_name0,json_priority0,json_priority,json_name,json_action,json_params
# args otherwise: action_path,json_filename
one_level () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local - label=${json_name} apath=$json_action group action_path=$1 priority=''
  # top level menu name
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  # prevent null labels
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  # fully qualify action path
  [[ -e "$action_path/$json_action" ]] && apath=\"$action_path/$json_action\"
  # sort by priority?
  [[ 123 = "$opt_sort" ]] && priority="${json_priority0:-0}$SEPARATOR${json_priority:-0}$SEPARATOR"

  echo "$TIER$SEPARATOR${priority}2$SEPARATOR$group · $label$SEPARATOR$apath $json_params"
}

# touch_runner emits action_path,action,json_params,group'.'json_name (separator ';')
# see also one_level() for args
touch_runner () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local label=$json_name action=$json_action group action_path=$1 priority=''
  # top level menu name
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  # prevent null labels
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  # qualify label
  label=`str_repl_chars "$group" . _`.$label
  # sort by priority?
  [[ 123 = "$opt_sort" ]] && priority="${json_priority0:-0}$SEPARATOR${json_priority:-0}$SEPARATOR"

  echo "$TIER$SEPARATOR$priority$action_path$SEPARATOR$action$SEPARATOR${json_params:-NULL}$SEPARATOR$label"
}

# two_level emits 3,group,json_name,action' 'json_params
# see also one_level() for args
two_level () {
  case $1 in backdoor) shift; set_backdoor_args "$@";; esac
  local label=$json_name apath=$json_action group action_path=$1 priority=''
  # top level menu name
  [[ "${json_name0}" ]] && group=${json_name0} || group=${xml_name}
  # prevent null labels
  [[ -z "$group" ]] && group=${1##*/}
  [[ -z "$label" ]] && label=$((++CountNulls))
  # fully qualify action path
  [[ -e "$action_path/$json_action" ]] && apath=\"$action_path/$json_action\"
  # sort by priority?
  [[ 123 = "$opt_sort" ]] && priority="${json_priority0:-0}$SEPARATOR${json_priority:-0}$SEPARATOR"
#group="$group,${json_priority0:-0}" # DEBUG
#label="$label,${json_priority:-0}" # DEBUG

  echo "$TIER$SEPARATOR${priority}3$SEPARATOR$group$SEPARATOR$label$SEPARATOR$apath $json_params"
}

# prepend modular color index - applied when -f=twolevel and -c>0
# emits one more field
colorize () {
  # global COLORMAX SEPARATOR
  local IFS=${NO_WSP} cindex=-1 cstate='' line meta group
  while read line; do
    IFS=${SEPARATOR} ; set -- $line ; meta=$1 group=$2 ; IFS=${NO_WSP}
    shift 1 # $* = $line w/o $meta
    if [[ "$cstate" != "$group" ]]; then
      cstate=$group
      cindex=$(( ($cindex + 1) % $COLORMAX ))
    fi
    echo "$((++meta))$SEPARATOR$cindex$SEPARATOR$*"
  done
}

# usage: loop [ignorecount]
# find and process all config.xml files and their corresponding json menu files
loop () {
local - IFS=:${NO_WSP} TIER=2 f px pj nj count=0 ignorecount=0 t list
case $1 in
  ignorecount) ignorecount=1 ;;
esac
for f in $(find $EXTENSIONDIR -name config.xml 2>&-); do
  log $f
  xml_var $f name menu
#echo "xml_name($xml_name) xml_menu($xml_menu)"
  [[ "$xml_menu" ]] || continue # not extension config.xml file
  case "${xml_menu##*.}" in
    json) ;; # ok
    *) continue ;; # do not know how to handle this menu type
  esac
  px=${f%/*} # px path to config.xml
  # pj path to json menu
  case "$xml_menu" in
    /*) pj=${xml_menu%/*}
    ;;
    *) # is relative
       pj=$px/${xml_menu}
       pj=${pj%/*}
    ;;
  esac
  nj=${xml_menu##*/} # nj json menu filename
  if [[ -f $pj/$nj ]]; then
    json_parse $pj/$nj $proc $pj $nj || count=$(($? + $count)) # allow -e by ||
  fi
done
log loop counted $count entries
# when extensions dir is empty
[[ 00 = $count$ignorecount ]] && test_applet install && loop ignorecount
# append  KUAL's own menu entries
[[ 0 = $ignorecount ]] && emit_self_menu
return 0
}

# output KUAL's own menu entries, see also exec_self_menu()
emit_self_menu() {
  local - IFS=${WSP_IFS} TIER=3 c0=$count
  # menu entry #1, replace/restore Store button with KUAL
  local verb=Replace btnpath=`store_button_filepath`
  if [[ -e "$btnpath" ]]; then
    [[ -e "$btnpath.KUAL_bak" ]] && verb=Restore
    $proc backdoor \
    "${SCRIPTPATH%/*}" '(backdoor)' \
    "$PRODUCTNAME" 1000 0 "$verb Store Button" \
    "/bin/ash" "\"$SCRIPTPATH\" \"-e=1,$verb\"" \
    && count=$((++count))
  fi
  # menu entry #2, change KUAL sort order
  local order0 order1 opt
  case "$opt_sort" in
    abc)   menu1=123; opt1=-s=123 ; menu2=ABC; opt2=-s=ABC ;;
    123)   menu1=abc; opt1=-s=abc ; menu2=ABC; opt2=-s=ABC ;;
    ABC|*) menu1=123; opt1=-s=123 ; menu2=abc; opt2=-s=abc ;;
  esac
  $proc backdoor \
  "${SCRIPTPATH%/*}" '(backdoor)' \
  "$PRODUCTNAME" 1000 0 "Sort Menu \"$menu1\"" \
  "/bin/ash" "\"$SCRIPTPATH\" \"-e=2,$opt1\"" \
  && count=$((++count))
  $proc backdoor \
  "${SCRIPTPATH%/*}" '(backdoor)' \
  "$PRODUCTNAME" 1000 0 "Sort Menu \"$menu2\"" \
  "/bin/ash" "\"$SCRIPTPATH\" \"-e=2,$opt2\"" \
  && count=$((++count))

  # other button above this line #
  TIER=3.99
  # menu entry #99, quit KUAL
  $proc backdoor \
  "/dev/null/sic" '(backdoor)' \
  "$PRODUCTNAME" 1000 99 "Quit" \
  "true" "" \
  && count=$((++count))
  #
  log "$(($count - $c0)) self-menu entries added"
}

# usage: exec_self_menu ENTRY#[,args]
exec_self_menu() {
  local - IFS=,
  set -- $*
  IFS=${WSP_IFS}
  case $1 in
  1) # replace/restore K5/PW Store button with KUAL
    local verb=$2 btnpath=`store_button_filepath` bak
    [[ -e "$btnpath" ]] || return # unsupported platform
    bak=$btnpath.KUAL_bak
    case $verb in
      Restore) [[ -e "$bak" ]] || return # nothing to restore
        mntroot rw && mv -f "$bak" "$btnpath"
        mntroot ro
        screen_msg "$enStoreButtonRestored" # killall cvm
      ;;
      Replace) [[ -e "$bak" ]] && return # already replaced
        local needle='app://com.lab126.store'
        if ! grep -q -m 1 -F "$needle" "$btnpath"; then
          screen_msg "$enStoreButtonUnchanged"
          return
        fi
        local repl=`KUAL_filepath`
        [[ -e "$repl" ]] || return # devs renamed KUAL file w/o notice
        if mntroot rw && mv "$btnpath" "$bak"; then
          sed -e "s~\([\"']\)$needle\(['\"]\)~\1file://$repl\2~" "$bak" > "$btnpath"
          mntroot ro
          screen_msg "$enStoreButtonReplaced" # killall cvm
        fi
      ;;
    esac
  ;;
  2) # change KUAL sort order
    local opt=$2 config=`config_full_path create` newtext='' line found=0
    local _s=`printf "[\x20\x09]"` dquot=`printf "\x22"`
    IFS=${NO_WSP}
    newtext=$( #
: SSTR
      sed -e "
/^${_s}*KUAL_options=/ {
	# delete existing sort option(s)
	s/${_s}-s=.*\>//g
	s/-s=.*\>${_s}//g
	s/-s=.*${dquot}/${dquot}/
}
      " "$config" \
    | {
: RSTR
    # add new sort option
    while read line; do
#echo >&2 ">$line<"
        case $line in #(
          *KUAL_options=\"\") echo "KUAL_options=\"$opt\"" ; found=1
        ;; #(
          *KUAL_options=\"*\") echo "${line%?} $opt\"" ; found=1
        ;; #(
          *KUAL_options=*) echo "KUAL_options=\"${line#KUAL_options=} $opt\"" ; found=1
        ;; #(
          *) echo "$line"
        ;;
        esac
      done
      [[ 0 = $found ]] && echo KUAL_options=\"$opt\"
      }
    ) #
    [[ 0 != ${#newtext} ]] && echo "$newtext" > "$config"
  ;;
  99) # reserved, Quit KUAL
  ;;
  esac
}

store_button_filepath() {
  local KT532=/usr/share/webkit-1.0/pillow/javascripts/search_bar.js
  [[ -e "$KT532" ]] && echo -n "$KT532"
}

KUAL_filepath() {
  local -
  set +f
  set -- `echo /mnt/us/documents/KUAL-KDK-*.azw2`
  [[ -e "$1" ]] && echo -n "$1"
}

# usage: test_applet install|uninstall
# adds/removes a simple test applet in First($EXTENSIONDIR)
# Installing clears and recreates an existing installation of the test applet
# return: non-zero on creation error
test_applet () {
  local - prnm=`str_repl_chars "$PRODUCTNAME" "${WSP}" _`
  local dir=${EXTENSIONDIR%%:*}/$prnm
  local sh="$dir/test.sh" xml="$dir/config.xml" json="$dir/menu.json"
  [[ -d "$dir" ]] && rm -f "$sh" "$xml" "$json" && rmdir "$dir"
  case "$1" in
  uninstall)
    if [[ -d "$dir" ]]; then
      echo >&2 "${0##*/}: XenErrTestAppletStuck"
      emit_error 1 XenErrTestAppletStuck
      return 1
    fi
    log "test applet uninstalled"
  ;;
  install)
: SSTR
    mkdir -p "$dir"
    if ! { [[ -d "$dir" ]] \
    && echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<extension>
	<information>
		<name>$PRODUCTNAME</name>
		<version>1.0</version>
		<author>stepk</author>
		<id>Test</id>
	</information>
	<menus>
		<menu type=\"json\">menu.json</menu>
	</menus>
</extension>" > "$xml" \
    && echo "{
      emit_error 1 XenErrNoTestApplet
\"items\": [
	{
		\"name\": \"$NBSP0$PRODUCTNAME\",
		\"priority\": 1000,
		\"items\": [
			{\"name\": \"${NBSP0}Test $PRODUCTNAME\", \"priority\": 0, \"action\": \"test.sh\"}
		]
	}
]
}" > "$json" \
    && echo "#/bin/ash -
[[ \"\$KUAL\" ]] && exec \$KUAL 1 -lm=3 \"$enTestApplet\" || eips 2 38 \"$XenErrNotInstalled\"
" > "$sh" \
    && chmod +x "$sh" && log "test applet installed"
    }
    then
      echo >&2 "${0##*/}: $XenErrNoTestApplet"
      emit_error 1 XenErrNoTestApplet
      return 1
    fi
  ;;
  esac
  return 0
: RSTR
}

## drop the first three fields
#drop3 () {
#  local - IFS=${NO_WSP} line
#  while read line; do
#    line=${line#*$SEPARATOR}
#    line=${line#*$SEPARATOR}
#    line=${line#*$SEPARATOR}
#    echo "$line"
#  done
#}

# formatter emits a formatted record; $1=FORMAT_SPEC (default multiline)
formatter () {
  local - IFS=$SEPARATOR fmt nl line
  case $1 in
    =) fmt="%s" ;; # passthrough
    tbl) fmt="%-2.2s|%-20.20s|%-25.25s|%-25.25s" ;;
    tab) fmt="%s\t" ;;
    *) [[ -n "$1" ]] && fmt=$1 || fmt='%s\n' ;;
  esac
  nl="${fmt%\\n}" ; [[ "$nl" = "$fmt" ]] && nl='\n' || unset nl
  while read line; do
    printf "$fmt" $line
    printf "$nl"
  done
}

# usage: emit_error TIER ERROR_MESSAGE_NAME [MESSAGE]
# Emit error message as a button label; TIER defines button placement:
# . TIER=1 put button at the beginning of the button list
# . TIER=2 put button according to sort criteria of loop()
# . TIER=3 put button at the end of the button list
# Reminder: calling screen_msg() from emit_error() is pointless, since
# the Kindlet overwrites the screen with the button list.
emit_error () {
  local TIER=$1 name=$2 msg
  shift 2
  eval "msg=\"\${$name} $*\"" # this must fit in a button label
  $proc backdoor /dev/null/sic '(backdoor)' '!err!' 0 0 "$msg" true ''
  EXITSTATUS=1
}

# parse script options
# Note: short options require '=' to set option values
get_options () {
local - opt status=0 x
# global opt_*
unset opt_execmenu opt_format opt_sort
for opt in "$@"; do
  case "$opt" in
    -c=*) x=${opt#*=}
       case "$x" in [0-9]|[0-9][0-9]|[0-9][0-9][0-9]) COLORMAX=$(($x)) ;; esac ;;
    -e=*) opt_execmenu=${opt#*=} ;;
    -f=*) x=${opt#*=}
      case "$x" in
        onelevel|twolevel|touchrunner|debuginfo) opt_format=$x ;;
        *)
          echo >&2 "${0##*/}: invalid option '-f=$x': using default options"
          echo "emit_error 1 XenErrUsage \"-f=$x invalid, defaults used\""
        ;;
      esac
    ;;
    -h|--help) usage >&2; exit ;;
    -l) ;; # pre-parsed near top of file
    -p=*) FORMATTER="formatter \"${opt#*=}\"" ;;
    -s=*)  x=${opt#*=}
      case "$x" in
        123|abc|ABC) opt_sort=$x ;;
        *)
          echo >&2 "${0##*/}: invalid option '-s=$x': using default options"
          echo "emit_error 1 XenErrUsage \"-s=$x invalid, defaults used\""
        ;;
      esac
    ;;
    *)
      echo >&2 "${0##*/}: invalid option '$opt': using default options"
      echo "emit_error 1 XenErrUsage \"$opt invalid, defaults used\""
      status=1
    ;;
  esac
done
return $status
}

# echo sort step
sortx () {
local - t byname=''
case "$opt_sort" in
  abc|ABC)
    case $proc in
      one_level) echo "| SORT -f -k 1,1n -k 3,3 -s | CUT -f 2-" ;;
      touch_runner) echo "| SORT -f -k 1,1n -k 5,5 -s | CUT -f 2-" ;;
      two_level) [[ 0 -lt $COLORMAX ]] && t=' | colorize' || t=''
        [[ ABC = $opt_sort ]] && byname="-k 4,4" # w/ byname we also sort action names within each group, and same name groups coalesce
        echo "| SORT -f -k 1,1n -k 3,3 $byname -s | CUT -f 2-$t"
      ;;
    esac
  ;;
  123)
    case $proc in
      one_level) echo "| SORT -f -k 1,1n -k 2,2n -s | CUT -f 4-" ;; # by group name only; adding by action name -k 3,3n yields questionable order because it seemingly mixes different groups together (though one_level really does not support groups)
      touch_runner) echo "| SORT -f -k 1,1n -k 2,2n -s | CUT -f 4-" ;;   # ditto
      two_level) [[ 0 -lt $COLORMAX ]] && t=' | colorize' || t=''
        echo "| SORT -f -k 1,1n -k 2,2n -k 5,5 -k 3,3n -s | CUT -f 4-$t" # while here prepending by group name -k 5,5 to by action name priority -k 3,3n yields a useful improvement: each priority tier is also lexicographic by group name.
      ;;
    esac
  ;;
  *)
    case $proc in
      two_level) [[ 0 -lt $COLORMAX ]] && t='| colorize' || t=''
      echo "|CUT -f 2-$t"
    ;;
      *) echo "|CUT -f 2-"
    esac
  ;;
esac
}

init () {
local TIER=1 gotOptions=false KUAL_options='' x

CONFIGPATH=`config_full_path`
SCRIPTPATH=`script_full_path`

# load optional config file and KUAL_options=
if [[ -e "$CONFIGPATH" ]]; then
  if ! source "$CONFIGPATH"; then
    echo "emit_error 1 XenErrConfig \"$CONFIGPATH\""
    echo "emit_error 3 XenErrConfig \"$CONFIGPATH\""
    KUAL_options='' # carry on with default options
  fi
fi

until [[ true = "$gotOptions" ]]; do
  if [[ \( 0 = $# -a -z "$KUAL_options" \) -o \( 1 = $# -a -n "$opt_log" -a -z "$KUAL_options" \) ]]; then
    set -- -f=twolevel -s=abc # default
  else
    set -- $KUAL_options "$@"
  fi
  if get_options "$@"; then
    gotOptions=true
  else
    KUAL_options=''
    set -- ${opt_log+-l}
  fi
done
[[ -z "$opt_format" ]] && opt_format=twolevel # default

[[ -e "$CONFIGPATH" -a -n "$opt_log" ]] && log "found $CONFIGPATH
`cat $CONFIGPATH`"
log "system `uname -rsnm`"
log "run options: $opt_format $opt_sort ($*)"
clean_up_previous_runs "$SCRIPTPATH"

if [[ "$opt_execmenu" ]]; then
  exec_self_menu $opt_execmenu
  exit $?
fi

case "$opt_format" in
  twolevel) proc=two_level; COLORIDX=-1 ; COLORSTATE="" ;;
  onelevel) proc=one_level ;;
  touchrunner) proc=touch_runner; SEPARATOR=';' ;;
  debuginfo) proc=debug_info ;;
#  *) echo 2>&1 ${0##*/}: unknown format \"$opt_format\"; usage; exit 1 ;;
esac

test_applet uninstall

# CONFIGPATH and SCRIPTPATH changed in init()
# all others changed in get_options()
echo "
CONFIGPATH='$CONFIGPATH'
SCRIPTPATH='$SCRIPTPATH'
opt_format='$opt_format'
opt_sort='$opt_sort'
opt_log='$opt_log'
opt_execmenu='$opt_execmenu'
proc='$proc'
COLORMAX='$COLORMAX'
FORMATTER='$FORMATTER'
"
}

# MAIN #

# IMPORTANT: *anything* that the user should see, including error messages,
# must be piped through $to_user, which sends to the Kindlet. Setting up
# $to_user requires calling init().
# Catch-22: init() could need to output early error messages through $to_user
# Solution: Capture init's output until $to_user is fully set up.
# By design we prefer capturing output in memory (without temp files). We run
# init through backticks, that is in a subshell[6] that can't change MAIN's
# environment. $starter is the captured output, and because of catch-22 it is
# dynamic code that will be evaluated when $to_user is fully set up.

log "start pid($$)"
starter=`init "$@"` # required setup for all further steps
log "starter($starter)"
proc=':' # NOP evaluation of very early error messages
eval "$starter" >/dev/null # no stdout until $to_user is set up
log "proc($proc)"
to_user="`sortx` | $FORMATTER"
log "to_user($to_user)"
eval "{ $starter; loop; } $to_user"
t=$?
#[[ x = "${XSECT:+x}" ]] && echo 0 && echo "$XSECT"
[[ -z "$EXITSTATUS" ]] && EXITSTATUS=$t
log "exit status($EXITSTATUS)"
exit $EXITSTATUS

