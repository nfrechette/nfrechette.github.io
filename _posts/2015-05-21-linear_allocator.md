---
layout: post
title: Linear Allocator
---
The first memory allocator we will cover is by far the simplest and serves as an introduction to the material. Today we cover the linear memory allocator ([code](https://github.com/nfrechette/gin/blob/master/include/gin/linear_allocator.h)).

### How it works

The internal logic is fairly simple:

* We initialize the allocator with a pre-allocated memory buffer and its size.
* `Allocate` simply increments a value indicating the current buffer offset.
* `Deallocate` does nothing
* `Reallocate` first checks if the allocation being resized is the last performed allocation and if it is, we return the same pointer and update our current allocation offset.
* `Reset` is used to free all allocated memory and return the allocator to its original initialized state.

There is very little work to do for all these functions which makes it very fast. `Deallocate` does nothing because in practice, it makes little sense to support it and other allocators are often better suited when freeing memory at the pointer level is required. The only sane implementation we could do is similar to how `Reallocate` works by checking if the memory being freed is the last allocation (last in, first out). Because we work with a pre-allocated memory buffer, `Reallocate` does not need to perform a copy if the last allocation is being resized and there is enough free space left regardless of whether it grows or shrinks.

Interestingly, you can almost free memory at the pointer level by using `Reallocate` and using a new size of 0 but in practice, the alignment used for the allocation would remain lost forever (if it was originally mis-aligned).

Critical to this allocator is that it adds no overhead per allocation and it does not modify the pre-allocated memory buffer. Not all allocators will have these properties and I will always mention this important bit. This makes it ideal for low level systems or for working with read-only memory.

### What can we use it for

Despite being a very simple allocator, it has a few uses. I have used it in the past with success to clean up code dealing with a lot of pointer arithmetic. The general idea is that if you have a memory buffer representing a custom binary format with most fields having a variable size and requiring alignment, you will end up with a lot of logic to take your raw buffer and split it into the various internal bits.

{% highlight cpp %}
uintptr_t buffer;   // user supplied
size_t bufferOffset = 0;
uint32_t* numValue1 = reinterpret_cast<uint32_t*>(buffer);  // assume buffer is properly aligned for first value
bufferOffset = AlignTo(bufferOffset + 1 * sizeof(uint32_t), alignof(uint8_t));
uint8_t* values1 = reinterpret_cast<uint8_t*>(buffer + bufferOffset);
bufferOffset = AlignTo(bufferOffset + *numValue1 * sizeof(uint8_t), alignof(uint16_t));
uint16_t* numValue2 = reinterpret_cast<uint16_t*>(buffer + bufferOffset);
bufferOffset = AlignTo(bufferOffset + 1 * sizeof(uint16_t), alignof(float));
float* values2 = reinterpret_cast<float*>(buffer + bufferOffset);
{% endhighlight %}

Using a linear allocator to wrap the buffer allows you to manipulate it in an elegant and efficient manner.

{% highlight cpp %}
LinearAllocator buffer(/* user supplied */);
uint32_t* numValue1 = new(buffer) uint32_t;
uint8_t* values1 = new(buffer) uint8_t[*numValue1];
uint16_t* numValue2 = new(buffer) uint16_t;
float* values2 = new(buffer) float[*numValue2];
{% endhighlight %}

Note that the above two versions are not 100% equivalent due to the fact C++11 offers no way to access the required alignment of the requested type when implementing the `new` operator. However, with macro support, the original intent above can be supported and be just as clear while supporting alignment properly. I plan to cover this important bit in a later post.

I wrote earlier that this allocator can be used with read-only memory which is a strange property for a memory allocator. Indeed, since it mostly abstracts away pointer arithmetic when partitioning a raw memory region without modifying it, we can use it to do just that over read-only memory. In the example above, this means that we can easily use it for writing and reading our custom binary format.

### What we can’t use it for

Due to the fact that we do not add per allocation overhead, we cannot properly support freeing memory at the pointer level while supporting variable alignment. When support for freeing memory is needed, other allocators are better suited.

This allocator is also generally a poor fit for very large memory buffers. Due to the fact that we need to pre-allocate it up front, we bear the full cost regardless of how much actual memory we allocate internally.

### Edge cases

There are two important edge cases with this allocator and they are shared by all allocators: overflow and out of memory conditions.

We can cause arithmetic overflow in two ways in this allocator: first by supplying a large alignment value, and second by attempting to allocate a large amount of memory. This is fairly simple to test but there is one small bit we must be careful with: if the alignment provided is very large, we can overflow in such a way that our resulting pointer would end up in our buffer either at a lower memory address if the allocation size is very large as well or at a higher memory address if the allocation size is small. The proper way to deal with this is to check overflow after taking into account the alignment and again after adjusting for the new allocation size.

We eventually run out of memory if we attempt to allocate more than our pre-allocated buffer owns.

### Potential optimizations

While the implementation I provide aims for safety first, in practice a linear allocator should never run out of memory nor should it overflow if the logic using it is correct. This is because by providing a pre-allocated buffer, either we assume we do not need more memory or our assumption is wrong. In the later case, it is highly likely that we do not check the return value of allocations which is of little help even if our allocator is safe. Usage scenarios for this allocator are also generally simple in logic with few unknown variables to cause havoc.

In this light, a number of improvements can be made by stripping the overflow and out of memory checks and simply keeping asserts around. I may end up providing a way to do just that with template arguments or macros in the future.

Another option is to remove the branches added by the overflow and out of memory checks and simply ensure the internal state does not change instead. There is very little logic and as such an early out branch could very well save very little in the rare case it is taken and at the same time, since it is rarely taken, we always end up performing most of the logic anyway.

Last but not least, `Reallocate` support is often not required and could trivially be stripped as well.

### Performance

Due to its simplicity, it offers great performance. All operations are *O(1)* and only amount to a few instructions.

On most 32 bit platforms, the size of an instance should be 24 bytes if `size_t` is used. On 64 bit platforms, the size should be 48 bytes with `size_t`. Both versions can be made even smaller with smaller integral types such as `uint16_t` (which would be very appropriate since this allocator is predominantly used with small buffers) or by stripping support for `Reallocate`. As such, either version will comfortably fit inside a single typical cache line of 64 bytes.

### Conclusion

Despite its simple internals, the linear allocator is an important building block. It serves as an ideal example for a number of sibling allocators we will see in the next few posts which involve similar internal logic and edge cases.

Next up, we will cover a variation: [the virtual memory aware linear allocator]({% post_url 2015-06-11-vmem_linear_allocator  %}).

### Alternate names

The most common alternate name for this allocator is called the *arena* allocator. However, that name is overloaded and is also often associated with a number of other allocators which manage a fixed memory region.

*Note that if you know a better name or alternate names for this allocator, feel free to contact me.*

[**Back to table of contents**]({% post_url 2016-10-18-memory_allocators_toc %})

