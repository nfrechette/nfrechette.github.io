---
layout: post
title: "Animation Compression: Constant Tracks"
---
One of the primary advantage of storing bone transforms in local space as opposed to object space is that it reduces dramatically the amount of data that changes. For example, if we have two bones connected, and they have their local rotation animated, we end up with two animated tracks in local space, but three tracks in object space. This is true because the rotation changes from the root bone will cause a translation offset on the second bone.

It is also the case that many bones are never animated by a majority of clips. For example, inverse kinematic (IK) bones are only ever animated when they are required (e.g. object pick up) and facial bones are typically used by cinematic clips or overlay clips. When bones aren’t animated, they will be by definition constant in our raw data.

Consequently, it is often the case that tracks are constant. In general, character animations end up animating many more rotation tracks than they do for translation or scale. As such, translation and scale tracks often end up entirely constant in a clip. Taking advantage of this can be done in one of two ways:

* Implicitly: linear key reduction will typically reduce such tracks to two keys since everything else can be interpolated (curve fitting and wavelet benefit similarly from this)
* Explicitly: by using a bit set that marks tracks as constant or variable

Typically, using a bit set and explicitly dropping constant tracks is the superior method to reduce the memory footprint but it does add a bit more complexity to the decompression algorithm. It is entirely worth it in my opinion.

Constant tracks will come in two forms:

* Constant and equal to the default track value (typically equal to the bind pose or identity)
* Constant and equal to some arbitrary track value

For obvious reasons, these tracks compress very well. In the first case, we only need to store a single bit per track. If a track is constant, we easily know which value it should have based on the track type (rotation, translation, or scale). In the second case, in addition to our single bit per track, we also need to store our single repeated key value. This single key can be stored raw since its memory footprint overall will remain small regardless or you can quantize it on fewer bits.

*My GDC presentation will include real numbers on the frequency of constant bones, constant tracks, and constant track components from a modern untitled AAA video game but I cannot include them here just yet.*

In my experience, the number of constant tracks is closely correlated by the number of constant track components (e.g. a constant scale track is equivalent to three constant scale track components). As such any extra gains we might have from using a bit set per track component (instead of per track) is likely to be offset by the larger bit set size and the extra complexity will likely make decompression slower.

[See also Animation Data in Numbers]({ post_url 2020-08-09-animation_data_numbers })

[Up next: Range Reduction]({% post_url 2016-11-09-anim_compression_range_reduction %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

