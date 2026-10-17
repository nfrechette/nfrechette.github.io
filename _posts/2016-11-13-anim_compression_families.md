---
layout: post
title: "Animation Compression: Main Compression Families"
---
Over the years, a number of techniques have emerged to address the problem of character animation compression. These can be roughly broken down into a handful of general families:

* [Simple Quantization]({% post_url 2016-11-15-anim_compression_quantization %}): Simply storing our key values on fewer bits
* [Advanced Quantization]({% post_url 2017-03-12-anim_compression_advanced_quantization %}): Super charge our simple quantization with a variable bit rate
* [Sub-sampling]({% post_url 2016-11-17-anim_compression_sub_sampling %}): Varying the sampling rate to reduce the number of key frames
* [Linear Key Reduction]({% post_url 2016-12-07-anim_compression_key_reduction %}): Removing keys that can be linearly interpolated from their neighbours
* [Curve Fitting]({% post_url 2016-12-10-anim_compression_curve_fitting %}): Calculating a curve that approximates our keys
* [Signal Processing]({% post_url 2016-12-19-anim_compression_signal_processing %}): Using [signal processing mathematical tools](https://en.wikipedia.org/wiki/Signal_processing) such as [PCA](https://en.wikipedia.org/wiki/Principal_component_analysis) and [Wavelets](https://en.wikipedia.org/wiki/Wavelet)

Note that [simple quantization]({% post_url 2016-11-15-anim_compression_quantization %}) and [sub-sampling]({% post_url 2016-11-17-anim_compression_sub_sampling %}) can be and often are used in tandem with the other three compression families although they can be used entirely on their own.

[Up next: Simple Quantization]({% post_url 2016-11-15-anim_compression_quantization %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

