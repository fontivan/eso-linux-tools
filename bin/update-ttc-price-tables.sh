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
# function PrintMessage()
#
# Description:
#   Print a message to stdout prefixed with a timestamp.
# Inputs:
#   $1 - The message to be printed
########################################################################################################################
function PrintMessage(){
  # Print a timestamp followed by the requested message
  echo "$(date +'[%m/%d/%Y] [%H:%M:%S]') ${1}"
}

########################################################################################################################
# function PrintError()
#
# Description:
#   Print a message to stdout with the [ERROR] tag.
# Inputs:
#   $1 - The message to be printed
########################################################################################################################
function PrintError(){
  # Print an error message
  PrintMessage "[ERROR] ${1}"
}

########################################################################################################################
# function PrintInfo()
#
# Description:
#   Print a message to stdout with the [INFO] tag.
########################################################################################################################
function PrintInfo(){
  # Print an info message
  PrintMessage "[INFO] ${1}"
}

########################################################################################################################
# function ReportErrorAndExit()
#
# Description:
#   Print a message stating that a fatal error has occured and call exit with a non zero status code.
########################################################################################################################
function ReportErrorAndExit(){

  # A fatal error has occured and we need to exit immediately
  PrintError "A fatal error has occured."
	exit 1
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
  
  # If an error occurs then this will be flagged to 1 instead
  local returnCode
  returnCode="0"

  # Check if the TTC_ADDON_DIR variable is set
  if [[ -z "${TTC_ADDON_DIR}" ]]
    then
    PrintError "The configuration variable 'TTC_ADDON_DIR' is required but was not defined."
    returnCode="1"
  fi
  
  # Check if the TTC_DOWNLOAD_URL variable is set
  if [[ -z "${TTC_DOWNLOAD_URL}" ]]
  then
    PrintError "The configuration variable 'TTC_DOWNLOAD_URL' is required but was not defined."
    returnCode="1"
  fi

  # If no error has occured this will still be 0
  return "${returnCode}"
}

########################################################################################################################
# function ValidateDependencies()
#
# Description:
#   Validate that the necessary dependencies for this script are available. Presently this checks that both `curl`
#   and `unzip` are available on the system path.
# Returns:
#   0 - If all necessary dependencies were found successfully.
#   1 - If any of the necessary dependenccies could not be found.
########################################################################################################################
function ValidateDependencies(){

  # If an error occurs then this will be flagged to 1 instead
  local returnCode
  returnCode="0"

  # Check if curl is available
  if ! 2>/dev/null 1>/dev/null which curl
  then
    PrintError "The program 'curl' is required but could not be found."
    returnCode="1"
  fi

  # Check if unzip is available
  if ! 2>/dev/null 1>/dev/null which unzip
  then
    PrintError "The program 'unzip' is required but could not be found."
    returnCode="1"
  fi

  # If no error has occured this will still be 0
  return "${returnCode}"
}

########################################################################################################################
# function CreateTemporaryDirectory()
#
# Description:
#  Create the temporary directory used to store the zip file downloaded from the TTC servers.
# Inputs:
#   $TTC_DOWNLOAD_DIR - The directory to be created.
# Returns:
#   0 - If the directory was created successfully or already existed.
#   1 - If the directory could not be created.
########################################################################################################################
function CreateTemporaryDirectory(){

  # Let the user know what we're about to do
	PrintInfo "Creating directory '${TTC_DOWNLOAD_DIR}'."

  # Attempt to create the directory
	if ! mkdir -p "${TTC_DOWNLOAD_DIR}"
	then
	  PrintError "Failed to create directory '${TTC_DOWNLOAD_DIR}'."
	  return 1
	fi

	# If we get here then we successfully created the directory
	PrintInfo "Successfully created directory '${TTC_DOWNLOAD_DIR}'."
	return 0

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
# function CleanDownloadedFiles()
#
# Description:
#  Delete the folder used as a temporary download location.
#  This will be automatically called on script exit via trap setup.
# Inputs:
#   $TTC_DOWNLOAD_DIR - The directory on disk that contains the files downloaded from the TTC server.
########################################################################################################################
function CleanDownloadedFiles(){

  # Let the user know what we're about to do
	PrintInfo "Deleting '${TTC_DOWNLOAD_DIR}'."

	# First check if the file even exists
	if [[ -f "${TTC_DOWNLOAD_DIR}" ]]
	then

	  # If it does exist then we will try to delete it
		if ! rm -rf "${TTC_DOWNLOAD_DIR}"
		then

	    # If it failed then we need to let the user know
			PrintError "Failed to delete file '${TTC_DOWNLOAD_DIR}'."
			return 1
		fi
	fi

	# If we get here then the file either never existed or was successfully deleted
	PrintInfo "Successfully deleted file '${TTC_DOWNLOAD_DIR}'."
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
  LoadConfiguration         || ReportErrorAndExit
  ValidateInputs            || ReportErrorAndExit
  ValidateDependencies      || ReportErrorAndExit
  CreateTemporaryDirectory  || ReportErrorAndExit
  DownloadTTCPriceTables    || ReportErrorAndExit
  InstallTTCPriceTables     || ReportErrorAndExit
  exit 0
}

########################################################################################################################
### Main
########################################################################################################################

# Configure the system trap to delete the temporary directory on exit
trap CleanDownloadedFiles EXIT

# Call the main function
Main
