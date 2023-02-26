---
layout: post
title: "Animation Compression: Measuring Accuracy"
---
Every compression algorithm covered herein is lossy in nature, so how we measure accuracy is critically important. Measured deviation from source data needs to be representative of the visual differences observed.

It is also important to compare algorithms against each other. It is surprising to learn that many academic papers on this topic use varying error metrics making meaningful comparison quite difficult.

Error measuring needs to meet a number of important criteria:

*   Account for the hierarchical nature the data since errors accumulate down the hierarchy when using local space transforms
*   Account for errors in all three tracks for every bone
*   Account for the fact that visual mesh almost never overlaps with its skeleton and the further away a vertex is from its bone the larger the error will end up being

# Object Space vs Local Space
For compression reasons, transforms and blending poses are usually stored in local space. However, due to the hierarchical nature, a small error on a parent bone could end up causing a much larger error on a child’s bone further down. For this reason, errors are best measured in object space.

Surprisingly, it is quite common for compression algorithms to use local space instead. Error is measured using linear key reduction and curve fitting algorithms.

# Approximating the Visual Error
Since a skeleton is generally never directly visible errors are visible on the visual mesh instead. This means the most accurate way to measure errors is to perform skinning for every keyframe and comparing vertices before and after compression.

Sadly, this would be terribly slow even with help from the GPU in many instances.

Instead, we can use virtual or fake vertices at a fixed distance from each bone. This is both intuitive and easy to achieve: for every object space bone transform we simply apply the transform to a local vertex position. For example, a vertex in local space of a bone at a fixed offset of 10cm will end up in object space with the object space bone transform applied. This step is done with both the source animation and the compressed animation so we can compare the distance between the two transformed vertices to measure error.

For this to work we need to use two virtual vertices per bone and they must be orthogonal to each other. Otherwise, if our single vertex happens to be co-linear with the bone’s rotation axis, the error could end up being less visible or entirely invisible. For this reason, two vertices are used with the maximum error delta. In practice, we would use something like `vec3(0, 0, distance)` and `vec3(0, distance, 0)`.

This properly takes into account all three bone tracks and it approximately takes into account the fact that the visual mesh is always some distance away from the skeleton.

Which virtual distance you use is important. A virtual distance much smaller than the distance of real vertices the error might end up being visible since error increases with distance for rotation and scale. If the distance is much larger we might end up retaining more accuracy than we otherwise need.

For most character bones a distance in the range of 2-10cm makes sense. Special bones like the root and camera might require higher accuracy and as such should probably use a distance closer to 1-10m.

Large animated objects also occasionally benefit from vertex to bone distances of 1-10m and either need extra bones added to reduce maximum distance, or the virtual distance needs to be adjusted correspondingly.

It’s also worth mentioning that we could probably extract the furthest skinned vertex per bone from the visual mesh and use that instead but keep in mind some bones might not have skinned vertices such as the root and camera bones.

# Conclusion
Accuracy is modified using a single intuitive number, the virtual vertex distance and is measured with a single value, object space distance.

Both Unity and Unreal measure accuracy in ways that are sub-optimal and fail to take into account all three properties outlined above. From what I have seen their techniques are also representative of a lot of game engines out there. Future posts will explore the solutions those game engines provide.

A number of compression algorithms use the error metric function to attempt to converge on a solution like linear key reduction, for example. If metrics are imprecise or poorly represent true error it is very likely that will be reflected in the end result. Many linear key reduction algorithms use a local space error metric which sometimes leads to important keys being removed from distant children of the point of error. For example, a pelvis key being removed can translate into a large error at the fingertip. The typical way to combat this side-effect is to use overly conservative error thresholds but this translates directly in the memory footprint increasing.

See also: [Dominance based error estimation]({% post_url 2023-02-26-dominance_based_error_estimation %})

[Up next: Constant Tracks]({% post_url 2016-11-03-anim_compression_constant_tracks %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})
