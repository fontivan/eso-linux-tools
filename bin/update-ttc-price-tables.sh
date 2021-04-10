#!/usr/bin/env bash

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

# Configure the shell options
set -eou pipefail

# Get the path of this script's own directory
MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# The temporary folder that will be used to download the necessary files from TTC servers
TTC_DOWNLOAD_DIR="/tmp/eso-ttc-data"

# The name of the file that will be temporary downloaded
TTC_DOWNLOAD_FILE_NAME="ttc-price-tables.zip"

# The derived path of the downloaded file
TTC_DOWNLOAD_FILE_PATH="${TTC_DOWNLOAD_DIR}/${TTC_DOWNLOAD_FILE_NAME}"

function PrintMessage(){
  # Print a timestamp followed by the requested message
  echo "$(date +'[%m/%d/%Y] [%H:%M:%S]') ${1}"
}

function PrintError(){
  # Print an error message
  PrintMessage "[ERROR] ${1}"
}

function PrintInfo(){
  # Print an info message
  PrintMessage "[INFO] ${1}"
}

function ReportErrorAndExit(){

  # A fatal error has occured and we need to exit immediately
  PrintError "A fatal error has occured."
	exit 1
}

function LoadConfiguration(){

  # The expected path to the configuration file
  TTC_CONFIG_FILE="${MY_DIR}/../etc/update-ttc-price-tables.config"

  # Check if the file exists
  if [[ ! -f "${TTC_CONFIG_FILE}" ]]
  then
    # If the file doesn't exist then this is a serious problem
    PrintError "The configuration '${TTC_CONFIG_FILE}' could not be found/opened."
    return 1
  fi

  # Source the resource file containing the configuration
  # shellcheck disable=SC1090
  source "${TTC_CONFIG_FILE}"
}

function ValidateInputs(){
  
  # We will later check if this variable has been set
  local hasErrorOccured
  hasErrorOccured=""

  # Check if the TTC_ADDON_DIR variable is set
  if [[ -z "${TTC_ADDON_DIR}" ]]
    then
    PrintError "The configuration variable 'TTC_ADDON_DIR' is required but was not defined."
    hasErrorOccured="1"
  fi
  
  # Check if the TTC_DOWNLOAD_URL variable is set
  if [[ -z "${TTC_DOWNLOAD_URL}" ]]
  then
    PrintError "The configuration variable 'TTC_DOWNLOAD_URL' is required but was not defined."
    hasErrorOccured="1"
  fi
  
  # If any error has occured we will return 1 so the caller can determine what to do.
  # By doing it this way we will print all the errors that have occured instead of 
  # immediately failing out on the first error.
  if [[ -n "${hasErrorOccured}" ]]
  then
    return 1
  fi
}

function ValidateDependencies(){

  # We will later check if this variable has been set
  local hasErrorOccured
  hasErrorOccured=""

  # Check if curl is available
  if ! 2>/dev/null 1>/dev/null which curl
  then
    PrintError "The program 'curl' is required but could not be found."
    hasErrorOccured="1"
  fi

  # Check if unzip is available
  if ! 2>/dev/null 1>/dev/null which unzip
  then
    PrintError "The program 'unzip' is required but could not be found."
    hasErrorOccured="1"
  fi

  # If any error has occured we will return 1 so the caller can determine what to do.
  # By doing it this way we will print all the errors that have occured instead of
  # immediately failing out on the first error.
  if [[ -n "${hasErrorOccured}" ]]
  then
    return 1
  fi

}

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

function Main(){
  LoadConfiguration         || ReportErrorAndExit
  ValidateInputs            || ReportErrorAndExit
  ValidateDependencies      || ReportErrorAndExit
  CreateTemporaryDirectory  || ReportErrorAndExit
  DownloadTTCPriceTables    || ReportErrorAndExit
  InstallTTCPriceTables     || ReportErrorAndExit
  exit 0
}

# Configure the system trap to delete the temporary directory on exit
trap CleanDownloadedFiles EXIT

# Call the main function
Main
