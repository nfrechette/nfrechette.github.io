---
layout: post
title: "Compressing Fortnite Animations"
---
New year, new stats! A few months ago, *Epic* agreed to let me use their *Fortnite* animations for my open source research with the [Animation Compression Library (ACL)](https://github.com/nfrechette/acl). Following months of work to refactor *Unreal Engine 4* in order to natively support animation compression plugins, it has finally entered the review stage on *Epic's* end. While I had hoped the changes could make it in time for *Unreal Engine 4.22*, due to unforeseen delays, *4.23* seems a much more likely candidate.

Even though the code isn't public yet, the new updated ACL plugin kicks ass and *Fortnite* is a great title to showcase it with. The real game uses the classic UE4 codecs but I recompressed everything with the latest and greatest. After spending several hundred hours compressing the animations, fixing bugs, and iterating I can finally present the results.

**TL;DR:** Inside *Fortnite*, ACL shines bright with **2x** faster compression, **2x** smaller memory footprint, and higher accuracy. Decompression is **1.6x** faster on desktop, **2.3x** faster on a *Samsung S8*, and **1.2x** faster on the *Xbox One*.

# Methodology

For the UE4 measurements I used a modified *UE 4.21* with its default **Automatic Compression**. It tries a list of codecs in parallel and selects the optimal result by considering both size and accuracy.

ACL uses a modified version of the open source [ACL Plugin v0.2.2](https://github.com/nfrechette/acl-ue4-plugin). It uses its own default compression settings and in the rare event where the error is above **1cm**, it falls back automatically to safer settings.

Although the UE4 refactor doesn't change the legacy codecs, it does speed up their decompression a bit compared to previous UE4 releases. That is one of many benefits everyone will get to enjoy as a result of my refactor work regardless of which codec is used.

## Error measurements

While the UE4 and ACL error measurements never exactly matched, they historically have been very close for every single clip I had tried, until *Fortnite*. As it turns out, some exotic animations brought to light the fact that some subtle differences in how they both measure the error can lead to some large perceived discrepancies. This has now been documented in the plugin [here](https://github.com/nfrechette/acl-ue4-plugin/blob/develop/Docs/error_measurements.md).

**Three** differences stand out: how the error is measured, where the error is measured in space, and where the error is measured in time. You can follow the link above for the gory details but the jist is that ACL is more conservative and more accurate in how it measures the error and it should always be trusted over what UE4 reports in case of doubt or disagreement.

It is worth noting that because ACL does not currently support a floating point sample rate (e.g 28.3 FPS), those clips (and there are many) have a higher reported error with UE4 because by rounding, we are effectively time stretching those clips a tiny bit. They still look just as good though. This will be fixed in the [next version](https://github.com/nfrechette/acl-ue4-plugin/issues/7).

# The animations

I extracted all the non-additive animations regardless of whether they were used by the game or not: a grand total of **8304** clips! A total raw size of **17 GB** and roughly **17.5 hours** worth of playback.

*Fortnite* has a surprising number of exotic clips. Some take **hours** to compress with UE4 and others have a range of motion as wide as the *distance between the earth and the moon*! These allowed me to identify a number of very subtle bugs in ACL and to fix them.

# Compression stats

|                 | ACL Plugin  | UE4    |
| -------                | --------   | --------      |
| **Compressed size**    | 498.21 MB | 1011.84 MB      |
| **Compression ratio**  | 35.55 : 1 | 17.50 : 1     |
| **Compression time**   | 12h 38m 04.99s | 23h 8m 58.94s |
| **Compression speed**  | 398.72 KB/sec | 217.62 KB/sec |
| **Max ACL error**      | 0.9565 cm | 8392339 cm     |
| **Max UE4 error**      | 108904.6797 cm | 8397727 cm     |
| **ACL Error 99<sup>th</sup> percentile** | 0.0309 cm | 2.1856 cm |
| **Samples below ACL error threshold** | 97.71 % | 77.37 % |

Once again, ACL performs admirably: the compression speed is twice as fast (**1.83x**), the memory footprint reduces in half (**2.03x** smaller), and the accuracy is right where we want it. This is also in line with the previous results from [Paragon](https://github.com/nfrechette/acl-ue4-plugin/blob/develop/Docs/paragon_performance.md).

![Fortnite Max Error Distribution](/public/acl/fortnite_max_error_distribution.png)

UE4's accuracy struggles a bit with a few clips but in practice the error might not be visible as the overwhelming majority of samples are very accurate. This is consistent as well with [previous results](http://nfrechette.github.io/2017/12/05/acl_paragon/).

![UE4 Import Comic](/public/acl/ue4_importing.png)

A handful of clips contribute to a large portion of the UE4 compression time and its high error. One clip in particular stands out: it has **1167 bones**, **8371 samples** at **120 FPS**, and a total raw size of **372.66 MB**. Its range of motion peaks at **477000 kilometers** away from the origin! It truly pushes the codecs to their absolute limits.

|                 | ACL Plugin  | UE4    |
| -------                | --------   | --------      |
| **Compressed size**    | 71.53 MB | 220.87 MB      |
| **Compression ratio**  | 5.21 : 1 | 1.69 : 1     |
| **Compression time**   | 1m 38.07s | 4h 51m 59.13s |
| **Compression speed**  | 3891.19 KB/sec | 21.78 KB/sec |
| **Max ACL error**      | 0.0625 cm | 8392339 cm     |
| **Max UE4 error**      | 108904.6797 cm | 8397727 cm     |

It takes almost **5 hours** to compress with UE4! In comparison, ACL zips through in well under **2 minutes**. While it tries its best with the default settings it ultimately ends up using the safety fallback and thus compresses *twice* in that amount of time.

Overall, if you added the ACL codec to the *Automatic Compression* list, here is how it would perform:

*  ACL is smaller for **7711** clips (**92.86 %**)
*  ACL is more accurate for **7576** clips (**91.23 %**)
*  ACL has faster compression for **5704** clips (**68.69 %**)
*  ACL is smaller, better, and faster for **5017** clips (**60.42 %**)
*  ACL wins Automatic Compression for **7863** clips (**94.69 %**)

# Decompression stats

*Fortnite* has the handy ability to create replays. These make gathering deterministic profiling numbers a breeze. The numbers that follow are from a *50 vs 50* replay. On each platform, a section of the replay with some high intensity action was profiled.

## Desktop

![Fortnite Desktop Decompression Time](/public/acl/fortnite_pc_decompression_time.png)

The performance on desktop looks pretty good. ACL is consistently faster, about **38%** on average. It also appears a bit less noisy, a direct benefit of the improved cache friendliness of its algorithm.

## Samsung S8

![Fortnite Samsung S8 Decompression Time](/public/acl/fortnite_s8_decompression_time_both.png)

![Fortnite Samsung S8 ACL Decompression Time](/public/acl/fortnite_s8_decompression_time_acl.png)

ACL really shines on mobile. On average it is **56%** faster but that is only part of the story. On the S8 it appears that the core is hyperthreaded and another thread does heavy work and applies cache pressure. This causes all sorts of spikes with UE4 but in comparison, the cache aware ACL allows it to maintain a clean and consistent performance.

Hyperthreading on the CPU (and the GPU) works, roughly speaking, by the processor switching to another thread already executing when it notices that the current thread is stalled waiting on a slow operation, typically when memory needs to be pulled into the cache. Both threads are executing in the sense that they have data being held in registers but only one of them advances at a time on that core. When one stalls, the other executes.

When you have a piece of code that triggers a lot of cache misses, such as some of the legacy UE4 codecs, the processor will be more likely to switch to the other hyperthread. When this happens, execution is suspended and it will only resume once the other thread stalls or the time slice expires. This could be a long time especially if the other hyperthread is executing cache friendly code and doesn't otherwise stall often.

This translates into the type of graph above where there is heavy fluctuation as the execution time varies widely from the noise of the neighbor hyperthread.

On the other hand, when the code is cache friendly, it doesn't give the chance to the other thread to run. This gives a nice and smooth graph for that current thread as the risk of long interruptions is reduced. When the code is that optimized, hyperthreading typically doesn't help speed things up much as both threads compete for the same time slice with few opportunities to hide stalling latency. This is also what I observed when [measuring the compression performance](http://nfrechette.github.io/2018/01/10/acl_v0.6.0/). In theory due to the higher cache pressure, performance could even degrade with hyperthreading but in practice I haven't observed it, not with ACL at least.

## Xbox One

![Fortnite Xbox One Decompression Time](/public/acl/fortnite_xb1_decompression_time.png)

On the *Xbox One* ACL is about **13%** faster on average. Both lines seem to have very similar shapes unlike the previous two platforms due in large part to the absence of hyperthreading. There are a few possibilities as to why the gain isn't as significant on this platform:

*  The MSVC compiler does not generate assembly that is as clean as it generates on PC, it's certainly sub-optimal on a few points. It fails to inline many trivial functions and it leaves around unnecessary shuffle instructions.
*  Perhaps the other threads that share the L2 thrash the hardware prefetcher, preventing it from kicking in. ACL benefits heavily from hardware prefetching.
*  The CPU is quite slow compared to the speed of its memory. This reduces the benefit of cache locality as it keeps L2 cache misses fairly cheap in comparison.

The last two points seems the most likely culprits. ACL does a bit more work per sample decompressed than UE4 but everything is cache friendly. This gives it a massive edge when memory is slow compared to the CPU clock as is the case on my desktop, the *Samsung S8*, and lots of other platforms.

# Conclusion

With faster compression, faster decompression on every platform, a smaller memory footprint, and higher accuracy, ACL continues to shine in UE4 and it won't be long now before everyone can find it on the marketplace for free.

In the meantime, in the next few months I will perform another release of ACL and its plugin with all the latest fixes made possible with *Fortnite's* data.

# Status update

To my knowledge, the first game released with ACL came out in *November 2018* with the public UE4 plugin: [OVERKILL's The Walking Dead](https://store.steampowered.com/app/717690/OVERKILLs_The_Walking_Dead/). I was told it reduced their animation memory footprint by over **50%** helping them fit within their console budgets.

A number of people have also integrated it into their own custom game engines and although I have no idea if they are using it or not, [Remedy Entertainment](https://github.com/Remedy-Entertainment/acl) has forked ACL!

Last but not least, I'd like to extend a special shout-out to *Epic* for allowing me to do this and to the ACL contributors!
