---
layout: post
title: "Animation Compression: Sub-sampling"
---
Once upon a time, sub-sampling was a very common compression technique but it is now mostly relegated to history books (and my boring blog!).

# How It Works

It is conceptually very simple:

*  Take your source data, either from Maya (3DS Max, etc.) or already sampled data at some sample rate
*  Sample (or re-sample) your data at a lower sample rate

Traditionally, character animations have a sample rate of 30 FPS. This means that for any given animated track, we end up with 30 keys per second of animation.

Sub-sampling works because in practice, most animations don’t move all that fast and a lower sampling rate is just fine and thus 15-20 FPS is generally good enough.

# Edge Cases

Now of course, this fails miserably if this assumption does not hold true or if a particular key is very important. It can often be the case that an important key is removed with this technique and there is sadly not much that can be done to avoid this issue short of selecting another sampling rate.

It is also worth mentioning that not all sampling rates are necessarily equal. If your source data is already discretized at some original sample rate, sampling rates that will retain whole keys are generally superior to sample rates that will force the generation of new keys by interpolating their neightbours.

For example, if my source animation track is sampled at 30 FPS, I have a key every `1s / 30 = 0.033s`. If I sub-sample it at 18 FPS, I have a key every `1s / 18 = 0.055s`. This means every key I need is not in sync with my original data and thus new keys must be generated. This will yield some loss of accuracy.

On the other hand, if I sub-sample at 15 FPS, I have a key every `1s / 15 = 0.066s`. This means every other key in my original data can be discarded and the remaining keys are identical to my original keys.

Another good example is sub-sampling at 20 FPS which will yield a key every `1s / 20 = 0.05s`. This means every 3rd key will be retained from the original data (**0.0** … 0.033 … 0.066 … **0.1** … 0.133 … 0.166 … **0.2** …). The other keys do not line up and will be artificially generated from our original neighbour keys.

The problem of keys not lining up is of course absent if your source animation data is not already discretized. If you have access to the Maya (or 3DS Max) curves, the sub-sampling will retain higher accuracy.

# In The Wild

In the wild, this used to be a very popular technique on older generation hardware such as the Xbox 360 and the PlayStation 3 (and older). It was very common to keep most of your main character animations with a high sample rate of say 30 FPS, while keeping most of your NPC animations at a lower sample rate of say 15 FPS. Any specific animation that required high accuracy would not be sub-sampled and this selection process was done by hand, making its usage somewhat error prone.

Due to its simplicity, it is also commonly used alongside other compression techniques (e.g. [linear key reduction]({% post_url 2016-12-07-anim_compression_key_reduction %})) to further reduce the memory footprint.

However, nowadays this technique is seldom used in large part because we aren’t as constrained by the memory footprint as we used to be and in part because we strive to push the animation quality ever higher.

[Up next: Linear Key Reduction]({% post_url 2016-12-07-anim_compression_key_reduction %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

