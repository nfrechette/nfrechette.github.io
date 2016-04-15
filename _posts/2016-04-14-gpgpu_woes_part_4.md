---
layout: post
title: GPGPU woes part 4
---
After fixing the [previous]({% post_url 2015-07-11-gpgpu_woes_part_3 %}) addressing issue, we move on to the next.

### Inconsistencies and limitations

Here are the outputs for the various OpenCL driver values on my laptop:

#### Windows 8.1 x64

* Device: Intel(R) Iris(TM) Graphics 5100

    * Max workgroup size: 512
    * Num compute units: 40
    * Local mem size: 65536
    * Global mem size: 1837105152
    * Is memory unified: true
    * Cache line size: 64
    * Global cache size: 2097152
    * Address space size: 64
    * Kernel local workgroup size: 512
    * Kernel local mem size: 0

* Device: Intel(R) Core(TM) i5-4278U CPU @ 2.60GHz

    * Max workgroup size: 1024
    * Num compute units: 4
    * Local mem size: 32768
    * Global mem size: 1837105152
    * Is memory unified: true
    * Cache line size: 64
    * Global cache size: 262144
    * Address space size: 64
    * Kernel local workgroup size: 1024
    * Kernel local mem size: 12288

#### OS X x64

* Device: Iris

    * Max workgroup size: 512
    * Num compute units: 40
    * Local mem size: 65536
    * Global mem size: 1610612736
    * Is memory unified: true
    * Cache line size: 0
    * Global cache size: 0
    * Address space size: 64
    * Kernel local workgroup size: 512
    * Kernel local mem size: 30720

* Device: Intel(R) Core(TM) i5-4278U CPU @ 2.60GHz

    * Max workgroup size: 1024
    * Num compute units: 4
    * Local mem size: 32768
    * Global mem size: 0
    * Is memory unified: true
    * Cache line size: 3145728
    * Global cache size: 64
    * Address space size: 64
    * Kernel local workgroup size: 1
    * Kernel local mem size: 0

As we can see, many things differs and both seems to report bad values for a few things.

An important difference between the CPU and GPU is that CPU local storage is limited to 32KB. But Why? Couldn’t the CPU variant simply consider local storage to be the same as normal memory and thus only be bounded by virtual (or physical) memory?

This seemingly arbitrary limitation makes a lot of sense when you consider the fact that local storage is supposed to be used to avoid touching main memory by keeping intermediate results in fast memory. The [CUDA programming guide](http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html) states that they [expose functions](http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capability-2-x) to let you tweak how much of GPU L1 is split between real L1 usage and local storage and L1 is fast, really fast.

Sadly, on the CPU we usually have no such control with how the L1 is used or controlled and it is also quite small: usually 32KB for code and 32KB for data. Note that some exotic platforms do allow you some minimal control over the CPU caches such as the Wii cache line locking instructions. However, generally speaking, it is very hard to control effectively by hand.

With most CPUs (including the one I am using) having very small L1 caches, it makes sense to limit local storage to the size of the L1. After all, if you design an algorithm around the use of very fast memory, performance could be adversely affected should you have less available in reality.
