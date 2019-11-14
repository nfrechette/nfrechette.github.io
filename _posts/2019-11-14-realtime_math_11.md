---
layout: post
title: "Realtime Math: faster than ever"
---

Today [Realtime Math](https://github.com/nfrechette/rtm) has finally reached [v1.1.0](https://github.com/nfrechette/rtm/releases/tag/v1.1.0)! This release brings a lot of good things:

*  Added support for Windows ARM64
*  Added support for VS2019, GCC9, clang7, and Xcode 11
*  Added support for Intel FMA and ARM64 FMA
*  Many optimizations, minor fixes, and cleanup

I spent a great deal of time optimizing the quaternion arithmetic for NEON and SSE and as a result, many functions are now among the fastest out there. In order to make sure not to introduce regressions, the [Google Benchmark](https://github.com/google/benchmark) library has been integrated and allows me to quickly whip up tests to try various ideas and variants.

RTM will be used in the upcoming [Animation Compression Library](https://github.com/nfrechette/acl) release for the new scalar track compression API. The subsequent ACL release will remove all of its internal math code and switch everything to RTM. Preliminary tests show that it speeds up its compression by about 10%.

## Is Intel FMA worth it?

As part of this release, [support for AVX2 and FMA was added](https://github.com/nfrechette/rtm/issues/21). Seeing how libraries like [DirectX Math](https://github.com/Microsoft/DirectXMath) already use FMA, I expected it to give a measurable performance win. However, on my Haswell MacBook Pro and my Ryzen 2950X desktop, it turned out to be significantly slower. As a result of these findings, I opted to not use FMA (although the relevant defines are present and handled). If you are aware of a CPU where FMA is faster, please reach out!

It is also worth noting that typically when *Fast Math* type compiler optimizations are enabled, FMA instructions are often automatically generated when it detects a pattern where they can be used. RTM explicitly disables this behavior with Visual Studio (by forcing *Precise Math* with a pragma) and as such even when it is enabled, the functions retain the SSE/AVX instructions that showed the best performance.

## ARM NEON performance notes

RTM, DirectX Math, and many other libraries make extensive use NEON SIMD intrinsics. However, while measuring various implementation variants for quaternion multiplication I noticed that using simple scalar math is considerably faster on both ARMv7 and ARM64 on my Pixel 3 phone and my iPad. Going forward I will make sure to always measure the scalar code path as a baseline.

## Compiler bugs

Surprisingly, RTM triggered 3 compiler code generation bugs this year. [#34](https://github.com/nfrechette/rtm/issues/34) and [#35](https://github.com/nfrechette/rtm/issues/35) in VS2019 as well as [#37](https://github.com/nfrechette/rtm/issues/37) in clang7. As soon as those are fixed and validated by continuous integration, I will release a new version (minor or patch).

## What's next

The development of RTM is largely driven by my work with ACL. If you'd like to see specific things in the next release, feel free to reach out or to create GitHub issues and I will prioritize them accordingly. As always, contributions welcome!

Thanks to [GitHub Sponsors](https://github.com/sponsors), you can [sponsor me](https://github.com/sponsors/nfrechette)! All funds donated will go towards purchasing new devices to optimize for as well as other related costs (like coffee).
