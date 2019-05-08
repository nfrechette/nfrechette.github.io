---
layout: post
title: "Faster arithmetic by flipping signs"
---

Over the years, I picked up a number of tricks to optimize code. Today I'll talk about one of them.

I first picked it up a few years ago when I was tasked with optimizing the cloth simulation code in [Shadow of the Tomb Raider](https://en.wikipedia.org/wiki/Shadow_of_the_Tomb_Raider). It had been fine tuned extensively with *PowerPC* intrinsics for the *Xbox 360* but its performance was lacking on *XboxOne* (*x64*). While I hoped to talk about it [2 years ago](http://nfrechette.github.io/2017/04/11/modern_simd_hardware/), I ended up side tracked with the [Animation Compression Library (ACL)](https://github.com/nfrechette/acl). However, last week while introducing *ARM64* fused muptiply-add support into ACL and the [Realtime Math (RTM)](https://github.com/nfrechette/rtm) library, I noticed an opportunity to use this trick when linearly interpolating [quaternions](https://en.wikipedia.org/wiki/Quaternion) and it all came back to me.

TL;DR: Flipping the sign of some arithmetic operations can lead to shorter and faster assembly.

# Flipping for fun and profit on x64

To understand how this works, we need to give a bit of context first.

On *PowerPC*, *ARM*, and many other platforms, before an instruction can use a value it must first be loaded from memory into a register explicitly with a load type instruction. This is not always the case with *x86* and *x64* where many instructions can take either a register or a memory address as input. In the later case, the load still happens behind the scenes and while it isn't really much faster by itself it does have a few benefits.

Not having an explicit load instruction means that we do not use one of the precious named registers. While under the hood the CPU has tons of registers (e.g modern processors have **50+ XMM registers**), the instructions can only reference a few of them: only **16** named XMM registers can be referenced. This can be very important if a piece of code places considerable pressure on the amount of registers it needs. Fewer named registers used means a reduced likelihood that registers have to spill on the stack and spilling introduces quite a few instructions as well. Altogether, removing that single load instruction can considerably improve the chances of a function getting inlined.

Fewer instructions also means a lower code cache footprint and better overall performance although in practice, I have found this impact very hard to measure.

Two things are important to keep in mind:

* An instruction that operates directly from memory will be slower than the same instruction working from a register: it has to perform the load operation and even if the value resides in the CPU cache, it still takes time.
* Most arithmetic instructions that take two inputs only support having one of them come from memory: addition, subtraction, multiplication, etc. Typically, only the second input (on the right) can come from memory.

To illustrate how flipping the sign of arithmetic operations can lead to improved code generation, we will use the following example:

<script src="https://gist.github.com/nfrechette/0654f9ca2d722524844dd1b99f9b5e85.js"></script>

Both *MSVC 19.20* and *GCC 9* generate the above assembly. The `1.0f` constant must be loaded from memory because `subss` only supports the second argument coming from memory. Interestingly, *Clang 8* figures out that it can use the sign flip trick all on its own:

<script src="https://gist.github.com/nfrechette/b36d26bebfecf67b2bacace7382ad07d.js"></script>

Because we multiply our input value by a constant, we are in control of its sign and we can leverage that fact to change our `subss` instruction into an `addss` instruction that can work with another constant from memory directly. Both functions are mathematically equivalent and their results are identical down to every last bit.

Short and sweet!

Not every mainstream compiler today is smart enough to do this on its own especially in more complex cases where other instructions will end up in between the two sign flips. Doing it by hand ensures that they have all the tools to do it right. Should the compiler think that performance will be better by loading the constant into a register anyway, it will also be able to do so (for example if the function is inlined in a loop).

# But wait, there's more!

While that trick is very handy on *x64*, it can also be used in a different context and I found a good example on *ARM64*: when linearly interpolating quaternions.

Typically linear interpolation isn't recommended with quaternions as it is not guaranteed to give very accurate results if the two quaternions are far apart. However, in the context of animation compression, successive quaternions are often very close to one another and linear interpolation works just fine. Here is what the function looked like before I used the trick:

<script src="https://gist.github.com/nfrechette/83f989059160c2befdcc67d3e2496db1.js"></script>

The code is fairly simple:

*  We calculate a bias and if both quaternions are on opposite sides of the [hypersphere](https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation#The_hypersphere_of_rotations) (negative dot product), we apply a bias to flip one of them to make sure that they lie on the same side. This guarantees that the path taken when interpolating will be the shortest.
*  We linearly interpolate: `(end - start) * alpha + start`
*  Last but not least, we normalize our quaternion to make sure that it represents a valid 3D rotation.

When I introduced the fused multiply-add support to *ARM64*, I looked at the above code and its generated assembly and noticed that we had a multiplication instruction followed by a subtraction instruction before our final fused multiply-add instruction. Can we do better?

While [*FMA3*](https://software.intel.com/sites/landingpage/IntrinsicsGuide/#techs=FMA) has a myriad of instructions for all sorts of fused multiply-add variations, [*ARM64* does not](https://developer.arm.com/architectures/instruction-sets/simd-isas/neon/intrinsics): it only has 2 such instructions: `fmla` ((a * b) + c) and `fmls` (-(a * b) + c).

Here is the interpolation broken down a bit more clearly:

*  `x = (end * bias) - start`                        (`fmul`, `fsub`)
*  `result = (x * alpha) + start`                 (`fmla`)

After a bit of thinking, it becomes obvious what the solution is:

*  `-x = -(end * bias) + start`                     (`fmls`)
*  `result = -(-x * alpha) + start`              (`fmls`)

By flipping the sign of our intermediate value with the `fmls` instruction, we can flip it again and cancel it out by using it once more while removing an instruction in the process. This simple change resulted in a **2.5 %** speedup during animation decompression (which also does a bunch of other stuff) on my iPad.

*Note: because `fmls` reuses one of the input registers for its output, a new `mov` instruction was added in the final inlined decompression code but it executes much faster than a floating point instruction.*

You can find the change in RTM [here](https://github.com/nfrechette/rtm/pull/17).
