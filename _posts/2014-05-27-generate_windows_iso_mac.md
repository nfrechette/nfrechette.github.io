---
layout: post
title: How to generate the Windows ISO from a Mac or Linux PC
---
Surprisingly, it turns out that getting your hands on a legal Windows ISO after purchasing it is not as easy as it might seem. After purchasing a digital copy of Windows in the Microsoft store, you will be able to download a Windows application that downloads the ISO for you after entering your product key.

Therein lies the issue: to create a Windows install media, you need access to a PC with Windows already installed. If like me all you have on hand is a Mac or Linux PC without easy or quick access to a PC with Windows (or one that you can trust with your product key), you are left in a tight spot. Even the Microsoft support will not be able to help you and will simply point out that it can’t be that hard to find a PC with Windows.

Worse still is that not all versions of Windows are supported and for example, all versions that run on the Free Amazon Web Services are not supported so this avenue is not open to us either (at least at the time of writing).

The only viable alternative appears to be to download the ISO from an untrusted torrent site. If like me this leaves you uneasy, read on.

As it turns out, an unrelated tool that Microsoft releases will allow us to execute that ISO generating executable in a safe and legal way.

### Step 1

Install [Virtual Box](https://www.virtualbox.org/). Virtual Box is a virtual machine application from Oracle that allows you to run an operating system in a virtualized environment as a guest.

### Step 2

Download a Virtual Box image from the [Internet Explorer Developer website](http://dev.modern.ie/tools/vms/). These images are legal versions of Windows provided by Microsoft to allow developers to test various Internet Explorer versions on various Windows versions. They expire after 90 days and cannot be activated but that doesn’t matter to us since we’ll only really use it for as long as the download of the ISO takes.

Simply grab the Windows 7 image (any Internet Explorer version will work) for the platform that you have (Mac or Linux) and need (32 or 64 bit).

### Step 3

Inside Virtual Box, import the Windows image downloaded at the previous step. The documentation recommends you set at least 2GB of RAM for the virtual machine to use. This is fine since we’ll only run it for a short amount of time anyway.

### Step 4

Use Virtual Box to [share a directory](https://www.virtualbox.org/manual/ch04.html#sharedfolders) with the virtual machine with write access and make sure it automatically mounts (easier for us). This is the directory where we will copy the ISO file into.

### Step 5

Launch the virtual machine instance and use it to run the executable from the Windows store. If you do not have access to it, I have not tested but presume that you might be able to use [this utility](http://windows.microsoft.com/en-us/windows-8/create-reset-refresh-media) as well.

### Step 6

Follow the instructions and download the ISO to some directory (e.g: the desktop). For some reason Virtual Box did not allow me to download directly to the shared directory we setup in *Step 4*. Either way, once the download terminates, simply copy the ISO to the shared directory.

### Profit!

That’s it! You are done and you can now get rid of Virtual Box if you wish to. You can now continue the steps to create your bootable DVD or USB stick from the ISO.

[There](http://www.tomshardware.com/answers/id-1800781/windows-iso-file.html) [are](http://kb.parallels.com/en/121009) [so](http://log.maniacalrage.net/post/78047230047/how-to-install-windows-8-1-on-a-new-mac-pro) [many](http://forums.whirlpool.net.au/archive/2155844) threads out there asking how to do this that I hope this will be able to help someone avoid the hassle I went through to find this. You would think Microsoft would make it easier for you to install their operating system...
