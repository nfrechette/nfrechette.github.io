---
layout: post
title: "Animation Compression Library: Paragon Results"
---
While working for Epic to improve Unreal 4's own animation compression and decompression, I asked for permission to use the Paragon animations for research purposes and they generously agreed. Today I have the pleasure to report the findings from that new data set!

This is significant for two reasons:

*  It allows for extensive stress testing with new data
*  Paragon is a real game with high animation quality

[![Paragon Official Trailer](https://i.ytimg.com/vi/3OCJCZJWA68/hqdefault.jpg)](https://www.youtube.com/watch?v=3OCJCZJWA68 "Paragon Official Trailer")

# Carnegie-Mellon University

Thus far, the [Carnegie-Mellon University](http://mocap.cs.cmu.edu/) data set has been the performance benchmark.

The data set contains **2534** clips. Each clip contains an animated character with **44** bones. The version of the data that I found comes from the [Unity store](https://www.assetstore.unity3d.com/en/#!/content/19991) where it is distributed in FBX form but sampled at **24** FPS. The total duration of the database is **09h 49m 37.58s**. It does not contain any 3D scale and its raw size is **1429.38 MB**. It exclusively contains motion capture animation data. It is publicly available and well known within the animation compression research community.

While the database is valuable, it is not entirely representative of all the animation assets that a AAA game might use for a few reasons:

*  Most AAA games today have well over **100** bones per character and sometimes as high as [**500**]({% post_url 2017-10-05-acl_in_ue4 %})
*  The sample rate is lower than the **30** FPS typically used in games
*  Motion capture data is often very noisy
*  Games often animate things other than characters such as cloth, objects, destruction, etc.
*  Many games make use of 3D scale

For these reasons, this data set is wonderful for unit testing and establishing a baseline for comparison but it falls a bit short with what I would ideally like.

You can see how Unreal and ACL compare against it [here](https://github.com/nfrechette/acl/blob/develop/docs/cmu_performance.md).

# Paragon

The Paragon data set contains **6558** clips for a total duration of **07h 00m 45.27s** and a raw size of **4276.11 MB**. As you can see, despite being shorter than CMU, it is about **3x** larger in size.

The data set contains among other things:

*  Lots of characters with varying number of bones
*  Animated objects of various shape and form
*  Very short and very long clips
*  Clips with unusual sample rate (as low as **2** FPS!)
*  World space clips
*  Lots of 3D scale
*  Lots of other exotic clips

This is great to stress test any compression algorithm and the results will be very representative of what could be expected in a AAA game.

To extract the animation clips, I used the Unreal 4 animation recompression commandlet and modified it to skip clips that ACL does not yet support (e.g. additive animations). I did my best to retain as many clips as possible. Every clip was saved in the [ACL file format](https://github.com/nfrechette/acl/blob/develop/docs/the_acl_file_format.md) allowing a binary exact representation.

Sadly, I am not at liberty to share this data set as I am only allowed to use it under a non-disclosure agreement. All hope is not lost though, Epic has expressed interest in perhaps making a small subset of the data publicly available for research purposes. Stay tuned!

# Bugs!

The value of undertaking this quickly became obvious when an exotic clip from the data set highlighted a bug in the variable bit rate selection that ACL used. A fix was made and the results were breathtaking: CMU reduced in size by **19%** (and Paragon reduced by **20%**)! You can read about it [here]({% post_url 2017-11-23-acl_v0.5.0 %}) in my previous blog post.

Three clips stress tested the accuracy of ACL and ended up with an unacceptable error as a result. This will be made evident by the graphs and numbers below. I am hoping to fix a number of accuracy issues in the next ACL release now that I have new data to validate against.

The bugs I found were not exclusively within ACL: two were found and still present in the latest Unreal 4 version. Thankfully, I was able to get in touch with Epic and these should be fixed in a future release.

In order to make the comparison as fair as possible, I had to locally disable the down-sampling variants within the Unreal 4 automatic compression method. One of the two bugs caused these variants to sometime crash. While down-sampling isn't often selected by the algorithm as the optimal choice for any given clip, disabling it means that compression is faster and possibly a bit larger as a result. Out of the **600** clips I managed to compress before finding the bug, only **3** ended up down-sampled. There are **9** down-sampled variants out of **27** in total (**33%**).

# Bottom line

UE 4.15 took **19h 56m 50.37s** single threaded to compress. It yielded a compressed size of **496.24 MB** for a compression ratio of **8.62 : 1**. The max error is **0.8619cm**.

ACL 0.5 took **19h 04m 25.11s** single threaded to compress (**01h 53m 42.84s** with **11** threads). It yielded a compressed size of **205.69 MB** for a compression ratio of **20.79 : 1**. The max error is **9.7920cm**.

On the surface, the compression time remains faster with ACL even with a significant portion of the variants disabled in the Unreal automatic compression. However, the memory footprint is dramatically smaller, a whooping **58.6%** smaller! As will be made apparent in the graphs below, once again the maximum error proves to be a poor metric of the true performance: **3** clips have an error above **0.8cm** with ACL.

# The results in images

All the results and many more images are also on GitHub [here](https://github.com/nfrechette/acl/blob/develop/docs/paragon_performance.md) for Paragon just like they are for CMU [here](https://github.com/nfrechette/acl/blob/develop/docs/cmu_performance.md). I will only show a few selected images in this post for brevity.

![Compression ratio distribution](/public/acl/acl_paragon_v050_compression_ratio_distribution.png)

As expected, ACL outperforms Unreal by a significant margin. Some clips on the right are truncated with unusually high compression ratios as high as **900 : 1** for some exotic clips but those are likely very long with little to no animated data and aren't too interesting or representative.

![Max error distribution](/public/acl/acl_paragon_v050_max_error_distribution.png)

Here again ACL outperforms Unreal over the overwhelming majority of the data set. On the right there are a small number of clips that perform somewhat poorly with both compression methods: a total of **101** clips have an error above **0.1cm** with ACL and **153** clips for Unreal.

![Distribution of the error for every bone at every key frame](/public/acl/acl_paragon_v050_exhaustive_error.png)

As I have [previously]({% post_url 2017-09-10-acl_v0.4.0 %}) mentioned, the max clip error is a poor measure of accuracy. Once again the full picture is much better and tells a different story.

ACL continues to shine, crossing the **0.01cm** threshold at the **99.23th** percentile. Unreal crosses the same threshold at the **89th** percentile.

Despite having a maximum error that is entirely unacceptable, it turns out that only **0.77%** of the compressed samples (out of **112 million**) exceed a sub-millimeter threshold. Aside from the **3** worst offending clips, everything else is cinematic and production quality. Not bad!

# Conclusion

As is apparent now, ACL performs admirably in a myriad of scenarios and continues to improve month after month. Real world data now confirms it. Half the memory footprint of Unreal is not insignificant even for a PC or PS4 game: less data to load into memory means faster streaming, less data to transfer means faster game download and installation times, and it can correlate with faster decompression performance too. For many PS4 and XB1 games, **200 MB** is perhaps small enough to load them all into memory up front and never stream them from disk afterwards.

As I continue to improve ACL, I will update the graphs and numbers with the latest significant releases. I also expect the improvements that I made to Unreal's own animation compression over the last few months to be part of a future release and when that happens I will again update everything.

Special thanks to [Raymond Barbiero](https://keybase.io/visualphoenix) for his very valuable feedback and to the continued support of many others!
