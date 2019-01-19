---
layout: post
title: "Introducing Realtime Math v1.0"
---
Almost two years ago now, I began writing the [Animation Compression Library](https://github.com/nfrechette/acl). I set out to build it to be production quality which meant I needed a whole lot of optimized math. At the time, I took a look at the landscape of math libraries and I opted to roll out my own. It has served me well, propelling ACL to success with some of the [fastest compression and decompression](http://nfrechette.github.io/2018/09/08/acl_v1.1.0/) performance in the industry. I am now proud to announce that the code has been refactored out into its own open source library: [Realtime Math v1.0 (RTM)](https://github.com/nfrechette/rtm) (MIT license).

There were a few reasons that motivated the choice to move the code out on its own:

* A significant amount of the ACL Continuous Integration build time is compiling and running the math unit tests which slows things down a bit more than I'd like
* It decouples code that will benefit from being on its own
* I believe it has its place in the landscape of math libraries out there

In order to support that last point, I reviewed **9** other popular and usable math libraries for realtime applications. I looked at these with the lenses of my own needs and experience, your mileage may vary.

*Disclaimer: the list of reviewed libraries is in no way exhaustive but I believe it is representative. Note that Unreal Engine 4 is included for informational purposes as it isn't really usable on its own. Libraries are listed in no particular order and I tried to be as objective as possible. If you spot any inaccuracies, don't hesitate to reach out.*

The list: *Realtime Math, MathFu, vectorial, VectorialPlusPlus, C OpenGL Graphics Math (CGLM), OpenGL Graphics Math (GLM), Industrial Light & Magic Base (ILMBase), DirectX Math, and Unreal Engine 4*.

## TL;DR: How Realtime Math stands out

I believe *Realtime Math* stands out for a few reasons.

It is geared for high performance, deeply hot code. Most functions will end up inlined but the price to pay is an API that is a bit more verbose as a result of being C-style. When the need arises to use intrinsics, it gets out of the way and lets you do your thing. Only two libraries had what I would call optimal inlinability: *Realtime Math* and *DirectX Math*. Only those two libraries properly support the *__vectorcall* calling convention explicitly and only RTM handles GCC and Clang argument passing explicitly.

While it still needs a bit of love, quaternions are a first class citizen and it is the only standalone open source library I could find that supports QVV transforms (a rotation quaternion, a 3d scale vector, and a translation vector).

*Realtime Math* uses a coding style similar to the C++ standard library and feels clean and natural to read and write.

It consists entirely of C++11 headers, it runs almost everywhere, it supports 64 bit floating point arithmetic, and it sports a very permissive MIT license.

## License

ACL is open source and uses the MIT license. I am never keen on adding dependencies and if I really have to, I want a permissive license free of constraints.

| Library           | License               |
| ----------------- | --------------------- |
| Realtime Math     | MIT                   |
| MathFu            | Apache 2.0            |
| vectorial         | BSD 2-clause          |
| VectorialPlusPlus | BSD 2-clause          |
| CGLM              | MIT                   |
| GLM               | Modified MIT          |
| ILMBase           | Custom but permissive |
| DirectX Math      | MIT                   |
| Unreal Engine 4   | UE4 EULA              |

## Header only

For simplicity and ease of integration, I want ACL to be entirely made of C++11 headers. This also constrains any dependencies to the same requirement.

| Library           | Header Only        |
| ----------------- | ------------------ |
| Realtime Math     | Yes                |
| MathFu            | Yes                |
| vectorial         | Yes                |
| VectorialPlusPlus | Yes                |
| CGLM              | Yes (optional lib) |
| GLM               | Yes                |
| ILMBase           | No                 |
| DirectX Math      | Yes                |
| Unreal Engine 4   | No                 |


## Verbosity, readability, and power

An important requirement for a math library is to be reasonably concise with average code without getting in the way if the need arises to dive right into raw intrinsics. In my experience, general math type abstractions take you very far but in order to squeeze out every cycle it is sometimes necessary to write custom per platform code. When this is required, it is important for the library to not hide its internals and leave the door open.

I am personally more a fan of C-style interfaces for a math library for various reasons: I can infer very well what happens under the hood (I have seen many libraries make *fancy* use of some operators that leave many newcomers to wonder what they do) and they are optimal for performance as we will discuss later. The downside of course is that they tend to be a bit more verbose. However, this largely boils down to a matter of personal taste.

*vectorial* is one of the few libraries that offers both a C-style interface and C++ wrappers and at the other end of the spectrum *DirectX Math* has both a namespace and a prefix for every type, constant and function.

| Library           | Verbosity                                    |
| ----------------- | -------------------------------------------- |
| Realtime Math     | Medium (C-style)                             |
| MathFu            | Light (C++ wrappers)                         |
| vectorial         | Light (C++ wrappers) and Medium (C-style)    |
| VectorialPlusPlus | Light (C++ wrappers)                         |
| CGLM              | Medium (C-style)                             |
| GLM               | Light (C++ wrappers)                         |
| ILMBase           | Light (C++ wrappers)                         |
| DirectX Math      | Medium++ (C-style with prefix and namespace) |
| Unreal Engine 4   | Light (C++ wrappers)                         |

It is very common for C-style math APIs to *typedef* their types to the underlying SIMD type. *Realtime Math*, *DirectX Math*, and many others do this. While this is great for performance, it does raise one problem: type safety is reduced. While usually those interfaces will opt to not expose proper vector2 or vector3 types and instead rely on functions that simply ignore the extra components, it doesn't work so well when vector4 and quaternions are mixed. Only *Realtime Math*, *DirectX Math* and *CGLM* have quaternions with C-style interfaces but only the first two have a distinct type for quaternions when SIMD intrinsics are disabled. This somewhat mitigates the issue because with both *Realtime Math* and *DirectX Math* you can compile without intrinsics and still have type safety validated there. Although at the end of the day, all three have functions with distinct prefixes for vector and quaternion math and as such type safety is unlikely to be an issue.

## Type and feature support

By virtue or being an animation compression library, ACL's needs are a bit different from a traditional realtime application. This dictated the need I had for specific types and features. I had no need for general 3x3 or 4x4 matrices as well as 2D vectors which are more commonly used in gameplay and rendering. However, 3x4 affine matrices, 3D and 4D vectors, quaternions, and QVV transforms (a quaternion, a vector3 translation, and a vector3 scale) are of critical importance. Those types are front and center in an animation runtime and I needed them to be fully featured and fast. Most of the libraries under review had way more features than I cared for (mostly for rendering) but generally missed proper or any support for quaternions and QVV transforms.

*MathFu appears to have a [bug](https://github.com/google/mathfu/issues/33) where the Matrix 4x4 SIMD template specialization isn't included by default and its [quaternions are 32 bytes](https://github.com/google/mathfu/issues/34) instead of the ideal 16 due to alignment constraints.*

*VectorialPlusPlus quaternions also take 32 bytes instead of 16 due to alignment constraints and most of their quaternion code appears to be scalar.*

*UE 4 is notable for being the only other library to support QVV and it does offer a VectorRegister type to support SIMD for Vector2/3/4 although most of the code written in the engine uses the scalar version.*

| Library           | Vector2 | Vector3 | Vector4 | Quaternion   | Matrix 3x3 | Matrix 4x4 | Matrix 3x4 | QVV  |
| ----------------- | ------- | ------- | ------- | ------------ | ---------- | ---------- | ---------- | ---- |
| Realtime Math     |         | SIMD    | SIMD    | SIMD         | SIMD       | SIMD       | SIMD       | SIMD |
| MathFu            | SIMD    | SIMD    | SIMD    | Partial SIMD | Scalar     | SIMD       | Scalar     |      |
| vectorial         |         | SIMD    | SIMD    |              |            | SIMD       |            |      |
| VectorialPlusPlus | SIMD    | SIMD    | SIMD    | Scalar       | SIMD       | SIMD       |            |      |
| CGLM              |         | SIMD    | SIMD    | SIMD         | SIMD       | SIMD       | SIMD       |      |
| GLM               | SIMD    | SIMD    | SIMD    | Partial SIMD | SIMD       | SIMD       | SIMD       |      |
| ILMBase           | Scalar  | Scalar  | Scalar  | Scalar       | Scalar     | Scalar     |            |      |
| DirectX Math      | SIMD    | SIMD    | SIMD    | SIMD         |            | SIMD       |            |      |
| Unreal Engine 4   | Scalar  | Scalar  | Scalar  | SIMD         |            | SIMD       |            | SIMD |

## SIMD architecture support

Equally important was the SIMD architecture support. I want to run ACL everywhere with the best performance possible, especially on mobile. SSE, AVX, and NEON are all equally important to me.

*Worth noting that 2 years ago DirectX NEON support appeared almost exclusively to be for Windows ARM NEON and I have no idea if it runs on iOS or Android even today.*

| Library           | SSE  | AVX  | NEON    |
| ----------------- | ---- | ---- | ------- |
| Realtime Math     | Yes  | Yes  | Yes     |
| MathFu            | Yes  |      | Yes     |
| vectorial         | Yes  |      | Yes     |
| VectorialPlusPlus | Yes  |      | Partial |
| CGLM              | Yes  | Yes  | Partial |
| GLM               | Yes  |      |         |
| ILMBase           |      |      |         |
| DirectX Math      | Yes  | Yes  | Yes     |
| Unreal Engine 4   | Yes  | Yes  | Yes     |

## Platform and compiler support

Here things are a bit more complicated as libraries will list platforms but not compilers or compilers but not platforms. I need ACL to run everywhere and this means limiting myself to C++11 features.

* Realtime Math: Windows (VS2015, VS2017) x86 and x64, Linux (gcc5, gcc6, gcc7, gcc8, clang4, clang5, clang6) x86 and x64, OS X (Xcode 8.3, Xcode 9.4, Xcode 10.1) x86 and x64, Android clang ARMv7-A and ARM64, iOS (Xcode 8.3, Xcode 9.4, Xcode 10.1) ARM64
* MathFu: Windows, Linux, OS X, Android
* vectorial: Unlisted but probably Windows, Linux, OS X, Android, and iOS
* VectorialPlusPlus: Unlisted but probably Windows
* CGLM: Windows, Unix, and probably everywhere
* GLM: VS2013+, Apple Clang 6, GCC 4.7+, ICC XE 2013+, LLVM 3.4+, CUDA 7+
* ILMBase: Unlisted but probably Windows, Linux, OS X
* DirectX Math: VS2015 and VS2017, possibly elsewhere
* Unreal Engine 4: Windows (VS2015, VS2017) x64, Linux x64, OS X x64, Android ARMv7-A (no NEON) and ARM64, iOS ARM64

## Continuous integration support

Continuous integration is a critical part of modern software development especially with C++ when multiple platforms are supported and maintained.

| Library           | Continuous Integration              |
| ----------------- | ------------------------- |
| Realtime Math     | Yes |
| MathFu            | No |
| vectorial         | No |
| VectorialPlusPlus | No |
| CGLM              | Yes |
| GLM               | Yes |
| ILMBase           | No |
| DirectX Math      | No |
| Unreal Engine 4   | Not public           |

## Dependencies

I'm not personally a big fan of pulling in tons of dependencies, especially for a math library. As mentioned earlier, the Unreal Engine 4 math library isn't really usable on its own because of this but is included regardless.

| Library           | Dependencies              |
| ----------------- | ------------------------- |
| Realtime Math     |                           |
| MathFu            | vectorial (BSD 2-clause)  |
| vectorial         |                           |
| VectorialPlusPlus | HandyCPP (custom license) |
| CGLM              |                           |
| GLM               |                           |
| ILMBase           |                           |
| DirectX Math      |                           |
| Unreal Engine 4   | Unreal Engine 4           |

## Floating point support

When I got started with ACL, I wasn't sure at the time if 64 bit floating point arithmetic might offer superior accuracy or not and if it would be worth using. As a result, I needed the math code to support both float32 and float64 types for everything with a seamless API between the two for quick testing. It later [turned out](http://nfrechette.github.io/2017/12/29/acl_research_arithmetic/) that the extra floating point precision isn't helping enough to be worth using.

| Library           | Float 32 Support | Float 64 Support   |
| ----------------- | ---------------- | ------------------ |
| Realtime Math     | Yes              | Yes (partial SIMD) |
| MathFu            | Yes              | Yes (no SIMD)      |
| vectorial         | Yes              |                    |
| VectorialPlusPlus | Yes              | Yes (partial SIMD) |
| CGLM              | Yes              |                    |
| GLM               | Yes              |                    |
| ILMBase           | Yes (no SIMD)    | Yes (no SIMD)      |
| DirectX Math      | Yes              |                    |
| Unreal Engine 4   | Yes              |                    |

## Inlinability

Due to the critical need for ACL to be as fast as possible on every platform, having the bulk of the math operations be inline is very important. Many things impact whether a function is inlined by the compiler but two stand out:

* Simple and short functions inline better
* Passing arguments by register needs fewer instructions which inlines better

Thankfully, most math function are fairly simple and short: add, mul, div, etc. C-style functions will generally have a slight advantage over C++ wrappers mainly because they also must track the implicit *this* pointer being passed around even if ultimately it is optimized out inside the caller. When the compiler needs to determine if it can inline a function, it uses a heuristic and the size of the intermediate assembly/IR/AST most likely  plays a role. Generally speaking, C++ wrapper functions that are short will inline just fine but some operations have a harder time due to their size: matrix 4x4 multiplication, quaternion multiplication, and quaternion interpolation. For this reason, I personally favor a C-style API for this sort of code.

The second point is not to be underestimated. Most of the libraries in the list either take the arguments by value or by *const* reference. While passing SIMD types by value does the right thing on ARM and passes them by register (up to 4), it does not work for aggregate types like matrices and it does not work with the default *x64* calling convention with MSVC. In order to be able to pass SIMD types by register with MSVC, you must use its *__vectorcall* [calling convention](https://msdn.microsoft.com/en-us/library/dn375768.aspx). It also works for aggregate and wrapper types. Up to **6** registers can be used for this. On desktop and Xbox One, using *__vectorcall* is critical for high performance code and sadly, most libraries do not support it explicitly (and not all support it implicitly if the whole compilation unit is forced to use that calling convention). With *Visual Studio 2015*, *__vectorcall* is the difference between having quaternion interpolation getting inlined or not. When I added support for it in ACL, I measured a roughly **5%** speedup during the decompression.

Note that once a function is inlined, whether the arguments are passed by register or not typically does not impact the generated assembly although it sometimes does (at least with MSVC especially when AVX is enabled).

*Some libraries which use a generic vector template class with specializations for SIMD (like MathFu) sometime end up passing *float32* arguments by const-reference instead of by value which is often suboptimal when not inlined.*

| Library           | Inlinability                          | Register Passing                   |
| ----------------- | ------------------------------------- | ---------------------------------- |
| Realtime Math     | Optimal (C-style + by register)       | Explicit (everywhere)              |
| MathFu            | Decent (C++ wrappers)                 | None                               |
| vectorial         | Good (C-style), Decent (C++ wrappers) | Implicit (C-style and ARM only)    |
| VectorialPlusPlus | Decent (C++ wrappers)                 | None                               |
| CGLM              | Good (C-style)                        | None                               |
| GLM               | Decent (C++ wrappers)                 | None                               |
| ILMBase           | Decent (C++ wrappers)                 | None                               |
| DirectX Math      | Optimal (C-style + by register)       | Explicit (vectorcall and ARM only) |
| Unreal Engine 4   | Decent (C++ wrappers)                 | None                               |

## Multiplication order

An important point of contention is how things are multiplied. As the list below shows, the OpenGL way is by far the most popular for open source math libraries.

It all boils down to whether vectors are represented as a *row* or as a *column*. In the former case, multiplication with a matrix takes the form `v' = vM`  while in the later case we have `v' = Mv`.  Linear algebra typically treats vectors as *columns* and OpenGL opted to use that convention for [that reason](http://steve.hollasch.net/cgindex/math/matrix/column-vec.html). If you think of matrices as functions that modify an input and return an output it ends up reading like this: `result = object_to_world(local_to_object(input))`. This reads right-to-left as is common with nested function evaluation. In my opinion, this is quite awkward to work with as most modern programming languages (and western languages) read left-to-right. Most linear algebra formulas use abstract letters and names for things which somewhat hides this nuance but when I write code, I try to keep my matrix names as clear as possible: what space are the input and output in. While you could technically reverse the naming `result = world_from_object * object_from_local * input` so it at least reads decently right-to-left, it's still harder to reason with because just about everything we work with in the world goes from somewhere to somewhere else and not the other way around: trains, buses, planes, Monday to Friday, 5@7, etc.

On the other hand, DirectX uses *row* vectors and ends up with the much more natural: `result = input * local_to_object * object_to_world`. Your input is in local space, it gets transformed into object space before finally ending up in world space. Clean, clear, and readable. If you instead multiply the two matrices together on their own, you get the clear `local_to_world = local_to_object * object_to_world` instead of the awkward `local_to_world = object_to_world * local_to_object` you would get with OpenGL and *column* vectors.

At the end of the day, which way you choose largely boils down to a personal choice (or whatever library you use for rendering) as I don't think there's a big performance difference between the two on modern hardware. For ACL, all its output data is in local space and although we evaluate the error in world space internally, this is entirely transparent to the client application and it is free to use either convention.

| Library           | Multiplication Style |
| ----------------- | -------------------- |
| Realtime Math     | DirectX              |
| MathFu            | OpenGL               |
| vectorial         | OpenGL               |
| VectorialPlusPlus | OpenGL               |
| CGLM              | OpenGL               |
| GLM               | OpenGL               |
| ILMBase           | OpenGL               |
| DirectX Math      | DirectX              |
| Unreal Engine 4   | DirectX              |

## Conclusion

Ultimately, which math library you choose for a particular project boils down to a matter of personal preference to a large extent. For the vast majority of the code you'll write, the performance and code generation is likely to be very close if not identical. Two years ago, I knew regardless of which option I picked I would have to do a lot of work to add what was missing. This greatly motivated me to just start from scratch as many middleware do and I do not regret the experience or results.

My top two favorite libraries are *Realtime Math* and *DirectX Math*. Both are quite similar today although *DirectX Math* wasn't quite as attractive when I started.

## Next steps

Over the next few days I will populate various issues on GitHub to document things that are missing or that could benefit from some love.

A core part that is partially missing at the moment is the quantization and packing logic that ACL already contains. I have not migrated that code yet in large part because I am not sure how to best expose it in a clean and consistent API. I do believe it belongs in RTM where everyone can benefit from it.

ACL does not yet use RTM but that migration is planned for ACL [v2.0](https://github.com/nfrechette/acl/issues/170).
