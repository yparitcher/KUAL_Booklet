##############################################
# KUAL: Kindle Unified Applications Launcher #
##############################################
http://www.mobileread.com/forums/showthread.php?p=2389078

Supporting the DX, K2, K2i, K3 Keyboard, Kindle 4, Kindle Touch, PW, PW2,
along with the KV, KT2, PW3, KOA, KT3, KOA2, PW4, KT4, KOA3, PW5, KT5, KS, KT6, PW6 & CS.

NOTE: Flashed 3.2.1 DX's may fail to handle kindlets properly.
There is a workaround tested by wakawakawaka (thanks to him for the DX testing)
http://www.mobileread.com/forums/showpost.php?p=1747631&postcount=354
Workaround 3.2.1 DX Link is above.
In addition, REALLY old firmwares of the Kindle 2 did not support kindlets.
Please update these to later firmwares to get support.
NOTE: On the KV, KT2 & PW3, we may only run on select firmware versions.
NOTE: On the KOA, KT3, KOA2, PW4, KT4, KOA3, PW5, KT5, KS, KT6, PW6 & CS, Kindlets are deprecated. As such, only the Booklet version is usable.


SUPPORT: READ THIS >>>

BitRot, No Magic, Voodoo (or Unicorns)  (what will work, what won't work)
SOME OF THE OLDER PROGRAMS NO LONGER WORK ON THE NEWER KINDLES
(nothing to do with this launcher they just dont work properly anymore)
SUCH AS MANY IN THIS OLD LIST:
http://wiki.mobileread.com/wiki/Kindle_Touch_Hacking#Extensions_for_the_GUI_Launcher
SOME OF THESE DONT WORK, SOME WORK ON CERTAIN FIRMWARES ONLY.
AS A COURTESY THESE APPLICATIONS ARE LISTED ON THE MAIN THREAD UNDER KNOWN ISSUES.

ALSO: SOME EXTENSION SUCH AS Kterm ARE DEVICE SPECIFIC.
THIS LAUNCHER WON'T MAGICALLY MAKE DEVICE-SPECIFIC CODE WORK ON OTHER DEVICES.
If it doesn't normally work on that type of device? It won't work via this either.

Enough shouting.
It's a launcher of "other things" not an exciting thing in itself.

We have now included a few helper scripts to get you going called "Helper"
(attached on main thread - unzip to [FAT-ROOT])
And also a set of extensions for the main KUAL helpers
(also available from main thread)

#####################################
# Requirements, Installation & Use: #
#####################################

Jailbreak:
Go find the relevant Jailbreak for your device.
Links are provided on the main thread.

Mobileread Kindlet Kit:
http://www.mobileread.com/forums/showthread.php?t=233932

Running the kindlet:
Depending on your device:

(k2, dx, K3, K4)
Put KUAL-KDK-1.0.azw2 in documents folder.
Run it by clicking new kindlet document in your list.

(Touch, PW, PW2, KV, KT2, PW3)
Put KUAL-KDK-2.0.azw2 in documents folder.
Run it by clicking icon.

(KOA, KT3, KOA2, PW4, KT4, KOA3, PW5, KT5, KS, KT6, PW6, CS)
Install the KUALBooklet update package via MRPI.
Run it by clicking KUAL document.

Expected output:
It should read thru the /mnt/us/extensions folder and build an extension list.
If you have NO extensions? It will show a message telling you that.
You then select a button to run the relevant command.
Paginated results are provided.
If the device shouts at you about keys, developer access, a testing device or a jailbreak,
you forgot to install the Mobileread Kindlet Kit ;).

NOTE: /mnt/us/extensions is simply a folder called "extensions"
a normal folder you can access when you connect via normal USB.
Usbnetworking is not "required" to access this folder.

TO EXIT:
Generally the kindlet will exit when you click a choice
Currently just press the HOME key if you have one or the < icon.
Or select an item, the menu is now self-terminating.

NOTE:
Additionally, you can also install a custom awk build (GNU awk), making the
parser around two times faster, by installing gawk with this extension:
http://www.mobileread.com/forums/showpost.php?p=2636883&postcount=59

Credits.
Twobob Ixtab Stepk Niluje
Thanks to KNC1 for download authentication support.
wakawakawaka for testing the DX prerequisites.
Yifan was the original chap whoms configs we parse.
All the unsung demo authors whose work we draw from on a daily basis.
And everyone else along the way.
