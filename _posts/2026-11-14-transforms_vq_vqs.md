---
layout: post
title: "VQ and VQS"
tags: [math]
description: "VQ and VQS transforms keep the rotation in a quaternion. This post explains why their piecewise multiplication works, and why the scale must be uniform."
image: /public/transforms/vqs_product_poster.jpg
twitter:
  card: summary_large_image
---
In the [previous post]({% post_url 2026-11-08-transforms_matrix %}), we saw that an affine matrix mixes the rotation, scale, and shear in the same 9 values. It can drift, and it does not interpolate. The VQ and VQS transforms do the opposite: they keep each part separate, and they represent the rotation as a quaternion. As such, a VQ cannot hold a scale, and a VQS can hold only a uniform scale. Neither can represent shear. In this post, we look at how they work, and why that scale must be uniform.

This post is part of the [Representing Affine Transforms series]({% post_url 2026-11-07-transforms_toc %}).

As in the rest of the series, vectors are row vectors: `p * R` rotates the point `p` with the rotation matrix `R`. `R^T` is the transpose of `R`, which is also its inverse. In RTM, `quat_mul_vector3(p, q)` computes `p * R`, where `R` is the rotation matrix of the quaternion `q`.

## VQ: a rotation and a translation

A VQ transform (`vqf` in RTM) is a rotation quaternion `q` and a translation `v`. It transforms a point as follows:

```
p' = p * R + v
```

The rotation applies first, followed by the translation. This is a rigid transform: it preserves the lengths of line segments and the angles between them. It needs 7 floats. In RTM, it uses two SIMD registers (8 floats, 32 bytes), because the translation has an unused `[w]` lane.

### Multiplication

Let `T1 = [v1, q1]` and `T2 = [v2, q2]`. `T1` transforms the point first, then `T2` transforms the result. To find the product, we expand the two steps:

```
p'' = (p * R1 + v1) * R2 + v2
p'' = p * (R1 * R2) + (v1 * R2 + v2)
```

This is what we want. The result has the same form as a VQ: a rotation, and then a translation. Thus the product is `T3 = [v3, q3]` with:

```
R3 = R1 * R2        ->  q3 = quat_mul(q1, q2)
v3 = v1 * R2 + v2   ->  v3 = quat_mul_vector3(v1, q2) + v2
```

Each part of the result needs only the parts of the inputs. The rotation of the child combines with the rotation of the parent. The translation of the child turns with the parent rotation, and then the parent translation adds to it. This is `vq_mul(lhs, rhs)` in RTM, with the order `local_to_world = vq_mul(local_to_object, object_to_world)`.

### Inverse

We solve `p' = p * R + v` for `p`:

```
p = (p' - v) * R^T
p = p' * R^T + (-v * R^T)
```

This is again a VQ: `q' = conjugate(q)` and `v' = -v * R^T`. The inverse is exact, and it is cheap: a quaternion conjugate only flips the sign of three components.

The product of two VQ transforms is a VQ, the product is associative, and each VQ has an exact inverse. Thus VQ transforms form a group, as matrices do. In a hierarchy, no information is lost.

## VQS: add a uniform scale

A VQS transform (`vqsf` in RTM) adds a scalar scale `s`:

```
p' = p * s * R + v
```

The scale applies first, followed by the rotation, then the translation. In RTM, I put the scale in the unused `[w]` lane of the translation. Thus a VQS uses the same two registers (**32 bytes**) as a VQ, and its scale costs no extra memory.

### Multiplication

We expand the two steps again:

```
p'' = (p * s1 * R1 + v1) * s2 * R2 + v2
p'' = p * s1 * R1 * s2 * R2 + v1 * s2 * R2 + v2
```

The first term has the form `s1 * R1 * s2 * R2`. To make it a VQS, we need the two scales together and the two rotations together. Can we move `s2` to the left of `R1`? Yes, because a scalar commutes with any matrix: `R1 * s2 = s2 * R1`. There is a nice geometric reason for this. With uniform scale, it does not matter whether we scale first and rotate afterwards or rotate first and scale afterwards: the result is the same. Thus:

```
s1 * R1 * s2 * R2 = (s1 * s2) * (R1 * R2)
```

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/uniform_scale_commutes_poster.jpg" aria-label="A uniform scale and a rotation give the same result in either order">
  <source src="/public/transforms/uniform_scale_commutes.mp4" type="video/mp4">
  <a href="/public/transforms/uniform_scale_commutes.mp4">A uniform scale and a rotation give the same result in either order</a>
</video>

*The left side scales the letter F by 1.6 and then rotates it by 40 degrees. The right side rotates it first and then scales it. The two results are the same.*

And the product is `T3 = [v3, q3, s3]` with:

```
s3 = s1 * s2
q3 = quat_mul(q1, q2)
v3 = quat_mul_vector3(v1 * s2, q2) + v2
```

Again, each part of the result needs only the parts of the inputs. This is exactly what `vqs_mul` computes. The parent scale also applies to the child translation, because the parent scales the full space of the child, its offset included.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/vqs_product_poster.jpg" aria-label="A child VQS and then its parent VQS give the same result as their product">
  <source src="/public/transforms/vqs_product.mp4" type="video/mp4">
  <a href="/public/transforms/vqs_product.mp4">A child VQS and then its parent VQS give the same result as their product</a>
</video>

*The left side applies the child VQS, and then the parent VQS. The dashed purple F is the result of the child alone. The right side applies the product in one step: the scales multiply (1.25 * 1.2 = 1.5), and the angles add (30 + 90 = 120 degrees). The parent scales the child translation `[1.5, 0]` to `[1.8, 0]`, and its rotation turns it to `[0, 1.8]`. The parent translation then adds `[1, 0]`. The two results are the same.*

### Inverse

We solve `p' = p * s * R + v` for `p`:

```
p = (p' - v) * R^T * (1 / s)
p = p' * (1 / s) * R^T + (-(v / s) * R^T)
```

We used the same property: `1 / s` commutes with `R^T`. Thus the inverse is again a VQS: `s' = 1 / s`, `q' = conjugate(q)`, and `v' = -(v / s) * R^T`. If the scale is zero, the inverse does not exist. For this case, RTM has a variant of `vqs_inverse` that uses a fallback scale below a threshold.

VQS transforms also form a group.

### Negative scale

A negative uniform scale is a reflection of all three axes (a point reflection). It is still a scalar, thus it still commutes with the rotation, and the multiplication and the inverse stay exact. `vqs_from_matrix` can find it again from a matrix: if the determinant of the matrix is negative and the scale is uniform, all three axes have a reflection.

## Why it must be uniform

The multiplication works because of one step: we moved the scale of the parent `s2` past the rotation of the child `R1`. That is true only for a scalar, or a scale that is the same on the three axes. Sadly, a non-uniform scale `S2 = diag(sx, sy, sz)` does not commute with a rotation:

```
R1 * S2 != S2 * R1
```

The two sides are equal only for special rotations, for example a rotation about an axis where the two other scale values are equal. In the post about VQV, we will see what happens when we ignore this.

## How VQ and VQS improve on matrices

* **Smaller.** 8 floats (32 bytes) in place of 12 (48 bytes), thus **33%** less memory.
* **No drift into shear.** The rotation is a quaternion. If it drifts, one normalization gives a valid rotation again. A VQS cannot hold shear at all.
* **They interpolate.** Each part interpolates on its own: the rotation with a `quat_lerp` (a normalized lerp) or a `quat_slerp`, the translation and the scale with a linear or exponential interpolation.
* **No decomposition.** The parts are already separate. An animation clip stores them as separate tracks, and the [Animation Compression Library](https://github.com/nfrechette/acl) compresses each one on its own.
* **Cheap to invert.** A conjugate, a reciprocal, and one rotation of a vector.

There is one drawback: the transform of a point. `quat_mul_vector3` uses more instructions than a matrix product with a point. Sometimes we must transform a lot of points with the same transform, for example the vertices of a mesh. In that case, I recommend that you convert the VQS to a matrix once with `matrix_from_vqs`, and then use the matrix.

## Conclusion

VQ and VQS are compact, they do not drift into shear, they interpolate, and they form a group. Their multiplication works piece by piece because a uniform scale commutes with a rotation. For rigid objects and for objects with a uniform scale, I recommend them over matrices.

However, non-uniform scale is quite useful: a squash and a stretch on a character, or a box that is longer on one axis. In the next post, we add a scale per axis, and we look at the problems that come with it.
