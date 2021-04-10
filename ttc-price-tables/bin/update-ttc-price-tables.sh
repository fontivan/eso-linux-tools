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
TTC_CONFIG_FILE="${MY_DIR}/../etc/update-ttc-price-tables.config"

# The temporary folder that will be used to download the necessary files from TTC servers
TTC_DOWNLOAD_DIR="/tmp/eso-ttc-data"

# The name of the file that will be temporary downloaded
TTC_DOWNLOAD_FILE_NAME="ttc-price-tables.zip"

# The derived path of the downloaded file
TTC_DOWNLOAD_FILE_PATH="${TTC_DOWNLOAD_DIR}/${TTC_DOWNLOAD_FILE_NAME}"

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
#   $TTC_CONFIG_FILE - The path to the configuration file.
# Returns:
#   0 - If the file exists and was loaded successfully.
#   1 - If the file does not exist or could not be loaded.
########################################################################################################################
function LoadConfiguration(){

    # Check if the file exists
    if [[ ! -f "${TTC_CONFIG_FILE}" ]]
    then
        # If the file doesn't exist then this is a serious problem
        PrintError "The configuration '${TTC_CONFIG_FILE}' could not be found."
        return 1
    fi

    # Source the resource file containing the configuration
    # shellcheck disable=SC1090
    if ! source "${TTC_CONFIG_FILE}"
    then
        PrintError "The configuration file '${TTC_CONFIG_FILE}' could not be loaded."
        return 1
    fi
}

########################################################################################################################
# function ValidateInputs()
#
# Description:
#   Validate that the required input configuration has been set.
# Inputs:
#   $TTC_ADDON_DIR - The directory of the TTC addon in the ESO Addons folder.
#   $TTC_DOWNLOAD_URL - The url to download the TTC files from.
# Returns:
#   0 - If all the necessary configuration is set.
#   1 - If one or more of the necessary variables is missing.
########################################################################################################################
function ValidateInputs(){

    ValidateInput 'TTC_ADDON_DIR' "${TTC_ADDON_DIR}" '1'
    ValidateInput 'TTC_DOWNLOAD_URL' "${TTC_DOWNLOAD_URL}" ''

}

########################################################################################################################
# function DownloadTTCPriceTables()
#
# Description:
#  Download the TTC price tables zip from the TTC servers and save it to the temporary storage directory.
# Inputs:
#   $TTC_DOWNLOAD_URL - The url of the file to download.
#   $TTC_DOWNLOAD_FILE_PATH - The path to store the file on disk.
# Returns:
#   0 - If the file was successfully downloaded
#   1 - If the file could not be downloaded.
########################################################################################################################
function DownloadTTCPriceTables(){

    # Let the user know what we're about to do
    PrintInfo "Downloading files from url '${TTC_DOWNLOAD_URL}' to file '${TTC_DOWNLOAD_FILE_PATH}'."

    # Attempt to download the file using curl
    if ! curl -s -o "${TTC_DOWNLOAD_FILE_PATH}" "${TTC_DOWNLOAD_URL}"
    then
        PrintError "Failed to download from '${TTC_DOWNLOAD_URL}'."
        return 1
    fi

    # If we get here then we successfully downloaded the file from the TTC servers
    PrintInfo "Downloaded TTC price tables to '${TTC_DOWNLOAD_FILE_PATH}'."
    return 0
}

########################################################################################################################
# function InstallTTCPriceTables()
#
# Description:
#  Install the TTC price tables into the addons folder.
# Inputs:
#   $TTC_ADDON_DIR - The directory to the TTC folder in the ESO addons folder.
#   $TTC_DOWNLOAD_FILE_PATH - The path to the file downloaded from the TTC servers.
# Returns:
#   0 - If the files were successfully installed.
#   1 - The the files could not be successfully installed.
########################################################################################################################
function InstallTTCPriceTables(){

    # Let the user know what we're about to do
    PrintInfo "Installing TTC price tables to '${TTC_ADDON_DIR}'."

    # Attempt to unzip the file at the required location
    if ! unzip -o -qq "${TTC_DOWNLOAD_FILE_PATH}" -d "${TTC_ADDON_DIR}"
    then

        # If it failed then we need to let the user know
        PrintError "Failed to install files to directory '${TTC_ADDON_DIR}'."
        return 1
    fi

    # If we get here then we were successful at installing the price tables
    PrintInfo "Successfully installed files to '${TTC_ADDON_DIR}'."
    return 0
}

########################################################################################################################
# function Main()
#
# Description:
#  Call the above functions in the appropriate order to accomplish the goal of installing the TTC price tables.
#  This means loading the configuration, validating the inputs, validating the dependencies, creating the working
#  directory, downloading the files, unpacking the files, and finally (via EXIT trap) cleaning up the working directory.
########################################################################################################################
function Main(){
    LoadCommonResources                             || ReportErrorAndExit
    LoadConfiguration                               || ReportErrorAndExit
    ValidateInputs                                  || ReportErrorAndExit
    ValidateDependencies                            || ReportErrorAndExit
    CreateTemporaryDirectory "${TTC_DOWNLOAD_DIR}"  || ReportErrorAndExit
    DownloadTTCPriceTables                          || ReportErrorAndExit
    InstallTTCPriceTables                           || ReportErrorAndExit
    exit 0
}

########################################################################################################################
### Main
########################################################################################################################

# Configure the system trap to delete the temporary directory on exit
# shellcheck disable=SC2064
trap "CleanTemporaryDirectory ${TTC_DOWNLOAD_DIR}" EXIT

# Call the main function
Main
