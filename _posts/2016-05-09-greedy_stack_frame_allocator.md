---
layout: post
title: Greedy Stack Frame Allocator
---
Today we cover the first stack frame allocator variant: the greedy stack frame allocator ([code](https://github.com/nfrechette/gin/blob/master/include/gin/stack_frame_allocator.h)). It takes the term greedy from how it manages free segments after popping a frame. To better understand how this allocator works, you should first read up on the [stack frame allocator family]({% post_url 2016-05-08-stack_frame_allocators %}).

### How it works

This allocator uses memory segments chained together. When an allocation is made, we find a free segment that can accommodate our allocation request. The first segment we check is the current live segment (the segment last used). Should it be full or the remaining space too small, we then look in the free segment list and pick (or allocate) a suitable candidate. Finally, we update our current live segment to the new used segment.

A segment behaves much like our [linear allocator]({% post_url 2015-05-21-linear_allocator %}) previously seen (also commonly called a memory region). Allocation is very cheap since it only involves bumping a pointer forward.

When we pop a frame, all segments that were used and are no longer required or alive are appended to a free list. This is where the allocator is greedy: it will only free the segments once the allocator is destroyed. The upside of this is that we will rarely require to allocate new segments which can involve an expensive malloc/kernel call.

Supporting `realloc` is trivial and works as expected.

The allocator also supports supplying it with pre-allocated segments that are externally managed. This is handy if you want to prime it with a larger segment which will thus become the minimum managed size. For example, you might know that the allocator is usually on average around 2MB, instead of letting it allocate segments of 64KB on demand, you register a single 2MB segment at initialization and later if it needs more memory, it will allocate 64KB segments on demand.

### What can we use it for

The greedy nature of the algorithm makes it ideal when the upper bound on memory usage is known or at the very least manageable and we can afford to keep the memory allocated. This is suitable for many applications and is indeed used in a similar form in Unreal 3 under the name of `FMemStack`. Many AAA games have shipped with this making extensive use of it.

### What we can’t use it for

The greedy nature makes it far less ideal when the upper bound isn’t known ahead of time or is possibly unbounded.

### Edge cases

Again, the usual edge cases here involve overflow caused by the size or alignment requested and must be carefully dealt with. Another edge case specific to this allocator remains: because of the linear allocation nature of the algorithm, live segments might not be 100% used and will naturally keep some unused slack. Generally speaking this isn’t such a big deal but it can trivially be tracked if required.

### Potential optimizations

Here again we can omit the overflow checks. In practice they are rarely required and could be left to assert instead. This is generally the approach taken in AAA game implementations.

Reallocate support is optional here as well and could be stripped if needed.

The implementation uses a `FrameDescription` in order to keep track of the order in which the frames are pushed to ensure we pop them back in reverse order. This is entirely for safety and in practice it could be omitted in a shipping build.

### Performance

The performance of this allocator is very good. Allocation is *O(1)* and deallocation is a noop. Frame pushing is *O(1)* and popping is *O(n)* where *n* is the number of live segments freed. All of these operations are very cheap.

Frames are very compact and their footprint is split between `AllocatorFrame` and a frame description allocated internally.

Segments have a small header (at most 24 bytes) required to chain them as well as to keep track of the allocated size, segment size, and some flags.

Generally, a stack frame allocator will often manage less than 4GB of memory as such it can be templated to use `uint32_t` internally. This yields a footprint of 40 bytes on 64 bit platforms for the allocator (a single cache line). This ensures that when we allocate, only 2 cache lines will usually be touched (the allocator instance and the live segment header).

### Conclusion

This is our first usable allocator and it is a powerful one. On older, slower hardware where taking locks and using a general malloc/free was expensive, I used a thread local stack allocator to great success in the performance sensitive portions of the code. Its simplicity and flexibility makes it ideal to replace allocators of containers that end up on the stack which might often reallocate memory.

Next up, we will cover a [virtual memory aware variant]({% post_url 2016-10-17-vmem_stack_frame_allocator %}) better suited for high performance AAA video games where the upper bound is generally known or can be reliably approximated. This second variant will be the last variant we will cover in this allocator family.

Note that it is often desirable to avoid the allocator to grow unbounded in memory in the presence of spikes and a common way to deal with this is to free some segments when we pop frames by keeping a free list with a small number of entries (slack). This is easily achieved with an hysteresis constraint. Alternatively, at a specific point in the code, you could call a function on the allocator to free some of its slack (e.g: at the start or end of a frame).

[Reddit thread](https://www.reddit.com/r/programming/comments/4ihr38/memory_allocators_explained_the_greedy_stack/)

[**Back to table of contents**]({% post_url 2016-10-18-memory_allocators_toc %})

