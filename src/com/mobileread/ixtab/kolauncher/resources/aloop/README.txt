*** THIS README FILE IS NOT UP-TO-DATE WITH KUAL 2 SOURCE CODE ***

Installing
----------

Drop the script anywhere, make it executable, optionally edit it and change
the default value of $EXTENSIONDIR. Run it with /bin/ash.

Using
-----

PLEASE NOTE USAGE, IT'S: /bin/ash /path/to/aloop.sh [options]

# /bin/ash aloop.sh -h 
Usage: aloopx.sh [options]
  parse menu files in /mnt/us/extensions:./extensions
  options may also be set in {/mnt/us/extensions:./extensions}/KUAL.cfg as
    KUAL_options="-f=twolevel -s" # (default options)
  when both KUAL_options and command-line options are present they are combined
  in this order, and if conflicts arise the last option wins.

Options: *=active when no options or just -l found in command-line or KUAL.cfg
 -h | --help
 -c=MAX   add modular color index in [0..MAX] when -f=twolevel
 -e=N[,ARGS]   exec backdoor entry N with ,-separated ARGS
*-f=NAME   select output function, NAME is one of:
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

Examples
--------

# 1 simple label (without top menu name) + action, unsorted
/bin/ash aloop.sh

# 2 list of parsed values
/bin/ash aloop.sh -f=debuginfo

# 3 if you use the TouchRunner launcher
/bin/ash aloop.sh -f=touchrunner -s >> /mnt/us/touchrunner/commands.txt

# 4 for two-level nested menus, like Komic's, label = menu name + item name
/bin/ash aloop.sh -f=twolevel

# 5 sort the two-level index by menu (top) level name and leave
# sub-items in the same order they appear in their json file
/bin/ash aloop.sh -f=twolevel -s

# 6 prepend a rolling 'color index' which resets to zero every N menus
/bin/ash aloop.sh -f=twolevel -s -c=3

# 7 Use -c=999 if you want a serial index from 0 to 998
/bin/ash aloop.sh -f=twolevel -s -c=999

# 8 two-level index sorted by priority (since version 20130221,a)
/bin/ash aloop.sh -f=twolevel -S

Release history
---------------

See CHANGELOG.txt
