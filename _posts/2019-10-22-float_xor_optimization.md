---
layout: post
title: "Faster floating point arithmetic with Exclusive OR"
---

Today it's time to talk about [another floating point arithmetic trick]({% post_url 2019-05-08-sign_flip_optimization %}) that sometimes can come in very handy with SSE2. This trick isn't novel, and I don't often get to use it but a few days ago inspiration struck me late at night in the middle of a long 3 hour drive. The results inspired this post.

I'll cover three functions that use it for [quaternion](https://en.wikipedia.org/wiki/Quaternion) arithmetic which have already been merged into the [Realtime Math (RTM)](https://github.com/nfrechette/rtm) library as well as the [Animation Compression Library (ACL)](https://github.com/nfrechette/acl). ACL uses quaternions heavily and I'm always looking for ways to make them faster.

*TL;DR: With SSE2, XOR (and other logical operators) can be leveraged to speed up common floating point operations.*

# XOR: the lesser known logical operator

Most programmers are familiar with `AND`, `OR`, and `NOT` logical operators. They form the bread and butter of everyday programming. And while we all learn about their cousin `XOR`, it doesn't come in handy anywhere near as often. Here is a quick recap of what it does.

A | B | A XOR B
--- | --- | ---
0 | 0 | 0
0 | 1 | 1
1 | 0 | 1
1 | 1 | 0

We can infer a few interesting properties from it:

*  Any input that we apply XOR to with zero yields the input
*  XOR can be used to flip a bit from `true` to `false` or vice versa by XOR-ing it with one
*  Using XOR when both inputs are identical yields zero (every zero bit remains zero and every one bit flips to zero)

Exclusive OR comes in handy mostly with bit twiddling hacks when squeezing every cycle counts. While it is commonly used with integer inputs, it can also be used with floating point values!

# XOR with floats

SSE2 contains support for XOR (and other logical operators) on both integral (`_mm_xor_si128`) and floating point values (`_mm_xor_ps`). Usually when you transition from the integral domain to the floating point domain of operations on a register (or vice versa), the CPU will incur a 1 cycle penalty. By implementing a different instruction for both domains, this hiccup can be avoided. Logical operations can often execute on more than one execution port (even on older hardware) which can enable multiple instructions to dispatch in the same cycle.

The question then becomes, when does it make sense to use them?

# Quaternion conjugate

For a quaternion `A` where `A = [x, y, z] | w` with real (`[x, y, z]`) and imaginary (`w`) parts, its [conjugate](https://en.wikipedia.org/wiki/Quaternion#Conjugation,_the_norm,_and_reciprocal) can be expressed as follow: `conjugate(A) = [-x, -y, -z] | w`. The conjugate simply flips the sign of each component of the real part.

The most common way to achieve this is by multiplying a constant just like [DirectX Math](https://github.com/microsoft/DirectXMath/blob/939c1a86b28f0d10858601b80faa7845070687fb/Inc/DirectXMathMisc.inl#L251) and Unreal Engine 4 do.

```c++
quatf quat_conjugate(quatf input)
{
	constexpr __m128 signs = { -1.0f, -1.0f, -1.0f, 1.0f };
	return _mm_mul_ps(input, signs);
}
```

This yields a single instruction (the constant will be loaded from memory as part of the multiply instruction) but we can do better. Flipping the sign bit can also be achieved by XOR-ing our input with the sign bit. To avoid flipping the sign of the `w` component, we can simply XOR it with zero which will leave the original value unchanged.

```c++
quatf quat_conjugate(quatf input)
{
	constexpr __m128 signs = { -0.0f, -0.0f, -0.0f, 0.0f };
	return _mm_xor_ps(input, signs);
}
```

Again, this yields a single instruction but this time it is much faster. See full results [here](https://github.com/nfrechette/rtm/issues/6) but on my MacBook Pro it is **33.5% faster**!

# Quaternion interpolation

Linear interpolation for scalars and vectors is simple: `result = ((end - start) * alpha) + start`.

While this can be used for quaternions as well, it breaks down if both quaternions are not on the [same side of the hypersphere](https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation#The_hypersphere_of_rotations). Both quaternions `A` and `-A` represent the same 3D rotation but lie on opposite ends of the 4D hypersphere represented by unit quaternions. In order to properly handle this case, we first need to calculate the dot product of both inputs being interpolated and depending its sign, we must flip one of the inputs so that it can lie on the same side of the hypersphere.

In code it looks like this:

```c++
quatf quat_lerp(quatf start, quatf end, float alpha)
{
	// To ensure we take the shortest path, we apply a bias if the dot product is negative
	float dot = vector_dot(start, end);
	float bias = dot >= 0.0f ? 1.0f : -1.0f;
	vector4f rotation = vector_neg_mul_sub(vector_neg_mul_sub(end, bias, start), alpha, start);
	return quat_normalize(rotation);
}
```

*The double `vector_neg_mul_sub` trick was explained in a [previous]({% post_url 2019-05-08-sign_flip_optimization %}) blog post.*

As mentioned, we take the sign of the dot product to calculate a bias and simply multiply it with the `end` input. This can be achieved with a compare instruction between the dot product and zero to generate a mask and using that mask to select between the positive and negative value of `end`. This is entirely branchless and boils down to a few instructions: 1x compare, 1x subtract (to generate `-end`), 1x blend (with AVX to select the bias), and 1x multiplication (to apply the bias). If AVX isn't present, the selection is done with 3x logical operation instructions instead. This is what Unreal Engine 4 and many others do.

Here again, we can do better with logical operators.

```c++
quatf quat_lerp(quatf start, quatf end, float alpha)
{
	__m128 dot = vector_dot(start, end);
	// Calculate the bias, if the dot product is positive or zero, there is no bias
	// but if it is negative, we want to flip the 'end' rotation XYZW components
	__m128 bias = _mm_and_ps(dot, _mm_set_ps1(-0.0f));
	__m128 rotation = _mm_add_ps(_mm_mul_ps(_mm_sub_ps(_mm_xor_ps(end, bias), start), _mm_set_ps1(alpha)), start);
	return quat_normalize(rotation);
}
```

What we really want to achieve is to do nothing (use `end` as-is) if the sign of the bias is zero and to flip the sign of `end` if the bias is negative. This is a perfect fit for XOR! All we need to do is XOR `end` with the sign bit of the bias. We can easily extract it with a logical AND instruction and a mask of the sign bit. This boils down to just two instructions: 1x logical AND and 1x logical XOR. We managed to remove expensive floating point operations while simultaneously using fewer and cheaper instructions.

*Measuring is left as an exercise for the reader.*

# Quaternion multiplication

While the previous two use cases have been in RTM for some time now, this one is brand new and is what crossed my mind the other night: quaternion multiplication can use the same trick!

Multiplying two quaternions with scalar arithmetic is done like this:

```c++
quatf quat_mul(quatf lhs, quatf rhs)
{
	float x = (rhs.w * lhs.x) + (rhs.x * lhs.w) + (rhs.y * lhs.z) - (rhs.z * lhs.y);
	float y = (rhs.w * lhs.y) - (rhs.x * lhs.z) + (rhs.y * lhs.w) + (rhs.z * lhs.x);
	float z = (rhs.w * lhs.z) + (rhs.x * lhs.y) - (rhs.y * lhs.x) + (rhs.z * lhs.w);
	float w = (rhs.w * lhs.w) - (rhs.x * lhs.x) - (rhs.y * lhs.y) - (rhs.z * lhs.z);

	return quat_set(x, y, z, w);
}
```

Floating point multiplications and additions being expensive, we can reduce their number by converting this to SSE2 and shuffling our inputs to line everything up. A few shuffles can line the values up for our multiplications but it is clear that in order to use addition (or subtraction), we have to flip the signs of a few components. Again, [DirectX Math](https://github.com/microsoft/DirectXMath/blob/939c1a86b28f0d10858601b80faa7845070687fb/Inc/DirectXMathMisc.inl#L143) does just this (and so does Unreal Engine 4).

```c++
quatf quat_mul(quatf lhs, quatf rhs)
{
	constexpr __m128 control_wzyx = { 1.0f,-1.0f, 1.0f,-1.0f };
	constexpr __m128 control_zwxy = { 1.0f, 1.0f,-1.0f,-1.0f };
	constexpr __m128 control_yxwz = { -1.0f, 1.0f, 1.0f,-1.0f };

	__m128 r_xxxx = _mm_shuffle_ps(rhs, rhs, _MM_SHUFFLE(0, 0, 0, 0));
	__m128 r_yyyy = _mm_shuffle_ps(rhs, rhs, _MM_SHUFFLE(1, 1, 1, 1));
	__m128 r_zzzz = _mm_shuffle_ps(rhs, rhs, _MM_SHUFFLE(2, 2, 2, 2));
	__m128 r_wwww = _mm_shuffle_ps(rhs, rhs, _MM_SHUFFLE(3, 3, 3, 3));

	__m128 lxrw_lyrw_lzrw_lwrw = _mm_mul_ps(r_wwww, lhs);
	__m128 l_wzyx = _mm_shuffle_ps(lhs, lhs,_MM_SHUFFLE(0, 1, 2, 3));

	__m128 lwrx_lzrx_lyrx_lxrx = _mm_mul_ps(r_xxxx, l_wzyx);
	__m128 l_zwxy = _mm_shuffle_ps(l_wzyx, l_wzyx,_MM_SHUFFLE(2, 3, 0, 1));

	__m128 lwrx_nlzrx_lyrx_nlxrx = _mm_mul_ps(lwrx_lzrx_lyrx_lxrx, control_wzyx); // flip!

	__m128 lzry_lwry_lxry_lyry = _mm_mul_ps(r_yyyy, l_zwxy);
	__m128 l_yxwz = _mm_shuffle_ps(l_zwxy, l_zwxy,_MM_SHUFFLE(0, 1, 2, 3));

	__m128 lzry_lwry_nlxry_nlyry = _mm_mul_ps(lzry_lwry_lxry_lyry, control_zwxy); // flip!

	__m128 lyrz_lxrz_lwrz_lzrz = _mm_mul_ps(r_zzzz, l_yxwz);
	__m128 result0 = _mm_add_ps(lxrw_lyrw_lzrw_lwrw, lwrx_nlzrx_lyrx_nlxrx);

	__m128 nlyrz_lxrz_lwrz_wlzrz = _mm_mul_ps(lyrz_lxrz_lwrz_lzrz, control_yxwz); // flip!
	__m128 result1 = _mm_add_ps(lzry_lwry_nlxry_nlyry, nlyrz_lxrz_lwrz_wlzrz);
	return _mm_add_ps(result0, result1);
}
```

The code this time is a bit harder to read but here is the gist:

* We need 7x shuffles to line everything up
* With everything lined up, we need 4x multiplications and 3x additions
* 3x multiplications are also required to flip our signs ahead of each addition (which conveniently can also be done with fused-multiply-add)

I'll omit the code for brevity but by using `-0.0f` and `0.0f` as our control values to flip the sign bits with XOR instead, quaternion multiplication becomes much [faster](https://github.com/nfrechette/rtm/issues/29). On my MacBook Pro it is **14%** faster while on my Ryzen 2950X it is **10%** faster! I also measured with ACL to see what the speed up would be in a real world use case: compressing lots of animations. With the data sets I measure with, this new quaternion multiplication accelerates the compression by up to **1.3%**.

*Most x64 CPUs in use today (including those in the PlayStation 4 and Xbox One) do not yet support fused-multiply-add and when I add support for it in RTM, I will measure again.*

# Is it safe?

In all three of these examples, the results are binary exact and identical to their reference implementations. Flipping the sign bit on normal floating point values (and infinities) with XOR yields a binary exact result. If the input is `NaN`, XOR will not yield the same output but it will yield a `NaN` with the sign bit flipped which is entirely valid and consistent (the sign bit is typically left unused on `NaN` values).

I also measured this trick with NEON on ARMv7 and ARM64 but sadly it is slower on those platforms (for now). It appears that there is indeed a penalty there for switching between the two domains and perhaps in time it will go away or perhaps something else is slowing things down.

*ARM64 already uses fused-multiply-add where possible.*

# Progress update

It has been almost a year since the [first release](https://nfrechette.github.io/2019/01/19/introducing_realtime_math/) of RTM. The next release should happen very soon now, just ahead of the next ACL release which will introduce it as a dependency for its [scalar track compression](https://github.com/nfrechette/acl/issues/71) API. I am on track to finish both releases before the end of the year.

Thanks to the new [GitHub Sponsors](https://github.com/sponsors) program, you can now [sponsor me](https://github.com/sponsors/nfrechette)! All funds donated will go towards purchasing new devices to optimize for as well as other related costs (like coffee).
