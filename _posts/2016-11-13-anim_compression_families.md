---
layout: post
title: "Animation Compression: Main Compression Families"
---
Over the years, a number of techniques have emerged to address the problem of character animation compression. These can be roughly broken down into five general families:

*  [Simple Quantization]({% post_url 2016-11-15-anim_compression_quantization %}): Simply storing our key values on fewer bits
*  [Sub-sampling]({% post_url 2016-11-17-anim_compression_sub_sampling %}): Varying the sampling rate to reduce the number of key frames
*  Linear Key Reduction: Removing keys that can be linearly interpolated from their neighbours
*  Curve Fitting: Calculating a curve that approximates our keys
*  Signal Processing: Using [signal processing mathematical tools](https://en.wikipedia.org/wiki/Signal_processing) such as [PCA](https://en.wikipedia.org/wiki/Principal_component_analysis) and [Wavelets](https://en.wikipedia.org/wiki/Wavelet)

Note that simple quantization and sub-sampling can be and often are used in tandem with the other three compression families although they can be used entirely on their own.

[Up next: Simple Quantization]({% post_url 2016-11-15-anim_compression_quantization %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

