---
layout: post
title: Virtual memory aware linear allocator
---
This allocator is a variant of the [linear allocator]({% post_url 2015-05-21-linear_allocator %}) we covered last time and again it serves to introduce a few important concepts to allocators. Today we cover the virtual memory aware linear memory allocator ([code](https://github.com/nfrechette/gin/blob/master/include/gin/vmem_linear_allocator.h)).

### How it works

The internal logic is nearly identical to the linear allocator with a few important tweaks:

* We `Initialize` the allocator with a buffer size. The allocator will use this size to reserve virtual memory but it will not commit any physical memory to it until it is needed.
* `Allocate` will commit physical memory on demand as we allocate.
* `Deallocate` remains unchanged and does nothing.
* `Reallocate` remains largely unchanged and like `Allocate` it will commit physical memory when needed.
* `Reset` remains largely the same but it now decommits all previously committed physical memory. 

Much like the vanilla linear allocator, the buffer is not modified by the allocator and there is no memory overhead per allocation.

There are two things currently missing from the implementation. The first is that we do not specify how eagerly we commit physical memory. There is a cost associated with committing (and decommitting) physical memory since we must call into the kernel to update the TLB page tables (and invalidate the relevant TLB entries). Depending on the usage scenarios, this can have an important cost. Currently we commit memory with a granularity of 4KB (the default page size on most platforms). In practice, even if the system uses pages of 4KB, we could use any multiple higher than this to commit memory with (e.g: commit in blocks of 128KB). The second missing implementation detail is that we simply decommit everything when we `Reset`. In practice, some sort of policy would be used here in order to manage slack. This policy would be required at initialization as well as when we reset. For similar reasons as stated prior, committing and decommitting have costs and reducing that overhead is important. In many cases it would make sense to keep some amount of the memory always committed. While these two important details are not necessarily important in this allocator variant, in many other allocators it is of critical importance. Decommitting memory is often very important to fight fragmentation and is critical when multiple allocators must work along side each other.

### What can we use it for

Unlike the vanilla linear allocator, because we commit physical memory on demand, this allocator is better suited for large buffers or for buffers where the used size is not known ahead of time. The only requirement is that we know an upper bound.

In the past, I have used something very similar to manage video game checkpoints. It is often known or enforced by the platform that a save game or checkpoint does not have a size larger than a known constant. However, it is very rare that we know the exact size it will have when the buffer must be created. To create your save game, you can simply employ this linear allocator variant with an upper bound, use it behind a stream type class to facilitate serialization and be done with it. You can sleep well at night knowing that no realloc will happen and no memory will be needlessly copied.

### What we can’t use it for

Much like the vanilla linear allocator, this allocator is ill suited if freeing memory at the pointer granularity is required.

### Edge cases

The edge cases of this allocator are identical to the vanilla linear allocator with the exception of two new ones we add to the list.

When we first initialize the allocator, virtual memory must be reserved. Virtual memory is a finite resource and can run out like everything else. On 32 bit systems, this value is typically 2 to 4GB. On 64 bit systems, this value is very large since typically 40 bits are used to represent it.

When we commit physical memory, we might end up running out. In this scenario, we still have free reserved virtual memory but we are out of physical memory. This can happen if the physical memory becomes fragmented and mixed page sizes are used by the application. For example, consider an allocator *A* using pages of 2MB while another allocator *B* uses pages of 4KB. It might be possible for the system to end up with holes that are smaller than 2MB. Since the TLB must refer to a contiguous region of physical memory when large pages are used, this is bad. On many platforms, the kernel will defragment physical memory if this happens by copying memory around and remapping TLB entries. However, not all platforms will do this and some will simply bail out on you.

### Potential optimizations

Much like the vanilla linear allocator, all observes optimization opportunities are also available here. Also, as previously discussed, depending how greedy we are with committing and how much slack we keep when decommitting, we can tune the performance quite effectively.

One notable other optimization avenue that is not for the faint of heart is that we can remove the check to commit memory inside the `Allocate` function and instead let the system produce an invalid access fault. By modifying the handler function and registering our allocator, we could commit memory when this happens and retry the faulting instruction. Depending on the granularity of the pages used to commit memory, this could reduce somewhat the overhead required for allocation by removing the branch required for this check.

While this implementation uses a variable to keep track of how much memory is committed, depending on the actual policy used, it could potentially be dropped as well. It was added for simplicity not out of necessity since in the current implementation, the allocated size could be rounded up to a multiple of the page size used for the purpose of tracking the committed memory.

### Performance

Due to its simplicity, it offers great performance. All allocation and deallocation operations are *O(1)* and only amount to a few instructions. However, resetting and destroying the allocator now have the added cost of decommitting physical memory and will thus be linearly dependant on the amount of committed memory.

On most 32 bit platforms, the size of an instance should be 28 bytes if `size_t` is used. On 64 bit platforms, the size should be 56 bytes with `size_t`. Both versions can be made even smaller with smaller integral types such as `uint32_t` or by stripping support for `Reallocate`. As such, either version will comfortably fit inside a single typical cache line of 64 bytes.

### Conclusion

Once again, this is a very simply and perhaps even toy allocator. However it serves as an important building block to discuss the various implications of committing and decommitting memory as well as the general implementation details surrounding these things. Manual virtual memory management is a classic and important tool of modern memory allocators and seeing it put to use in a simple context will serve as a learning example.

Fundamentally, linear allocators are a variation of a much more interesting and important allocator: the stack frame allocator. In essence, linear allocators are stack frame allocators where only a single frame is supported. Pushing of the frame happens at initialization and popping happens when we reset or at destruction.

Next up, we will cover the ever so useful: [stack frame allocators]({% post_url 2016-05-08-stack_frame_allocators %}).

### Alternate names

To my knowledge, there is no alternate name for this allocator since it isn’t really a real allocator one would see in the wild.

*Note that if you know a better name or alternate names for this allocator, feel free to contact me.*

[Reddit thread](http://www.reddit.com/r/programming/comments/39gl0d/memory_allocators_explained_the_virtual_memory/)

[**Back to table of contents**]({% post_url 2016-10-18-memory_allocators_toc %})

