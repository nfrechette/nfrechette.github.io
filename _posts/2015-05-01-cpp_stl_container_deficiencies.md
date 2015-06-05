---
layout: post
title: C++ STL container deficiencies
---
In the AAA video game community, it is common to reimplement containers to fix a number of deficiencies. EA STL being a very good example of this. You can find a document [here](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2271.html) that explains in great detail the reasoning behind it. Some of the points are a bit dated and have been fixed with C++11 or will be fixed in C++14. I will not repeat them here but I will add some of my own.

### Some function names are un-intuitive
`deque` and `list` have `push/pop` which are symmetric and this is good. But `insert/erase` seems a poor choice of words and we have the `emplace` variants which overlap the two functionalities.
`vector` appears to have a mix of queue/stack like functions (`push/pop` and `front/back`) but this choice of words is a poor fit when talking about arrays.

Naming things is always sensitive subject and in the interest of discussion I give the following two examples: Java uses `add/remove` for all container operations while C# uses `Add/Remove` and `Insert/RemoveAt`.

### Vector is a poor container name
In video games, and mathematical applications, vectors are N dimensional. This reflects the STL container name but in video games vectors are almost always 2D, 3D, or 4D. Ultimately, this can yield some confusion. Even in the `vector` documentation, it is explained in terms of arrays while array is reserved for an array of fixed size that also happens to be inline. In practice, there are many useful variants of array implementations and adding a simple qualifier to the name makes everything much more clear: `FixedArray`, `InlineArray`, `DynamicArray`, `HybridArray`, etc.

### The meaning of the word ‘size’ is overloaded and confusing
Size in C++ means many things. `size_t` is defined as the type of the result of the `sizeof` family of operators. On most systems it will be the same size as the largest integral register (32 or 64 bits) and will typically match `uintptr_t` for this reason. The `sizeof` operators also return a size and this size is measured in bytes (which can be 8 or more bits depending on the platform). For the containers, `size()` returns the number of elements.

Size is thus a type, a number of bytes and a number of elements depending on the context.

### Templating the allocator on the container type is a bad idea
EA STL touches on most of the issues related with the poor STL memory allocator support but it forgets an important point: the speed gain of templating the allocator type renders refactoring code much harder. It is not unusual to write a function that takes a container as argument and at a later time, the need to change the allocator type arises. This forces the user to change every site where the allocator type appears which can end up being many functions. I have witnessed optimizations that could not be performed because the amount of work would be too great due to this. It is also often desirable to write functions that will require allocation/deallocation that are allocator agnostic without templating the whole function on the allocator type.

A common fix for this is to use an allocator interface with virtual functions which is simple and clean. The bitsquid engine [does this](http://bitsquid.blogspot.ca/2010/09/custom-memory-allocation-in-c.html). It is not without its faults but it is ultimately much more flexible. I plan to discuss this in further detail in later posts.

### Containers are often larger than they need to be
It is not unusual to end up with hundred of thousands or even millions of array containers and the likes. In this scenario, every byte counts and this can end up bloating objects that hold them. Generally, `size_t` is far too large to keep track of sizes and in fact, many video game engines will simply hardcode a `uint32_t` instead (only the most recent game consoles now have more than 4GB of memory, and just barely). However, even this is often wasteful as the norm is to have tiny arrays and not larger ones. It would be much more flexible is we had a base container templated on the type used to track the sizes and define all popular variants: `Vector8`, `Vector16`, `Vector32`, `Vector64`, etc. The container should then check for overflow and assert/fail if it does so. We could have a default `Vector` without a size specified that defaults to a sensible configurable value (e.g: `Vector32` or `Vector64`).

Another source of waste is the allocator contained inside the containers. For reasons discussed above, it is desirable to store a pointer to the allocator inside containers. Since a container that requires allocation will already have a pointer to point to the allocated memory, and since we can rely on the fact that the container has two states (unallocated and allocated), we can store that pointer inside the data pointer in the former case (and use either a flag in the LSB or the capacity of the container to tell which state it is in) and simply append it at the front or back of the allocated memory in the later case. This will save a few bytes in the container object itself reducing the size of the holding object. I will discuss this again in a future blog post.

### Removing items from an unsorted array
It is generally the norm that array containers will hold their contents unsorted. When this is the case, upon removing an item, we can simply overwrite it with the last item of the array instead of shifting all the elements left. This ensures a much more deterministic runtime cost for this operation.

### Containers hide everything
Sometimes, having a C style API with a raw view is beneficial. [The bitsquid foundation library](http://bitsquid.blogspot.ca/2012/11/bitsquid-foundation-library.html) explains and uses this. However, at the same time, in the vast majority of cases, it does not make sense to expose programmers directly to this as it can be error prone (it becomes easy to make a container out of sync or corrupted). For example, bit sets often come in two variants: an inline array of bits and a dynamically allocated array of bits. It is often the case that the code will be duplicated to support both cases. However, at times a third cases arises: when you need to make your dynamic bit array inline as part of a larger memory block (e.g.: imagine a dynamic array where for each slot we also store a bit, with the STL containers, we would have two dynamic allocations when one would suffice). In the later scenario, none of the bit set functions can be reused and they must again be duplicated. In practice, all three cases can be implemented by reusing functions that take as input a raw view of the bit set along with the number of bits.

I plan to look at a number of these topics more in depth in future blog posts, stay tuned!

