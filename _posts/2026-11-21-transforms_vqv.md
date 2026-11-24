---
layout: post
title: "VQV and non-uniform scale"
tags: [math]
description: "VQV transforms add a scale per axis to a VQS. This post shows the shear that their product discards, and why the inverse fails."
image: /public/transforms/non_uniform_scale_shear_poster.jpg
twitter:
  card: summary_large_image
---
A [VQS]({% post_url 2026-11-14-transforms_vq_vqs %}) holds only a uniform scale. Artists want more: a scale per axis to squash and stretch a character, or to make a box longer along one axis. The VQV transform is thus: a quaternion, a translation, and a 3D scale. Two examples you may have come across: `FTransform` in Unreal Engine is a VQV and `UsdSkelAnimation` uses a VQV for storage (and it converts them to matrices when it needs to manipulate them). It works well enough, but it is not mathematically correct. It does not form a group, its product discards information, and its inverse is not a true inverse. This post explains why, and when it is safe to use.

This post is part of the [Representing Affine Transforms series]({% post_url 2026-11-07-transforms_toc %}).

## The VQV transform

A VQV (`vqvf` in RTM) is a rotation quaternion `q`, a translation `v`, and a scale `S = diag(sx, sy, sz)`:

```
p' = p * S * R + v
```

The scale is applied first, followed by the rotation, and the translation. It holds 10 floats. In RTM, it uses three SIMD registers (12 floats, 48 bytes).

The transform of one point with one VQV is exact. However, the problems start when we multiply two VQV transforms.

## The product

Let `T1 = [v1, q1, S1]` be a child and `T2 = [v2, q2, S2]` its parent. We expand the two steps, as in the VQS post:

```
p'' = (p * S1 * R1 + v1) * S2 * R2 + v2
p'' = p * S1 * R1 * S2 * R2 + v1 * S2 * R2 + v2
```

With a uniform scale, we moved `S2` to the left of `R1`. With a non-uniform scale, we cannot: `R1 * S2 != S2 * R1`. But a VQV product does it anyway:

```
S3 = S1 * S2              (per component)
q3 = quat_mul(q1, q2)
v3 = quat_mul_vector3(v1 * S2, q2) + v2
```

This is what `vqv_mul` in RTM computes. The translation part is correct: `v1 * S2 * R2 + v2` is the true value. The 3x3 part is not. The true 3x3 part is `S1 * R1 * S2 * R2`, but the VQV gives `S1 * S2 * R1 * R2`.

## The product discards the shear

The [matrix post]({% post_url 2026-11-08-transforms_matrix %}#a-rotation-and-a-non-uniform-scale-create-shear) shows the cause: a rotation followed by a non-uniform scale creates shear. With `R1 * S2 = (R1 * S2 * R1^T) * R1`, the true 3x3 part is:

```
S1 * (R1 * S2 * R1^T) * R1 * R2
```

The matrix `R1 * S2 * R1^T` is the scale of the parent, expressed in the frame of the child. In general, it is not diagonal: it holds shear. The VQV product replaces it with `S2`, and thus discards the shear.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/non_uniform_scale_shear_poster.jpg" aria-label="A non-uniform scale after a rotation creates shear">
  <source src="/public/transforms/non_uniform_scale_shear.mp4" type="video/mp4">
  <a href="/public/transforms/non_uniform_scale_shear.mp4">A non-uniform scale after a rotation creates shear</a>
</video>

*The left side scales a square by `[1, 2]` and then rotates it by 45 degrees: the result is a rectangle with a rotation, and its corner stays at 90 degrees. The right side rotates the square first and then scales it: the result is a rhombus, and its corner becomes 53 degrees.*

The left side of the video is what the VQV product computes: the scale, then the rotation. The right side is the correct result: the rotation of the child, then the scale of the parent. With a point: the child has a rotation of 45 degrees about Z, and the parent has a scale of `[1, 2, 1]`. The point `[1, 0, 0]` through the child, and then through the parent, goes to `[0.7071, 1.4142, 0]`. Through the VQV product, it goes to `[0.7071, 0.7071, 0]`.

The shear has no place to go. The 3x3 part of a VQV, `S * R`, always has orthogonal rows, and a matrix with shear does not. We cannot mix the shear with the rotation either: a rotation preserves the angles between lines while shear changes them.

## The inverse is not an inverse

The true inverse of `p' = p * S * R + v` is:

```
p = (p' - v) * R^T * S^-1
```

For a VQV, the 3x3 part must have the form `S' * R'`. With `R' = R^T`, we need:

```
S' * R^T = R^T * S^-1     ->     S' = R^T * S^-1 * R
```

The same problem: `R^T * S^-1 * R` is a scale in a turned frame, and it is not diagonal. Thus the true inverse is not a VQV. `vqv_inverse` returns `S' = S^-1`, `q' = conjugate(q)`, and `v' = -(v * S^-1) * R^T`.

Does `inverse(T)` undo `T`? Only in one direction, and this is a strange property. With the VQV product, `T * inverse(T)` is the identity: the scales cancel, the rotations cancel, and the translations cancel. But `inverse(T) * T` is not the identity. And `inverse(T)` does not undo `T` on a point. Take `T` with a rotation of 45 degrees about Z, a scale of `[1, 2, 1]`, and a translation of `[1, 0, 0]`:

* `T * inverse(T)` has a translation of `[0, 0, 0]`.
* `inverse(T) * T` has a translation of `[-0.5, 0.5, 0]`.

Without the translation, the point `[1, 0, 0]` goes to `[0.7071, 0.7071, 0]` through `T`. Through `inverse(T)`, it comes back to `[0.75, -0.25, 0]`, not to `[1, 0, 0]`.

A left inverse that is not a right inverse is a sign that the structure is not a group. The product is also not associative: `(A * B) * C` and `A * (B * C)` can give different results, and both can be different from the three steps applied to a point one after the other. In a hierarchy, the result depends on the order in which we accumulate the transforms. This is problematic because it is common to cache transform concatenations in a hierarchy and with VQV this is ill advised.

We can reduce the problem with functions that multiply by the inverse directly. They never store the inverse in a VQV. RTM 2.5 adds three of them, and it deprecates `vqv_inverse`.

For a point, `vqv_inverse_mul_point3(point, vqv)` computes `p = (p' - v) * R^T * S^-1`: first the translation, then the inverse rotation, then the inverse scale. The result is exact: in the example above, the point comes back to `[1, 0, 0]`.

For the product of two transforms, we need two functions, because without a group, we cannot get one from the other:

* **`vqv_mul_inverse(A, B)` computes `A * inverse(B)`.** This converts a transform from object space to local space: `child_local = vqv_mul_inverse(child_object, parent_object)`. Its translation is exact: `(vA - vB) * RB^T * SB^-1`. Its rotation is `RA * RB^T`, and its scale is `SA / SB`. The 3x3 part of the true product, `SA * RA * RB^T * SB^-1`, still has shear in general, thus the result still loses information. But it loses it in one step, not in two. With positive scales, `vqv_mul(vqv_mul_inverse(A, B), B)` gives `A` again.
* **`vqv_inverse_mul(A, B)` computes `inverse(A) * B`.** This is the transform used for skinning: `vqv_inverse_mul(bind_object, current_object)` moves a vertex from the bind pose to the current pose. Its rotation is `RA^T * RB`, and its scale is `SB / SA`. Its translation, `vB - vA * (SB / SA) * RA^T * RB`, sends the position of the joint in the bind pose, `vA`, exactly to its position in the current pose, `vB`. Thus with positive scales, `vqv_mul(A, vqv_inverse_mul(A, B))` gives `B` again.

  The 3x3 part of the true product is `RA^T * (SA^-1 * SB) * RB`. The two scales are diagonal, thus they combine. If a joint has the same scale in the two poses, `SA^-1 * SB` is the identity, and the result is the exact product, even with a non-uniform scale. A stored inverse does not give this exact result. Its translation, `-(vA * SA^-1) * RA^T`, applies the inverse scale before the inverse rotation, but the true inverse applies the inverse rotation first.

  When the two scales are different, no VQV can hold the true product, and the 3x3 part is wrong. But the error of a vertex `p` is a product with `p - vA`. Thus the position of the joint is still exact, and the error grows with the distance from the joint, not with the distance from the origin of object space.

## When it works

VQV is exact in these cases:

* **The scale of the parent is uniform.** Then `S2` commutes with `R1`. A non-uniform scale on a leaf joint (with no children) is safe, because no child can rotate and introduce shear.
* **The child has no rotation relative to the parent.** Then `R1` is the identity. The same is true for a rotation that keeps the axes of the parent scale, for example a rotation about Z when `sx = sy`, or a rotation of 180 degrees about one axis.
* **One transform at a time.** The transform of a point with one VQV is exact. Thus a chain of transforms applied to a point one after the other is exact. However, because VQVs are not associative, we cannot multiply the transforms first before applying the result to a point.

In the other cases, the error is small when the scale is close to 1, or when the rotation of the child is small. This is why it works well enough in practice: most characters have no scale, and most props have a uniform scale.

When it fails, the artists see it. A child under a parent with a non-uniform scale does not stretch along the axes of the parent: it stretches along its own axes.

## Interpolation

Each part of a VQV interpolates on its own: the quaternion with a slerp, and the scale and the translation with an exponential or linear interpolation. When an artist sets the keys, in the local space of a joint, the result is correct. This is the usual case in an animation clip. As long as blends are done in local space, they will behave correctly.

With a negative scale, this is true only when the clips agree on which axes have the reflection. As we will see in [the next section](#negative-scale), the same transform has more than one VQV. A reflection of the X axis, followed by a rotation of 180 degrees about Z, is a reflection of the Y axis:

```
diag(-1, 1, 1) * Rz(180) = diag(-1, 1, 1) * diag(-1, -1, 1) = diag(1, -1, 1)
```

One clip can hold a mirrored transform with a scale of `[-1, 1, 1]`, and another clip can hold the same transform with a scale of `[1, -1, 1]`. A blend of 50% then gives a scale of `[0, 0, 1]`: the joint shrinks to a line, and its rotation turns by 90 degrees. But the two transforms were the same. The keys of a single clip can have the same problem, when a decomposition puts the reflection on a different axis from one frame to the next. An exponential interpolation also needs two keys with the same sign, because the logarithm of a negative scale does not exist.

In object space, each transform is a product, and the VQV product discards the shear. With a positive scale, the product is continuous, thus the interpolation does not jump. But it takes a wrong path, with a wrong scale.

Take the example from [the shear section](#the-product-discards-the-shear): the parent has a scale of `[1, 2, 1]`, and the child turns from 0 to 90 degrees about Z. Assume that we need the transform of the child in object space, for example to blend it. We compute it at two keys, 0 and 90 degrees, and we interpolate between them. The X axis of the child must go to `[0.7071, 1.4142, 0]` at 45 degrees, and to `[0, 2, 0]` at 90 degrees. There are two ways to compute the keys:

* **Keys from the VQV product.** We multiply the VQV of the child by the VQV of the parent. The two keys have a scale of `[1, 2, 1]`. At 90 degrees, the X axis goes to `[0, 1, 0]`: the key is already wrong. Halfway, the X axis goes to `[0.7071, 0.7071, 0]`. The child stretches along its own axes, not along the axes of the parent.
* **Exact keys.** We multiply the two transforms as matrices, and we decompose the result into a VQV. At 0 and 90 degrees, the true transform has no shear, thus the decomposition is exact: a scale of `[1, 2, 1]` at 0 degrees, and a scale of `[2, 1, 1]` with a rotation of 90 degrees. The two keys are correct. Halfway, the interpolation gives a scale of `[1.5, 1.5, 1]`, and the X axis goes to `[1.0607, 1.0607, 0]`. The true transform at 45 degrees has shear, and no VQV can hold it. Thus even exact keys give a wrong path between them.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/vqv_interpolation_poster.jpg" aria-label="The interpolation of a child under a parent with a non-uniform scale, with three types of keys">
  <source src="/public/transforms/vqv_interpolation.mp4" type="video/mp4">
  <a href="/public/transforms/vqv_interpolation.mp4">The interpolation of a child under a parent with a non-uniform scale, with three types of keys</a>
</video>

*The child turns from 0 to 90 degrees under a parent with a scale of `[1, 2]`. The green ring and the dashed grey line show where the X axis of the child must be. The left side is the true product. The middle uses keys from the VQV product: the X axis stays on a circle of radius 1. The right side uses exact keys: it is correct at the two keys, but not between them.*

Thus, I recommend that you interpolate the local transforms first, and then multiply them. An interpolation of the products is wrong when a parent has a non-uniform scale.

### Blends in object space

Sometimes a blend must happen in object space. For example, an aim layer keeps the head of a character pointed at a target, regardless of the pose of the spine. For this, I recommend that you put only the rotations in object space, and that you keep the scale and the translation in local space:

1. For each pose, compute a chain of rotations only: `Q(j) = quat_mul(q(j), Q(parent))`. The scale and the translation do not enter the chain.
2. Blend each `Q(j)` with a slerp. Blend the scale and the translation in local space.
3. Convert back to local space with the blended rotation of the parent: `q(j) = quat_mul(Q(j), quat_conjugate(Q(parent)))`.
4. Compute the pose with the usual VQV product.

A product of quaternions loses nothing and is associative, and the inverse of a rotation is its conjugate. Thus the round trip from local space to object space and back is exact. Nothing goes through a matrix, thus there is no decomposition and no ambiguity. The scale keeps the values that the artist set. Each joint needs only one quaternion product in each direction.

However, the chain computes `R1 * R2`, the same rotation as the VQV product. When a parent has a non-uniform or a negative scale, this is not the true orientation of the child. The true orientation also has the shear, or the mirror that we will see in [the next section](#negative-scale). The blend is still smooth, but it does not keep the visual orientation exactly. For example, under a parent with a scale of `[-1, 1, 1]`, the head turns the wrong way. With a positive uniform scale, the chain gives the true orientation. The caveats of a scale blend in local space also stay: the clips must agree on the axes of each reflection. Last, the positions do not blend in object space. Each translation blends in local space, thus a joint moves along the arcs of its parents, not on a straight line. This is usually what we want.

Why not blend the translation and the scale in object space too? Their conversion is exact. The VQV product computes the translation exactly, and `vqv_inverse_mul_point3` brings a position back to local space. The scale in object space is the product of the scale values along the chain, and a division brings it back. But the blend changes the result. A lerp moves each position on a straight line, thus the bones change length. If a bone turns by 90 degrees between two poses, it is **29%** shorter halfway. With a layer, a joint keeps its position while its parent moves, and the bone stretches. To keep a position in object space, I recommend IK, not a blend. For the scale, a product of non-uniform scale values is not a scale along the axes of object space, thus its blend has no clear meaning. With a uniform scale and an exponential interpolation, the blend in object space gives the same result as the blend in local space. A layer can still use it to keep the scale of a joint, regardless of the scale of its parents.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/vqv_object_space_blend_poster.jpg" aria-label="A layered blend of the head rotation in local space, in object space, and in object space under a mirrored spine">
  <source src="/public/transforms/vqv_object_space_blend.mp4" type="video/mp4">
  <a href="/public/transforms/vqv_object_space_blend.mp4">A layered blend of the head rotation in local space, in object space, and in object space under a mirrored spine</a>
</video>

*A layer takes the spine from a base pose that leans by up to 20 degrees, and the head from an aim pose. The grey figure is the aim pose, and the dashed green line is the gaze that the layer must keep. On the left, the head rotation blends in local space, thus the head turns with the spine. In the middle, the rotations blend in object space, and the gaze stays on the line. On the right, the spine has a scale of `[-1, 1]`. The rotation chain ignores the mirror, thus the head turns the wrong way, by twice the lean.*

## Negative scale

A non-uniform scale already makes the product discard the shear. A negative scale adds two more problems. The first is in the decomposition. A scale of `[-1, -1, 1]` is a reflection of two axes, and that is the same as a rotation of 180 degrees about Z. Thus the same matrix has more than one VQV: one with the negative scale, and one with the rotation. A reflection of one axis has the same problem: we cannot know which axis it was on. In RTM, `vqv_from_matrix` puts the reflection on the axis with the largest scale.

The second problem is in the product. The VQV product moves the parent scale `S2` past the child rotation `R1`. Let us write `S2` as its signs `N2`, a diagonal of 1 and -1, times its absolute value `|S2|`. The signs can move past the rotation exactly, because `N2` is its own inverse:

```
R1 * N2 = N2 * (N2 * R1 * N2)
```

`N2 * R1 * N2` is the rotation of the child, seen in the mirror of the parent. A reflection preserves the lengths and the angles, thus it adds no shear. But the VQV product keeps `R1`, not its mirror. For example, the child has a rotation of 90 degrees about Z, and the parent has a scale of `[-1, 1, 1]`. The X axis of the child must go to `[0, 1, 0]`. The VQV product sends it to `[0, -1, 0]`, an error of 180 degrees. The correct VQV has a scale of `[-1, 1, 1]` and a rotation of -90 degrees: the mirror reverses the turn of the child.

<video width="1280" height="720" autoplay loop muted playsinline poster="/public/transforms/vqv_mirror_product_poster.jpg" aria-label="A child rotation under a parent mirror: the true product, the VQV product, and the mirrored rotation">
  <source src="/public/transforms/vqv_mirror_product.mp4" type="video/mp4">
  <a href="/public/transforms/vqv_mirror_product.mp4">A child rotation under a parent mirror: the true product, the VQV product, and the mirrored rotation</a>
</video>

*The child turns from 0 to 90 degrees under a parent with a scale of `[-1, 1]`. The dashed grey line in the middle of each panel is the mirror. The green ring shows where the X axis of the child must be. The left side is the true product: the rotation, then the mirror. The middle is the VQV product: the mirror, then the same rotation, thus the X axis turns the wrong way. The right side is the VQV with the mirrored rotation: it turns by -90 degrees and matches the true product.*

Thus, when an input scale is negative, `vqv_mul` multiplies two matrices. It removes the scale from the result, and it restores the sign of each axis, so that the remaining 3x3 part is a rotation. The scale of the result is still `S1 * S2`. The matrix product costs more, but a negative scale on a root joint mirrors a full character, thus this case must be correct. If the parent scale is also non-uniform, the result still has shear, and the rotation from the matrix is only an approximation.

## Conclusion

VQV adds a scale per axis to VQS, but it does not have a place for the shear that a rotation creates between a scaled parent and its child. Its product discards that shear, its inverse is only a left inverse, and its product is not associative. It is exact when the scale of the parents is uniform, and it is close when the scale is close to 1.

For storage, for example in an animation clip, I recommend VQV: it is compact, and each part interpolates in local space. But in a hierarchy with a non-uniform scale, the transform must keep the shear. In the [next post]({% post_url 2026-11-28-transforms_vqm %}), we replace the scale vector with a 3x3 matrix.

## References

* [RTM: vqvf.h](https://github.com/nfrechette/rtm/blob/develop/includes/rtm/vqvf.h)
* [RTM: types supported](https://github.com/nfrechette/rtm/blob/develop/docs/types_supported.md)
