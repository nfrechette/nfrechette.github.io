---
layout: post
title: "Animation Compression: Uniform Segmenting"
---
Uniform segmenting is performed by splitting a clip into a number of blocks of equal or approximately equal size. This is done for a number of reasons.

# Range Reduction

Splitting large clips (such as cinematics) into smaller blocks allows us to use [range reduction]({% post_url 2016-11-09-anim_compression_range_reduction %}) on each track within a block. This can often help reach higher levels of compression especially on longer clips. This is typically done on top of the clip range reduction to further increase our compression accuracy.

# Easier Seeking

For some compression algorithms, seeking is slow because it involves searching for the keys or control points surrounding the particular time `T` we are trying to sample. Techniques exist to speed this up by using optimal sorting but it adds complexity. With blocks sufficiently small (e.g. 16 key frames), optimal sorting might not be required nor the usage of a cursor (cursors are used by these algorithms to keep track of the last sampling performed to accelerate the search of the next sampling). See the posts about [linear key reduction]({% post_url 2016-12-07-anim_compression_key_reduction %}) and [curve fitting]({% post_url 2016-12-10-anim_compression_curve_fitting %}) for details.

With uniform segmenting, finding which blocks we need is very fast in large part because there are typically few blocks for most clips.

# Streaming and [TLB](https://en.wikipedia.org/wiki/Translation_lookaside_buffer) Friendly

The easier seeking also means the clips are much easier to stream. Everything you need to sample a number of key frames is bundled together into a single contiguous block. This makes it easy to cache them or prefetch them during playback.

For similar reasons, this makes our clip data more TLB friendly. All our relevant data needed for a number of key frames will use the same contiguous memory pages.

# Required For Wavelets

Wavelet functions typically work on data whose’s size is a power of two. Some form of padding is used to reach a power of two when the size doesn’t match. To avoid excessive padding, clips are split into uniform blocks. See the post about wavelet compression for details.

# Downsides

Segmenting a clip into blocks does add some amount of memory overhead:

* Each clip will now need to store a mapping of which block is where in memory.
* If [range reduction]({% post_url 2016-11-09-anim_compression_range_reduction %}) is done per block as well, each block now includes range information.
* Blocks might need a header with some flags or other relevant information.
* And for some compression algorithms such as [curve fitting]({% post_url 2016-12-10-anim_compression_curve_fitting %}), it might force us to insert extra control points or to retain more key frames.

However, the upsides are almost aways worth the hassle and overhead.

[Up next: Main Compression Families]({% post_url 2016-11-13-anim_compression_families %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

