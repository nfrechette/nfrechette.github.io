---
layout: post
title: "Animation Compression: Table of Contents"
toc: "Animation Compression"
---
Character animation compression is an exotic topic that seems to need to be re-approached only about once per decade. Over the course of 2016 I've been developing a novel twist to an older technique and I was lucky enough to be invited to talk about it at the [2017 Game Developers Conference (GDC)](http://www.gdconf.com/). This gave me the sufficient motivation to write this series.

The amount of material available regarding animation compression is surprisingly thin and often poorly detailed. My hope for this series is to serve as a reference for anyone looking to improve upon or implement efficient character animation compression techniques.

Each post is self-contained and detailed enough to be approachable to a wide audience.

# Table of Contents

*   [Preface]({% post_url 2016-10-25-anim_compression_preface %})
*   [Terminology]({% post_url 2016-10-26-anim_compression_terminology %})
*   [Animation Data]({% post_url 2016-10-27-anim_compression_data %})
*   [Measuring Compression Accuracy]({% post_url 2016-11-01-anim_compression_accuracy %})
*   [Constant Tracks]({% post_url 2016-11-03-anim_compression_constant_tracks %})
*   [Range Reduction]({% post_url 2016-11-09-anim_compression_range_reduction %})
*   [Uniform Segmenting]({% post_url 2016-11-10-anim_compression_uniform_segmenting %})
*   [Main Compression Families]({% post_url 2016-11-13-anim_compression_families %})
    *   [Simple Quantization]({% post_url 2016-11-15-anim_compression_quantization %})
    *   [Advanced Quantization]({% post_url 2017-03-12-anim_compression_advanced_quantization %})
    *   [Sub-sampling]({% post_url 2016-11-17-anim_compression_sub_sampling %})
    *   [Linear Key Reduction]({% post_url 2016-12-07-anim_compression_key_reduction %})
    *   [Curve Fitting]({% post_url 2016-12-10-anim_compression_curve_fitting %})
    *   [Signal Processing]({% post_url 2016-12-19-anim_compression_signal_processing %})
*   [Error Compensation]({% post_url 2016-12-22-anim_compression_error_compensation %})
*   [Case Studies]({% post_url 2016-12-23-anim_compression_case_studies %})
    *   [Unreal 4]({% post_url 2017-01-11-anim_compression_unreal4 %})
    *   [Unity 5]({% post_url 2017-01-30-anim_compression_unity5 %})
*   [GDC 2017 Presentation]({% post_url 2017-03-08-anim_compression_gdc2017 %})

# ACL: An open source solution

My answer to the lack of open source implementations of the above algorithms and topics has prompted me to start my own.
See all the code and much more over on GitHub for the [Animation Compression Library](https://github.com/nfrechette/acl)!
