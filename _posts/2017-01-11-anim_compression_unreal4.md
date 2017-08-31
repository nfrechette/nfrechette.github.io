---
layout: post
title: "Animation Compression: Unreal 4"
---
[![Unreal 4 2017](https://img.youtube.com/vi/WC6Xx_jLXmg/0.jpg)](https://www.youtube.com/watch?v=WC6Xx_jLXmg "Unreal 4 2017")

[Unreal 4](https://en.wikipedia.org/wiki/Unreal_Engine#Unreal_Engine_4) offers a wide range of [documented](https://docs.unrealengine.com/latest/INT/Engine/Animation/Sequences/) character animation compression settings.

It offers the following compression algorithms:

*   [Least Destructive](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#least_destructive)
*   [Remove Every Second Key](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#second_key)
*   [Remove Trivial Keys](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#trivial_keys)
*   [Bitwise Compress Only](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#bitwise_only)
*   [Remove Linear Keys](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#remove_linear)
*   [Compress each track independently](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#compress_independently)
*   [Automatic](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#automatic_setting)

*Note: The following review was done with Unreal 4.15*

## <a name="least_destructive"></a>Least Destructive
>  Reverts any animation compression, restoring the animation to the raw data.

This setting ensures we use raw data. It sets all tracks to use no compression which means they will have full floating point precision where **None** is used for translation and **Float 96** for rotation, explained [below](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#bitwise_only). Interestingly it does not appear to revert the scale to a sensible default raw compression setting which is likely a bug.

## <a name="second_key"></a>Remove Every Second Key
>  Keyframe reduction algorithm that simply removes every second key.

This setting does exactly what it claims; it removes every other key. It is a variation of [sub-sampling](http://nfrechette.github.io/2016/11/17/anim_compression_sub_sampling/). Each remaining key is further [bitwise compressed](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#bitwise_only).

Note that this compression setting also removes the [trivial keys](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#trivial_keys).

## <a name="trivial_keys"></a>Remove Trivial Keys
>  Removes trivial frames of tracks when position or orientation is constant over the entire animation from the raw animation data.

This takes advantage of the fact that very often [tracks are constant](http://nfrechette.github.io/2016/11/03/anim_compression_constant_tracks/) and when it happens a single key is kept and the rest is discarded.

## <a name="bitwise_only"></a>Bitwise Compress Only
>  Bitwise animation compression only; performs no key reduction.

This compression setting aims to retain every single key and encodes them with various variations. It is a custom flavor of [simple quantization](http://nfrechette.github.io/2016/11/15/anim_compression_quantization/) and will use the same format for every track in the clip. You can select one format per track type: rotation, translation, and scale.

These are the possible formats:

*   **None:** Full precision.
*   **Float 96:** Full precision is used for translation and scale. For rotations, a quaternion component is dropped and the rest are stored with full precision.
*   **Fixed 48:** For rotations, a quaternion component is dropped and the rest is stored on **16** bits per component.
*   **Interval Fixed 32:** Stores the value on **11-11-10** bits per component with range reduction. For rotations, a quaternion component is dropped.
*   **Fixed 32:** For rotations, a quaternion component is dropped and the rest is stored on **11-11-10** bits per component.
*   **Float 32:** This appears to be a semi-deprecated format where a quaternion component is dropped and the rest is encoded onto a custom float format with **6** or **7** bits for the mantissa and **3** bits for the exponent.
*   **Identity:** The identity quaternion is always returned for the rotation track.

Only three formats are supported for translation and scale: **None, Interval Fixed 32**, and **Float 96**. All formats are supported for rotations.

If a track has a single key it is always stored with full precision.

When a component is dropped from a rotation quaternion, **W** is always selected. This is safe and simple since it can be reconstructed with a square root as long as our quaternion is normalized. The sign is forced to be positive during compression by negating the quaternion if **W** was originally negative. A quaternion and its negated opposite [represent the same rotation on the hypersphere](https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation#The_hypersphere_of_rotations).

Sadly, the selection of which format to use is done manually and no heuristic is used to perform some automatic selection with this setting.

Note that this compression setting also removes the [trivial keys](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#trivial_keys).

## <a name="remove_linear"></a>Remove Linear Keys
>  Keyframe reduction algorithm that simply removes keys which are linear interpolations of surrounding keys.

This is a classic variation on [linear key reduction](http://nfrechette.github.io/2016/12/07/anim_compression_key_reduction/) with a few interesting twists.

They use a [local space error metric coupled with a partial virtual vertex error metric](http://nfrechette.github.io/2016/11/01/anim_compression_accuracy/). The local space metric is used classically to reject key removal beyond some error threshold. On the other hand, they check the impacted end effector (e.g. leaf) bones that are children of a given track. To do so a virtual vertex is used but no attempt is made to ensure it isn’t co-linear with the rotation axis. Bones in between the two bones (the one being modified and the leaf) are not checked at all and should they end up with unacceptable error, it will be invisible and not accounted for by the metric.

There is also a bias applied on tracks to attempt to remove similar keys on children and their parent bone tracks. I’m not entirely certain why they would opt to do this but I doubt it can harm the results.

On the decompression side no cursor or acceleration structure is used; meaning that each time we sample the clip we will need to search for which keys to interpolate between and we do so per track.

Note that this compression setting also removes the [trivial keys](http://nfrechette.github.io/2017/01/11/anim_compression_unreal4/#trivial_keys).

## <a name="compress_independently"></a>Compress each track independently
>  Keyframe reduction algorithm that removes keys which are linear interpolations of surrounding keys, as well as choosing the best bitwise compression for each track independently.

This compression setting combines the [linear key reduction](http://nfrechette.github.io/2016/12/07/anim_compression_key_reduction/) algorithm along with the [simple quantization](http://nfrechette.github.io/2016/11/15/anim_compression_quantization/) bitwise compression algorithm.

It uses various custom [error metrics](http://nfrechette.github.io/2016/11/01/anim_compression_accuracy/) which appear local in nature with some adaptive bias. Each encoding format will be tested for each track and the best result will be used based on the desired error threshold.

## <a name="automatic_setting"></a>Automatic
>  Animation compression algorithm that is just a shell for trying the range of other compression schemes and picking the smallest result within a configurable error threshold.

A large mix of the previously mentioned algorithms are tested internally. In particular, various mixes of [sub-sampling](http://nfrechette.github.io/2016/11/17/anim_compression_sub_sampling/) are tested along with [linear key reduction](http://nfrechette.github.io/2016/12/07/anim_compression_key_reduction/) and [simple quantization](http://nfrechette.github.io/2016/11/15/anim_compression_quantization/). The best result is selected given a specific error threshold. This is likely to be somewhat slow due to the large number of variations tested (**35** at the time of writing!).

# Conclusion
In memory, every compression setting has a layout that is naive with the data sorted by tracks followed by keys. This means that during decompression each track will incur a cache miss to read the compressed value.

Performance wise, decompression times are likely to be high in [Unreal 4](https://en.wikipedia.org/wiki/Unreal_Engine#Unreal_Engine_4) in large part due to the memory layout not being cache friendly and the lack of an acceleration structure such as a cursor when linear key reduction is used; and it is likely used often with the *Automatic* setting. This is an obvious area where it could improve.

Memory wise, the linear key reduction algorithm should be fairly conservative but it could be minimally improved by ditching the local space [error metric](http://nfrechette.github.io/2016/11/01/anim_compression_accuracy/). Coupled with the bitwise compression it should yield a reasonable memory footprint; although it could be further improved by using more [advanced quantization]({% post_url 2017-03-12-anim_compression_advanced_quantization %}) techniques.

[Up next: Unity 5]({% post_url 2017-01-30-anim_compression_unity5 %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})
