---
layout: post
title: "Pitfalls of linear sample reduction: Part 3"
---
**A quick recap:** animation clips are formed from a set of time series called tracks. Tracks have a fixed number of samples per second and each track has the same length. The [Animation Compression Library](https://github.com/nfrechette/acl) retains every sample while *Unreal Engine* uses the popular method of [removing samples that can be linearly interpolated]({% post_url 2016-12-07-anim_compression_key_reduction %}) from their neighbors.

The [first post]({% post_url 2019-07-23-pitfalls_linear_reduction_part1 %}) showed how removing samples negates some of the benefits that come from [segmenting]({% post_url 2016-11-10-anim_compression_uniform_segmenting %}), rendering the technique a lot less effective.

The [second post]({% post_url 2019-07-25-pitfalls_linear_reduction_part2 %}) explored how sorting (or not) the retained samples impacts the decompression performance.

This third post will take a deep dive into the memory overhead of the three techniques we have been discussing so far:

* Retaining every sample with ACL
* Sorted and unsorted linear sample reduction

## Should we remove samples or retain them?

ACL does not yet implement a sample reduction algorithm while UE4 is missing a number of features that ACL provides. As such, in order to keep things as fair as possible, some assumptions will be made for the sample reduction variants and we will thus extrapolate some results using ACL as a baseline.

In order to find out if it is worth it to remove samples and how to best go about storing the remaining samples, we will use the *Main Trooper* from the [Matinee fight scene](2017-10-05-acl_in_ue4). It has 541 bones with no animated 3D scale (1082 tracks in total) and the sequence has 1991 frames (~66 seconds long) per track. A total of 71 tracks are constant, 1 is default, and 1010 are animated. Where segmenting is concerned, I use the arbitrarily chosen segment #13 as a baseline. ACL splits this clip in 124 segments of about 16 frames each. This clip has a *LOT* of data and a high bone count which should highlight how well these algorithms scale.

We will track three things we care about:

* The number of bytes touched during decompression for a full pose
* The number of cache lines touched during decompression for a full pose
* The total compressed size

Due to the simple nature of animation decompression, the number of cache lines touched is a good indicator of overall performance as it often can be memory bound.

All numbers will be rounded up to the nearest byte and cache line.

All three algorithms use linear interpolation and as such require two poses to interpolate our final result.

*See the annex at the end of the post for how the math breaks down*

### The shared base

Some features are always a win and will be assumed present in our three algorithms:

* If a track has a single repeating sample (within a threshold), it will be deemed a [constant track]({% post_url 2016-11-03-anim_compression_constant_tracks %}). Constant tracks are collapsed into a single full resolution sample with 3x floats (even for rotations) with a single bit per track to tell them apart.
* If a constant track is identical to the identity value for that track type (e.g. quaternion identity), it will be deemed a default track. Default tracks have no sample stored, just a single bit per track to tell them apart.
* All animated tracks (not constant or default) will be normalized within their min/max values by performing [range reduction]({% post_url 2016-11-09-anim_compression_range_reduction %}) over the whole clip. This increases the accuracy which leads to a lower memory footprint for the majority of clips. To do so, we store our range minimum and extent values as 3x floats each (even for rotations).

The current UE4 codecs do not have special treatment for constant and default tracks but they do support range reduction. There is room for improvement here but that is what ACL uses right now and it will be good enough for our calculations.

|                      | Bytes touched | Cache lines touched | Compressed size |
| -------------------- | ------------- | ------------------- | --------------- |
| **Default bit set**  | 136           | 3                   | 136 bytes       |
| **Constant bit set** | 136           | 3                   | 136 bytes       |
| **Constant values**  | 852           | 14                  | 852 bytes       |
| **Range values**     | 24240         | 379                 | 24240 bytes     |
| **Total**            | 25364         | 399                 | 25 KB           |

In order to support variable bit rates where each animated track can have its own bit rate, ACL stores 1 byte per animated track (and per segment). This is overkill as only 19 bit rates are currently supported but it keeps things simple and in the future the extra bits will be used for other things. When segmenting is enabled with ACL, range reduction is also performed per segment and adds 6 bytes of overhead per animated track for the quantized range values.

|                          | Bytes touched | Cache lines touched | Compressed size |
| ------------------------ | ------------- | ------------------- | --------------- |
| **Bit rates**            | 1010          | 16                  | 123 KB          |
| **Segment range values** | 6060          | 95                  | 734 KB          |

### The ACL results

We will consider two cases for ACL. The default compression settings have segmenting enabled which is great for the memory footprint and compression speed but due to the added memory overhead and range reduction, decompression is a bit slower. As such, we will also consider the case where we disable segmenting in order to bias for faster decompression.

With segmenting, the animated pose size (just the samples, without the bit rate and segment range values) for the segment #13 is 3777 bytes (60 cache lines). This represents about 3.74 bytes per sample or about 30 **b**its **p**er **s**ample (**bps**).

Without segmenting, the animated pose size is 5903 bytes (93 cache lines). This represents about 5.84 bytes per sample or about 46 **bps**.

Although the UE4 codecs do not support variable bit rates the way ACL does, we will assume that we use the same algorithm and as such these numbers of 30 and 46 bits per samples will be used in our projections. Because 30 bps is only attainable with segmenting enabled, we will also assume it is enabled for the sample reduction algorithms when using that bit rate.

|                        | Bytes touched | Cache lines touched | Compressed size |
| ---------------------- | ------------- | ------------------- | --------------- |
| **With segmenting**    | 39990         | 625                 | 7695 KB         |
| **Without segmenting** | 38172         | 597                 | 11503 KB        |

As we can see, while segmenting reduces considerably the overall memory footprint (by 33%), it does contribute to quite a few extra cache lines being touched (4.7% more) during decompression despite the animated pose being 36% smaller. This highlights how normalizing the samples within the range of each segment increases their overall accuracy and reduces the number of bits required to maintain it.

### Unsorted sample reduction

In order to decompress when samples are missing, we need to store the sample time (or index). For every track, we will search for the two samples that bound the current time we are interpolating at and reconstruct the correct interpolation alpha from them. To keep things simple, we will store this time value on 1 byte per sample retained (for a maximum of 256 samples per clip or segment) along with the total number of samples retained per track on 1 byte. Supporting arbitrary track decompression efficiently also requires storing an offset map where each track begins. For simplicity's sake, we will omit this overhead but UE4 uses 4 bytes per track. When decompressing, we will assume that we immediately find the two samples we need within a single cache line and that both samples are within another cache line (2 cache misses per track).

These estimates are very conservative. In practice, the offsets are required to support *Levels of Detail* as well as efficient single bone decompression and more than 1 byte is often required for sample indices and their count in larger clips. In the wild, the memory footprint is surely going to be larger than these projections will show.

*Values below assume every sample is retained, for now.*

|                                      | Bytes touched | Cache lines touched | Compressed size |
| ------------------------------------ | ------------- | ------------------- | --------------- |
| **Sample times**                     | 2020          | 1010                | 1964 KB         |
| **Sample count with segmenting**     | 1010          | 16                  | 123 KB          |
| **Sample values with segmenting**    | 7575          | 1010                | 7346 KB         |
| **Total with segmenting**            | 43039         | 2546                | 10315 KB        |
| **Sample count without segmenting**  | 1010          | 16                  | 1 KB            |
| **Sample values without segmenting** | 11615         | 1010                | 11470 KB        |
| **Total without segmenting**         | 40009         | 2435                | 13583 KB        |

When our samples are unsorted, it becomes obvious why decompression is quite slow. The number of cache lines touched is staggering: 2435 cache lines which represents 153 KB! This scales linearly with the number of animated tracks. We can also see that despite the added overhead of segmenting, the overall memory footprint is lower (by 23%) but not by as much as ACL.

*Despite my claims from the first post, segmenting appears attractive here. This is a direct result of our estimates being conservative and UE4 not supporting the aggressive per track quantization that ACL provides.*

### Sorted sample reduction

With our samples sorted, we will add 16 bits of metadata per sample to store the sample time, the track index, and track type. This is optimistic. In reality, some samples would likely require more than that.

Our context will only store animated tracks to keep it as small as possible. We will consider two scenarios: when our samples are stored with full precision (96 bits per sample) and when they are packed with the same format as the compressed byte stream (in which case we simply copy the values into our context when seeking, no unpacking occurs). As previously mentioned, linear interpolation requires us to store two samples per animated track.

|                             | Bytes touched | Cache lines touched |
| --------------------------- | ------------- | ------------------- |
| **Context values @ 96 bps** | 24240         | 379                 |
| **Context values @ 46 bps** | 12808         | 198                 |
| **Context values @ 30 bps** | 14626         | 230                 |

Right off the bat, it is clear that if we want interpolation to be as fast as possible (with no unpacking), our context is quite large and requires evicting quite a bit of CPU cache. To keep the context footprint as low as possible, going forward we will assume that we store the values packed inside it. Storing packed samples into our context comes with challenges. Each segment will have a different pose size and as such we either need to resize the context or allocate it with the largest pose size. When packed in the compressed byte stream, each sample is often bit aligned and copying into another bit aligned buffer is more expensive than a regular `memcpy` operation. Keeping the context size low requires some work.

*Note that the above numbers also include the bytes touched for the bit rates and segment range values (where relevant) because they are needed for interpolation when samples are packed.*

|                                          | Bytes touched | Cache lines touched | Compressed size |
| ---------------------------------------- | ------------- | ------------------- | --------------- |
| **Compressed values with segmenting**    | 5798          | 91                  | 11274 KB        |
| **Compressed values without segmenting** | 7919          | 123                 | 15398 KB        |
| **Total with segmenting**                | 45788         | 720                 | 12156 KB        |
| **Total without segmenting**             | 46091         | 720                 | 15424 KB        |

*Note that the compressed size above does not consider the footprint of the context required at runtime to decompress but the bytes and cache lines touched do.*

Compared to the unsorted algorithm, the memory overhead goes up quite a bit: the constant struggle between size and speed.

The number of cache lines touched during decompression is quite a bit higher (15%) than ACL. In order to match ACL, 100% of the samples must be dropped which makes sense considering that we use the same bit rate as ACL to estimate and our context stores two poses which is also what ACL touches. Reading the compressed pose is added on top of this. As such, if every sample is dropped within a pose and already present in our context the decompression cost will be at best identical to ACL since the two will perform about the same amount of work. Reading compressed samples and copying them into our context will take some time and lead to a net win for ACL.

If instead we keep the context at full precision and unpack samples once into it, the picture becomes a bit more complicated. If no unpacking occurs and we simply interpolate from the context, we will be touching more cache lines overall but everything will be very hardware friendly. Decompression is likely to beat ACL but the evicted CPU cache might slow down the caller slightly. Whether this yields a net win is uncertain. Any amount of unpacking that might be required will slow things down further as well. Ultimately, even if enough samples are dropped and it is faster, it will come with a noticeable increase in runtime memory footprint and the complexity to manage a persistent context.

### Three challengers enter, only one emerges victorious

|                                 | Bytes touched | Cache lines touched | Compressed size |
| ------------------------------- | ------------- | ------------------- | --------------- |
| **Uniform with segmenting**     | 39990         | 625                 | 7695 KB         |
| **Unsorted with segmenting**    | 43039         | 2546                | 10315 KB        |
| **Sorted with segmenting**      | 45788         | 720                 | 12156 KB        |
| **Uniform without segmenting**  | 38172         | 597                 | 11503 KB        |
| **Unsorted without segmenting** | 40009         | 2435                | 13583 KB        |
| **Sorted without segmenting**   | 46091         | 720                 | 15424 KB        |

ACL retains every sample and touches the least amount of memory and it applies the lower CPU cache pressure. However, so far our estimates assumed that all samples were retained and as such, we cannot make a determination as to whether or not it also wins on the overall memory footprint. What we can do however, is determine how many samples we need to drop in order to match it.

With unsorted samples, we have to drop roughly 30% of our samples in order to match the compressed memory footprint of ACL with segmenting and 15% without. However, regardless of how many samples we remove, the decompression performance will never come close to the other two techniques due to the extremely high number of cache misses.

With sorted samples, we have to drop roughly 40% of our samples in order to match the compressed memory footprint of ACL with segmenting and 25% without. The number of cache lines touched during decompression is now quite a bit closer to ACL compared to the unsorted algorithm. It may or may not end up being faster to decompress depending on how many samples are removed, the context format used, and how many samples need unpacking but it will always evict more of the CPU cache.

It is worth noting that most of these numbers remain true if cubic interpolation is used instead. While the context object will double in size and thus require more cache lines to be touched during decompression, the total compressed size will remain the same if the same number of samples are retained.

[The fourth]({% post_url 2019-07-31-pitfalls_linear_reduction_part4 %}) and last blog post in the series will look at how many samples are actually removed in *Paragon* and *Fortnite*. This will complete the puzzle and paint a clear picture of the strengths and weaknesses of linear sample reduction techniques.

### Annex

Inputs:

* `num_segments = 124`
* `num_samples_per_track = 1991`
* `num_tracks = 1082`
* `num_animated_tracks = 1010`
* `num_constant_tracks = 71`
* `bytes_per_sample_with_segmenting = 3.74`
* `bytes_per_sample_without_segmenting = 5.84`
* `num_animated_samples = num_samples_per_track * num_animated_tracks = 2010910`
* `num_pose_to_interpolate = 2`

Shared math:

* `bitset_size = num_tracks / 8 = 136 bytes`
* `constant_values_size = num_constant_tracks * sizeof(float) * 3 = 852 bytes`
* `range_values_size = num_animated_tracks * sizeof(float) * 6 = 24240 bytes`
* `clip_shared_size = bitset_size * 2 + constant_values_size + range_values_size = 25364 bytes = 25 KB`
* `bit_rates_size = num_animated_tracks * 1 = 1010 bytes`
* `bit_rates_size_total_with_segmenting = bit_rates_size * num_segments = 123 KB`
* `segment_range_values_size = num_animated_tracks * 6 = 6060 bytes`
* `segment_range_values_size_total = segment_range_values_size * num_segments = 734 KB`
* `animated_pose_size_with_segmenting = bytes_per_sample_with_segmenting * num_animated_tracks = 3778 bytes`
* `animated_pose_size_without_segmenting = bytes_per_sample_without_segmenting * num_animated_tracks = 5899 bytes`

ACL math:

* `acl_animated_size_with_segmenting = animated_pose_size_with_segmenting * num_samples_per_track = 7346 KB`
* `acl_animated_size_without_segmenting = animated_pose_size_without_segmenting * num_samples_per_track = 11470 KB`
* `acl_decomp_bytes_touched_with_segmenting = clip_shared_size + bit_rates_size + segment_range_values_size + acl_animated_pose_size_with_segmenting * num_pose_to_interpolate = 39990 bytes`
* `acl_decomp_bytes_touched_without_segmenting = clip_shared_size + bit_rates_size + acl_animated_pose_size_without_segmenting * num_pose_to_interpolate = 38172 bytes`
* `acl_size_with_segmenting = clip_shared_size + bit_rates_size_total_with_segmenting + segment_range_values_size_total + acl_animated_size_with_segmenting = 8106 KB` (actual size is lower due to the bytes per sample changing from segment to segment)
* `acl_size_without_segmenting = clip_shared_size + bit_rates_size + acl_animated_size_without_segmenting = 11496 KB` (actual size is higher by a few bytes due to misc. clip overhead)

Unsorted linear sample reduction math:

* `unsorted_decomp_bytes_touched_sample_times = num_animated_tracks * 1 * num_pose_to_interpolate = 1010 bytes`
* `unsorted_sample_times_size_total = num_animated_samples * 1 = 1964 KB`
* `unsorted_sample_counts_size = num_animated_tracks * 1 = 1010 bytes`
* `unsorted_sample_counts_size_total = unsorted_sample_counts_size * num_segments = 123 KB`
* `unsorted_animated_size_with_segmenting = acl_animated_size_with_segmenting = 7346 KB`
* `unsorted_animated_size_without_segmenting = acl_animated_size_without_segmenting = 11470 KB`
* `unsorted_total_size_with_segmenting = clip_shared_size + bit_rates_size_total_with_segmenting + segment_range_values_size_total + unsorted_sample_times_size_total + unsorted_sample_counts_size_total + unsorted_animated_size_with_segmenting = 10315 KB`
* `unsorted_total_size_without_segmenting = clip_shared_size + bit_rates_size_total + unsorted_sample_times_size_total + unsorted_sample_counts_size + unsorted_animated_size_without_segmenting = 13583 KB`
* `unsorted_total_sample_size_with_segmenting = unsorted_sample_times_size_total + unsorted_animated_size_with_segmenting = 9310 KB`
* `unsorted_total_sample_size_without_segmenting = unsorted_sample_times_size_total + unsorted_animated_size_without_segmenting = 13434 KB`
* `unsorted_drop_rate_with_segmenting = (unsorted_total_size_with_segmenting - acl_size_with_segmenting) / unsorted_total_sample_size_with_segmenting = 28 %`
* `unsorted_drop_rate_without_segmenting = (unsorted_total_size_without_segmenting - acl_size_without_segmenting) / unsorted_total_sample_size_without_segmenting = 15.5 %`

Sorted linear sample reduction math:

* `full_resolution_context_size = num_animated_tracks * num_pose_to_interpolate * sizeof(float) * 3 = 24240 bytes = 24 KB`
* `with_segmenting_context_size = num_pose_to_interpolate * animated_pose_size_with_segmenting = 7556 bytes`
* `without_segmenting_context_size = num_pose_to_interpolate * animated_pose_size_without_segmenting = 11798 bytes`
* `with_segmenting_context_decomp_bytes_touched = with_segmenting_context_size + bit_rates_size + segment_range_values_size = 14626 bytes = 15 KB`
* `without_segmenting_context_decomp_bytes_touched = without_segmenting_context_size + bit_rates_size = 12808 bytes = 13 KB`
* `sorted_decomp_compressed_bytes_touched_with_segmenting = num_animated_tracks * sizeof(uint16) + animated_pose_size_with_segmenting = 5798 bytes`
* `sorted_decomp_compressed_bytes_touched_without_segmenting = num_animated_tracks * sizeof(uint16) + animated_pose_size_without_segmenting = 7919 bytes`
* `sorted_animated_size_with_segmenting = num_animated_samples * sizeof(uint16) + acl_animated_size_with_segmenting = 11274 KB`
* `sorted_animated_size_without_segmenting = num_animated_samples * sizeof(uint16) + acl_animated_size_without_segmenting = 15398 KB`
* `sorted_decomp_bytes_touched_with_segmenting = with_segmenting_context_decomp_bytes_touched + sorted_decomp_compressed_bytes_touched_with_segmenting + clip_shared_size = 45788 bytes = 45 KB`
* `sorted_decomp_bytes_touched_without_segmenting = without_segmenting_context_decomp_bytes_touched + sorted_decomp_compressed_bytes_touched_without_segmenting + clip_shared_size = 46091 bytes = 46 KB`
* `sorted_total_size_with_segmenting = clip_shared_size + bit_rates_size_total_with_segmenting + segment_range_values_size_total + sorted_animated_size_with_segmenting = 12156 KB`
* `sorted_total_size_without_segmenting = clip_shared_size + bit_rates_size + sorted_animated_size_without_segmenting = 15424 KB`
* `sorted_drop_rate_with_segmenting = (sorted_total_size_with_segmenting - acl_size_with_segmenting) / sorted_animated_size_with_segmenting = 40 %`
* `sorted_drop_rate_without_segmenting = (sorted_total_size_without_segmenting - acl_size_without_segmenting) / sorted_animated_size_without_segmenting = 25.5 %`
