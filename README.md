# eso-linux-tools

This is a small set of scripts to make managing ESO on Linux slightly easier

There are currently 2 scripts available:

1. download-addons
2. ttc-price-tables

# download-addons

This script is designed to read in a TOML configuration file containing a list of addons 
and install them all in your ESO folder.

To configure the script, first create your TOML file and put it somewhere safe.
Next, configure the file in the etc directory to point to both your ESO addon folder and
your newly created TOML addon list.

After completing configuration, run the script in the bin directory to automatically download
and install all the addons in the TOML file.

# ttc-price-tables

This script is designed to download and install the TTC price tables to your ESO Addons folder.

This is necessary because the TTC client does not work on Linux (even under WINE)

To configure the script, edit the file in the etc directory to point to both your 
TTC addon folder and the server region url for your area.

After completing configuration, run the script in the bin directory to automatically download
and install the TTC price tables in your TTC addon folder.

# the script says its missing a dependency

These scripts rely on the following programs:

1. awk
2. curl
3. sed
4. unzip

If they are not already installed then you should install them as per your 
distribution's installation method.

# automation

It is possible to configure the one or both of these scripts automatically.
Personally I have the non-Steam version of ESO so in Lutris I have the TTC Price table
script configured as a pre-launch script so I know my price data is up to date.
If you want you could also do your addons like this but the script is not "smart" so it
downloads all the addons every time, instead of checking for what needs to be updated or added.
