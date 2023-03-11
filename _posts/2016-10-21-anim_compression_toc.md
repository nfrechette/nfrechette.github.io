---
layout: post
title: "Animation Compression: Table of Contents"
toc: "Animation Compression"
---
Character animation compression is an exotic topic that seems to need to be re-approached only about once per decade. Over the course of 2016 I've been developing a novel twist to an older technique and I was lucky enough to be invited to talk about it at the [2017 Game Developers Conference (GDC)](http://www.gdconf.com/). This gave me the sufficient motivation to write this series.

The amount of material available regarding animation compression is surprisingly thin and often poorly detailed. My hope for this series is to serve as a reference for anyone looking to improve upon or implement efficient character animation compression techniques.

Each post is self-contained and detailed enough to be approachable to a wide audience.

## Table of Contents

*   [Preface]({% post_url 2016-10-25-anim_compression_preface %})
*   [Terminology]({% post_url 2016-10-26-anim_compression_terminology %})
*   [Animation Data]({% post_url 2016-10-27-anim_compression_data %})
    *   [Animation Data in Numbers]({% post_url 2020-08-09-animation_data_numbers %})
*   Measuring Compression Accuracy
    *   [Simulating mesh skinning]({% post_url 2016-11-01-anim_compression_accuracy %})
    *   [Dominance based error estimation]({% post_url 2023-02-26-dominance_based_error_estimation %})
*   [Constant Tracks]({% post_url 2016-11-03-anim_compression_constant_tracks %})
*   [Range Reduction]({% post_url 2016-11-09-anim_compression_range_reduction %})
*   [Uniform Segmenting]({% post_url 2016-11-10-anim_compression_uniform_segmenting %})
*   [Main Compression Families]({% post_url 2016-11-13-anim_compression_families %})
    *   [Simple Quantization]({% post_url 2016-11-15-anim_compression_quantization %})
    *   [Advanced Quantization]({% post_url 2017-03-12-anim_compression_advanced_quantization %})
    *   [Sub-sampling]({% post_url 2016-11-17-anim_compression_sub_sampling %})
    *   [Linear Sample Reduction]({% post_url 2016-12-07-anim_compression_key_reduction %})
        *   [Pitfalls of linear sample reduction: Part 1]({% post_url 2019-07-23-pitfalls_linear_reduction_part1 %})
        *   [Pitfalls of linear sample reduction: Part 2]({% post_url 2019-07-25-pitfalls_linear_reduction_part2 %})
        *   [Pitfalls of linear sample reduction: Part 3]({% post_url 2019-07-29-pitfalls_linear_reduction_part3 %})
        *   [Pitfalls of linear sample reduction: Part 4]({% post_url 2019-07-31-pitfalls_linear_reduction_part4 %})
    *   [Curve Fitting]({% post_url 2016-12-10-anim_compression_curve_fitting %})
    *   [Signal Processing]({% post_url 2016-12-19-anim_compression_signal_processing %})
*   [Error Compensation]({% post_url 2016-12-22-anim_compression_error_compensation %})
*   Bind Pose Optimizations
    *   [Bind Pose Additive]({% post_url 2018-05-08-anim_compression_additive_bind %})
    *   [Bind Pose Stripping]({% post_url 2022-01-23-anim_compression_bind_pose_stripping %})
*   [Clip metadata packing]({% post_url 2020-08-11-clip_metadata_packing %})
*   [Morph Target Animation Compression]({% post_url 2020-05-04-morph_target_compresion %})
*   [Progressive Animation Streaming]({% post_url 2021-01-17-progressive_animation_streaming %})
*   [Compressing looping animations]({% post_url 2022-04-03-anim_compression_looping %})
*   [Manipulating the sampling time for fun and profit]({% post_url 2022-06-05-anim_compression_rounding_time %})
*   [Case Studies]({% post_url 2016-12-23-anim_compression_case_studies %})
    *   [Unreal 4]({% post_url 2017-01-11-anim_compression_unreal4 %})
    *   [Unity 5]({% post_url 2017-01-30-anim_compression_unity5 %})
*   [GDC 2017 Presentation]({% post_url 2017-03-08-anim_compression_gdc2017 %})

## ACL: An open source solution

My answer to the lack of open source implementations of the above algorithms and topics has prompted me to start my own. See all the code and much more over on GitHub for the [Animation Compression Library](https://github.com/nfrechette/acl) as well as its *Unreal Engine* [plugin](https://github.com/nfrechette/acl-ue4-plugin)!
