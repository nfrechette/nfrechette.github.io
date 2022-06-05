---
layout: post
title: "Manipulating the sampling time for fun and profit"
---
The [Animation Compression Library](https://github.com/nfrechette/acl) works with uniformly sampled animation clips. For each animated data track, every sample falls at a predictable and regular rate (e.g. 30 samples/frames per second). This is done to keep the decompression code simple and fast: with samples being so regular, they can be packed efficiently, sorted by their timestamp.

![Uniform sampling](/public/uniform_sampling.jpg)

When we decompress, we simply find the surrounding samples to reconstruct the value we need.

```c++
float t = ... // At what time in the clip we sample

float duration = (num_samples - 1) * sample_rate;
float normalized_t = t / duration;
float sample_offset = normalized_t * (num_samples - 1);

int first_sample = trunc(sample_offset);
int second_sample = min(first_sample + 1, num_samples - 1);

float interpolation_alpha = sample_offset - first_sample;

interpolation_alpha = apply_rounding(interpolation_alpha, rounding_mode);

float result = lerp(sample_values[first_sample], sample_values[second_sample], interpolation_alpha);
```

This allows us to continously animate every value smoothly over time. However, that is not always necessary or desired. To support these use cases, ACL supports several **sample time rounding modes** in order to achieve various effects.

Rounding modes:

*  `none`: no rounding means that we linearly interpolate.
*  `floor`: the first/earliest sample is returned with full weight (`interpolation alpha = 0.0`). This can be used to step animations forward. Visually, on a character animation, it would look like a stop motion performance.
*  `ceil`: the second/latest sample is returned with full weight (`interpolation alpha = 1.0`). This might not have a valid use case but ACL supports it regardless for the sake of completeness. Unlike `floor` above, ceil returns values that are in the future which might not line up with other events that haven't happened yet: particle effects, audio cues (e.g. footstep sounds), and other animations. *If you know of a valid use case for this, please reach out!*
*  `nearest`: the nearest sample is returned with full weight (`interpolation alpha = 0.0 or 1.0 using round to nearest`). ACL uses this internally when measuring the compression error. The error is measured at every keyframe and because of floating point rounding, we need to ensure that a whole sample is used. Otherwise, we might over/undershoot.
*  `per_track`: each animated track can specify which rounding mode it wishes to use.

## Per track rounding

*This is a new feature that has been requested by a few studios (included in the upcoming ACL 2.1 release).*

When working with animated data, sometimes tracks within a clip are not homogenous and represent very different things. Synthetic joints can be introduced which do not represent something directly observable (e.g. camera, IK targets, pre-processed data). At times, these do not represent values that can be safely interpolated.

For example, imagine that we wish to animate a stop motion character along with a camera track in a single clip. We wish for the character joints to step forward in time and not interpolate (`floor` rounding) but the camera must move smoothly and interpolate (no rounding).

More commonly, this happens with scalar tracks. These are often used for animating blend shape (aka morph target) weights along with various other gameplay values. Gameplay tracks can mean anything and even though they are best stored as floating point values (to keep storage and their manipulation simple), they might not represent a smooth range (e.g. integral values, enums, etc).

When such mixing is used, each track can specify what rounding mode to use during decompression (ACL does not store this information in the compressed data).

*Note: tracks that do not interpolate smoothly also do not blend smoothly (between multiple clips) and special care must be taken when doing so.*

See [here](https://github.com/nfrechette/acl/blob/develop/docs/handling_per_track_rounding.md) for details on how to use this new feature.

## Performance implications

During decompression, ACL always interpolates between two samples even if the per track rounding feature is disabled during compilation. The most common rounding mode is `none` which means we interpolate. This allows us to keep the code simple. We simply snap the interpolation alpha to `0.0` or `1.0` when we `floor` and `ceil` respectively (or with `nearest`) and we make sure to use a [stable linear interpolation function](https://fgiesen.wordpress.com/2012/08/15/linear-interpolation-past-present-and-future/).

As a result, every rounding mode has the same performance with the exception of the `per track` one.

Per track rounding is disabled by default and the code is entirely stripped out because it isn't commonly required. When enabled, it adds a small amount of overhead on the order of **2-10%** slower (AMD Zen2 with SSE2) regardless of which rounding mode individual tracks use.

During decompression, ACL unpacks 8 samples at a time and interpolates them in pairs. These are then cached in a structure on the execution stack. This is done ahead, before the interpolated samples are needed to be written out which means that during interpolation, it does not know which sample belongs to which track. That determination is only done when we read it from the cached structure. The reason for this will be the subject of a future blog post but it is done to speed up decompression by hiding memory latency.

As a result of this design decision, the only way to support per track rounding is to cache all possible rounding results. When we need to read an interpolated sample, we can simply index into the cache with the rounding mode chosen for that specific track. In practice, this is much cheaper than it sounds because even though it adds quite a few extra instructions to execute (SSE2 will be quite a bit worse than AVX here due to the lack of VEX prefix and blend instructions), they can do so independently of other surrounding instructions and in the shadow of expensive square root instructions for rotation sub-tracks (we need to reconstruct the quaternion `w` component and we need to normalize the resulting interpolated value). In practice, we don't have to interpolate three times (one for each possible alpha value) because both `0.0` and `1.0` are trivial.

## Caveats when key frames are removed

When the [database feature]({% post_url 2021-01-17-progressive_animation_streaming %}) is used, things get a bit more complicated. Whole keyframes can be moved to the database and optionally stripped. This means that non-neighboring keyframes might interpolate together.

When all tracks interpolate with the same rounding mode, we can reconstruct the right interpolation alpha to use based on our closest keyframes present.

For example, let's say that we have 3 keyframes: A, B, and C. Consider the case where we sample the time just after where B lies (at time `t`).

![Keyframe reconstruction](/public/keyframe_reconstruction.jpg)

If B has been moved to the database and isn't present in memory during decompression, we have to reconstruct our value based on our closest remaining neighbors A and C (an inherently lossy process). When all tracks use the same rounding mode, this is clean and fast since only one interpolation alpha is needed for all tracks:

*  `none`: one alpha value is needed between A and C, past the 50% mark where B lies (see `x'` above)
*  `floor`: one alpha value is needed at 50% between A and C to reconstruct B (see `B'` above)
*  `ceil`: one alpha value is needed at 100% on C
*  `nearest`: the same alpha value as `floor` and `ceil` is used

However, consider what happens when individual tracks have their own rounding mode. We need three different interpolation alphas that are not trivial (`0.0` or `1.0`). Trivial alphas are very cheap since they fully match our known samples. To keep the code flexible and fast during decompression, we would have to fully interpolate three times:

*  Once for `floor` since the interpolation alpha needed for it might not be a nice number like `0.5` if multiple consecutive keyframes have been removed.
*  Once for `ceil` for the same reason as `floor`.
*  Once for `none` for our actual interpolated value.

As a result, the behavior will differ for the time being as ACL will return A with `floor` instead of the reconstructed B. This is unfortunate and I hope to address this in the next minor release (v2.2).

*Note: This discrepancy will only happen when interpolating with missing keyframes. If the missing keyframes are streamed in, everything will work as expected as if no database was used.*

In a future release, ACL will support [splitting tracks into layers](https://github.com/nfrechette/acl/issues/392) to group them together. This will allow us to use different rounding modes for different layers. We will also be able to specify [which tracks have values that can be interpolated or not](https://github.com/nfrechette/acl/issues/407), allowing us to identify boundary keyframes that cannot be moved to the database.

I would have liked to properly handle this right off the bat however due to time constraints, I opted to defer this work until the next release. I'm hoping to finalize the release of [v2.1](https://github.com/nfrechette/acl/milestone/11) this year. There is no ETA yet for v2.2 but it will focus on [streaming and other improvements](https://github.com/nfrechette/acl/milestone/12).

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})
