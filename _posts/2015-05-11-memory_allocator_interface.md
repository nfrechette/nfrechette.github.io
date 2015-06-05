---
layout: post
title: A memory allocator interface
---
[As previously discussed]({% post_url 2015-05-01-cpp_stl_container_deficiencies %}), the memory allocator integration into C++ STL containers is far from ideal.

[Attempts to improve on it](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2008/n2554.pdf) have been made but I have yet to meet anyone satisfied with the current state of things.

Memory in large applications will typically come from two majors places: new/malloc calls and container allocations. Today we will only discuss the later.

### Where are we at?

There appears to be two main approaches when it comes to memory allocator interfaces:

* Templating the container with the allocator used (C++ STL, Unreal 3)
* Implementing an interface and perform a virtual function call (Bitsquid)

The first, as previously discussed, has a number of downsides but on the up side, it is the fastest since all allocation calls are likely to either be inline or at least be a static branch.

The second, while much more flexible, introduces indirection and as [previously discussed]({% post_url 2015-05-05-caches_everywhere %}), is slower and generally less performant. Not only do we introduce an extra cache miss (and likely TLB miss) but we introduce an indirect branch which the CPU will not be able to prefetch.

Can we do better?

### The compromise

It seems that the cost of added flexibility is to use an indirect branch. This is unavoidable. However, we can remove the extra cache and TLB miss by defining a partial inline virtual function dispatch table in the allocator interface.

The idea is simple:

* There are typically few allocator instances (on the order of <100 instances isn’t unusual)
* Allocator instances are often small in memory footprint and often will fit within one or two cache lines (even when they manage a lot of memory, the footprint will generally lie somewhere else in memory and not inline with the allocator)
* Most container allocations can be implemented with a single function: `realloc`

We can thus conclude that it is a viable alternative to add a function pointer to a `realloc` function inline within the allocator and call this for all our needs.

Here is the code ([which is also on github](https://github.com/nfrechette/gin/blob/master/include/gin/allocator.h)):

{% highlight cpp %}
class Allocator
{
protected:
    typedef void* (*ReallocateFun)(Allocator*, void*, size_t, size_t, size_t);

    inline          Allocator(ReallocateFun reallocateFun);

public:
    virtual         ~Allocator() {}

    virtual void*   Allocate(size_t size, size_t alignment) = 0;
    virtual void    Deallocate(void* ptr, size_t size) = 0;

    inline void*    Reallocate(void* oldPtr, size_t oldSize, size_t newSize, size_t alignment);

    virtual bool    IsOwnerOf(void* ptr) const = 0;

protected:
    ReallocateFun   m_reallocateFun;
};

void* Allocator::Reallocate(void* oldPtr, size_t oldSize, size_t newSize, size_t alignment)
{
    assert(m_reallocateFun);
    return (*m_reallocateFun)(this, oldPtr, oldSize, newSize, alignment);
}
{% endhighlight %}

A number of things stand out and are important:

* This is not a proper interface but instead an abstract base class.
* We provide some virtual functions for common things and more will come later (debugging features, etc.)
* Reallocate is inline and *NOT* virtual
* Deallocate/Reallocate follow the latest C++ standard and include the *size* used when the original allocation was made to allow further optimizations within allocator implementations.
* Alignment must be provided which is important for AAA video games, and more generally with SIMD code.
* The first argument to the `ReallocateFun` is an instance of the base class itself. This is important because it points to a static free standing function as such when we call `Reallocate`, the implicit `this` present as first argument will simply be forwarded as is with no extra register shuffling (at least on x64) even if it ends up not inlined and allows the implementation to call a member function without shuffling registers as well.

Usage is very simple:

* An allocator simply derives from this base class, implement the necessary function and initializes the base class with a function pointer to a suitable reallocate function.
* Containers simply call `Reallocate(nullptr, 0, size, alignment)` to allocate, `Reallocate(ptr, size, 0, alignment)` to deallocate and simply supply all arguments to reallocate.

It is often the case that containers will simply reallocate (e.g: vector<..> with POD) and as such this interface is ideally suited for this. With this implementation, when a container performs an allocation or deallocation, the cache miss to access the reallocate function pointer will load relevant data in its cache line leading to less wasted cycles compared to the virtual function dispatch approach while maintaining all the flexibility needed by the indirection and the interface.

In the coming blog posts, I will introduce a number of memory allocators and containers that will use this new interface.

