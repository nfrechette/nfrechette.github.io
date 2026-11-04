---
layout: post
title: "Representing Affine Transforms: Table of Contents"
tags: [math]
toc: "Representing Affine Transforms"
description: "A series about popular affine transform types: affine matrices, VQ, VQS, VQV, VQM, and the scale orientation of OpenUSD."
---
Affine transforms are common in video games and other realtime applications. They can represent object rotations, translations, scale, and shear. These can also be mixed and combined in various ways (e.g. in a hierarchy of transforms). There are multiple ways to represent them and each format has its own strengths and drawbacks.

My library [Realtime Math (RTM)](https://github.com/nfrechette/rtm) implements most of these types. In this series, I'll cover the popular formats and how they work.

Each post uses the conventions of RTM. Vectors are row vectors, and they multiply on the left of matrices: `p' = p * M`. Thus a product `A * B` applies `A` first, then `B`. The type names read from right to left in the order of operations. For example, a VQS applies the scale (S) first, then the rotation (Q), then the translation (V). I kept the mathematical convention for the type names, because it makes them easier to search for. The RTM documentation explains [the reason for its convention](https://github.com/nfrechette/rtm/blob/develop/docs/api_conventions.md#matrix-multiplication-ordering).

In the types below, the letters have the following meaning:
* `V`: A `vector3` that represents either a translation (on the left hand side) or a 3D scale (on the right hand side).
* `Q`: A normalized `quaternion` that represents a rotation or the scale orientation in `VQQV`.
* `S`: A single `scalar` that represents uniform scale.
* `M`: A `matrix3x3` that represents non-uniform scale and shear.

## Table of Contents

I add a link to each post here when I publish it.

* Affine Matrices: 4x4 (or sometimes 3x4) matrices, the tried and true classic. Heavily used in rendering and 3D authoring software (e.g. Maya, Blender).
* VQ and VQS: a rigid transformation with and without uniform scale. Also called a `TRS` (translation-rotation-scale) or `SQT` (scale-quaternion-translation) transform.
* VQV: a rigid transformation with a non-uniform scale.
* VQM: an affine transformation with non-uniform scale and shear.
* VQQV: an affine transformation with non-uniform scale and shear. Unlike `VQM` which represents scale and shear as a 3x3 matrix, here it is represented as a scale and orientation.

## Quick reference

| Type | Parts | Floats (SIMD storage) | Group | Interpolates | Scale | Shear |
| ---- | ----- | --------------------- | ----- | ------------ | ----------------- | ----- |
| Affine matrix | 3x3 matrix, translation | 12 (16) | Yes | No | Yes | Yes |
| VQ | quaternion, translation | 7 (8) | Yes | Yes | No | No |
| VQS | quaternion, translation, scalar | 8 (8) | Yes | Yes | Uniform only | No |
| VQV | quaternion, translation, vector3 | 10 (12) | No | Yes | Yes | No (discarded) |
| VQM | quaternion, translation, 3x3 matrix | 16 (16) | Yes | Yes | Yes | Yes |
| VQQV | quaternion, translation, vector3, quaternion | 14 (16) | Yes (through a matrix) | Local space only | Yes | Yes |

*Group*: in exact arithmetic, the product of two transforms is exact and associative, and each transform has an exact inverse.
