---
layout: post
title: "VQM: a quaternion with a scale/shear matrix"
tags: [math]
description: "VQM transforms keep a quaternion and a 3x3 scale/shear matrix. This post derives their product, inverse, and interpolation, and shows why they form a group."
image: /public/transforms/vqm_product_poster.jpg
twitter:
  card: summary_large_image
---
The [VQV transform]({% post_url 2026-11-21-transforms_vqv %}) holds a scale per axis, but it has no place for the shear that a rotation induces when a scaled parent is applied to a rotating child. Its product discards that shear, and its inverse cannot be represented in VQV form. The VQM transform fixes this with one change: it replaces the scale vector with a full 3x3 scale/shear matrix. The rotation stays in a quaternion, and the translation stays separate. The result forms a group, as an affine matrix does, and it interpolates, as a VQV does. Michael Aristidou and Xin Li describe it in *The VQM-Group and its Applications*, and I added it to [Realtime Math 2.4]({% post_url 2026-11-01-rtm_v2.4 %}) as `vqmf` and `vqmd`.

This post is part of the [Representing Affine Transforms series]({% post_url 2026-11-07-transforms_toc %}).

## The VQM transform

A VQM is a rotation quaternion `q`, a translation `v`, and a 3x3 scale/shear matrix `M`:

```
p' = p * M * R + v
```

`M` applies first, followed by the rotation `R` of the quaternion, and finally by the translation. `M` can hold anything that a 3x3 matrix can hold: a scale per axis, a shear, a negative scale, and a reflection. When `M` is diagonal, a VQM is the same as a VQV.

## The quaternion/matrix product

The 3x3 part of the transform is `M * R`: a matrix multiplied with a rotation. RTM has `R` only as a quaternion. How do we multiply a matrix with a quaternion?

With row vectors, each row of `M` represents one axis: the first row is where the X axis goes. Then `M * R` multiplies each row of `M` with `R`:

```
M * R = | row0(M) * R |
        | row1(M) * R |
        | row2(M) * R |
```

Thus we rotate each row of `M` with the quaternion, and `quat_mul_vector3(row, q)` gives `row * R`. This is how `matrix_from_vqm` builds an affine matrix: three rotations of a vector, and the translation in the last row.

The same is true for `M * R^T`: rotate each row of `M` with the conjugate of the quaternion. The product and the inverse below need these two forms.

In practice, I do not always use the quaternion for these products in RTM. When a function needs `R` more than once, it builds the rotation matrix once with `matrix_from_quat`, and then it uses matrix products. Three calls to `quat_mul_vector3` give the same result, but they are slower.

## The product

Let `T1 = [v1, q1, M1]` be a child and `T2 = [v2, q2, M2]` its parent. We expand the two steps:

```
p'' = (p * M1 * R1 + v1) * M2 * R2 + v2
p'' = p * M1 * R1 * M2 * R2 + v1 * M2 * R2 + v2
```

We want the result in the form `p * M3 * R3 + v3`. The translation is easy:

```
v3 = v1 * M2 * R2 + v2
```

For the 3x3 part, we choose the rotation of the result: `R3 = R1 * R2`, as with all the other types. Then `M3` must satisfy:

```
M3 * R1 * R2 = M1 * R1 * M2 * R2
M3           = M1 * R1 * M2 * R1^T
M3           = (M1 * R1) * (M2 * R1^T)
```

We multiplied the two sides on the right with `R2^T * R1^T`, the inverse of `R1 * R2`. That is all. The product is exact, and it does not need a decomposition.

Look at the middle term: `R1 * M2 * R1^T`. This is the term that the VQV post found. It is the scale/shear of the parent, expressed in the frame of the child. A VQV must discard it when `M2` is a non-uniform scale, because the result is not diagonal. A VQM keeps it in `M3`. Thus `M3` can contain shear even when `M1` and `M2` contain only a scale.

With the example of the VQV post (a child with a rotation of 45 degrees about Z, and a parent with a scale of `[1, 2, 1]`):

```
M3 = | 1.5  0.5  0 |
     | 0.5  1.5  0 |
     | 0    0    1 |
```

The point `[1, 0, 0]` goes to `[0.7071, 1.4142, 0]`: the same value as the two steps one after the other.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/vqm_product_poster.jpg" aria-label="The VQV product discards the shear, and the VQM product keeps it">
  <source src="/public/transforms/vqm_product.mp4" type="video/mp4">
  <a href="/public/transforms/vqm_product.mp4">The VQV product discards the shear, and the VQM product keeps it</a>
</video>

*The child, a unit square, turns from 0 to 90 degrees under a parent with a scale of `[1, 2]`. The dashed green outline is the correct result, and the green ring shows where the X axis of the child must be. On the left, the VQV product keeps the scale `[1, 2]` along the axes of the child, thus it discards the shear. On the right, the VQM product keeps the shear in `M3`, and its result is on top of the correct result at each angle. At 45 degrees, `M3` is the matrix above.*

`vqm_mul` computes `M1 * R1` and `M2 * R1^T` with one rotation matrix `R1`, and multiplies them. `M1 * R1` does not depend on the parent. Thus in a hierarchy, where the parent is the result of the previous product, the CPU can compute it in parallel with that product.

### Why it forms a group

* **Closure.** The product of two VQM transforms is a VQM: the derivation above gives its three parts.
* **Associativity.** The quaternion product is associative. For a fixed rotation `R3`, `M3` and `v3` follow from the matrix product, which is associative. Thus `(T1 * T2) * T3` and `T1 * (T2 * T3)` give the same parts.
* **Identity.** `[0, identity, I]`.
* **Inverse.** See the next section.

## The inverse

We solve `p' = p * M * R + v` for `p`:

```
p = (p' - v) * R^T * M^-1
```

The quaternions multiply separately, thus the product of `q` and the quaternion of the inverse must be the identity. Thus `q' = conjugate(q)` and `R' = R^T`. Then `M'` must satisfy:

```
M' * R^T = R^T * M^-1
M'       = R^T * M^-1 * R
```

And the translation is `v' = -v * R^T * M^-1`. Compare this with the VQV post: the VQV needed `S' = R^T * S^-1 * R`, which is not diagonal, and it had to discard it. The VQM keeps it.

The inverse exists when `M` has an inverse: its determinant is not zero. For a zero scale, `vqm_inverse` has a variant with a fallback scale and a threshold, as `vqv_inverse` does. With the example of the VQV post, the point `[1, 0, 0]` goes through `T` and then through `vqm_inverse(T)`, and it comes back to `[1, 0, 0]`.

## One matrix, more than one VQM

There is one subtle point. `M` is a general 3x3 matrix, thus it can also hold a rotation. If that rotation is the inverse of the rotation quaternion, the two cancel. Then the transform is the same as a VQM with the identity rotation and the scale/shear without that rotation.

An example: the VQM `[0, q90, R90^T]` has a rotation of 90 degrees about Z in its quaternion, and a rotation of -90 degrees about Z in `M`. Its 3x3 part is `R90^T * R90 = I`. Thus it moves no point, as the identity `[0, identity, I]` does, but its parts are different.

This is true for each rotation. Let `A` be the 3x3 part of an affine matrix. For each rotation `R`, the VQM `[v, q, A * R^T]` gives the same matrix, because `A * R^T * R = A`. Thus two VQM transforms can move each point to the same position and still have different parts. To compare two VQM transforms, compare their matrices (`matrix_from_vqm`), not their parts.

This can seem strange, but quaternions have a similar property. Each rotation has two quaternions, `q` and `-q`: this is the double cover. If `q` turns by an angle `a` about an axis, `-q` turns by `a - 360` degrees about the same axis: the same orientation, reached the other way around. For example, `q` turns by 90 degrees, and `-q` turns by 270 degrees in the opposite direction. When we convert a rotation matrix to a quaternion, we must choose one of the two. The choice does not change the rotation, but it changes the path of an interpolation. A VQM has the same problem, but the choice is not between two values: it is between all possible rotations.

Can a 3x3 matrix even tell us which part is a rotation? I would argue that it cannot. Each 3x3 matrix is a diagonal scale multiplied by a series of shears, and a rotation is also [a series of shears]({% post_url 2026-11-08-transforms_matrix %}#rotation-as-a-series-of-shears). Thus when we say that `M` holds a rotation, we choose to read some of its shears as a rotation. Each decomposition makes this choice in its own way, for example the Gram-Schmidt process or the polar decomposition, and each one gives a unique answer. But no decomposition can find the parts that the artist set. Once the parts merge into an affine matrix, that information is lost. Thus I recommend that you keep the parts, and that you avoid a decomposition when you can.

Note that this does not break the group. The product rule acts on the parts, and it is exact on the parts:

* The quaternion of the product is always `quat_mul(q1, q2)`. It does not depend on `M1` or `M2`.
* With that rotation, only one `M3` and one `v3` give the correct matrix.

Thus the parts of `(T1 * T2) * T3` and `T1 * (T2 * T3)` are equal, not only their matrices. The conversion to a matrix also keeps the products:

```
matrix_from_vqm(T1 * T2) = matrix_from_vqm(T1) * matrix_from_vqm(T2)
```

A hierarchy of VQM transforms and the same hierarchy of matrices give the same result.

In other words, a VQM is an affine matrix and a unit quaternion that multiply separately. The quaternion of an object space VQM is the product of the local quaternions, as in a hierarchy of VQ or VQV transforms. `M` holds what remains: the scale and the shear.

## Interpolation

Each part interpolates on its own:

* The rotation with `quat_lerp` or `quat_slerp`.
* The translation with a linear interpolation.
* The scale with an exponential interpolation.
* The shear with a linear interpolation of its 6 values.

The linear interpolation of a matrix does not work for a rotation, as the [matrix post]({% post_url 2026-11-08-transforms_matrix %}) shows. But in a VQM, the quaternion holds the rotation, and `M` holds only a scale and a shear. Each value of `M` is a valid scale/shear, and the interpolation of two valid values gives a valid value. There is no constraint to break. `vqm_lerp` does this.

The interpolation acts on the parts, not on the matrices. Thus it is correct only when `M` holds no rotation that the quaternion should hold. Take the two VQM transforms of the identity from the section "One matrix, more than one VQM": `[0, identity, I]` and `[0, q90, R90^T]`. Halfway, `vqm_lerp` gives a rotation of 45 degrees, and `M = (I + R90^T) / 2`. That `M` is a rotation of -45 degrees with a scale of 0.7071 on X and Y. The two rotations cancel, but the scale stays. Thus the two keys move no point, but the halfway transform does. This is the problem of the matrix post again: a linear interpolation of a rotation in `M`.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/vqm_identity_lerp_poster.jpg" aria-label="Two VQM keys of the identity interpolate to a smaller transform">
  <source src="/public/transforms/vqm_identity_lerp.mp4" type="video/mp4">
  <a href="/public/transforms/vqm_identity_lerp.mp4">Two VQM keys of the identity interpolate to a smaller transform</a>
</video>

*The two keys are the identity: `[0, identity, I]` and `[0, q90, R90^T]`. On the left, `quat_lerp` turns the quaternion toward 90 degrees. In the middle, the lerp of `M` turns by the opposite angle, but its rows also become shorter. On the right is their product: the two turns almost cancel, but the scale stays. Halfway, the F is 0.71 times its size, and the dashed green outline shows the identity.*

Thus the keys of an interpolation must come from the same source: parts that an artist authors, or the same conversion from a matrix.

A scale interpolates better with an exponential interpolation: halfway between a scale of 1 and a scale of 4, the result is 2, not 2.5. Two scales combine with a multiplication, not an addition, thus an interpolation of a scale must also be multiplicative. An exponential interpolation is a linear interpolation of the logarithm of each value. Daniel Holden explains this in the section "Lerp and Eerp" of [Scalar Velocity](https://theorangeduck.com/page/scalar-velocity). `vqm_slerp` interpolates the diagonal of `M` with `vector_eerp`. For the shear, it divides each column of `M` by its diagonal value, interpolates the result linearly, and then multiplies again with the new diagonal. An exponential interpolation needs two values with the same sign that are not zero. For a scale that changes sign or that is zero, `vqm_slerp` uses a linear interpolation on that axis.

## Where does the rotation go?

The same matrix can map to more than one VQM, thus we must choose how to split its 3x3 part between the quaternion and `M`. RTM makes this choice in two places: in each product, and when it converts a matrix.

### Why not a symmetric M?

A VQQV keeps only a symmetric scale/shear `K`. The polar decomposition `A = K * U` gives the rest, a rotation `U`, to the quaternion. Can we do the same with a VQM, and keep only a symmetric `M`? The matrix of the transform does not change: `K * U * R` is equal to `M * R`. But I do not do this in RTM, for three reasons.

**The cost.** The product gives `M3 = (M1 * R1) * (M2 * R1^T)`, and in general, that matrix is not symmetric. To keep a symmetric `M`, each product needs a polar decomposition, with an iterative algorithm, as we will see in the VQQV post.

**The product rule.** The rotation `U` of each polar decomposition goes into the quaternion of the result. Then the quaternion of a product is no longer `quat_mul(q1, q2)`, and the quaternion and the matrix no longer multiply separately. The quaternion of an object space VQM is then not the product of the local rotations.

**The path of the interpolation.** This is the most important reason. Is there a rotation in a shear? That depends on how we decompose it. Take the 2D shear `x' = x + 2 * y`:

```
M = | 1  0 |
    | 2  1 |
```

The polar decomposition writes it as `M = K * U`, with a rotation `U` of -45 degrees and:

```
K = | 0.7071  0.7071 |
    | 0.7071  2.1213 |
```

Thus two VQM transforms give the same matrix: `[0, identity, M]` (the shear form) and `[0, U, K]` (the polar form). But they do not interpolate in the same way. We interpolate each one from the identity with `vqm_lerp`:

* In the shear form, `M` is a shear at each step: `x' = x + 2 * t * y`. Each point moves on a straight line, parallel to the X axis.
* In the polar form, `K` interpolates linearly, but the quaternion turns. Each point moves on a curve.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/shear_interpolation_poster.jpg" aria-label="A shear interpolates on straight lines, and its polar form interpolates on curves">
  <source src="/public/transforms/shear_interpolation.mp4" type="video/mp4">
  <a href="/public/transforms/shear_interpolation.mp4">A shear interpolates on straight lines, and its polar form interpolates on curves</a>
</video>

*The two sides start at the identity and end at the same shear, x' = x + 2 * y. The orange lines are the paths of the corners. On the left, the shear form interpolates M, and the corners move on straight lines. On the right, the polar form interpolates K and the quaternion, and the corners move on curves.*

Halfway, the corner `[1, 1]` is at `[2, 1]` in the shear form, and at `[1.8478, 1.3066]` in the polar form: **0.3423** apart. The two forms have the same ends, but not the same path.

The shear form does not keep the rows of `M` orthogonal: halfway, the dot product of the X and Y rows is 1. For a shear, this is correct. In the matrix post, a linear interpolation broke a rotation, because a rotation must keep its rows orthogonal. A shear has no such constraint: a linear interpolation of two shears is a shear.

Thus a linear interpolation treats `M` as a scale/shear, and the quaternion holds the rotation of the joint. If we move a part of the shear into the quaternion, that part turns on an arc, and the transforms between the keys change.

*Side note: when the determinant is positive, the polar decomposition is unique and continuous. Thus this is not the jump that we will see in the VQQV post. Both paths are smooth, but they are different.*

### From a matrix

`vqm_from_matrix` converts an affine matrix to a VQM. As we saw, the choice of `R` is free: `M = A * R^T` gives the same matrix for each `R`. RTM chooses `R` with the Gram-Schmidt process on the rows of `A`, the largest row first. The third axis has the sign that gives `R` a determinant of +1. Thus `R` is always a pure rotation, and a reflection, if any, goes in `M`. When `A` has no shear and a positive scale, `R` is the original rotation, and `M` is the original scale.

The same matrix always gives the same VQM. But with shear, the rows of `A` are not orthogonal, and the rotation depends on the row that the process starts with. For the shear of the previous section, the process starts with the largest row, `[2, 1]`. It returns a rotation of -63.43 degrees, and `M = [0.4472, 0.8944; 0, 2.2361]`: neither the shear form nor the polar form. If two keys have a different largest row, the function can choose a rotation for each key that is not close to the other, and the interpolation between them is wrong.

How far apart can the two rotations be? Take the example of the VQV post again: a child turns about Z under a parent with a scale of `[1, k, 1]`. At 45 degrees, the X row and the Y row of the object space matrix have the same length, thus the largest row changes there. The rotation that `vqm_from_matrix` returns jumps by `atan(k) - atan(1 / k)`: **5.45** degrees for `k = 1.1`, and **36.87** degrees for `k = 2`. The keys stay exact, because `M` compensates. But with `k = 2` and two keys at 44 and 46 degrees, `vqm_lerp` is **0.081** away from the true transform on a unit axis halfway. Two keys on the same side of 45 degrees give 0.0002.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/vqm_gram_schmidt_jump_poster.jpg" aria-label="Keys from vqm_from_matrix jump in rotation, and keys from the parts do not">
  <source src="/public/transforms/vqm_gram_schmidt_jump.mp4" type="video/mp4">
  <a href="/public/transforms/vqm_gram_schmidt_jump.mp4">Keys from vqm_from_matrix jump in rotation, and keys from the parts do not</a>
</video>

*The child turns from 30 to 60 degrees under a parent with a scale of `[1, 2]`, with a key every 5 degrees. The dotted grey lines show the rotation of the quaternion alone, and the dashed green outline is the true transform. On the left, the keys come from `vqm_from_matrix`. Between the keys at 42.5 and 47.5 degrees, their quaternions are 24.6 and 65.4 degrees, and the result moves away from the true transform by up to 0.082. On the right, the keys come from the parts, and the quaternion follows the child.*

A decomposition that is continuous removes the jump. A Gram-Schmidt process with a fixed order of the rows gives an error of 0.0002 on the same keys, and a polar decomposition gives 0.0003. In this example, the polar decomposition also finds the rotation of the child. Thus the jump is a problem only for a VQM that comes from a matrix with shear and a clearly non-uniform scale, and only between the two keys around the change.

A matrix alone does not tell us which part is a shear. Thus I recommend that you build a VQM from its parts (with `vqm_set`, or with a product) when you can. Use `vqm_from_matrix` only when you have nothing but a matrix.

## Memory and cost

A VQM has 16 floats: 4 for the quaternion, 3 for the translation, and 9 for `M`. RTM puts them in four SIMD registers (64 bytes for `vqmf`): the rotation, the translation, and the first two rows of `M`. The third row of `M` goes in the unused `[w]` lanes of the three other registers.

The product computes three 3x3 matrix products, thus it costs more than a VQV product. To limit this cost, I added a flag for when `M` is exactly the identity: a quiet NaN with a fixed payload in the `m22` slot. A valid `M` is finite, thus this value cannot be a real `m22`. With the flag, `vqm_mul`, `vqm_mul_point3`, `vqm_inverse`, `vqm_lerp`, and `vqm_slerp` skip `M`. For example, `vqm_mul` with a parent that holds the flag computes the same operations as `vq_mul`.

How large is the difference? I measured each product with `float` values on an Apple M1 Max (NEON), compiled with clang at `-O2`. The throughput is the time of one product when the products do not depend on each other. The latency is the time of one product in a chain of 8 products, as in a hierarchy, where each product needs the result of the previous one. The values are in nanoseconds for one product:

| Product | Throughput | Latency |
|---|---|---|
| `matrix_mul` (3x4) | 1.30 | 6.01 |
| `vq_mul` | 4.98 | 7.53 |
| `vqv_mul`, positive scale | 5.57 | 7.53 |
| `vqv_mul`, negative scale | 24.87 | 59.12 |
| `vqm_mul`, the two inputs have the flag | 5.21 | 8.30 |
| `vqm_mul`, only the parent has the flag | 5.19 | |
| `vqm_mul`, no flag | 12.50 | 18.28 |

Without the flag, `vqm_mul` costs **2.2** times a `vqv_mul` with a positive scale in throughput, and **2.4** times in a chain. With the flag, it costs about the same as `vq_mul`: **5%** more in throughput, and **10%** more in a chain. A VQV with a negative scale is the slowest product of the list: `vqv_mul` goes through two matrices, removes the scale, and converts the result back to a quaternion, as the VQV post explains. It costs **2.0** times a `vqm_mul` without the flag in throughput, and **3.2** times in a chain. A VQM needs no such path, because `M` holds the reflection. A chain of rigid joints keeps the flag, because the product copies the `M` of the child when the parent has the flag. The 3x4 matrix product needs no quaternion operations, and it is the fastest: its throughput is **9.6** times better than `vqm_mul` without the flag. In a chain, the difference is only **3** times. I measured only this CPU. On x64, the ratios can be different.

## VQV in, VQM out

A VQV converts to a VQM with no loss: `vqm_set(rotation, translation, scale)` puts the scale on the diagonal of `M`. This is the approach that I recommend: keep VQV for the local transforms, where the artists author them and where they compress well, and use VQM for the products in a hierarchy. The local poses keep their format, and the object space poses are now correct.

## Conclusion

The VQM keeps what is good in a VQV: a normalized quaternion for the rotation, and parts that interpolate on their own. It adds what the VQV is missing: a place for the shear. Its product, its inverse, and its interpolation need no decomposition, and the product is associative. The cost is 16 bytes more than a VQV, and a slower product when the scale/shear part is not the identity.

In the last post of the series, we look at a different way to hold the scale/shear part: the scale orientation of OpenUSD.

## References

* Michael Aristidou and Xin Li, *The VQM-Group and its Applications*
* [RTM: vqmf.h](https://github.com/nfrechette/rtm/blob/develop/includes/rtm/vqmf.h)
* [RTM: types supported](https://github.com/nfrechette/rtm/blob/develop/docs/types_supported.md)
