---
layout: post
title: "Keep an eye out for buffer security checks"
---
By default, when compiling C++, Visual Studio enables the `/GS` flag for [buffer security checks](https://docs.microsoft.com/en-us/cpp/build/reference/gs-buffer-security-check?view=vs-2019).

In functions that the compiler deems vulnerable to the stack getting overwritten, it adds buffer security checks. To detect if the stack has been tampered with during execution of the function, it first writes a sentinel value past the end of the reserved space the function needs. This sentinel value is random per process to avoid an attacker guessing its value. Just before the function exits, it calls a small function that validates the sentinel value: `__security_check_cookie()`.

The rules on what can trigger this are as follow (from the MSDN documentation):

*  The function contains an array on the stack that is larger than 4 bytes, has more than two elements, and has an element type that is not a pointer type.
*  The function contains a data structure on the stack whose size is more than 8 bytes and contains no pointers.
*  The function contains a buffer allocated by using the `_alloca` function.
*  The function contains a data structure that contains another which triggers one of the above checks.


This is all fine and well and **you should never disable it program/file wide**. But you should keep an eye out. In very performance critical code, this small overhead can have a sizable impact. I've observed this over the years a few times but it now popped up somewhere I didn't expect it: my math library [Realtime Math (RTM)](https://github.com/nfrechette/rtm).

## Non-zero cost abstractions

The SSE2 headers define a few types. Of interest to us today is `__m128` but others suffer from the same issue as well (including wider types such as `__m256`). Those define a register wide value suitable for SIMD intrinsics: `__m128` contains four 32 bit floats. As such, it takes up 16 bytes.

Because it is considered a native type by the compiler, it does not trigger buffer security checks to be inserted despite being larger than 8 bytes without containing pointers.

However, the same is not true if you wrap it in a struct or class.

```c++
struct scalarf
{
    __m128 value;
};
```

The above struct might trigger security checks to be inserted: it is a struct larger than 8 bytes that does not contain pointers.

Similarly, many other common math types suffer from this:

```c++
struct matrix3x3f
{
    __m128 x_axis;
    __m128 y_axis;
    __m128 z_axis;
};
```

Many years ago, in a discussion about an unrelated compiler bug, someone at Microsoft mentioned to me that it is best to typedef SIMD types than it is to wrap them in a concrete type; it should lead to better code generation. They didn't offer any insights as to why that might be (and I didn't ask) and honestly I had never noticed any difference until security buffer checks came into play, *last Friday*. Their math library *DirectX Math* uses a typedef for its vector type and so does RTM everywhere it can. But sometimes it can't be avoided.

RTM also extensively uses a helper struct pattern to help keep the code clean and flexible. Some code such as a vector dot product returns a scalar value. But on some architectures, it isn't desirable to treat it as a `float` for performance reasons (PowerPC, x86, etc). For example, with x86 float arithmetic does not use SSE2 unless you explicitly use intrinsics for it: by default it uses the x87 floating point stack (with MSVC at least). If this value is later needed as part of more SSE2 vector code (such as vector normalization), the value will be calculated from two SSE2 vectors, be stored on the x87 float stack, only to be passed back to SSE2. To avoid this roundtrip when using SSE2 with x86, RTM exposes the `scalarf` type. However, sometimes you really need the value as a float. The usage dictates what you need. To support both variants with as little syntactic overhead as possible, RTM leverages return type overloading (it's not really a thing in C++ but it can be faked with implicit coercion). It makes the following possible:

```c++
vector4f vec1 = vector_set(1.0f, 2.0f, 3.0f);
vector4f vec2 = vector_set(5.0f, 6.0f, 7.0f);

scalarf dot_sse2 = vector_dot3(vec1, vec2);
float dot_x87 = vector_dot3(vec1, vec2);
vector4f dot_broadcast = vector_dot3(vec1, vec2);
```

This is very clean to use and the compiler can figure out what code to call easily. But it is ugly to implement; a small price to pay for readability.

```c++
// A few things omited for brevity
struct dot3_helper
{
    inline operator float()
    {
        return do_the_math_here1();
    }

    inline operator scalarf()
    {
        return do_the_math_here2();
    }

    inline operator vector4f()
    {
        return do_the_math_here3();
    }

    vector4f left_hand_side;
    vector4f right_hand_side;
};

constexpr dot3_helper vector_dot3(vector4f left_hand_side, vector4f right_hand_side)
{
    return dot3_helper{ left_hand_side, right_hand_side };
}
```

>  Side note, on ARM `scalarf` is a typedef for `float` in order to achieve optimal performance.

There is a lot of boilerplate but the code is very simple and either *constexpr* or marked *inline*. We create a small struct and return it, and at the call site the compiler invokes the right implicit coercion operator. It works just fine and the compiler optimizes everything away to yield the same lean assembly you would expect. We leverage inlining to create what should be a zero cost abstraction. Except, in rare cases (at least with Visual Studio as recent as 2019), inlining fails and everything goes wrong.

>  Side note, the above is one example why `scalarf` cannot be a typedef because we need it distinct from `vector4f` both of which are represented in SSE2 as a `__m128`. To avoid this issue, `vector4f` is a typedef while `scalarf` is a wrapping struct.

Many math libraries out there wrap SIMD types in a proper type and use similar patterns. And while generally most math functions are small and get inlined fine, it isn't always the case. In particular, these security buffer checks can harm the ability of the compiler to inline while at the same time degrading performance of perfectly safe code.

## 8 instructions is too much

All of this worked well until I noticed, out of the blue, a performance regression in the [Animation Compression Library](https://github.com/nfrechette/acl) when I updated to the latest RTM version. This was very strange as it should have only contained performance optimizations.

[Here](https://github.com/nfrechette/acl/blob/1cd782149e59c4d682791f4cc23b104a51627c16/includes/acl/compression/skeleton_error_metric.h#L342) is where the code generation changed:

```c++
// A few things omited for brevity
__declspec(safebuffers) rtm::scalarf calculate_error_no_scale(const calculate_error_args& args)
{
    const rtm::qvvf& raw_transform_ = *static_cast<const rtm::qvvf*>(args.transform0);
    const rtm::qvvf& lossy_transform_ = *static_cast<const rtm::qvvf*>(args.transform1);

    const rtm::vector4f vtx0 = args.shell_point_x;
    const rtm::vector4f vtx1 = args.shell_point_y;

    const rtm::vector4f raw_vtx0 = rtm::qvv_mul_point3_no_scale(vtx0, raw_transform_);
    const rtm::vector4f raw_vtx1 = rtm::qvv_mul_point3_no_scale(vtx1, raw_transform_);

    const rtm::vector4f lossy_vtx0 = rtm::qvv_mul_point3_no_scale(vtx0, lossy_transform_);
    const rtm::vector4f lossy_vtx1 = rtm::qvv_mul_point3_no_scale(vtx1, lossy_transform_);

    const rtm::scalarf vtx0_error = rtm::vector_distance3(raw_vtx0, lossy_vtx0);
    const rtm::scalarf vtx1_error = rtm::vector_distance3(raw_vtx1, lossy_vtx1);

    return rtm::scalar_max(vtx0_error, vtx1_error);
}
```

>  Side note, as part of a prior effort to optimize that performance critical function, I had already disabled buffer security checks which are unnecessary here.

The above code is fairly simple. We take two 3D vertices in local space and transform them to world space. We do this for our source data (which is raw) and for our compressed data (which is lossy). We calculate the 3D distance between the raw and lossy vertices and it yields our compression error. We take the maximum value as our final result.

`qvv_mul_point3_no_scale` is [fairly heavy](https://github.com/nfrechette/rtm/blob/bc5e3fa1b00fd1b99c62120281c8b5505237a907/includes/rtm/qvvf.h#L117) instruction wise and it doesn't get fully inlined. Some of it does but the `quat_mul_vector3` it contains does not inline.

By the time the compiler gets to the `vector_distance3` calls, the compiler struggles. Both VS2017 and VS2019 fail to inline 8 instructions (the `vector_length3` [it contains](https://github.com/nfrechette/rtm/blob/bc5e3fa1b00fd1b99c62120281c8b5505237a907/includes/rtm/vector4f.h#L1368)).

```c++
// const rtm::scalarf vtx0_error = rtm::vector_distance3(raw_vtx0, lossy_vtx0);
vsubps      xmm1,xmm0,xmm6
vmovups     xmmword ptr [rsp+20h],xmm1
lea         rcx,[rsp+20h]
vzeroupper
call        rtm::rtm_impl::vector4f_vector_length3::operator rtm::scalarf
```

>  Side note, when AVX is enabled, Visual Studio often ends up attempting to use wider registers when they aren't needed, causing the addition of `vzeroupper` and other artifacts that can degrade performance.

```c++
// inline operator scalarf() const
// {
sub         rsp,18h
mov         rax,qword ptr [__security_cookie]
xor         rax,rsp
mov         qword ptr [rsp],rax
// const scalarf len_sq = vector_length_squared3(input);
vmovups     xmm0,xmmword ptr [rcx]
vmulps      xmm2,xmm0,xmm0
vshufps     xmm1,xmm2,xmm2,1
vaddss      xmm0,xmm2,xmm1
vshufps     xmm2,xmm2,xmm2,2
vaddss      xmm0,xmm0,xmm2
// return scalar_sqrt(len_sq);
vsqrtss     xmm0,xmm0,xmm0
// }
mov         rcx,qword ptr [rsp]
xor         rcx,rsp
call        __security_check_cookie
add         rsp,18h
ret
```

And that is where everything goes wrong. Those 8 instructions calculate the 3D dot product and the square root required to get the length of the vector between our two points. They balloon up to 16 instructions because of the security check overhead. Behind the scenes, VS doesn't fail to inline 8 instructions, it fails to inline something larger than we see when everything goes right.

This was quite surprising to me, because until now I had never seen this behavior kick in this way. Indeed, try as I might, I could not reproduce this behavior in a small playground (yet).

In light of this, and because the math code within Realtime Math is very simple, I have decided to annotate every function to explicitly disable buffer security checks. Not every function requires this but it is easier to be consistent for maintenance. This restores the optimal code generation and `vector_distance3` finally inlines properly.

I am now wondering if I should explicitly force inline short functions...
