#!/bin/sh

#
# syscl/Yating Zhou/lighting from bbs.PCBeta.com
# Unlock HiDPI limitation for Recovery HD.
#

#================================= GLOBAL VARS ==================================

#
# The script expects '0.5' but non-US localizations use '0,5' so we export
# LC_NUMERIC here (for the duration of the unlockRecovery.sh) to prevent errors.
#
export LC_NUMERIC="en_US.UTF-8"

#
# Prevent non-printable/control characters.
#
unset GREP_OPTIONS
unset GREP_COLORS
unset GREP_COLOR

#
# Display style setting.
#
BOLD="\033[1m"
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
OFF="\033[m"

#
# Define two status: 0 - Success, Turn on,
#                    1 - Failure, Turn off
#
kBASHReturnSuccess=0
kBASHReturnFailure=1

#
# Located repository.
#
REPO=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#
# Path and filename setup.
#
config_plist="/Volumes/EFI/EFI/CLOVER/config.plist"

#
# Define variables.
#
# Gvariables stands for getting datas from OS X.
#
gArgv=""
gDebug=${kBASHReturnFailure}
gRecoveryHD_DMG="/Volumes/Recovery HD/com.apple.recovery.boot/BaseSystem.dmg"
gBak_Time=$(date +%Y-%m-%d-h%H_%M_%S)
gBak_Dir="${REPO}/Backups/${gBak_Time}"
#
# Gain Product ver and OS ver
#
gProductVer="$(sw_vers -productVersion)"
gMINOR_VER=${gProductVer:3:2}

#
#--------------------------------------------------------------------------------
#

function _PRINT_MSG()
{
    local message=$1

    case "$message" in
      OK*    ) local message=$(echo $message | sed -e 's/.*OK://')
               echo "[  ${GREEN}OK${OFF}  ] ${message}."
               ;;

      FAILED*) local message=$(echo $message | sed -e 's/.*://')
               echo "[${RED}FAILED${OFF}] ${message}."
               ;;

      ---*   ) local message=$(echo $message | sed -e 's/.*--->://')
               echo "[ ${GREEN}--->${OFF} ] ${message}"
               ;;

      NOTE*  ) local message=$(echo $message | sed -e 's/.*NOTE://')
               echo "[ ${RED}Note${OFF} ] ${message}."
               ;;
    esac
}

#
#--------------------------------------------------------------------------------
#

function _tidy_exec()
{
    if [ $gDebug -eq 0 ];
      then
        #
        # Using debug mode to output all the details.
        #
        _PRINT_MSG "DEBUG: $2"
        $1
      else
        #
        # Make the output clear.
        #
        $1 >/tmp/report 2>&1 && RETURN_VAL=0 || RETURN_VAL=1

        if [ "${RETURN_VAL}" == 0 ];
          then
            _PRINT_MSG "OK: $2"
          else
            _PRINT_MSG "FAILED: $2"
            cat /tmp/report
        fi

        rm /tmp/report &> /dev/null
    fi
}

#
#--------------------------------------------------------------------------------
#

function _touch()
{
    local target_file=$1

    if [ ! -d ${target_file} ];
      then
        _tidy_exec "mkdir -p ${target_file}" "Create ${target_file}"
    fi
}

#
#--------------------------------------------------------------------------------
#

function _del()
{
    local target_file=$1

    if [ -d ${target_file} ];
      then
        _tidy_exec "sudo rm -R ${target_file}" "Remove ${target_file}"
      else
        if [ -f ${target_file} ];
          then
            _tidy_exec "sudo rm ${target_file}" "Remove ${target_file}"
        fi
    fi
}

#
#--------------------------------------------------------------------------------
#

function _printBackupLOG()
{
    local gDAY="${gBak_Time:5:2}/${gBak_Time:8:2}/${gBak_Time:0:4}"
    local gTIME="${gBak_Time:12:2}:${gBak_Time:15:2}:${gBak_Time:18:2}"
    local gBackupLOG=$(echo "${gBak_Dir}/BackupLOG.txt")

    #
    # Print Header.
    #
    echo "  Backup Recovery HD(BaseSystem.dmg)"                                                   > "${gBackupLOG}"
    echo ''                                                                                       >>"${gBackupLOG}"
    echo "  DATE:                     $gDAY"                                                      >>"${gBackupLOG}"
    echo "  TIME:                     $gTIME"                                                     >>"${gBackupLOG}"
    local gRecentFileMD5=$(md5 -q "${gBak_BaseSystem}")
    echo "  Origin Recovery HD MD5:   ${gRecentFileMD5}"                                          >>"${gBackupLOG}"
    local gPatchedFileMD5=$(md5 -q "${gBaseSystem_PATCH}")
    echo "  Patched Recovery HD MD5:  ${gPatchedFileMD5}"                                         >>"${gBackupLOG}"
    echo ''                                                                                       >>"${gBackupLOG}"
}

#
#--------------------------------------------------------------------------------
#

function _bakBaseSystem()
{
    gLastOpenedFileMD5=$(md5 -q "${gRecoveryHD_DMG}")

    if [ -d "${REPO}/Backups" ];
      then
        if [[ `ls ${REPO}/Backups/*` == *'.txt'* ]];
          then
            gBakFileNames=($(ls ${REPO}/Backups/*/*.txt))
        fi
    fi

    if [[ "${#gBakFileNames[@]}" -gt 0 ]];
      then
        gBakFileMD5=($(cat ${gBakFileNames[@]} | grep 'Patched Recovery HD MD5:' | sed -e 's/.*: //' -e 's/ //'))
        for checksum in "${gBakFileMD5[@]}"
        do
          if [[ $checksum == $gLastOpenedFileMD5 ]];
            then
              _PRINT_MSG "OK: Backup found. No more patch operations need"
              exit -0
          fi
        done
    fi

}

#
#--------------------------------------------------------------------------------
#

function _getEDID()
{
    #
    # Whether the Intel Graphics kernel extensions are loaded in cache?
    #
    if [[ `kextstat` == *"Azul"* && `kextstat` == *"HD5000"* ]];
      then
        #
        # Yes. Then we can directly assess EDID from ioreg.
        #
        # Get raw EDID.
        #
        gEDID=$(ioreg -lw0 | grep -i "IODisplayEDID" | sed -e 's/.*<//' -e 's/>//')

        #
        # Get native resolution(Rez) from $gEDID.
        #
        # Get horizontal resolution. Arrays start from 0.
        #
        gHorizontalRez_pr=${gEDID:116:1}
        gHorizontalRez_st=${gEDID:112:2}
        gHorizontalRez=$((0x$gHorizontalRez_pr$gHorizontalRez_st))

        #
        # Get vertical resolution. Actually, Vertical rez is no more needed in this scenario, but we just use this to make the
        # progress clear.
        #
        gVerticalRez_pr=${gEDID:122:1}
        gVerticalRez_st=${gEDID:118:2}
        gVerticalRez=$((0x$gVerticalRez_pr$gVerticalRez_st))
      else
        #
        # No, we cannot assess EDID from ioreg. But now the resolution of current display has been forced to the highest resolution as vendor designed.
        #
        gSystemRez=$(system_profiler SPDisplaysDataType | grep -i "Resolution" | sed -e 's/.*://')
        gSystemHorizontalRez=$(echo $gSystemRez | sed -e 's/x.*//')
        gSystemVerticalRez=$(echo $gSystemRez | sed -e 's/.*x//')
    fi

    #
    # Patch IOKit? (2880x1800 = rMBP 15')
    #
    if [[ $gHorizontalRez -gt 2880 || $gSystemHorizontalRez -gt 2880 ]];
      then
        #
        # Yes, We indeed require a patch to unlock the limitation of flash rate of IOKit to power up the QHD+/4K display.
        #
        # Note: the argument of gPatchIOKit is set to 0 as default if the examination of resolution fail, this argument can ensure all models being powered up.
        #
        gPatchIOKit=0
      else
        #
        # No, patch IOKit is not required, we won't touch IOKit(for a more intergration/clean system since less is more).
        #
        gPatchIOKit=1
    fi

    #
    # Passing gPatchIOKit to gPatchRecoveryHD.
    #
    gPatchRecoveryHD=${gPatchIOKit}
}

#
#--------------------------------------------------------------------------------
#

function _recoveryhd_fix()
{
    #
    # Mount Recovery HD.
    #
    local gRecoveryHD=""
    local gMountPoint="/tmp/RecoveryHD"
    local gBaseSystem_RW="/tmp/BaseSystem_RW.dmg"
    local gBaseSystem_PATCH="/tmp/BaseSystem_PATCHED.dmg"
    diskutil list
    printf "Enter ${RED}Recovery HD's ${OFF}IDENTIFIER, e.g. ${BOLD}disk0s3${OFF}"
    read -p ": " gRecoveryHD
    _tidy_exec "diskutil mount ${gRecoveryHD}" "Mount ${gRecoveryHD}"
    _touch "${gMountPoint}"

    #
    # Gain origin file format(e.g. UDZO...).
    #
    local gBaseSystem_FS=$(hdiutil imageinfo "${gRecoveryHD_DMG}" | grep -i "Format:" | sed -e 's/.*://' -e 's/ //')
    local gTarget_FS=$(echo 'UDRW')

    #
    # Backup origin BaseSystem.dmg to ${REPO}/Backups/.
    #
    _bakBaseSystem
    _touch "${gBak_Dir}"
    cp "${gRecoveryHD_DMG}" "${gBak_Dir}"
    gBak_BaseSystem="${gBak_Dir}/BaseSystem.dmg"
    chflags nohidden "${gBak_BaseSystem}"

    #
    # Mount esp.
    #
    diskutil list
    printf "Enter ${RED}EFI's${OFF} IDENTIFIER, e.g. ${BOLD}disk0s1${OFF}"
    read -p ": " gEFI
    _tidy_exec "diskutil mount ${gEFI}" "Mount ${gEFI}"

    #
    # Fixed RecoveryHD issues (c) syscl.
    #
    # Check BooterConfig = 0x2A.
    #
    local target_BooterConfig="0x2A"
    local gClover_BooterConfig=$(awk '/<key>BooterConfig<\/key>.*/,/<\/string>/' ${config_plist} | egrep -o '(<string>.*</string>)' | sed -e 's/<\/*string>//g')
    #
    # Added BooterConfig = 0x2A(0x00101010).
    #
    if [ -z $gClover_BooterConfig ];
      then
        /usr/libexec/plistbuddy -c "Add ':RtVariables:BooterConfig' string" ${config_plist}
        /usr/libexec/plistbuddy -c "Set ':RtVariables:BooterConfig' $target_BooterConfig" ${config_plist}
      else
        #
        # Check if BooterConfig = 0x2A.
        #
        if [[ $gClover_BooterConfig != $target_BooterConfig ]];
          then
            #
            # Yes, we have to touch/modify the config.plist.
            #
            /usr/libexec/plistbuddy -c "Set ':RtVariables:BooterConfig' $target_BooterConfig" ${config_plist}
        fi
    fi

    #
    # Start to override.
    #
    _PRINT_MSG "--->: ${BLUE}Convert ${gBaseSystem_FS}(r/o) to ${gTarget_FS}(r/w) ...${OFF}"
    _tidy_exec "hdiutil convert "${gBak_BaseSystem}" -format ${gTarget_FS} -o ${gBaseSystem_RW} -quiet" "Convert ${gBaseSystem_FS}(r/o) to ${gTarget_FS}(r/w)"
    _tidy_exec "hdiutil attach "${gBaseSystem_RW}" -nobrowse -quiet -readwrite -noverify -mountpoint ${gMountPoint}" "Attach Recovery HD"
    _unlock_pixel_clock
    _tidy_exec "hdiutil detach $gMountPoint" "Detach mountpoint"
    #
    # Convert to origin format.
    #
    _PRINT_MSG "--->: ${BLUE}Convert ${gTarget_FS}(r/w) to ${gBaseSystem_FS}(r/o) ...${OFF}"
    _tidy_exec "hdiutil convert "${gBaseSystem_RW}" -format ${gBaseSystem_FS} -o ${gBaseSystem_PATCH} -quiet" "Convert ${gTarget_FS}(r/w) to ${gBaseSystem_FS}(r/o)"
    _PRINT_MSG "--->: ${BLUE}Unlocking pixel clock for Recovery HD ...${OFF}"
    cp ${gBaseSystem_PATCH} "${gRecoveryHD_DMG}"
    chflags hidden "${gRecoveryHD_DMG}"
    _printBackupLOG

    #
    # Clean redundant dmg files.
    #
    _tidy_exec "rm $gBaseSystem_RW $gBaseSystem_PATCH" "Clean redundant dmg files"
    _tidy_exec "diskutil unmount ${gRecoveryHD}" "Unmount ${gRecoveryHD}"
}

#
#--------------------------------------------------------------------------------
#

function _unlock_pixel_clock()
{
    let gDelimitation_OSVer=12

    if [ $gMINOR_VER -ge $gDelimitation_OSVer ];
      then
        #
        # 10.12+
        #
        gTarget_rhd_Framework="$gMountPoint/System/Library/Frameworks/CoreDisplay.framework/Versions/Current/CoreDisplay"
      else
        #
        # 10.12-
        #
        gTarget_rhd_Framework="$gMountPoint/System/Library/Frameworks/IOKit.framework/Versions/Current/IOKit"
    fi
    sudo perl -i.bak -pe 's|\xB8\x01\x00\x00\x00\xF6\xC1\x01\x0F\x85|\x33\xC0\x90\x90\x90\x90\x90\x90\x90\xE9|sg' ${gTarget_rhd_Framework}
    _tidy_exec "sudo codesign -f -s - ${gTarget_rhd_Framework}" "Patch and sign framework for Recovery HD"
}

#
#--------------------------------------------------------------------------------
#

function main()
{
    #
    # syscl   - Just in case if someone simply copy M3800 instead of `git clone` it.
    #
    # PMheart - We should make a detection for Command Line Tools. If no CLT available, we should install it.
    #
    if [ ! -x /usr/bin/make ];
      then
        _PRINT_MSG "NOTE: ${RED}Xcode Command Line Tools from Apple not found!${OFF}"
        _tidy_exec "xcode-select --install" "Install Xcode Command Line Tools"
        exit 1
    fi

    #
    # Check if the patch is necessary, since less is more.
    #
    _getEDID

    if [ $gPatchRecoveryHD -eq 1 ];
      then
        #
        # No, patch is no need on your PC. Patch whatsover?
        #
        read -p "Patch Recovery HD on your PC is no need. Do you want to continue (y/n)? " unsupportedConfirmed
        case "$unsupportedConfirmed" in
              y|Y) return
              ;;
              *) exit 1
              ;;
        esac
    fi

    #
    # Get argument.
    #
    gArgv=$(echo "$@" | tr '[:lower:]' '[:upper:]')
    if [[ $# -eq 1 && "$gArgv" == "-D" || "$gArgv" == "-DEBUG" ]];
      then
        #
        # Yes, we do need debug mode.
        #
        _PRINT_MSG "NOTE: Use ${BLUE}DEBUG${OFF} mode"
        gDebug=0
      else
        #
        # No, we need a clean output style.
        #
        gDebug=1
    fi

    #
    # Fixed UHD/QHD+ Recovery HD entering issues (c) syscl.
    #
    _recoveryhd_fix

    #
    # Unmount EFI.
    #
    _tidy_exec "diskutil unmount ${gEFI}" "Unmount ${gEFI}"

    _PRINT_MSG "NOTE: Congratulations! All operations have been completed"
    _PRINT_MSG "NOTE: Reboot now. Then enjoy your OS X! -${BOLD}syscl/lighting/Yating Zhou @PCBeta${OFF}"
}

#==================================== START =====================================

main "$@"

#================================================================================

exit ${RETURN_VAL}
