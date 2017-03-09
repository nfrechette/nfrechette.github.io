---
layout: post
title: "Animation Compression: Unity 5"
---
[![Unity 5 Official Trailer](https://img.youtube.com/vi/AJ6Mkx1KEns/0.jpg)](https://www.youtube.com/watch?v=AJ6Mkx1KEns "Unity 5 Official Trailer")

[Unity 5](https://en.wikipedia.org/wiki/Unity_(game_engine)) is a very popular video game engine on mobile devices and other platforms. Being a state of the art game engine, it supports everything you might need when it comes to character animation including compression.

The relevant [FBX Importer](https://docs.unity3d.com/Manual/FBXImporter-Animations.html) and [Animation Clip](https://docs.unity3d.com/Manual/class-AnimationClip.html) documentation is very sparse. It’s worth mentioning that [Unity 5](https://en.wikipedia.org/wiki/Unity_(game_engine)) is a closed source software and as such, there is some amount of uncertainty and speculation. However, I was able to get in touch with an old colleague working at [Unity](https://en.wikipedia.org/wiki/Unity_(game_engine)) to clarify what happens under the hood.

Before we dig into what each compression setting does we must first briefly cover the data representations that [Unity 5](https://en.wikipedia.org/wiki/Unity_(game_engine)) uses internally.

# Track Data Encoding
The engine uses one of three encodings to represent an animation track regardless of the track data type (quaternion, vector, float, etc.):
*   [Legacy Curve](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#legacy_curve)
*   [Streaming Curve](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#streaming_curve)
*   [Dense Curve](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#dense_curve)

Rotation tracks are always encoded as four curves to represent a full quaternion (one curve per component). An obvious win here could be to instead encode rotations as quaternion logarithms or by dropping the quaternion **W** component or the largest component. This would of course immediately reduce the memory footprint for rotation tracks by **25%** at the expense of a few instructions to reconstruct the original quaternion.

## Legacy Curve
Legacy curves are a strange beast. The source data is sampled uniformly at a fixed interval such as **30 FPS** and is kept unsorted in full precision. Using discreet samples during decompression a [Hermite curve](https://en.wikipedia.org/wiki/Cubic_Hermite_spline) is constructed on the fly and interpolated. It is unclear to me how this format emerged but it has since been superseded by the other two and it is not frequently used.

It must have been quite slow to decompress and should probably be avoided.

## Streaming Curve
Streaming curves are proper curves that use [Hermite coefficients](https://en.wikipedia.org/wiki/Cubic_Hermite_spline). A track is split into intervals and each interval is encoded as a distinct spline. This allows discontinuities between intervals. For example, a camera cut or teleporting the root in a cinematic. Each interval has a small header of **8** bytes and each control point is stored in full floating point precision plus an index. This is likely overkill. Full floating point precision is typically far too much for encoding rotations and using [simple quantization](http://nfrechette.github.io/2016/11/15/anim_compression_quantization/) to store them on 16 bits per component or less could provide significant memory savings.

The resulting control points are sorted by time followed by track to render them as cache as efficient as possible which is a very good thing. At decompression, a cursor or cache is used to avoid repeatedly searching for our control points when playback is continuous and predictable. For these two reasons streaming curves are very fast to decompress in the average use case.

## Dense Curve
What [Unity 5](https://en.wikipedia.org/wiki/Unity_(game_engine)) calls a dense curve I would call a raw format. The original source data is sampled at a fixed interval such as **30 FPS** and nothing more is done to it as far as I am aware. The data is sorted to make it cache efficient by time and track. No [linear key reduction](http://nfrechette.github.io/2016/12/07/anim_compression_key_reduction/) is performed or attempted. The sampled values are not quantized and are simply stored with full precision.

Dense curves will typically have a smaller memory footprint than [streaming curves](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#streaming_curve) only for very short tracks or for tracks where the data is very noisy such as a motion capture. For this reason, they are unlikely to be used in practice.

Overall their implementation is simple but perhaps a bit naive. Using [simple quantization](http://nfrechette.github.io/2016/11/15/anim_compression_quantization/) would give significant memory gains here without degrading decompression performance and might even speed it up! On the upside decompression speed is very likely to be faster than with streaming curves.

# Compression Settings
At the time of writing, [Unity 5](https://en.wikipedia.org/wiki/Unity_(game_engine)) supports three compression settings:
*   [No Compression](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#no_compression)
*   [Keyframe Reduction](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#keyframe_reduction)
*   [Optimal](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#optimal)

## No Compression
The most detailed quote from the documentation about what this setting does is:

>  Disables animation compression. This means that Unity doesn’t reduce keyframe count on import, which leads to the highest precision animations, but slower performance and bigger file and runtime memory size. It is generally not advisable to use this option - if you need higher precision animation, you should enable keyframe reduction and lower allowed Animation Compression Error values instead.

From what I could gather the originally imported clip is sampled uniformly (e.g. **30 FPS**) and each track is converted into a [streaming curve](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#streaming_curve). This ensures everything remains smooth and accurate but the overhead can be very significant since all samples are retained. To make things worse nothing is done for constant tracks with this setting.

## Keyframe Reduction
The most detailed quote from the documentation is:

>  Removes redundant keyframes.

When this setting is used constant tracks will be collapsed to a single value and redundant control points in animated tracks which will be removed within the specified error threshold. This setting uses [streaming curves](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#streaming_curve) to represent track data.

Only three thresholds are exposed for this compression setting. One for each track type: rotation, translation, and scale. This is very likely to lead to the problems discussed in my post on [measuring accuracy](http://nfrechette.github.io/2016/11/01/anim_compression_accuracy/). And indeed, a quick search yields [this gem](https://forum.unity3d.com/threads/animation-cost-key-reducer.42841/). Even though it dates from [Unity 3(2010)](https://en.wikipedia.org/wiki/Unity_(game_engine)), I doubt the animation compression has changed much. Unfortunately, the problems it raises are both very telling and common with local space error metric functions. Here are some relevant excerpts:

>  Now, you may be asking yourself, why would this guy turn off the key reducer in the first place? The answer is simple. The key reducer sucks. Here’s why.
>
>  Every animation I have completed for this project uses planted keys to anchor the feet (and sometimes hands) to the floor. This allows me to grab any part of the body and animate it, knowing that the feet will not move. When I export the FBX, the keys stay intact. I can bring the animation back into Max or into Maya using the keyframe reducer for either software, and the feet remain anchored. When I bring the same FBX into Unity the feet slide around. Often quite noticably. The only way to stop the feet from sliding is to turn off the key reducer.

This is a very common problem with local space error functions. Tweaking them is hard! The end result is that very often a weaker compression or no compression at all is used when issues are found on a clip by clip basis. I have seen this exact behavior from animators working on [Unreal 3](https://en.wikipedia.org/wiki/Unreal_Engine#Unreal_Engine_3) back in the day and very recently in a proprietary AAA game engine. Even though from the user’s perspective the issue is the animation compression algorithm, in reality, the issue is almost entirely due to the error function.

>  What I would really like to see is some options within Unity’s animation importer. A couple ideas:
>
>  1) Max’s FBX keyframe reduction has several precision threshold settings that dictate how accurate the keyframe reduction should be. In Unity, it’s all or nothing. I would love the ability to adjust the threshold in which a keyframe gets added. I could turn up the sensitivity on some animations to reduce sliding and possibly turn it down on areas that need fewer keys than are given by the current value.
>
>  2) I’m not sure if this is possible, but it would be great to set keyframe reductions on some bones and not others. That way I can keep the arm chain in the proper location without having to bloat the keyframes of every bone in the whole skeleton.

Exposing a single error threshold per track type is very common and provides a source of frustration for animators. They often know which bones need higher accuracy but are unable to properly tweak per bone thresholds. Sadly, when this feature is present the settings often end up being copy & pasted with overly conservative values which yield a higher than needed memory footprint. Nobody has time to tweak a large number of thresholds repeatedly.

>  Unity 3 actually corrects the problem by giving us direct control over the keyframe reduction vs allowable error. If you find your animation is sliding to much, dial down the Position Error and/or Rotation Error settings in the animation import settings.
>
>  Unfortunately, I didn’t find any satisfying setup :/
>
>  I got some characters that move super fast in their anim, and I need the player to see the move correctly for gameplay / balance reasons.
>
>  So it can works for some anims, but not for others (making them feel like they are teleporting).
>
>  And under a certain reduction threshold, the memory size benefit is too small to resolve loading times problem :/
>
>  In fact, the only reduction setting I found that didn’t caused teleportations was :
>
>  Position : 0.1  
>  Rotation : 0.1  
>  Scale : 0 (as there is never any animated scale)
>
>  But this is still causing huge file sizes :(

A single error threshold per track type also means that the error threshold has to be as low as your most sensitive bone requires. This will, in turn, retain higher accuracy that might otherwise be needed yielding again a higher memory footprint that is often unacceptable.

## Optimal
The most detailed quote from the documentation is:

>  Let unity decide how to compress. Either by keyframe reduction or by using dense format. Unity will pick the most optimal of the two.

This is very vague and judging from [the results](http://answers.unity3d.com/questions/822418/what-are-the-differences-between-animation-compres.html) of a [quick search](http://answers.unity3d.com/questions/1180871/what-did-unitys-animation-compression-options-opti.html), a lot of people are curious.

Thankfully, I was able to get some answers!

If a track is very short or very noisy (which could happen with motion capture clips or baked simulations), the key reduction algorithm might not give appreciable gains and it is possible that a [dense curve](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#dense_curve) might end up having a smaller memory footprint than a [streaming curve](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#streaming_curve). When this happens for a particular track it will use the curve with the smallest memory footprint. As such, within a single clip, we can have a mix of [dense](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#dense_curve) and [streaming](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#streaming_curve) curves.

# Conclusion
The [Unity 5](https://en.wikipedia.org/wiki/Unity_(game_engine)) documentation is sparse and at times unclear. It leads to rampant speculation as to what might be going on under the hood and a lot of confusing results.

Its error function is poor, exposing a single value per track type. This leads to classic issues such as turning compression off to retain accuracy and using an overly conservative threshold to retain accuracy at the expense of the memory footprint. It perpetuates the stigma that animation compression can be painful to work with and can easily butcher an animator’s work without manual tweaking. Fixing the error function could be a reasonably simple task.

The optimal compression setting seems to be a very reasonable default value but it is not clear why the other two are exposed at all. Users are very likely to use one of the other settings instead of tweaking the error function thresholds which is probably a bad idea.

All curve types encode the data in full precision with **32-bit** floating point numbers. This is likely overkill in a very large number of scenarios and implementing some form of [simple quantization](http://nfrechette.github.io/2016/11/15/anim_compression_quantization/) could provide huge memory gains with little work and little effort. Due to the reduced memory footprint, decompression timings might even improve.

Furthermore, rotation tracks could be encoded in a better format than a full quaternion further reducing the memory footprint for minimal work.

From what I could find nobody seemed to complain about animation decompression performance at runtime. This is mostly likely a direct result of the cache friendly data format and the usage of a cursor for [streaming curves](http://nfrechette.github.io/2017/01/30/anim_compression_unity5/#streaming_curve).

[Up next: GDC 2017 Presentation]({% post_url 2017-03-08-anim_compression_gdc2017 %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})
