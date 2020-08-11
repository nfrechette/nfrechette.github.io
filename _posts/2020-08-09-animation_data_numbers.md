---
layout: post
title: "Animation data in numbers"
---
For a while now, I've been meaning to take some time to instrument the [Animation Compression Library (aka ACL)](https://github.com/nfrechette/acl) and look more in depth at the animations I have. Over the years I've had a lot of ideas on what could be improved and good data is critical in deciding where my time is best spent optimizing. I'm not sure if this will be of interest to many people out there but since I went ahead and did all that work, I might as well publish it!

## The basics

An animation clip is made up of a number of tracks each containing an equal number of transform or scalar samples (we use uniform sampling). Transform tracks are further broken down into sub-tracks for rotation, translation, and scale. Each sub-track is in one of three states:

*  Animated: every sample is retained and quantized
*  Constant: a single sample is repeating and retained
*  Default: a single repeating sample equal to the sub-track identity, no sample retained

Each sub-track type has its own identity. Rotations have the quaternion identity, translations have `0.0, 0.0, 0.0`, and scale tracks have `0.0, 0.0, 0.0` or `1.0, 1.0, 1.0` depending on whether the clip is additive or not and its additive type.

Being able to collapse constant and default tracks is [an important optimization]({% post_url 2016-11-03-anim_compression_constant_tracks %}). They are fairly common and allow us to considerably trim down on the number of samples we need to compress.

Sub-tracks that are animated end up having their [samples normalized]({% post_url 2016-11-09-anim_compression_range_reduction %}) within the full range of values within the clip. This range information is later used to reconstruct our original sample.

*Note that constant sample values and range values are currently stored with full float32 precision.*

## The compression format

When an animation is compressed with ACL, it is first broken down into [segments]({% post_url 2016-11-10-anim_compression_uniform_segmenting %}) of approximately 16 samples per track. As such, we end up with data that is needed regardless where we sample our clip and data that is needed only when we need a particular segment.

The memory layout roughly breaks down like this:

*  Per clip metadata
   *  Headers
   *  Offsets
   *  Track sub-type states
   *  Per clip constant samples
   *  Per clip animated sample ranges
*  Our segments
*  Optional metadata

Each segment ends up containing the following:

*  Per segment metadata
   *  Number of bits used per sub-track
   *  Sub-track range information (we also normalize our samples per segment)
*  The animated samples packed on a variable number of bits

In order to figure out what to try and optimize next, I wanted to see where the memory goes within the above categories.

## The datasets

I use three datasets for regression testing and for research and development:

*  [Carnegie-Mellon University motion capture database](https://github.com/nfrechette/acl/blob/develop/docs/cmu_performance.md)
*  [Paragon](https://github.com/nfrechette/acl/blob/develop/docs/paragon_performance.md)
*  [Fortnite]({% post_url 2019-01-25-compressing_fortnite_animations %})

We'll focus more on Paragon and Fortnite since they are more representative and substantial but CMU is included regardless.

*Special thanks to Epic for letting me use their animations for research purposes!*

When calculating the raw size of an animation clip, I assume that each track is animated and that nothing is stripped. As such, the raw size can be calculated easily: `raw size = num bones * num samples * 10 * sizeof(float)`. Each sample is made up of 10 floats: 4x for the rotation, 3x for the translation, and 3x for the scale.

Here is how they look at a glance:

|                      | CMU        | Paragon    | Fortnite    |
| -------------------- | ---------- | ---------- | ----------- |
| Number of clips      | 2534       | 6558       | 8310        |
| Raw size             | 1429.38 MB | 4276.11 MB | 17724.75 MB |
| Compressed size      | 71.00 MB   | 208.39 MB  | 483.54 MB   |
| Compression ratio    | 20.13 : 1  | 20.52 : 1  | 36.66 : 1   |
| Number of tracks     | 111496     | 816700     | 1559545     |
| Number of sub-tracks | 334488     | 2450100    | 4678635     |

### Sub-track breakdown

|                               | CMU    | Paragon | Fortnite |
| ----------------------------- | ------ | ------- | -------- |
| Number of default sub-tracks  | 34.09% | 37.26%  | 42.01%   |
| Number of constant sub-tracks | 52.29% | 43.95%  | 50.33%   |
| Number of animated sub-tracks | 13.62% | 18.78%  | 7.66%    |

| CMU                              | Default | Constant | Animated |
| -------------------------------- | ------- | -------- | -------- |
| Number of rotation sub-tracks    | 0.00%   | 64.41%   | 38.59%   |
| Number of translation sub-tracks | 2.27%   | 95.46%   | 2.27%    |
| Number of scale sub-tracks       | 100.00% | 0.00%    | 0.00%    |

| Paragon                          | Default | Constant | Animated |
| -------------------------------- | ------- | -------- | -------- |
| Number of rotation sub-tracks    | 10.85% | 47.69% | 41.45% |
| Number of translation sub-tracks | 3.32% | 82.98% | 13.70% |
| Number of scale sub-tracks       | 97.62% |1.19%    | 1.19% |

| Fortnite                         | Default | Constant | Animated |
| -------------------------------- | ------- | -------- | -------- |
| Number of rotation sub-tracks    | 21.15% | 62.84% | 16.01% |
| Number of translation sub-tracks | 7.64% | 86.78% | 5.58% |
| Number of scale sub-tracks       | 97.23% | 1.38% | 1.39% |

Overall, across all three data sets, about half the tracks are constant. Translation tracks tend to be constant much more often. Most tracks aren't animated but rotation tracks tend to be animated the most. Rotation tracks are 3x more likely to be animated than translation tracks and scale tracks are very rarely animated (~1.3% of the time). As such, segment data mostly contains animated rotation data.

### Segment breakdown

| Number of segments | CMU   | Paragon | Fortnite |
| ------------------ | ----- | ------- | -------- |
| Total              | 51909 | 49213   | 121175   |
| 50th percentile    | 10    | 3       | 2        |
| 85th percentile    | 42    | 9       | 18       |
| 99th percentile    | 116   | 117     | 187      |

Half the clips are very short and only contain 2 or 3 segments for Paragon and Fortnite. Those clips are likely to be 50 frames or less, or about 1-2 seconds at 30 FPS. For Paragon, 85% of the clips have 9 segments or less and in Fortnite we have 18 segments or less.

### Compressed size breakdown

| Compressed size | CMU   | Paragon | Fortnite |
| ------------------ | ----- | ------- | -------- |
| Total | 71.00 MB | 208.39 MB | 483.54 MB |
| 50th percentile    | 15.42 KB | 15.85 KB | 9.71 KB |
| 85th percentile    | 56.36 KB | 48.18 KB | 72.22 KB |
| 99th percentile    | 153.68 KB | 354.54 KB | 592.13 KB |

| Clip metadata size | CMU   | Paragon | Fortnite |
| ------------------ | ----- | ------- | -------- |
| Total size | 4.22 MB (5.94%) | 24.38 MB (11.70%) | 38.32 MB (7.92%) |
| 50th percentile    | 9.73% | 22.03% | 46.06% |
| 85th percentile    | 18.68% | 46.06% | 97.43% |
| 99th percentile    | 37.38% | 98.48% | 98.64% |

| Segment metadata size | CMU   | Paragon | Fortnite |
| ------------------ | ----- | ------- | -------- |
| Total size | 6.23 MB (8.78%) | 22.61 MB (10.85%) | 54.21 MB (11.21%) |
| 50th percentile    | 8.07% | 6.88% | 0.75% |
| 85th percentile    | 9.28% | 11.37% | 10.95% |
| 99th percentile    | 10.59% | 21.00% | 26.21% |

| Segment animated data size | CMU   | Paragon | Fortnite |
| ------------------ | ----- | ------- | -------- |
| Total size | 60.44 MB (85.13%) | 160.98 MB (77.25%) | 390.15 MB (80.69%) |
| 50th percentile    | 81.92% | 70.55% | 48.22% |
| 85th percentile    | 87.08% | 79.62% | 81.65% |
| 99th percentile    | 88.55% | 87.93% | 89.25% |

From this data, we can conclude that our efforts might be best spent optimizing the clip metadata where the constant track data and the animated range data will contribute much more relative to the overall footprint. Short clips have less animated data but just as much metadata as longer clips with an equal number of bones. Even though overall the clip metadata doesn't contribute much, for the vast majority of clips it does contribute a significant amount (for half the Fortnite clips, clip metadata represented 46.06% or more of the total clip size).

The numbers are somewhat skewed by the fact that a few clips are *very* long. Their animated footprint ends up dominating the overall numbers hence why breaking things down by percentile is insightful here.

The clip metadata isn't as optimized and it contains more low hanging fruits to attack. I've spent most of my time focusing on the segment animated data but as a result, pushing things further on that front is much harder and requires more work and a higher risk that what I try won't pan out.

### Animated data breakdown

|  | CMU   | Paragon | Fortnite |
| ------------------ | ----- | ------- | -------- |
| Total compressed size | 71.00 MB | 208.39 MB | 483.54 MB |
| Animated data size | 60.44 MB (85.13%) | 160.98 MB (77.25%) | 390.15 MB (80.69%) |
| 70% of animated data removed | 28.69 MB (2.47x smaller) | 95.70 MB (2.18x smaller) | 210.44 MB (2.30x smaller) |
| 50% of animated data removed | 40.78 MB (1.74x smaller) | 127.90 MB (1.63x smaller) | 288.47 MB (1.68x smaller) |
| 25% of animated data removed | 55.89 MB (1.27x smaller) | 168.15 MB (1.24x smaller) | 386.00 MB (1.25x smaller) |

A common optimization is to strip a number of frames from the animation data (aka sub-sampling or frame stripping). This is very destructive but can yield good memory savings. Since we know how much animated data we have and its relative footprint, we can compute ballpark numbers for how much smaller removing 70%, 50%, or 25% of our animated data might be. The numbers above represent the total compressed size after stripping and the reduction factor.

In my next post, I'll explore the results of [quantizing the constant sample values and the clip range values]({% post_url 2020-08-11-clip_metadata_packing %}), stay tuned!

[Animation Compression Table of Contents]({% post_url 2016-10-21-anim_compression_toc %})