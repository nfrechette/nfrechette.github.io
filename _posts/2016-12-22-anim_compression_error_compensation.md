---
layout: post
title: "Animation Compression: Error Compensation"
---
Unless you use the curves directly authored by the animator for your animation clip, the animation compression you use will end up being lossy in nature and some amount of fidelity will be lost (possibly visible to the naked eye or not). To combat the loss of accuracy, three error compensation techniques emerged over the years to help push the memory footprint further down while keeping the visual results acceptable: in-place correction, additive correction, and [inverse kinematic](https://en.wikipedia.org/wiki/Inverse_kinematics) correction.

# In-place Correction

This technique has already been detailed in [Game Programming Gems 7](http://www.amazon.com/Game-Programming-Gems-Series/dp/1584505273). As such, I won’t go into implementation details unless there is significant interest.

As we have [seen previously]({% post_url 2016-10-27-anim_compression_data %}), our animated bone data is stored in local space which means that any error on a parent bone will propagate to its children. Fundamentally this technique aims to compensate our compression error by applying a small correction to each track to help stop the error propagating in our hierarchy. For example, if we have two parented bones, a small error in the parent bone will offset the child in object space. To account for this and compensate, we can apply a small offset on our child in local space such that the end result in object space is as close to the original animation as possible.

## Up Sides

The single most important up side of this technique is that it adds little to no overhead to the runtime decompression. The bulk of the overhead remains entirely on the offline process of compression. We only add overhead on the decompression if we elect to introduce tracks to compensate for the error.

## Down Sides

There are four issues with this technique.

### Missing Tracks

We can only apply a correction on a particular child bone if it is animated. If it is not animated, adding our correction will end up adding more data to compress and we might end up increasing the memory footprint. If the translation track is not animated, our correction will be partial in that with rotation alone we will not be able to match the exact object space position to reach in order to mirror the original clip.

### Noise

Adding a correction for every key frame will tend to yield noisy tracks. Each key frame will end up with a micro-correction which in turn will need somewhat higher accuracy to keep it reliable. For this reason, tracks with correction in them will tend to compress a bit more poorly.

### Compression Overhead

To properly calculate the correction to apply for every bone track, we must calculate the object space transforms of our bones. This adds extra overhead to our compression time. It may or may not end up being a huge deal, your mileage may vary.

### Track Ranges

Due to the fact that we add corrections to our animated tracks, it is possible and probable that our track ranges might change as we compress and correct our data. This needs to be properly taken into account, further adding more complexity if range reduction is used.

# Additive Correction

Additive correction is very similar to the in-place correction mentioned above. Instead of modifying our track data in-place by incorporating the correction, we can instead store our correction separately as extra additive tracks and combine it during the runtime decompression.

This variation offers a number of interesting trade-offs which are worth considering:

*  Our compressed tracks do not change and will not become noisy nor will their range change
*  Missing tracks are not an issue since we always add separate additive tracks
*  Adding the correction at runtime is very fast and simple
*  Additive tracks are compressed separately and can benefit from a different accuracy threshold

However by its nature, the memory overhead will most likely end up being higher than with the in-place variant.

# Inverse Kinematic Correction

The last form of error compensation leverages [inverse kinematics](https://en.wikipedia.org/wiki/Inverse_kinematics). The idea is to store extra object space translation tracks for certain high accuracy bones such as feet and hands. Bones that come into contact with things such as the environment tend to make compression inaccuracy very obvious. Using these high accuracy tracks, we run our [inverse kinematic algorithm](https://en.wikipedia.org/wiki/Inverse_kinematics) to calculate the desired transforms of a few parent bones to match our desired pose. This will tend to spread the error of our parent bones, making it less obvious while keeping our point of contact fixed and accurate.

Besides allowing our compression to be more aggressive, this technique does not have a lot of up sides. It does have a number of down sides though:

*  Extra tracks means extra data to compress and decompress
*  Even a simple [2-bone inverse kinematic algorithm](http://mrl.nyu.edu/~perlin/gdc/ik/ik.java.html) will end up slowing down our decompression since we need to calculate object space transforms for our bones involved
*  By its very nature, our parent bones will no longer closely match the original clip, only the general feel might remain depending on how far the [inverse kinematic](https://en.wikipedia.org/wiki/Inverse_kinematics) correction ends up putting us.

# Conclusion

All three forms of error correction can be used with any compression algorithm but they all have a number of important down sides. For this reason, unless you need the compression to be very aggressive, I would advise against using these techniques. If you choose to do so, the first two appear to be the most appropriate due to their reduced runtime overhead. Note that if you really wanted to, all three techniques could be used simultaneously but that would most likely be very extreme.

Up next: Case Studies

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

