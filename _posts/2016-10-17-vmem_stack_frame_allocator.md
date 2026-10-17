---
layout: post
title: Virtual Memory Aware Stack Frame Allocator
---
Today we cover the second variant: the virtual memory aware stack frame allocator ([code](https://github.com/nfrechette/gin/blob/master/include/gin/vmem_stack_frame_allocator.h)). This is a fairly popular incarnation of the [stack frame allocator pattern]({% post_url 2016-05-08-stack_frame_allocators %}) and I have seen quite a few implementations in the wild in line with this toy implementation. Similar in spirit to the [virtual memory aware linear allocator]({% post_url 2015-06-11-vmem_linear_allocator %}), here again we gain in simplicity and performance by leveraging the virtual memory system.

### How it works

Not a whole lot differs from the previous implementation aside from the fact that we are no longer segmented. In AAA video games, it is quite common to have a known upper bound (or it is easily approximated) for these allocators and as such we can simplify the implementation quite a bit by having a single segment. To avoid wasting memory, we simply reserve a virtual address range, and commit/decommit memory as needed.

With a single segment, a lot of logic is removed and simplified. When we allocate, we will commit more memory gradually in blocks of our page size. In a real implementation, this size would likely be larger depending on the page size, 64KB would be a decent size to use. 

Popping is very easy and fast and it never causes memory to decommit. This is done to avoid repeated commit/decommit calls and managing some hysteresis. In practice, these allocators often have a known fixed lifetime. For example, we might have an instance of the allocator for main thread allocations during a single frame. As such, it is easy at the end of the frame to decommit once and retain some amount of slack. It is also very common to have 2 or 3 for rendering purposes and while they might be double (or triple) buffered, the principle remains.

### What can we use it for

Similar to the classic segmented implementation, this variant is almost a drop in replacement. It is best suited when the upper bound on the usage is known. It would not be unusual for this implementation to live alongside the segmented implementation: during development, the segmented version is used such that it never fails, and closer to releasing the product, the upper bound is calculated and the virtual memory aware variant is used instead.

### What we can’t use it for

For obvious reasons, this variant is not ideal when the maximum memory footprint is not known or if it needs to grow unbounded. While on a 64 bit system you could technically reserve 4TB of address space and it would likely be enough, in practice another variant might be a better fit.

### Edge cases

Unlike the classic greedy variant, popping will not decommit memory, as such if memory pressure is high, special care needs to be taken to avoid issues. Under some circumstances, if an out of memory situation arises with some other allocator, decommitting the slack might allow you to retry the allocation.

### Performance

The performance of this allocator is very good. Allocation is O(1) and deallocation is O(1). Both operations are very cheap if no call to the kernel is required to commit memory.

### Conclusion

This is our second usable allocator and its usage is quite common. Single segment implementations might not always be virtual memory aware, but they remain the same in nature. Many AAA video game titles have been released with very similar implementations to great success.

Next up, we will revisit the linear memory allocator family to cover an important addition: the thread safe linear allocator. This will be our first thread safe implementation and it is a variant that is very common in multithreaded rendering code.

[Reddit thread](https://www.reddit.com/r/programming/comments/57y0iv/memory_allocators_explained_the_virtual_memory/)

[**Back to table of contents**]({% post_url 2016-10-18-memory_allocators_toc %})

