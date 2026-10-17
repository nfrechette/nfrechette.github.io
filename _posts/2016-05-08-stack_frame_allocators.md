---
layout: post
title: Stack Frame Allocators
---
This allocator family is quite possibly one of the most common memory management technique. 

Note that there are many variants possible of this allocator. As such we will only cover a few to give a general overview of what it can look like. Actual production versions in the wild will often be custom and tailored to the specific application needs. Unlike our [linear allocator]({% post_url 2015-05-21-linear_allocator %}) previously covered, this allocation technique is very common and in use in many applications.

### How it works

A topic that comes very early when introducing many programming languages is the call stack. It is central to C, C++, and many other languages. The execution stack used for this mechanic operates as a stack frame based memory management algorithm which is handled by the compiler and the hardware (on x86 and x64).

Every C++ programmer is familiar with the stack and all it has to offer. Each function call pushes a new frame on the stack when it enters and later pops it when it exits. In this context, a frame is a section of memory that holds our local function variables that cannot be stored in registers.

Our stack frame allocator works in much the same way except that pushing and popping of frames is made explicit. This makes it a very powerful and familiar tool.

Our frame based allocators will use a common [AllocatorFrame](https://github.com/nfrechette/gin/blob/master/include/gin/allocator_frame.h) class and the usage is simple:

{% highlight cpp %}
AllocatorFrame frame(allocatorInstance);
// Allocate here with ‘allocatorInstance’
{% endhighlight %}

Popping of the frame is automatic when the destructor is called or it can be popped manually with `AllocatorFrame::Pop()`.

In a frame based allocator such as this, when the frame is popped, all allocations made within our frame can be freed and the memory reclaimed. Different allocator variants will handle this differently as we will later see. The bottom line is that you should not keep pointers to that memory since it is no longer valid. On the plus side, freeing memory is very fast as a bulk operation.

### What can we use it for

It allows us to allocate memory dynamically and return it from a function. This is very common and handy when we do not know the maximum amount of potential results returned (maybe we have a rare worst case scenario) and we want to avoid increasing the stack.

It supports `realloc` for the topmost allocation, useful when appending to vectors.

When using a thread local allocator, we can avoid expensive heap accesses since we offer better performance due to reduced cache and TLB usage. Execution stack memory is often forced to use 4KB pages and this is often controlled by the kernel but our parallel stack can use any page size it wants (when such control is available to user space).

Moving large allocations (such as strings) off the call stack reduces the risks of a malicious user causing the return address to be overwritten and abused in the presence of buffer overflow bugs. It can trivially replace `alloca` and everything it is used for.

Depending on the variant, it can access all system memory unlike our linear allocator.

Because it is often faster than a generalized heap allocator (potentially shared between multiple threads), if our allocated data is thread local (e.g: a vector on the stack), we can trivially migrate the allocations to use our frame allocator and save on allocation, deallocation, and reallocation.

### What we can’t use it for

Much like our linear allocator, stack frame allocators do not support generalized deallocation of memory. This is largely mitigated by the fact that freeing is still supported but now happens in a last in/first out order due to our stack frames.

### Performance

Performance of stack frame based allocators is generally very good due in large part to their simplicity when allocating and the bulk free operation. It is very common to have a stack frame allocator per thread which can also avoids a lock operation since they generally do not require to be shared between threads.

Generally speaking, the performance is enhanced compared to a generalized heap allocator because by design we use a smaller virtual memory range or we guaranty that we can re-use a previously used range keeping our TLB usage optimal. This also helps the CPU cache.

### Conclusion

Up next we will cover a simple variant: [the greedy stack frame allocator]({% post_url 2016-05-09-greedy_stack_frame_allocator %}).

### Alternate names

This memory allocator is often abbreviated to simply ‘Stack Allocator’. There are so many variants that are possible that there are probably just as many names.

*Note that if you know a better name or alternate names for this allocator, feel free to contact me.*

[Reddit thread](https://www.reddit.com/r/programming/comments/4ie1xv/memory_allocators_explained_the_stack_frame/)

[**Back to table of contents**]({% post_url 2016-10-18-memory_allocators_toc %})

