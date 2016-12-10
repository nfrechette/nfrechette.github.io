---
layout: post
title: "Animation Compression: Table of Contents"
---
I am in the process of getting a presentation approved for the [GDC 2017](http://www.gdconf.com/) on the topic of character animation compression. While the topic is warm and fresh in my memory, I thought it would do me some good to take a break from [memory allocators]({% post_url 2016-10-18-memory_allocators_toc %}) and talk about the various approaches to this. I also happen to have some free time ahead of me before I find and start my next contract.

While I will not be able to cover the presentation content prior to the conference (if it is approved), I will cover as much material as I can while leading up to it and eventually it will make its way on here.

This post is meant as a table of content that will link to all the relevant topics I will cover. It will be updated as time goes by and as material is published.

I will do my best to keep this series of posts self contained and detailed enough to be approachable to a wide audience. The amount of material out there regarding animation compression is surprisingly very thin or often poorly detailed. My hope is for this series to serve as a reference for anyone curious about this topic and looking at improving or implementing these techniques.

If time permits, and if I can get approval from various relevant parties, I might go ahead and implement some of these techniques into an actual production ready library.

# Table of Content

* [Preface]({% post_url 2016-10-25-anim_compression_preface %})
* [Terminology]({% post_url 2016-10-26-anim_compression_terminology %})
* [Animation Data]({% post_url 2016-10-27-anim_compression_data %})
* [Measuring Compression Accuracy]({% post_url 2016-11-01-anim_compression_accuracy %})
* [Constant Tracks]({% post_url 2016-11-03-anim_compression_constant_tracks %})
* [Range Reduction]({% post_url 2016-11-09-anim_compression_range_reduction %})
* [Uniform Segmenting]({% post_url 2016-11-10-anim_compression_uniform_segmenting %})
* [Main Compression Families]({% post_url 2016-11-13-anim_compression_families %})
  * [Simple Quantization]({% post_url 2016-11-15-anim_compression_quantization %})
  * [Sub-sampling]({% post_url 2016-11-17-anim_compression_sub_sampling %})
  * [Linear Key Reduction]({% post_url 2016-12-07-anim_compression_key_reduction %})
  * [Curve Fitting]({% post_url 2016-12-10-anim_compression_curve_fitting %})
  * Signal Processing
* Error Compensation
* Case Studies
  * Unity 5
  * Unreal 4

