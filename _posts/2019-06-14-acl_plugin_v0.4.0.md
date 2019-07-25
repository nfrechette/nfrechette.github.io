---
layout: post
title: "Comparing past and present Unreal Engine 4 animation compression"
---
Ever since the [Animation Compression Library UE4 Plugin](https://github.com/nfrechette/acl-ue4-plugin) was released in *July 2018*, I have been comparing and tracking its progress against *Unreal Engine 4.19.2*. For the sake of consistency, even when newer UE versions came out, I did not integrate ACL and measure from scratch. This was convenient and practical since animation compression doesn't change very often in UE and the numbers remain fairly close over time. However, in *UE 4.21* significant changes were made and comparing against an earlier release was no longer a fair and accurate comparison.

As such, I have updated my baseline to *UE 4.22.2* and am releasing a new version of the plugin to go along with it: [v0.4](https://github.com/nfrechette/acl-ue4-plugin/releases/tag/v0.4.0). This new plugin release does not bring significant improvements on the previous one (they both still use [ACL v1.2](https://github.com/nfrechette/acl/releases/tag/v1.2.0)) but it does bring the necessary changes to integrate cleanly with the newer UE API. One of the most notable changes in this release is the introduction of [git patches](https://github.com/nfrechette/acl-ue4-plugin/tree/develop/Docs#engine-integration) for the custom engine changes required to support the ACL plugin. Note that earlier engine versions are not officially supported although if there is interest, feel free to reach out to me.

One benefit of the thorough measurements that I regularly perform is that not only can I track ACL's progress over time but I can also do the same with Unreal Engine. Today we'll talk about *Unreal* a bit more.

## What changed in UE 4.21

Two years ago *Epic* asked me to improve their own animation compression. The primary focus was on improving the compression speed of their automatic compression codec while maintaining the existing memory footprint and decompression speed. Improvements to the other metrics was considered a stretch goal.

The automatic compression codec in *UE 4.20* and earlier tried **35+** codec permutations and picked the best overall. Understandably, this could be quite slow in many cases.

To speed it up, two important changes were made:

*  The codecs tried were distilled into a white list of the 11 most commonly used codecs
*  The codecs are now evaluated in parallel

This brought a significant win. As mentioned at the [Games Developer Conference 2019](https://youtu.be/tWVZ6KO4lRs?t=1256), the introduction of the white list brought the time to compress *Fortnite* (while cooking for the *Xbox One*) from **6h 25mins** down to **1h 50mins**, a speed up of **3.5x**. Executing them in parallel lowered this even more, down to **40mins** or about **2.75x** faster. Overall, it ended up **9.6x** faster.

While none of this impacted the codecs or the API in any way, *UE 4.21* also saw significant changes to the codec API. The reason for this will be the subject of my [next blog post]({% post_url 2019-07-23-pitfalls_linear_reduction_part1 %}): failed optimization attempts and the lessons learned from them. In particular, I will show why removing samples that can be reconstructed through interpolation has significant drawbacks. Sometimes despite your best intentions and research, things just don't pan out.

## The juicy numbers

For the *GDC* presentation we only measured a few metrics and only while cooking *Fortnite*. However, every release I use a much more extensive set of animations to track progress and many more metrics. Here are all the numbers.

*Note: The ACL plugin v0.3 numbers are from its integration in UE 4.19.2 while v0.4 is with UE 4.22.2. Because the Unreal codecs didn't change, the decompression performance remained roughly the same. The ACL plugin accuracy numbers are slightly different due to fixes in the commandlet used to extract them. The compression speedup for the ACL plugin largely comes from the switch to Visual Studio 2017 that came with UE 4.20.*

### Carnegie-Mellon University database performance

For details about this data set and the metrics used, see [here](https://github.com/nfrechette/acl-ue4-plugin/blob/develop/Docs/cmu_performance.md).

|                 | ACL Plugin v0.4.0 | ACL Plugin v0.3.0 | UE v4.22.2  | UE v4.19.2 |
| -------                | --------   | --------      | --------      | --------      |
| **Compressed size**    | 74.42 MB | 74.42 MB | 100.15 MB | 99.94 MB |
| **Compression ratio**  | 19.21 : 1 | 19.21 : 1 | 14.27 : 1   | 14.30 : 1 |
| **Compression time**   | 5m 10s | 6m 24s | 11m 11s | 1h 27m 40s |
| **Compression speed**  | 4712 KB/sec | 3805 KB/sec | 2180 KB/sec | 278 KB/sec |
| **Max ACL error**      | 0.0968 cm | 0.0702 cm | 0.1675 cm  | 0.1520 cm |
| **Max UE4 error**      | 0.0816 cm | 0.0816 cm | 0.0995 cm    | 0.0996 cm |
| **ACL Error 99<sup>th</sup> percentile** | 0.0089 cm | 0.0088 cm | 0.0304 cm | 0.0271 cm |
| **Samples below ACL error threshold** | 99.90 % | 99.93 % | 47.81 % | 49.34 % |

### Paragon database performance

For details about this data set and the metrics used, see [here](https://github.com/nfrechette/acl-ue4-plugin/blob/develop/Docs/paragon_performance.md).


|                   | ACL Plugin v0.4.0 | ACL Plugin v0.3.0 | UE v4.22.2   | UE v4.19.2 |
| -------               | --------      | -------               | -------               | -------               |
| **Compressed size**   | 234.76 MB | 234.76 MB | 380.37 MB | 392.97 MB |
| **Compression ratio** | 18.22 : 1 | 18.22 : 1 | 11.24 : 1   | 10.88 : 1 |
| **Compression time**  | 23m 58s | 30m 14s | 2h 5m 11s | 15h 10m 23s |
| **Compression speed** | 3043 KB/sec | 2412 KB/sec | 582 KB/sec | 80 KB/sec |
| **Max ACL error**     | 0.8623 cm | 0.8623 cm | 0.8619 cm      | 0.8619 cm |
| **Max UE4 error**     | 0.8601 cm | 0.8601 cm | 0.6424 cm      | 0.6424 cm |
| **ACL Error 99<sup>th</sup> percentile** | 0.0100 cm | 0.0094 cm | 0.0438 cm | 0.0328 cm |
| **Samples below ACL error threshold** | 99.00 % | 99.19 % | 81.75 % | 84.88 % |

### Matinee fight scene performance

For details about this data set and the metrics used, see [here](https://github.com/nfrechette/acl-ue4-plugin/blob/develop/Docs/fight_scene_performance.md).

|               | ACL Plugin v0.4.0 | ACL Plugin v0.3.0 | UE v4.22.2 | UE v4.19.2 |
| -------               | --------  | -------               | -------               | -------               |
| **Compressed size**   | 8.77 MB | 8.77 MB | 23.67 MB   | 23.67 MB |
| **Compression ratio** | 7.11 : 1 | 7.11 : 1 | 2.63 : 1   | 2.63 : 1 |
| **Compression time**  | 16s | 20s | 9m 36s | 54m 3s |
| **Compression speed** | 3790 KB/sec | 3110 KB/sec | 110 KB/sec | 19 KB/sec |
| **Max ACL error**     | 0.0588 cm | 0.0641 cm | 0.0426 cm | 0.0671 cm |
| **Max UE4 error**     | 0.0617 cm | 0.0617 cm | 0.0672 cm  | 0.0672 cm |
| **ACL Error 99<sup>th</sup> percentile** | 0.0382 cm | 0.0382 cm | 0.0161 cm | 0.0161 cm |
| **Samples below ACL error threshold** | 94.61 % | 94.52 % | 94.23 % | 94.22 % |

## Conclusion and what comes next

Overall, the new parallel white list is a clear winner. It is dramatically faster to compress and none of the other metrics measurably suffered. However, despite this massive improvement ACL remains *much* faster.

For the past few months I have been working with Epic to refactor the engine side of things to ensure that animation compression plugins are natively supported by the engine. This effort is ongoing and will hopefully land soon in an Unreal Engine near you.
