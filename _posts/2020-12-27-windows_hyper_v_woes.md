---
layout: post
title: "Windows Hyper-V woes"
---
This weekend, I noticed that [AMD Ryzen Master](https://www.amd.com/en/technologies/ryzen-master) (a great tool to control your CPU when profiling code performance) and [VirtualBox](https://www.virtualbox.org/) both stopped working for me under Windows 10. I wasn't too sure how it happened and I spent a good deal of time chasing what went wrong so I am documenting my process and result here in hope that it might help others as well.

## Why aren't they working?

Over the last few years, Windows has been roling out a hypervisor of its own: [Hyper-V](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/about/). This allows you to run virtual machines (without VMWare, VirtualBox, or some other similar program). It also allows isolation of various [security components](https://docs.microsoft.com/en-us/windows/security/identity-protection/credential-guard/credential-guard-requirements), further improving kernel safety. When the hypervisor is used, Windows runs inside it, much like a guest OS runs inside a host OS in a virtual machine setup. This is the root cause of my woes.

AMD Ryzen Master [complains](https://community.amd.com/t5/drivers-software/amd-ryzen-master-1-3-0-618-vbs-error/td-p/179477) (see also [this](https://github.com/microsoft/WSL/issues/4771)) that [Virtualization Based Security (VPS)](https://docs.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs) is enabled. From my understanding, what this means is that running this program within a virtual machine isn't supported or recommended. [Some hacks](https://github.com/milesburchell/RyzenMasterVBSFix) are floating around to patch the executable to allow the check to be skipped and it does appear to work (although I haven't tested it myself). Attempting to disable VPS lead me to pain and misery and in the end nothing worked.

In turn, VirtualBox attempts to run a virtual machine inside the hypervisor virtual machine. This is problematic because to keep performance fast under virtualization, the CPU exposes hardware a feature to accelerate virtual memory translation and now that feature is used by Windows and it cannot be shared and used by VirtualBox. While the latest version will still run your guest OS (Ubuntu in my case), it will be terribly slow. So slow as to be unusable. Older VBox versions might simply refuse to start the guest OS. [This thread](https://forums.virtualbox.org/viewtopic.php?f=6&t=90853) is filled with sorrow.

I spent hours pouring over forum threads trying to piece together the puzzle.

## How did it suddenly get turned on?

I was confused at first, because I hadn't changed anything related to Hyper-V or anything of the sort. How then, did it suddenly start being used? As it turns out, I installed [Docker](https://www.docker.com/) which is built on top of this.

## Fixing this once and for all

Finding a solution wasn't easy. Microsoft documents the many security features that virtualization provides and since I use my desktop for work as well, I wanted to make sure that turning it off was safe for me. Many forum posts offer various suggestions on what to do from modifying the registry, to uninstalling various things.

The end goal for me was to be able to stop using the virtualization as it cannot coexist with Ryzen Master and VirtualBox. To do so, you must uninstall every piece of software that requires it. [This VirtualBox forum post](https://forums.virtualbox.org/viewtopic.php?f=1&t=62339#p452019) lists known components that use it:

*  Application Guard
*  Credential Guard
*  Device Guard
*  <any> * Guard
*  Containers
*  Hyper-V
*  Virtual Machine Platform
*  Windows Hypervisor Platform
*  Windows Sandbox
*  Windows Server Containers
*  Windows Subsystem for Linux 2 (WSL2) (WSL1 does not enable Hyper-V)

To remove them, press the Windows Key + X -> App and Features -> Programs and Features -> Turn Windows features on or off.

You'll of course need to uninstall Docker and other similar software.

To figure out if you are using Device Guard and Credential Guard, Microsoft provides [this tool](https://www.microsoft.com/en-us/download/details.aspx?id=53337). Run it from a PowerShell instance with administrative privileges. Make sure the execution environment is unrestricted as well (as per the readme). And run it with the `-Ready` switch to see whether or not they are used. Those features might be required by your system administrator if you work in an office or perhaps required by your VPN to connect. In my case, the features weren't used and as such it was safe for me to remove the virtualization.

Once everything that might require virtualization has been removed, it is time to turn it off. Whether Windows boots inside the virtualized environment or not is determined by the boot loader. [See this thread for examples](https://stackoverflow.com/questions/30496116/how-to-disable-hyper-v-in-command-line). You can create new bootloader entries if you like but I opted to simply turn it off by executing with administrative privileges in a command prompt: `bcdedit /set hypervisorlaunchtype off`. If you need to turn it back on, you can execute this: `bcdedit /set hypervisorlaunchtype auto`.

Simply reboot and you should be good to go!
