*** THIS README-dev FILE IS NOT UP-TO-DATE WITH KUAL 2 SOURCE CODE ***

Introduction
------------

Aloop.sh a.k.a. parse.sh is a parser front-end for the KUAL kindlet. Originally,
the kindlet unpacked parse.sh into a temporary folder and ran it to find and
parse the xml and json[7] files that implement KUAL buttons. As development
has progressed additional functions have moved from the kindlet to aloop.sh,
in particular:
. sorting
. cleaning up temporary files (some)
. generating KUAL's own menus
and new functions have been added, notably:
. screen reporting area

Parse.sh is the slimmed version of aloop.sh; dev/debug code and comments are
removed to increase performance and reduce size. Parse.sh is packed into
the KUAL laucher kindlet.

The rest of this note describes aloop.sh and its internal workings.
Please note that aloop.sh runs under the busybox ash variant.[0]

Logging and Debugging
---------------------

Aloop.sh can log debugging/tracing messages to stderr. By default logging is
disabled. Option -l enables log output. With logging on the kindlet
should redirect aloop's stderr. To add log messages to the source code use:
  log "some message"

Option -f=debuginfo dumps all parsed json variables to stdout.

If the default separator character prints garbage on your terminal, pipe:
  aloop.sh | tr `printf "\x01"` " "
Or set the internal variable FORMATTER for table output,i.e.,
  FORMATTER="formatter tbl" # default FORMATTER="formatter"
Don't forget to reset FORMATTER to its default value or you will surprise
the Kindlet! You can also change FORMATTER with command-line option -p:
  -p==    passthrough
  -p=tbl  table
  -p=tab  tabs
  -p="%10.10s"   columns, width 10 (any printf format string should work)

While debugging aloop.sh you may take advantage of shell flags -x and -e:
  # /bin/ash -x -e aloop.sh -l

This applies also when debugging menu actions, including KUAL's own. Given
menu action SOME_ACTION (in menu.json), temporarily re-write it as
  /bin/ash -x -e SOME_ACTION 2>/tmp/action.log
then run it via KUAL and examine the trace file /tmp/action.log.

Flow
----

Note that the kindlet starts the parser script only once, and it expects all
communication to take place through standard input. As a way of speaking, the
script sends all its data to the kindlet through a single stream "channel"
then it exits.

Step 1 - initialization
~~~~~~

Script initialization sets shell option -f to prevent unnecessary pathname
expansion which could interfere with string operations, should input data
include shell metacharacters.  Then it sets global variables:

# dev can change
CONFIGFILE="KUAL.cfg"
PRODUCTNAME="KUAL"
EXTENSIONDIR=/mnt/us/extensions

# notable internal globals
SEPARATOR=$'\x01' # character code 1, UTF-8 encoded
COLORMAX=0 # don't 'colorize'
FORMATTER="formatter" # $1:''(\n,default) 'tbl'(table) 'tab'(\t)
CONFIGPATH=... # null if no config file
SCRIPTPATH=...
TIER=... # output placement

and determines Kindle busybox version to load model-specific support (code was
removed after version 20130127,a).

Step 2 - configuration
~~~~~~

The script calls init() which sources the optional configuration file
KUAL.cfg, parses command-line options (and line 'KUAL_options=...' in KUAL.cfg)
and sets global variables for all other functions.

At this stage the script captures early error messages which will be later sent
to the kindlet, when the channel (pipe) $to_user will be fully set up.

The script calls send_config() to transfer KUAL.cfg configuration variables,
NAME=VALUE, to the kindlet.

Step 3 - $to_user
~~~~~~

When channel $to_user is open, the script evaluates early error messages
and sends them $to_user followed by the button records that loop() generates.
Loop() goes through all config.xml files and for each file it calls xml_var()
and json_parse() to get values in config.xml and its associated json menu file.
Json_parse() stores values in global variables xml_<name> and json_<name> where
each <name>s correspond to XML tags and json keys.
Run aloop.sh -f=debuginfo to see an actual list of <name>s / values.

Then json_parse() calls a processing function $proc to emit the output label
and executable action for each set of xml_ / json_ variables. Several processing
functions are available, and can be selected with option -f.
For instance, function one_level() generates simple labels suitable for
a flat (non-nested) menu. Processing function two_level() is more advanced and
produces labels suitable for a two-level (nested) menu.
However KUAL 1 can't display nested menus and flattens the two levels.
See also section Json Menu Structure.
Before exiting, loop() checks to see if at least one valid menu item is found.
If not, loop() installs a test applet and emits its menu item. So the GUI
can safely assume that there is at least one item to display and that the
standard /mnt/us/extensions file tree exists.
Note that the test applet is automatically uninstalled upon starting the script.
Since version 20130221,a loop() also emits KUAL's own menus.

Channel $to_user applies predefined options to optionally sort and
'colorize' the output list.

Step 4 - termination
~~~~~~

Note that the script file isn't deleted when the script terminates. It will
be deleted the next time the script starts. See paragraph 'Temporary Files'.

The Output List
---------------

The output list is divided into three tiers, 1, 2 and 3. Tier 1 is positioned
at the beginning of the list, tier 2 in the middle, and tier 3 at the end.
Tier 1 is used for error messages, tier 2 for regular menu items, and tier 3
for KUAL's own menu.

To place a button in a specific tier, set variable $TIER and call the
processing function. You can use decimals to force and order within each tier.
You can mix the call sequence as you please. Sample call sequence:

  $TIER   label                Unsorted Buttons  Sorted Buttons
  -----   -----                ----------------  --------------
   2      lblC                      err2             err1
   2      lblA                      err1             err2
   1      err2                      lblC             lblA
   2      lblB                      lblA             lblB
   3.99   Quit                      lblB             lblC
   3      Open                      Open             Open
   1      err1                      Quit             Quit

More On Processing Functions
----------------------------

Adding a new processing function is a matter of assembling the available
xml_ and json_ variables to build the output record format that the GUI
module expects, for instance:
  pretty_label="$xml_name : $json_name"
would result in pretty_label "Orientation : Portrait"
if such are the values that a sample json menu file declares.
generating the command string would look similar to:
  command="$json_action $json_params"
which would result in command "bin/setorientation.sh U"

Note that all values must be properly encoded UTF-8 strings.[4]

Since version 20130221,a - which introduced features that imply a
variable-length output record, processing functions must prepend META
information (the record length) to each record, i.e.,
  2;label;action
  3;group;label;action
  4;cindex;group;label;action

One_level Processing Function
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

One_level() builds an output record which consists of:
  json_name,action' 'json_params
This output format is best suited for single-item json files. It is probably
less appealing for nested menus, because the group menu name isn't displayed,
and sorting the list results in scattering sub-items that the developer of the
menu really meant to keep together. One_level was the standard format up to
KUAL version 0.3, then it got replaced with two_level.

Two_level Processing Function
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Two_level() vs one_level() adds a group menu (the $json_name_ if set, the
$xml_name otherwise), which is suitable for identifying nested menus. When
option -c=N with N>0 specifies a maximum color value, two_level also prepends a
modular 'color' index ($cindex) modulo $COLORMAX, which the GUI could use for
displaying groups in zebra-style strips. cindex increments when the the group
name changes, so all json_names in the same group share the cindex. The GUI
could map each cindex value to a different background color and fill the page
with zebra stripes to help visually identifying groups of menu sub-items.
Each stripe is as tall as the number of sub-items that belong to a menu group.
Possibly the GUI could display information more concisely by (inline)
prefixing the group name on the first item label only. This device is useful
when the GUI page layout consists of tabular text only (no icons or navigable
menus). Cindex output can be serialized by specifying -c=999 or disabled
altogether with -c=0 or by leaving out option -c.

Note: for two_level() to group menus correctly all json_names belonging
to the same group must come in an uninterrupted sequence of calls to two_level.
Such is the case when function loop() does the calling.

Example for $COLORMAX=3, '-' is the field separator
0 - Orientation - Up - bin/turn.sh U
0 - Orientation - Down - bin/turn.sh D
1 - Komic - Sort books - bin/komic.sh -sort
1 - Komic - Delete book - bin/komic.sh -del
2 - kterm - KTerm - bin/kterm
0 - XTerm - XTerm - bin/xterm
1 - Helper - 411 - ...
1 - Helper - 711 - ...
1 - Helper - Gray menu - ...
2 - System - Restart framework - ...
etc.

Touch_runner Processing Function
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Touch_runner() outputs action,json_params,group'.'json_name with ';' as the 
separator character. This format is compatible with version 3.0 of launcher
TouchRunner's configuration file format /mnt/us/touchrunner/commands.txt
Ref. https://github.com/CrazyCoder/coolreader-kindle-qt/downloads
Ref. http://www.mobileread.com/forums/showpost.php?p=2388962&postcount=297

Kindle Compatibility
--------------------

Aloop used to be implemented as a bundle of scripts (modules). This approach
allowed supporting older kindle models K3/DX without negatively affecting the
performance of newer models KT/PW. Due to the lack of advanced busybox ash
features, aloop for K3/DX required frequently spawning the sed command, with
a noticeable performance hit. KT/PW aloop did not need sed.

However, for the GUI kindlet to start a modular aloop was too complex, so
twobob created a monolithic script by merging some modules together. The
resulting script achieved compatibility across all kindles to the expense of
a performance hit on KT/PW.

Now a newer implementation of the monolithic script fine-tunes using
sed to achieve both compatibility and performance on all platforms.

Monolithic Implementations
~~~~~~~~~~~~~~~~~~~~~~~~~~

Version 20130130,a achieves compatibility and performance by greatly
reducing the number of times sed is called.

Version 20130129,a was not released. Branched off of version 20130128,a
as a proof-of-concept that even the limited features of busybox 1.7.2 are
enough to parse json data without using sed. Version 29 runs on all kindles
but is too slow.

Version 20130128,a was not released. Mainly it was a clean up of the interim
monolithic version that twobob created by merging modules aloop.sh and
compat-K3.sh from version 20130127,a. Version 28 used sed to parse json data.

Modular Implementations
~~~~~~~~~~~~~~~~~~~~~~~

Version 20130127,a consisted of a bundle of modules. Necessarily the main file
aloop.sh had to use least-common-denominator syntax/features, while the
compatibility layer files varied in their use of newer syntax:

(3) compat-K3.sh for busybox 1.7.2 Kindle 3 & Kindle DX US/Int/Graphite models
    this module uses the sed command.
(5) compat-K5.sh for busybox 1.17.1 Kindle Touch and Kindle PaperWhite models.

Performance Comparison
~~~~~~~~~~~~~~~~~~~~~~

Comparing aloop running on KT 5.1.2 with default options on ash 1.17.1 (KT/PW)
vs. ash 1.7.2 (K3/DX). Kernel linux 2.6.31-rt11-lab126 armv7l. All runs same 10
extensions (test-tree-kindle.tgz).

               monolithic
30 /bin/busybox      30 ./busybox-k3 
real    0.52s        real    1.19s
user    0.16s        user    0.25s
sys     0.26s        sys     0.45s

28 /bin/busybox      28 ./busybox-k3
real    1.78s        real    4.69s
user    0.37s        user    0.76s
sys     1.26s        sys     1.87s

                modular
27 /bin/busybox      27 ./busybox-k3
real    0.89s        real    2.97s
user    0.41s        user    0.50s
sys     0.12s        sys     1.50s

Further reading: [5]

Sorting
-------

Aloop implements stable sorting, which means that if record A appears before
record B in the input set, and sort criteria do not affect the relative order
of A and B, then A will appear before B in the output set, for any A and B.

Lexicographic and priority sort criteria are provided through options
-s=abc and -s=123 respectively. In some cases (-f=twolevel) lexicographic and
priority sorting are combined to yield an 'expected/natural' order.
In all cases lexicographic order folds upper- and lower-case letters
together.
Json key "priority", for a whole menu and for individual menu entries, is
a (possibly negative) integer, which defaults to 0 when no json value is set.

Temporary Files
---------------

Since version 0.3.3 the kindlet doesn't delete aloop.sh after the script exits.
Instead it leaves the file in the temporary directory where it was unpacked so
that the kindlet can call aloop.sh as a menu action with option -e, which is the
execution backdoor to KUAL's self-generated menus.

Function clean_up_previous_runs() is invoked early in each run to delete the
copies of the script that previous runs might have left in the temporary
directory. Note that this design leaves at most one copy of the script in the
temporary folder at any time.

Note also that when the kindlet terminates cleanly (as opposed to it being
aborted by pressing the back button), no copy of the script is left around,
since the kindlet marks the script delete.OnExit.

Self-generated Menus
--------------------

Look at functions emit_self_menu() and exec_self_menu() - the former outputs
KUAL's own menu entries, and the latter gets invoked with the -e command-line
option to execute a menu entry.

Generating menus from within aloop.sh allows for creating dynamic menu labels
which reflect kindle's internal state. For instance in emit_self_menu entry #1
(Replace/Restore Store Button) toggles the label between Replace and Restore
based on the existence of a system file. Such toggling would not be possible
if aloop.sh read the menu label from a json file.

When adding ash code for a new KUAL menu entry, you can use any of the
functions in aloop.sh, notably:
. screen_msg() - uses eips to print a 4-line message box
. script_full_path() - tells you aloop's own directory location
. store_button_filepath - defined on K5/PW only
and more.

Scripting Interface
-------------------

KUAL starts a script, which can call aloop's functions as follows:

  [ "$KUAL" ] && $KUAL $number $args

The code checks to see if $KUAL is defined (this test will fail for a
script that does not run under KUAL). Then it calls $KUAL's (actually
aloop's) function number $number (1,2,...) with function-specific
arguments $args. For example:

  msg="USBNETWORKING $DIRECTION CHANGES COMPLETE
`date`"
  [ "$KUAL" ] && $KUAL 1 "$msg" || eips 2 38 "$msg"

It is a good idea to always provice a fallback measure should $KUAL be
undefined. In the above example ' || eips 2 38 "$msg" ' is the fallback.

The following function numbers are available:

   1  Write up to 4 lines to the screen reporting area.
      Arguments: [-lm=COL] [-wo] "$message"
      Default left margin is column 5. Insert -lm=N, with N=0..48, to change
      Add -wo (after -lm, if any) to write OVER a previous screen_msg (skips blanking the reporting area)
      Leading dash(es) in $message are deleted (otherwise eips gets confused).
      Exclamation marks in $message white out to end of line (eips does it).
      Screenshot: http://www.mobileread.com/forums/showpost.php?p=2438452&postcount=496
      Test script (white space matters):
      | lm=1
      | while [[ $lm -le 46 ]]; do
      | ash /mnt/us/opt/bin/aloop.sh -x 1 -lm=$lm $wo "a
      |  b
      |   c
      |    d"
      | wo=-wo
      | lm=$(($lm + 4))
      | sleep 1
      | done

   2  Save KUAL error log as a new document.

The Test Applet
---------------

Currently the test applet prints a welcome message in the screen reporting
area, and directs the user to install extensions.

Json Menu Structure
-------------------

Going from KUAL 1 (flat menu) to KUAL 2 (nested menu) we face an issue
concerning how to properly describe a menu object with json.
Two slightly different menu templates are in common use.
The first template fully conforms to Yifan Lu's definition[8], e.g.:
{
  "items": [
     {"name": "Main menu, Item 1", "action": "act1.sh"},
     {
       "name": "Main menu, Submenu 1",
       "items": [
         {"name": "Submenu 1, Item 1", "action": "act11.sh"},
         {"name": "Submenu 1, Item 2", "action": "act12.sh"}
       ]
     }
  ]
}

Template 1 provides no explicit way of specifying a main menu label, which
suggests to me that Yifan Lu's intended the Kindle menu button as the main menu,
and when you press it Yifan Lu's launcher displays "Main menu, Item 1" as the
top level item.

Template 2 is a sort of application package menu:
{
  "name": "Application 1 menu"
  "items": [
     {"name": "Application 1 menu, Item 1", "action": "act1.sh"},
     {
       "name": "Application 1 menu, Submenu 1",
       "items": [
         {"name": "Application 1 menu, Submenu 1, Item 1", "action": "act11.sh"},
         {"name": "Application 1 menu, Submenu 1, Item 2", "action": "act12.sh"}
       ]
     }
  ]
}

The two templates look almost the same, but a small difference is of great import.
Template 2 (mis)uses the first "name" as a structural element to insert a
submenu - the Application menu - into the main menu.
Notice that with template 2 there is no syntactically valid way to add a single
item at the top level.

KUAL 1 (flat menu series) treats both templates indistinctly, because all menu
items are inserted at the top menu level anyway.

The upcoming KUAL 2 (nestable menu series) ignores all top-level keys but "items".
So it effectively interprets the second template as it interprets the first one.
In KUAL 2, "Application 1 menu, Item 1" displays as a single, top-level menu
entry, just like "Main menu, Item 1".

References
----------

[0] Almquist shell versions
    http://www.in-ulm.de/~mascheck/various/ash/#busybox

[1] Can a bash script determine where it is? Includes accounting for links.
    http://hintsforums.macworld.com/archive/index.php/t-73839.html

[2] [KT]Turn store button on search bar to browser button
    http://www.mobileread.com/forums/showthread.php?p=2427816
    http://www.mobileread.com/forums/showthread.php?p=2392969

[3] Sorting Tutorial
    http://www.skorks.com/2010/05/sort-files-like-a-master-with-the-linux-sort-command-bash/

[4] How do you echo a 4 digit unicode character in bash?
    http://stackoverflow.com/questions/602912/how-do-you-echo-a-4-digit-unicode-character-in-bash
  . The Absolute Minimum Every Software Developer Absolutely, Positively Must Know About Unicode and Character Sets (No Excuses!)
    http://www.joelonsoftware.com/articles/Unicode.html

[5] Optimizing Shell Scripts
    http://www.thelinuxblog.com/optimizing-shell-scripts/
  . How To Remove Comments From A Shell Script
    http://blog.sleeplessbeastie.eu/2012/11/07/how-to-remove-comments-from-a-shell-script/

[6] SubShell
    http://mywiki.wooledge.org/SubShell
    
[7] Crockford, Douglas (May 28, 2009). "Introducing JSON". json.org. Retrieved July 3, 2009
    http://json.org/

[8] Yifan Lu's original graphical menu for the Kindle
    https://github.com/yifanlu/KindleLauncher/blob/master/src/com/yifanlu/Kindle/JSONMenu.java

[9] Basic vs. Extended Regular Expressions
    http://en.wikipedia.org/wiki/Regular_expression#Deciding_equivalence_of_regular_expressions
