Add-Ons Manager for EPiServer
=========

This is a script that provides a basic interface for managing EPiServer Add-Ons using the command line.
In order to be able to execute the script you need to have EPiServer 7.5 and PowerShell 3 installed.
The script is not signed, so you might need to change the execution policy by running this command in PowerShell command line (x86 if you have a 64 bit OS): 

```PowerShell
Set-ExecutionPolicy RemoteSigned
```

More informatoin available [here](http://world.episerver.com/Blogs/Sergey-Vorushilo/Dates/2013/12/Command-line-support-for-Add-On-system/)

Here is some interface screenshots.
---------

Site selection:

![SelectSite](https://raw.github.com/SergVro/AddOnsManager/master/Documentation/SelectSite.png "Select a site")

Main menu:

![MmainMenu](https://raw.github.com/SergVro/AddOnsManager/master/Documentation/MainMenu.png "Main menu")

List of installed add-ons:

![Installed](https://raw.github.com/SergVro/AddOnsManager/master/Documentation/ListOfInstalled.png "Installed add-ons")

