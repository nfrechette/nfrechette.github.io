---
layout: post
title: "Animation Compression: Measuring Accuracy"
---
How we measure our compression accuracy is critically important. Since all the compression algorithms we will cover are lossy in nature, how we measure the deviation from the source data needs to be representative of the visual difference we might observe.

It is also important to allow us to compare our algorithms against each other. You might be surprised to learn that a lot of academic papers on this topic use varying error metrics making any meaningful comparison quite hard.

Our error measuring function needs to satisfy a small number of important properties:

* We need to take into account the hierarchical nature our data since the error will accumulate down the hierarchy when using local space transforms
* We need to account for the error in all three tracks for every bone
* We need to account for the fact that the visual mesh almost never overlaps with the skeleton and the further away a vertex is from its bone, the larger the error will end up being

# Object Space vs Local Space

For compression reasons, our transforms are usually stored in local space. Local space is also often used when blending poses at runtime as such it is the most common format. However, due to the hierarchical nature, a small error on a parent bone could end up causing a much larger error on a child bone further down. For this reason, the error is best measured in object space.

Surprisingly, it is quite common for compression algorithms to use local space instead to measure error. Very often, this is how the error is measured with linear key reduction and curve fitting algorithms.

# Approximating the Visual Error

Since our skeleton is generally never directly visible, any error will be visible on the visual mesh instead. This means the most accurate way to measure any error would be to perform skinning for every key frame and comparing every vertex before and after compression.

Sadly, this would be terribly slow even with help from the GPU in many instances.

Instead, we can use virtual or fake vertices at a fixed distance from each bone. This is both intuitive and easy to achieve: for every object space bone transform, we simply apply the transform to a local vertex position. For example, I can use a vertex in local space of a bone at a fixed offset of say 10cm, and by applying the object space bone transform, my vertex will end up in object space. This step is done both with the source animation and the compressed animation and we can then compare the distance between the two transformed vertices to measure our error.

Note that we need to use two virtual vertices per bone and they must be orthogonal to each-other. Otherwise, if our single vertex happens to be co-linear with the bone rotation axis, the error could end up being less visible or entirely invisible. For this reason, two vertices are used and the maximum error delta can be used. In practice, you would use something like `vec3(0, 0, distance)` and `vec3(0, distance, 0)`.

This properly takes into account all three bone tracks and it approximately takes into account the fact that the visual mesh is always some distance away from the skeleton.

Which virtual distance you use is important: if it is much smaller than the distance of real vertices, the error might end up being visible (since error increases with distance for rotation and scale), and if the distance is much larger, we might end up retaining more accuracy than we otherwise need.

For most character bones, a distance in the range of 2-10cm makes sense. Special bones such as the root and camera might require higher accuracy and as such should probably use a higher distance in the range of 1-10m.

It is also common for certain large animated objects to have distances larger than 1-10m between a vertex and the bone it is skinned on. As such these objects either need extra bones added to reduce that maximum distance or the virtual distance needs to be adjusted correspondingly.

Note that you could probably extract the furthest skinned vertex per bone from the visual mesh and use that instead but do keep in mind some bones might not have skinned vertices such as the root and camera bones.

# Conclusion

Our accuracy is tweaked with a single intuitive number (the virtual vertex distance) and it is measured with a single simple value: an object space distance. These are generally easy to understand and reason about.

Both Unity and Unreal measure accuracy in ways that are sub-optimal and fail to take into account all three properties we outlined above. From what I have seen, their techniques are also representative of a lot of game engines out there. Future posts will explore the solutions those game engines provide.

A number of compression algorithms will use the error metric function to attempt to converge to a solution (e.g. linear key reduction). As such, if the metric is imprecise or poorly represents the true error, it is very likely that the end result will be poor. And indeed, in my experience, many linear key reduction algorithms out there use a local space error metric which can and sometimes leads to important keys being removed where the error accrued on the distant children is unacceptable (e.g. a pelvis key being removed can translate into a large error at the fingertip). The typical way to combat this side-effect is to tweak the local error metric such that it becomes even more conservative and ends up retaining the desired key. This translates directly in the memory footprint increasing.

Up next: Constant Tracks

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

