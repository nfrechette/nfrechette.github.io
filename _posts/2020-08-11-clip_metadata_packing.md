---
layout: post
title: "Animation clip metadata packing"
---
In my [previous blog post]({% post_url 2020-08-09-animation_data_numbers %}), I analyzed over 15000 animations. This offered a number of key insights about what animation data looks like for compression purposes. If you haven't read it yet, I suggest you do so first as it covers the terminology and basics for this post. I'll also be using the same datasets as described in the previous post.

As mentioned, most clips are fairly short and the metadata we retain ends up having a disproportionate impact on the memory footprint. This is because long and short clips have the same amount of metadata everything else being equal.

## Packing range values

Each animated track has its samples normalized within the full range of motion for each clip. This ends up being stored as a minimum value and a range extent. Both are three full precision 32 bit floats. Reconstructing our original sample is done like this:

`sample = (normalized sample * range extent) + range minimum`

This is quick and efficient.

Originally, I decided to retain full precision here out of convenience and expediency during the original implementation. But for a while now, I've been wondering if perhaps we can quantize the range values as well on fewer bits. In particular, each sample is also normalized a second time within the range of motion of the segment it lies in and those per segment range values are quantized to 8 bits per component. This works great as range values do not need to be all that accurate. In fact, over two years ago I tried to quantize the segment range values on 16 bits instead to see if things would improve (accuracy or memory footprint) and to my surprise, the result was about the same. The larger metadata footprint did allow higher accuracy and fewer bits retained per animated sample but over a large dataset, the two canceled out.

In order to quantize our range values, we must first extract the total range: every sample from every track. This creates a sort of Axis Aligned Bounding Box for rotation, translation, and scale. Ideally we want to treat those separately since by their very nature, their accepted range of values can differ by quite a bit. For translation and scale, things are a bit complicated as some tracks require full precision and the range can be very dynamic from track to track. In order to test out this optimization idea, I opted to try with rotations first. Rotations are much easier to handle since quaternions have their components already normalized within `[-1.0, 1.0]`. I went ahead and quantized each component to 8 bits with padding to maintain the alignment. Instead of storing 6x float32 (24 bytes), we are storing 8x uint8 (8 bytes). This represents a 3x reduction in size.

Here are the results:

| CMU                                       | Before    | After     |
| ----------------------------------------- | --------- | --------- |
| Compressed size                           | 70.61 MB  | 70.08 MB  |
| Compressed size 50th percentile           | 15.35 KB  | 15.20 KB  |
| Compression ratio                         | 20.24 : 1 | 20.40 : 1 |
| Max error                                 | 0.0725 cm | 0.0741 cm |
| Track error 99th percentile               | 0.0089 cm | 0.0089 cm |
| Error threshold percentile rank (0.01 cm) | 99.86 %   | 99.86 %   |

| Paragon                                   | Before    | After     |
| ----------------------------------------- | --------- | --------- |
| Compressed size                           | 208.04 MB | 205.92 MB |
| Compressed size 50th percentile           | 15.83 KB  | 15.12 KB  |
| Compression ratio                         | 20.55 : 1 | 20.77 : 1 |
| Max error                                 | 2.8824 cm | 3.5543 cm |
| Track error 99th percentile               | 0.0099 cm | 0.0111 cm |
| Error threshold percentile rank (0.01 cm) | 99.04 %   | 98.89 %   |

| Fortnite                                  | Before    | After     |
| ----------------------------------------- | --------- | --------- |
| Compressed size                           | 482.65 MB | 500.95 MB |
| Compressed size 50th percentile           | 9.69 KB   | 9.65 KB   |
| Compression ratio                         | 36.72 : 1 | 35.38 : 1 |
| Max error                                 | 69.375 cm | 69.375 cm |
| Track error 99th percentile               | 0.0316 cm | 0.0319 cm |
| Error threshold percentile rank (0.01 cm) | 97.69 %   | 97.62 %   |

At first glance, it appears a small net win with CMU and Paragon but then everything goes downhill with Fortnite. Even though all three datasets see a win in the compressed size for 50% of their clips, the end result is a significant net loss for Fortnite. The accuracy is otherwise slightly lower. As I've [mentioned before]({% post_url 2017-09-10-acl_v0.4.0 %}), the max error although interesting can be very misleading.

It is clear that for some clips this is a win, but not always nor overall. Due to the added complexity and the small gain for CMU and Paragon, I've opted not to enable this optimization nor push further at this time. It requires more nuance to get it right but it is regardless worth revisiting at some point in the future. In particular, I want to wait until I have rewritten how constant tracks are identified. Nearly every animation compression implementation out there that detects constant tracks (ACL included) does so by using a local space error threshold. This means that it ignores the object space error that it contributes to. In turn, this sometimes causes undesirable artifacts in very exotic cases where a track needs to be animated below the threshold where it is detected to be constant. I plan to handle this more holistically by integrating it as part of the global optimization algorithm: a track will be constant for the clip only if it contributes an acceptable error in object space.


## Packing constant samples

Building on the previous range packing work, we can also use the same trick to quantize our constant track samples. Here however, 8 bits is too little so I quantized the constant rotation components to 16 bits. Instead of storing 3x float32 (12 bytes) for each constant rotation sample, we'll be storing 4x uint16 (8 bytes): a 1.33x reduction in size.

*Before results contain packed range values as described above.*

| CMU                                       | Before    | After     |
| ----------------------------------------- | --------- | --------- |
| Compressed size                           | 70.08 MB  | 72.54 MB  |
| Compressed size 50th percentile           | 15.20 KB  | 15.72 KB  |
| Compression ratio                         | 20.40 : 1 | 19.70 : 1 |
| Max error                                 | 0.0741 cm | 0.0734 cm |
| Track error 99th percentile               | 0.0089 cm | 0.0097 cm |
| Error threshold percentile rank (0.01 cm) | 99.86 %   | 99.38 %   |

| Paragon                                   | Before    | After     |
| ----------------------------------------- | --------- | --------- |
| Compressed size                           | 205.92 MB | 213.17 MB |
| Compressed size 50th percentile           | 15.12 KB  | 15.43 KB  |
| Compression ratio                         | 20.77 : 1 | 20.06 : 1 |
| Max error                                 | 3.5543 cm | 5.8224 cm |
| Track error 99th percentile               | 0.0111 cm | 0.0344 cm |
| Error threshold percentile rank (0.01 cm) | 98.89 %   | 96.84 %   |

| Fortnite                                  | Before    | After        |
| ----------------------------------------- | --------- | ------------ |
| Compressed size                           | 500.95 MB | 663.01 MB    |
| Compressed size 50th percentile           | 9.65 KB   | 9.83 KB      |
| Compression ratio                         | 35.38 : 1 | 26.73 : 1    |
| Max error                                 | 69.375 cm | 5537580.0 cm |
| Track error 99th percentile               | 0.0319 cm | 0.9272 cm    |
| Error threshold percentile rank (0.01 cm) | 97.62 %   | 88.53 %      |

Even though our clip metadata size does reduce considerably, overall it yields a significant net loss. The reduced accuracy forces animated samples to retain more bits. It seems that lossless compression techniques might work better here although it would still be quite hard since each constant sample is disjoint: there is little redundancy to take advantage of.

With constant rotation tracks, the quaternion W component is dropped just like for animated samples. I also tried to retain the W component with full precision along with the other three. The idea being that if reducing accuracy increases the footprint, would increasing the accuracy reduce it? Sadly, it doesn't. The memory footprint ended up being marginally higher. It seems like the sweet spot is to drop one of the quaternion components.

## Is there any hope left?

Although both of these optimizations turned out to be failures, I thought it best to document them here anyway. With each idea I try, whether it pans out or not I learn more about the domain and I grow wiser.

There still remains opportunities to optimize the clip metadata but they require a bit more engineering to test out. For one, many animation clips will have constant tracks in common. For example, if the same character is animated in many different ways over several animations, each of them might find that many sub-tracks are not animated. In particular, translation is rarely animated but very often constant as it often holds the bind pose. To better optimize these, animation clips must be compressed as a whole in a database of sorts. It gives us the opportunity to identity redundancies across many clips.

In a few weeks I'll begin implementing animation streaming and to do so I'll need to create such a database. This will open the door to these kind of optimizations. Stay tuned!

[Animation Compression Table of Contents]({% post_url 2016-10-21-anim_compression_toc %})
