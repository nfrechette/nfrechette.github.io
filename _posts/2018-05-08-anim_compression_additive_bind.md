---
layout: post
title: "How much does additive bind pose help?"
---
A common trick when compressing an animation clip is to store it relative to the bind pose. The conventional wisdom is that this allows to [reduce the range of motion]({% post_url 2016-11-09-anim_compression_range_reduction %}) of many bones, increasing the accuracy and the likelihood that constant bones will turn into the identity, and thus allowing a lower memory footprint as a result. I have implemented this specific feature many times in the past and the results were consistent: a memory reduction of **3-5%** was generally observed.

Now that the [Animation Compression Library](https://github.com/nfrechette/acl) supports additive animation clips, I thought it would be a good idea to test this claim once more.

## How it works

The concept is very simple to implement:

*  Before compression happens, the bind pose is removed from the clip by subtracting it from every key.
*  Then, the clip is compressed as usual.
*  Finally, after we decompress a pose, we simply add back the bind pose.

The transformation is lossless aside from whatever loss happens as a result of floating point precision. It has two primary side effects.

The first is that bone translations end up having a much shorter range of motion. For example, a walking character might have the pelvic bone about **60cm** up from the ground (and root bone). The range of motion will thus circle around this large value for the whole track. Removing the bind pose brings the track closer to zero since the bind pose value of that bone is likely very near **60cm**. Smaller floating point values generally retain higher accuracy. The principle is identical to normalizing a track within its range.

The second impacts constant tracks. If the pelvic bone is not animated in a clip, it will retain some constant value. This value is often the bind pose itself. When this happens, removing the bind pose yields the identity rotation and translation. Since these values are trivial to reconstruct at runtime, instead of having to store the constant floating point values, we can store a simple bit set.

As a result, hand animated clips with the bind pose removed often find themselves with a lower memory footprint following compression.

Mathematically speaking, how the bind pose is added or removed can be done in a number of ways, much like additive animation clips. While additive animation clips heavily depend on the animation runtime, ACL now supports [three variants](https://github.com/nfrechette/acl/blob/develop/docs/additive_clips.md):

*  Relative space
*  Additive space 0
*  Additive space 1

*The last two names are not very creative or descriptive... Suggestions welcome!*

## Relative space

In this space, the clip is reconstructed by multiplying the bind pose with a normal `transform_mul` operation. For example, this is the same operation used to convert from local space to object space. Performance wise, this is the slowest: to reconstruct our value we end up having to perform **3** quaternion multiplications and if negative scale is present in the clip, it is even slower (extra code not shown below, see [here](https://github.com/nfrechette/acl/blob/develop/includes/acl/math/transform_32.h)).

```c++
Transform transform_mul(const Transform& lhs, const Transform& rhs)
{
	Quat rotation = quat_mul(lhs.rotation, rhs.rotation);
	Vector4 translation = vector_add(quat_rotate(rhs.rotation, vector_mul(lhs.translation, rhs.scale)), rhs.translation);
	return transform_set(rotation, translation, scale);
}
```

## Additive space 0

This is the first of the two classic additive spaces. It simply multiplies the rotations, it adds the translations, and multiplies the scales. The animation runtime [ozz-animation](http://guillaumeblanc.github.io/ozz-animation/) uses this format. Performance wise, this is the fastest implementation.

```c++
Transform transform_add0(const Transform& base, const Transform& additive)
{
	Quat rotation = quat_mul(additive.rotation, base.rotation);
	Vector4 translation = vector_add(additive.translation, base.translation);
	Vector4 scale = vector_mul(additive.scale, base.scale);
	return transform_set(rotation, translation, scale);
}
```

## Additive space 1

This last additive space combines the base pose in the same way as the previous except for the scale component. This is the format used by Unreal 4. Performance wise, it is very close to the previous space but requires an extra instruction or two.

```c++
Transform transform_add1(const Transform& base, const Transform& additive)
{
	Quat rotation = quat_mul(additive.rotation, base.rotation);
	Vector4 translation = vector_add(additive.translation, base.translation);
	Vector4 scale = vector_mul(vector_add(vector_set(1.0f), additive.scale), base.scale);
	return transform_set(rotation, translation, scale);
}
```

It is worth noting that because these two additive spaces differ only by how they handle scale, if the animation clip has none, both methods will yield identical results.

## Results

Measuring the impact is simple: I simply enabled all three modes one by one and compressed all of the [Carnegie-Mellon University](https://github.com/nfrechette/acl/blob/develop/docs/cmu_performance.md) motion capture database as well as all of the [Paragon](https://github.com/nfrechette/acl/blob/develop/docs/paragon_performance.md) data set. Decompression performance was not measured on its own but the compression time will serve as a hint as to how it would perform.

Everything has been measured with my desktop using *Visual Studio 2015* with *AVX* support enabled with up to **4** clips being compressed in parallel. All measurements were performed with the upcoming *ACL v0.8* release.

![CMU Results](/public/acl/acl_cmu_bind_additive_results.png)

CMU has no scale and it is thus no surprise that the two additive formats perform the same. The memory footprint and the max error remain overall largely identical but as expected the compression time degrades. No gain is observed from this technique which further highlights how this data set differs from hand authored animations.

![Paragon Results](/public/acl/acl_paragon_bind_additive_results.png)

Paragon shows the results I was expecting. The memory footprint reduces by about **7.9%** which is quite significant and the max error improves as well. Again, we can see both additive methods performing equally well. The relative space clearly loses out here and fails to show significant gains to compensate for the dramatically worse compression performance.

## Conclusion

Overall it seems clear that any potential gains from this technique are heavily data dependent. A nearly **8%** smaller memory footprint is nothing to spit at but in the grand scheme of things, it might no longer be worth it in 2018 when decompression performance is likely much more important, especially on mobile devices. It is not immediately clear to me if the reduction in memory footprint could save enough to translate into fewer cache lines being fetched but even so it seems unlikely that it would offset the extra cost of the math involved.

See also the related [bind pose stripping]({% post_url 2022-01-23-anim_compression_bind_pose_stripping %}) optimization.

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})
