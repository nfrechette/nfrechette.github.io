---
layout: post
title: "Animation Compression: Animation Data"
---
Animation clips more or less always boil down to the same thing: a series of animated tracks. There might also be other pre-processed data (such as the total root displacement, etc.) but we won’t concern ourselves with this since their impact on compression is usually limited. Instead, we will focus on bone transform tracks: rotation, translation, and scale.

While we can represent all three tracks within a single affine 4x4 matrix, for compression purposes it is usually best to treat them separately. For one thing, a full column of the matrix doesn’t need to be compressed as it never changes and we can typically encode the rotation in a form much more compact than a 3x3 matrix.

# Rotation

Rotations in general can be represented by many forms and choosing an appropriate representation is important for reducing our memory footprint while maintaining high accuracy.

Common representations include:

* 3x3 matrix (9 float values)
  * wasteful, don’t use this for compression…
* quaternion (4 float values)
  * high accuracy, fast decompression, a bit larger than the others
* quaternion with dropped W component (3 float values)
  * W can be reconstructed with a square root, the quaternion can be flipped to keep it in the positive hemisphere
* quaternion with dropped largest component (3 float values + 2 bit)
  * similar to dropping W, but offers higher accuracy
* quaternion logarithm (3 float values)
  * this is equivalent to the rotation axis multiplied by the rotation angle around our axis
* axis & angle (4 float values)
  * a bit larger than most alternatives
* polar axis & angle (3 float values)
  * high accuracy but slower decompression
* Euler angles (3 float values)
  * best avoided due to [Gimbal lock](https://en.wikipedia.org/wiki/Gimbal_lock) issues near the poles if quaternions are expected at runtime

Which representation is best depends in large part on what the animation runtime uses internally for blending clips. There are three common formats used at runtime:

* 4x4 affine matrix
* quaternion
* quaternion logarithm

If the compressed format doesn’t match the runtime format, a conversion will be required and it has an associated cost (typically sin & cos are involved).

Some formats offer higher accuracy than others at an equal number of bits. A separate post will go further in depth about their various error/size metrics.

Generally speaking, the formats with 3 float values are a good starting point to build compression on. Which of them you use might not have a very dramatic impact on the resulting memory footprint but I could be wrong. Obviously, using a format with 4 floats or more will result in an increased memory footprint but beyond that, it might not matter all that much.

Rotations are often animated but their range of motion is typically fairly small in any given clip and the total range is bounded by the unit sphere (-PI/PI for angles, and -1/+1 for axis/quaternion components).

Because rotations work on the unit sphere, the error needs to be measured on the circumference traced by the associated children. For example, if I have an error of 1 degree on my parent bone rotation, the error at the position of a short child bone will be less than that of a longer child bone: the arc length formed by a 1 degree rotation depends on the sphere radius. This needs to be taken into account by our error measuring function as we will see later in a separate post.

# Translation

Translations are typically encoded as 3 floats. Translations are generally not animated except for a few bones such as the pelvis. They tend to be constant and often match the bind pose translation. Sadly, they are typically not bounded as some bones can be animated in world space (e.g. root bone in a cinematic) or they can move very far from their parent bone (e.g. camera).

They could also be encoded as an axis and a length (4 floats) and in its polar equivalent (3 floats). Whether the polar form is a better tradeoff or not, I cannot say at this time without measuring the impact on the accuracy, memory footprint, and decompression speed. It might not work out so great for very large translation values (e.g. world space).

# Scale

Scale is not common nor is it typical in character animation but it does turn up. For our purposes we will only consider non-uniform scaling with 3 floats but uniform scaling with a single float would be a natural extension.

Scale is very rarely animated and as such it will generally match the bind pose scale. Unfortunately, the range of possible values is unbounded with the minor exception that a scale of 0.0 is generally invalid.

Because the scale affects the rotation part of a 4x4 affine matrix, the same issues pertaining to the error are present.

Similar to translations, it might be possible to encode it in axis/length form but whether or not this is a good idea remains unclear to me at this time.

# The skeleton hierarchy

Due to its hierarchical nature, we can infer a number of properties about our data:

* In local space, bones higher up in the hierarchy contribute more to the overall error
* In local space, a parent bone and its children can be animated independently, leading to improved compression but reduced accuracy since any error will accumulate down the hierarchy
* In object space, if a parent is animated, all children will in turn be animated as well but this also means their error does not propagate

As we will see in a later post, these properties can be leveraged to reduce our overall error.

# Bone velocity

Generally, we will only compress sampled keys from our original source sequence and as such the velocity information is partially lost. However, it remains relevant for a number of reasons:

* High velocity sequences (or moments) will typically compress poorly and these are quite common when they come from an offline simulation (e.g. cloth or hair simulation) or motion capture (e.g. facial animation).
* Smooth and low velocity clips will generally compress best and thankfully these are also the most common. Most hand authored sequences will fall in this category.
* Most character animation sequences have low velocity motion for most bones (they move slowly and smoothly)
* Many bone tracks have no velocity due to the fact that they are constant and it is also common for bones to be animated only for certain parts of a clip

To properly adapt to these conditions, our compression algorithm needs to be adaptive in nature: it needs to use more bits when they are needed for high velocity moments, and use fewer bits when they aren’t needed. As we will see later, there are various techniques to tackle this.

[See also Animation Data in Numbers]({ post_url 2020-08-09-animation_data_numbers })

[Up next: Measuring Accuracy]({% post_url 2016-11-01-anim_compression_accuracy %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

