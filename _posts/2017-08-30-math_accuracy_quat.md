---
layout: post
title: "Math accuracy: Normalizing quaternions"
---
While investigating precision issues with [ACL]( https://github.com/nfrechette/acl), I ran into two problems that I hadn’t seen documented elsewhere and that slightly surprised me.

# Dot product

Calculating the dot product between two vectors is a very common operation used for all sorts of things. In an animation compression library, it’s primary use is normalizing [quaternions](https://en.wikipedia.org/wiki/Quaternion). Due to the nature of the code, accuracy is very important as it can impact the final compressed size as well as the resulting decompression error.

[SSE 4](https://en.wikipedia.org/wiki/SSE4) introduced a dot product instruction: `DPPS`. It allows the generated code to be more concise and compact by using fewer registers and instructions. I won’t speak to its performance here but sadly; its accuracy is not good enough for us by a tiny, yet important, sliver.

For the purpose of this blog post, we will use the following nearly normalized quaternion as an example: `{ X, Y, Z, W } = { -0.6767403483, 0.7361232042, 0.0120376134, -0.0006215832 }`. This is a real quaternion from a real clip of the [Carnegie-Mellon University (CMU) motion capture database](http://mocap.cs.cmu.edu/) that proved to be problematic. With doubles, the dot product is **1.0000001612809224**.

Using plain C++ yields the following code and assembly (compiled with AVX support under Visual Studio 2015 with an x64 target):
<script src="https://gist.github.com/nfrechette/745866253ad7a664bd97af1e008060a2.js"></script>

*  The result is: **1.00000024**. Not quite the same but close.

Using the SSE 4 dot product instruction yields the following code and assembly:
<script src="https://gist.github.com/nfrechette/22cc41715d593f1cd5fc60aaab1c37ef.js"></script>

*  The result is: **1.00000024**.

Using a pure SSE 2 implementation yields the following assembly:
<script src="https://gist.github.com/nfrechette/e957d56c693228dd6c6f299ca68936e3.js"></script>

*  The result is: **1.00000012**.

These are all nice but it isn’t immediately obvious how big the impact can be. Let’s see how they perform after taking the square root (note that the SSE 2 `SQRT` instruction is used here):

*  C++: **1.00000012**
*  SSE 4: **1.00000012**
*  SSE 2: **1.00000000**

Again, these are all pretty much the same. What happens when we take the square root reciprocal after 2 [iterations of Newton-Raphson](https://en.wikipedia.org/wiki/Newton%27s_method)?
<script src="https://gist.github.com/nfrechette/42c139a2ebac76976804d8bad1ff7e27.js"></script>

*  C++: **0.999999881**
*  SSE 4: **0.999999881**
*  SSE 2: **0.999999940**

With this square root reciprocal, here is how our quaternions look after being multiplied to normalize them and their associated dot product.

*  C++: `{ -0.676740289, 0.736123145, 0.0120376116, -0.000621583138 }` = **0.999999940**
*  SSE 4: `{ -0.676740289, 0.736123145, 0.0120376116, -0.000621583138 }` = **1.00000000**
*  SSE 2: `{ -0.676740289, 0.736123145, 0.0120376125, -0.000621583138 }` = **0.999999940**

Here is the dot product calculated with doubles:

*  C++: **0.99999999381912441**
*  SSE 4: **0.99999999381912441**
*  SSE 2: **0.99999999384079208**

And the new square root:

*  C++: **0.999999940**
*  SSE 4: **1.00000000**
*  SSE 2: **0.999999940**

Now the new reciprocal square root:

*  C++: **1.00000000**
*  SSE 4: **1.00000000**
*  SSE 2: **1.00000000**

After all of this, our delta from a true length of **1.0** before (as calculated with doubles) was **1.612809224e-7** before normalization. Here is how they fare afterwards:

*  C++: **6.18087559e-9**
*  SSE 4: **6.18087559e-9**
*  SSE 2: **6.15920792e-9**

And thus, the difference between using SSE 4 and SSE 2 is just **2.166767e-11**.

As it turns out, the SSE 2 implementation appears the most accurate one and yields the lowest decompression error as well as a smaller memory footprint (by a tiny bit).

# Normalizing a quaternion

There are two mathematically equivalent ways to normalize a quaternion: taking the dot product, calculating the square root, and dividing the quaternion with the result, or taking the dot product, calculating the reciprocal square root, and multiplying the quaternion with the result.

Are the two methods equivalent with floating point mathematics? Again, we will not discuss the performance implications as we are only concerned with accuracy here. Using the previous example quaternion and using the SSE 2 dot product yields the following result with the first method:

*  Dot product: **1.00000012**
*  Length: `sqrt(1.00000012)` = **1.00000000**
*  Normalized quaternion using division: `{ -0.6767403483, 0.7361232042, 0.0120376134, -0.0006215832 }`
*  New dot product: **1.00000012**
*  New length: **1.00000000**

And now using the reciprocal square root with 2 Newton-Raphson iterations:

*  Dot product: **1.00000012**
*  Reciprocal square root: **0.999999940**
*  Normalized quaternion using multiplication: `{ -0.676740289, 0.736123145, 0.0120376125, -0.000621583138 }`
*  New dot product: **0.999999940**
*  New length: **0.999999940**
*  New reciprocal square root: **1.00000000**

By using the division, normalization fails to yield us a more accurate quaternion because of square root is **1.0**. The reciprocal square root instead allows us to get a more accurate quaternion as demonstrated in the previous section.

# Conclusion

It is hard to see if the numerical difference is meaningful but over the entire CMU database, both tricks together help reduce the memory footprint by **200 KB** and lower our error by a tiny bit.

For most game purposes, the accuracy implication of these methods does not matter all that much and rarely have a measurable impact. Picking whichever method is fastest to execute might just be good enough.

But when accuracy is of a particular concern, special care must be taken to ensure every bit of precision is retained. This is one of the motivating reasons for ACL having its own internal math library: granular control over performance and accuracy.

