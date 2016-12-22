---
layout: post
title: "Animation Compression: Signal Processing"
---
Algorithm variants in the [signal processing](https://en.wikipedia.org/wiki/Signal_processing) category can take many forms but the most common and popular approach is to use [Wavelets](https://en.wikipedia.org/wiki/Wavelet). As such, we will only cover that particular flavour and I happen to know a decent amount about it having implemented it once in the past for [Thief (2014)](https://en.wikipedia.org/wiki/Thief_(2014_video_game)) (which used it extensively for all its character animation clips on all supported platforms).

Other variants of this family might rely on these various techniques:

*  [Discrete cosine transform](https://en.wikipedia.org/wiki/Discrete_cosine_transform)
*  [Principal component analysis](https://en.wikipedia.org/wiki/Principal_component_analysis)
*  [Principal geodesic analysis](https://en.wikipedia.org/wiki/Principal_geodesic_analysis)

It is worth mentioning that the last two flavours are also commonly used alongside clustering and database approaches. If there is interest, I might detail those further at some point.

# How It Works

At their core, implementations that leverage wavelets for compression will be split into four discreet steps:

*  Pre-processing
*  The wavelet transform
*  Quantization
*  Entropy coding

The flow of information is illustrated as follow:

![Wavelet Algorithm Layout](/public/wavelet_compression_process.jpg)

The most important step is of course the wavelet function around which everything is centred. We will thus cover it first before the other steps which will help clarify their purpose.

It is worth noting that aside from quantization, all the steps involved are effectively lossless (they only suffer from some minor floating point rounding). As such, by altering how many bits we use for the quantization step, we can control how aggressive we want to be with our compression.

The decompression is simply the reverse process of each individual step, each performed in reverse order.

## Wavelet Basics

Sadly, going in depth on this topic is out of scope for this series and I am not entirely sure whether or not I am qualified to teach such material. Here, we will only discuss the wavelet properties and what it means for us with respect to character animation and compression in general.

The simplest wavelet function is by far the [Haar wavelet](https://en.wikipedia.org/wiki/Haar_wavelet) but you should not use it for compression. However, it should serve as a good starting point for the topic if you are curious.

By definition, wavelet functions are recursive: each application of the function is referred as a sub-band and will output an equal number of scale and coefficient values (each exactly half the original input size), and in turn we will recursively apply the function on the resulting scale values of the previous sub-band. The end result is a single scale value and `N - 1` coefficients where `N` is the input size.

![Recursive Wavelet](/public/wavelet_recursive_1d.png)

For the [Haar wavelet](https://en.wikipedia.org/wiki/Haar_wavelet), the scale is simply the sum of two input values, and the coefficient is their difference. As far as I know, most wavelet functions will function similarly which yields coefficients that are as close to zero as possible (and exactly zero for a constant input signal).

The [Haar wavelet](https://en.wikipedia.org/wiki/Haar_wavelet) is not suitable for compression because it has a single vanishing moment. What this means is that the input data is processed in pairs, each outputting a single scale and a single coefficient. However the pairs never overlap which means that if there is a discontinuity in between two pairs, it will not be taken into account yielding undesirable artifacts if the coefficients are not accurate (and as we will see later, we will quantize them). As such a decent alternative is to use something like a [Daubechies D4 wavelet](https://en.wikipedia.org/wiki/Daubechies_wavelet). This is the function I used on [Thief](https://en.wikipedia.org/wiki/Thief_(2014_video_game)) and it turned out quite decent for our purposes. Note that a number of academic papers I found on the subject failed to document which wavelet function they used, a grave mistake...

The wavelet transform can be entirely lossless by using an integer variant but in practice we can simply use an ordinary floating point variant since our compression is lossy by nature and the rounding will not measurably impact the results.

Since the wavelet function decomposes the signal into an [orthonormal basis](https://en.wikipedia.org/wiki/Orthonormal_basis), we will be able to achieve the highest compression by considering as much of the signal as possible (not unlike [principal component analysis](https://en.wikipedia.org/wiki/Principal_component_analysis)). As such we can simply concatenate all our tracks together into a single 1D signal. The up side of this is that by considering all the data as a whole, we can find a single [orthonormal basis](https://en.wikipedia.org/wiki/Orthonormal_basis) which will allow us to quantize more aggressively but by having a larger signal to transform, the decompression speed will suffer. In practice to keep it reasonably fast on modern hardware, each track would likely be processed independently in a small power of two such at 16 keys at a time. For [Thief](https://en.wikipedia.org/wiki/Thief_(2014_video_game)), all rotation tracks and translation tracks were aggregated independently (we ran the wavelet transform once for rotation tracks, and once for translation tracks) up to a maximum segment size of **64 KB**.

## Pre-processing

Because wavelet functions are recursive, the size of the input data needs to be a power of two. If our size doesn’t match, we will need to introduce some form of padding:

*  Pad with zeroes
*  Repeat the last value
*  Mirror the signal
*  Loop the signal
*  Maybe something even more creative?

Which approach you choose for padding is likely to have a fairly minimal impact on compression but it might still be measurable. Your guess is as good as mine regarding which is best. In practice, we will always try to avoid padding as much as possible by keeping our input size fairly small and by processing the input data in blocks or segments.

The scale of the output coefficients are a function of the scale and smoothness of our input values. As such it makes sense to perform [range reduction]({% post_url 2016-11-09-anim_compression_range_reduction %}) and to normalize our input values.

## Quantization

After applying the wavelet transform, the number of output values will match the number of input values. No compression has happened yet.

As we mentioned previously, our output values will be partitioned into sub-bands (and a single scale value) and be somewhat centred around zero (both positive and negative). Each sub-band will end up with a different range of values: larger sub-bands (the first applications of the wavelet function) will be filled with high frequency information while the smaller sub-bands will comprise the low frequency information. This is important, it means that a single low frequency coefficient will impact a larger range of values after performing the inverse wavelet transform. As such, low frequency coefficients need higher accuracy than high frequency coefficients.

To achieve compression, we will quantize our coefficients (and keep the single scale value with full precision) into a reduced number of bits. Due to the nature of the data, we will perform range reduction per sub-band and normalize our values between `[-1.0, 1.0]`. We only need to keep the range extent for reconstruction and simply assume that the range is centred around zero. For the lower frequency sub-bands, with 1, 2, 4 coefficients, quantization might not make sense due to the extra overhead of the range extent. Once our values are normalized, we can quantize them. To chose how many bits to use per coefficient, we can simply hardcode a high number such as **16** bits or **12** bits, or alternatively we can try various values and attempt to optimize towards an optimal solution to meet some error threshold. Depending on the number of input values that we process, quantization could also be performed globally instead of per sub-band (e.g. processing 16 keys at a time) reducing the range information overhead.

## Entropy Coding

If we wish to push compression further (and we need to in order to be competitive with the other techniques), we need to perform [entropy coding](https://en.wikipedia.org/wiki/Entropy_encoding). This compression step is entirely lossless.

After our quantization phase, we obtain a number of integer values centred around zero (and a single scale). The most obvious thing that we can compress now is the fact that we have very few large values. To leverage this, we apply a [zigzag transform](https://wiki.multimedia.cx/index.php/Zigzag_Reordering) on our data, mapping negative integers to positive unsigned integers such that values closest to zero remain closest to zero. This transforms our data in such a way that we still end up with very few large values. This is significant because it means that most of our values now have many leading zeroes in their representation in memory.

For example, suppose we quantize everything onto **16** bit signed integers: `-50, 50, 32760`. In memory, these values are represented with [twos complement](https://en.wikipedia.org/wiki/Two's_complement): `0xFFCE, 0x0032, 0x7FF8`. This is not great and how to compress this further is not immediately obvious. Now we apply the [zigzag transform](https://wiki.multimedia.cx/index.php/Zigzag_Reordering) and map our signed integers into unsigned integers: `100, 99, 65519`. In memory, these unsigned integers are now represented as: `0x0064, 0x0063, 0xFFEF`. It is now obvious that smaller values have a lot of leading zeros and thus an easily predictable pattern has emerged which will compress well.

At this point, a generic entropy coding algorithm is used: [zlib](https://en.wikipedia.org/wiki/Zlib), [Huffman](https://en.wikipedia.org/wiki/Huffman_coding), or some custom [arithmetic coding algorithm](https://en.wikipedia.org/wiki/Arithmetic_coding). Luke Mamacos gives a decent example [here](https://worldoffries.wordpress.com/2015/08/25/simple-entropy-coder/) of a wavelet arithmetic encoder that takes advantage of the leading zeros.

Note that if you process a very large input in a single block, you will likely end up with lots of padding at the end which will typically end up as all zero values after the quantization step. It can be a win to use [run length encoding](https://en.wikipedia.org/wiki/Run-length_encoding) to compress those as well before the entropy coding phase.

# In The Wild

As will be made obvious by the length of this post, signal processing algorithms will tend to be the most complex in terms of understanding what happens as well as having the most code involved. This makes their maintenance and usage less popular which is why they aren’t all that common in the wild.

While it can be used and the compression can be competitive if the right entropy coding algorithm is used, they tend to be far too slow to decompress and too complex to implement and maintain for the results that they give.

That being said, on [Thief](https://en.wikipedia.org/wiki/Thief_(2014_video_game)), I implemented a wavelet compression algorithm (they were all the rage at the time) to replace the [linear key reduction]({% post_url 2016-12-07-anim_compression_key_reduction %}) algorithm used in [Unreal 3](https://en.wikipedia.org/wiki/Unreal_Engine#Unreal_Engine_3). The [linear key reduction]({% post_url 2016-12-07-anim_compression_key_reduction %}) algorithm was very hard to tweak properly due to a naive error function it used which resulted in a large memory footprint or inaccurate animation clips. The wavelet implementation ended up being faster to compress with and yielded a smaller memory footprint with good accuracy.

# Performance

Fundamentally, the wavelet decomposition allows us to exploit temporal coherence in our animation clip data. But this comes at a price. In order to sample a single key frame, we must reverse everything, meaning if we process 16 keys at a time, we must decompress our 16 keys to sample a single one of them (or two if we linearly interpolate as we normally would when sampling our clip). For this reason wavelet implementations are terribly slow to decompress and end up not being competitive at all, speed wise. This of course only gets worse as you process a larger input signal. On [Thief](https://en.wikipedia.org/wiki/Thief_(2014_video_game)), full decompression on the [Play Station 3](https://en.wikipedia.org/wiki/PlayStation_3) [SPU](https://en.wikipedia.org/wiki/Cell_(microprocessor)#Synergistic_Processing_Elements_.28SPE.29) took between **800us** and **1300us** for blocks of data up to **64 KB**.

Obviously, this is entirely unacceptable (with other techniques likely in the range of **30us** and **200us**). To mitigate this and keep it competitive, an intermediate cache is necessary.

The idea of the cache is to perform the expensive decompression once for a block of data (e.g. 16 keys) and re-use it in the future. At 30 FPS, our 16 keys will be usable for roughly 0.5 seconds. This is of course not free as we now need to implement and maintain an entire new layer of complexity. We must first decompress into the cache, and then interpolate our keys from it. The decompression can typically be launched early as to avoid stalls when interpolating but it is not always possible to do this. This is particularly problematic on the first frame of gameplay where a large number of animations will start to play at the same time while our cache is empty or stale. For similar reasons, the same issue happens when a cinematic moment starts or any major abrupt change in gameplay.

On the up side, as we decompress only once into the cache, we can also take a bit of time to swizzle our data and sort it by key and bone such that our data per key frame is now contiguous. Sampling from our cache then becomes more or less equivalent to sampling with [simple quantization]({% post_url 2016-11-15-anim_compression_quantization %}). For this reason, sampling from the cache is extremely fast and competitive (as fast as [simple quantization]({% post_url 2016-11-15-anim_compression_quantization %})).

On [Thief](https://en.wikipedia.org/wiki/Thief_(2014_video_game)), our small cache was held in main memory while our wavelet compressed data was held in video memory on the [Play Station 3](https://en.wikipedia.org/wiki/PlayStation_3). This played very well in our favour with the rare decompressions not impacting the rendering bandwidth as much and keeping interpolation fast. This also contributed to slower decompression times but it was still faster than it was on the [Xbox 360](https://en.wikipedia.org/wiki/Xbox_360).

As is now obvious, the signal processing algorithms should be avoided in favour of simpler algorithms that are easier to implement, maintain, and end up just as competitive when properly implemented.

[Up next: Error Compensation]({% post_url 2016-12-22-anim_compression_error_compensation %})

[**Back to table of contents**]({% post_url 2016-10-21-anim_compression_toc %})

