Unlock HiDPI on Recovery HD
============

On QHD+/UHD PCs/laptops, we cannot easily boot into Recovery HD since the pixel locked by IOKit. We can only boot in the Recovery HD on high resolution(Hi-DPI) PCs/laptops by setting Inject Graphics = False, which is inconvenient and hard to operate under such a high resolutions. 

I've tested on my DELL Precision M3800. Wish you all enjoy it. Any feedback is welcomed! 

Overview of the tools/solutions
----------------

Fortunately, we can remove such limitation by patching the IOKit as we did in OS X to unlock the HiDPI for QHD+ and UHD. The only  differences we have to keep in mind: 
1. We need first to decompress Recovery HD base(read-only) to readwrite for further patch.
2. BooterConfig: We have to unlock HiDPI during boot to prevent graphics glitches. (0 x _ _ _ _ _ _ 1 _).
3. Once we have done the following, we can then compress Recovery HD base to origin format and enjoy the Hi-DPI on Recovery HD.

The above procedures should better be completed automatically, I wrote a bash script to finish the whole tasks. 

How to use unlockRecovery.sh
----------------

- Download the latest unlockRecovery.sh by entering the following command in a terminal window:
``` sh
curl -o ~/unlockRecovery.sh https://raw.githubusercontent.com/syscl/HiDPI-RecoveryHD/master/unlockRecovery.sh
```
- This will download unlockRecovery.sh to your home directory (~) and the next step is to change the permissions of the file(+x) so that it can be run.
```sh
chmod +x ~/unlockRecoveryHD.sh
```
- Run the script in a terminal window by:
``` sh
~/unlockRecoveryHD.sh
```
Enter your EFI's identifier for fix BooterConfig in config.plist, then enter your Recovery HD's identifier to unlock the pixels clock. 

Reboot.

Change Log
----------------

2016-5-28

- Added resolution detection(less is more).

2016-5-27

- Added BooterConfig = 0x2A to enable HiDPI during boot.

////