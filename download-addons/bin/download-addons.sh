#!/usr/bin/env bash

########################################################################################################################
# MIT License
#
# Copyright (c) 2021 fontivan
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
########################################################################################################################

########################################################################################################################
### Configuration
########################################################################################################################
set -eou pipefail

########################################################################################################################
# Constants
########################################################################################################################

# Get the path of this script's own directory
MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# The path to the common libraries
LIB_DIR="${MY_DIR}/../../common/lib"

# The expected path to the configuration file
ESO_ADDONS_CONFIG_FILE="${MY_DIR}/../etc/download-addons.config"

# The temporary folder that will be used to download all the addons
ADDON_DOWNLOAD_DIR="/tmp/eso-addons"

########################################################################################################################
### Functions
########################################################################################################################

########################################################################################################################
# function LoadCommonResources()
#
# Description:
#   Load the resource files from the common library directory
# Inputs:
#   $LIB_DIR - The folder containing the common libraries
# Returns:
#   0 - If the file exists and was loaded successfully.
#   1 - If the file does not exist or could not be loaded.
########################################################################################################################
function LoadCommonResources(){

    # Check if the file exists
    if [[ ! -d "${LIB_DIR}" ]]
    then
        # If the file doesn't exist then this is a serious problem
        PrintError "The library directory '${LIB_DIR}' could not be found."
        return 1
    fi

    # Source the resource file containing the configuration
    # shellcheck disable=SC1090
    local fileList
    fileList="$(ls "${LIB_DIR}")"

    # This will be returned later
    local returnCode
    returnCode="0"

    local currentFile
    local currentPath
    # Loop over all the files in the directory
    for currentFile in ${fileList}
    do
        # Construct the absolute path to the file
        currentPath="${LIB_DIR}/${currentFile}"

        # Check if the file even exists
        if [[ -f ${currentPath} ]]
        then

            # If the file exists try to load it
            # shellcheck disable=SC1090
            if ! source "${currentPath}"
            then
                # The file could not be loaded
                PrintError "The library file '${currentPath}' could not be loaded."
                returnCode="1"
            fi
        else
            # The file could not be found
            PrintError "The library file '${currentPath}' could not be found."
            returnCode="1"
        fi
    done

    return "${returnCode}"

}

########################################################################################################################
# function LoadConfiguration()
#
# Description:
#   Load the configuration file containing the required variables for the script to execute.
# Inputs:
#   $ESO_ADDONS_CONFIG_FILE - The path to the configuration file.
# Returns:
#   0 - If the file exists and was loaded successfully.
#   1 - If the file does not exist or could not be loaded.
########################################################################################################################
function LoadConfiguration(){

    # Check if the file exists
    if [[ ! -f "${ESO_ADDONS_CONFIG_FILE}" ]]
    then
      # If the file doesn't exist then this is a serious problem
      PrintError "The configuration '${ESO_ADDONS_CONFIG_FILE}' could not be found."
      return 1
    fi

    # Source the resource file containing the configuration
    # shellcheck disable=SC1090
    if ! source "${ESO_ADDONS_CONFIG_FILE}"
    then
      PrintError "The configuration file '${ESO_ADDONS_CONFIG_FILE}' could not be loaded."
      return 1
    fi
}

########################################################################################################################
# function ValidateInputs()
#
# Description:
#   Validate that the required input configuration has been set.
# Inputs:
#   $ESO_ADDON_DIR - The directory of the TTC addon in the ESO Addons folder.
#   $TTC_DOWNLOAD_URL - The url to download the TTC files from.
# Returns:
#   0 - If all the necessary configuration is set.
#   1 - If one or more of the necessary variables is missing.
########################################################################################################################
function ValidateInputs(){

    ValidateInput 'ESO_ADDON_DIR' "${ESO_ADDON_DIR}" '1'
    ValidateInput 'ESO_ADDON_LIST_FILE' "${ESO_ADDON_LIST_FILE}" ''

}

########################################################################################################################
# function DownloadAndInstallAddons()
#
# Description:
#   Download the addons from the eso-ui servers and install them in the ESO addons directory.
# Inputs:
#   $ESO_ADDON_LIST_FILE - The path to the file containing the list of addons
#   $ADDON_DOWNLOAD_DIR - The path to store the file on disk.
# Returns:
#   0 - If the addons were successfully downloaded and installed.
#   1 - If any errors occured.
########################################################################################################################
function DownloadAndInstallAddons(){

    # Let the user know what we're about to do
    PrintInfo "Downloading addons from file '${ESO_ADDON_LIST_FILE}'."

    local addonName
    local currentKey
    local currentLine
    local currentValue
    local downloadUrl

    addonName=""
    currentKey=""
    currentLine=""
    currentValue=""
    downloadUrl=""

    while read -r currentLine
    do
        # If this is not a name or url then reset the variables
        if [[ "${currentLine}" == "[[addons]]" ]]
        then
            addonName=""
            downloadUrl=""
        fi

        # Awk will be used to check for key/value pairs
        currentKey="$(echo "${currentLine}" | awk '{ split($0,a,"="); print a[1] }' | sed 's/\"//g' | sed 's/\s*//g')"
        currentValue="$(echo "${currentLine}" | awk '{ split($0,a,"="); print a[2] }' | sed 's/\"//g' | sed 's/\s*//g')"

        # Check if the key matches one of our expected ones and if so save the value appropriately
        if [[ "${currentKey}" == "name" ]]
        then
            addonName="${currentValue}"
        elif [[ "${currentKey}" == "url" ]]
        then
            downloadUrl="${currentValue}"
        fi

        # If both are set then download the file and install it in the ESO addons folder
        if [[ -n "${addonName}" && -n ${downloadUrl} ]]
        then

            # TODO: Handle failure cases within the subshell
            (
                # The eso ui addon download page doesn't seem to play nicely with curl so the subshell will
                # parse the direct download url out from the page
                cd "${ADDON_DOWNLOAD_DIR}"
                local directDownloadUrl
                directDownloadUrl="$(curl -s "${downloadUrl}" | grep Problems | sed 's/.*<a href=\"//' | sed 's/\">Click.*//')"
                PrintInfo "Downloading addon '${addonName}' from url '${directDownloadUrl}'."

                # Attempt to download the zip from the url
                if ! curl -s -o "${addonName}.zip" "${directDownloadUrl}"
                then
                    PrintError "Failed to download addon '${addonName}'."
                else
                    PrintInfo "Installing addon '${addonName}.'"

                    # Attempt to unpack the zip in the addon folder
                    if ! unzip -o -qq "${addonName}.zip" -d "${ESO_ADDON_DIR}"
                    then
                        PrintError "Failed to install addon '${addonName}'."
                    else
                        PrintInfo "Successfully installed addon '${addonName}'."
                    fi
                fi
            )

        fi

    done < "${ESO_ADDON_LIST_FILE}"

    PrintInfo "Downloaded all addons from file '${ESO_ADDON_LIST_FILE}'."
    return 0
}

########################################################################################################################
# function Main()
#
# Description:
#  Call the above functions in the appropriate order to accomplish the goal of installing all the addons in the list.
#  This includes loading common resources, loading the script specific configuration file, validating the inputs,
#  validating the dependencies, creating a temporary working directory, and finally downloading and installing all
#  the addons in the list file.
########################################################################################################################
function Main(){
    LoadCommonResources                                 || ReportErrorAndExit
    LoadConfiguration                                   || ReportErrorAndExit
    ValidateInputs                                      || ReportErrorAndExit
    ValidateDependencies                                || ReportErrorAndExit
    CreateTemporaryDirectory  "${ADDON_DOWNLOAD_DIR}"   || ReportErrorAndExit
    DownloadAndInstallAddons                            || ReportErrorAndExit
    exit 0
}

########################################################################################################################
### Main
########################################################################################################################

# Configure the system trap to delete the temporary directory on exit
# shellcheck disable=SC2064
trap "CleanTemporaryDirectory ${ADDON_DOWNLOAD_DIR}" EXIT

# Call the main function
Main
