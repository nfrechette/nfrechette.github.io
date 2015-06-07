---
layout: post
title: Virtual function dispatching
redirect_from: /2014/04/30/virtual_function_dispatching
---
Very often, [C++ interviews ask about the virtual table](http://programmers.stackexchange.com/questions/80591/why-is-no-c-interview-complete-if-it-does-not-have-vtable-questions): how it works, how is it implemented and the tricky bits around constructors & destructors. However, rarely are the following questions asked: why is it the way it is and are there alternatives?

Seeing how the C++ standard does not mandate how virtual function dispatching should be implemented, it is interesting that most compilers ended up converging on the current table approach. The [wikipedia article](http://en.wikipedia.org/wiki/Virtual_method_table) does a fairly good job to explain how it works and gives a good idea of the problem it is trying to solve. However, it fails to address the assumptions and performance constraints that likely shaped the current design.

For simplicity’s sake, we will only consider the case of single inheritance but keep in mind all methods discussed here can be extended to support multiple inheritance.

Let us go back to the drawing board and take a closer look at the problem we are trying to solve, what our tools are and our performance constraints.

### The problem:
It is often desirable to derive from a base class and override part of its behaviour. This is best achieved by implementing a specialized function that the base class would call (or for that matter, any code) when present or call the base implementation when our only knowledge is the type of the base class at a particular function call site.

### The tools:
All classes and functions are known at compile time and ideally we want to leverage that as much as possible.

### The performance constraints:
Memory and CPUs are slow and scarce and we want to have this mechanism be as fast as possible and at the same time be as compact in memory as possible. We can safely assume that for some classes we could have a large number of such virtual functions and we can assume as well that for some classes we might have a large number of instances.

### The inline solution:
The simplest solution would simply be to store a function pointer for every such virtual function inside the object itself. At object construction, we can simply set these pointers and later when we need to invoke them, we simply call the correct function pointer.

The upside of such a simple method is that the information we need is right there inside the object and we can access it directly. It will also end up with the rest of the adjacent object data in whatever [cache line](http://en.wikipedia.org/wiki/CPU_cache) is loaded to access the function pointer. By identifying which data is used by which function, we could move relevant data close to that function pointer and improve locality. Calling such a virtual function would thus incur a single data cache miss (to access the pointer).

The downside is that it does not scale. The more virtual functions we add, the larger our objects will end up being. This is made even worse on platforms with 64 bit pointers. The cost to initialize those data members also increases with each new virtual function. Finally, if enough virtual functions are added, our cache line might end up being completely filled by them such that no other immediately useful information ends up being loaded anyway.

Ultimately, this method will not degrade gracefully when either the number of object instances increases or the number of virtual functions rises.

This method is ideal when:

* the number of virtual functions per class is low
* meaningful data can be moved close to the virtual function pointer (eg: a getter and the returned value)
* the number of class instances is low

### The dispatch function:
A more flexible approach would be for our objects to have a single function pointer to a per class dispatch function. This function would then be called in a similar fashion to syscall(..): an extra argument to indicate which virtual function is expected would be provided. On object construction, similar to the previous approach, we simply set the proper dispatch function.

The upside is that now our cost per object is a single function pointer and we are very flexible. At runtime we could add extra data to change the dispatching behaviour (and indeed a mechanism similar to this is used by many dynamic languages for duck typing and such) and we are also very flexible in our we store the virtual function pointers: we can either store them in an array somewhere along with the identifier that we need to match or we can store it inline in the assembly stream. The latter approach is also interesting because it could end up being more compact than the former on architectures where instruction sizes can vary and that support relative jumps (e.g.: x64). Another point in favour of the later approach is that the code cache generally has less pressure than the data cache by virtue of the facts that code execution is largely linear and more easily prefetched and there is also less code compared to data. Last but not least, a dispatch function for a given class only needs to test the virtual functions it implements and defer resolution to its base class should it not handle the call.

The downside is that to find the correct virtual function pointer to call we need to introduce extra branching which will could end up being poorly predicted. Various methods can mitigate this: sorting the virtual functions in a tree structure to guaranty O(log(n)) access time (it could even be updated at runtime to favour hot functions) or the introduction of a bloom filter as an early out mechanism. Another problem is the calling convention: because for efficiency reasons we need a register to hold the virtual function identifier when we call our dispatch function, that register must be reserved to avoid shuffling all the registers and the stack when the effective virtual function is called. While this approach scales well when the number of object instances increases, it does not scale as well when the number of virtual functions rises.

Compared to the previous approach, we will need to incur one data cache miss for the dispatch function pointer and one (or more) code cache miss for the dispatching code. The compiler could be smart here and position the dispatch code close to the virtual functions of the same class in hope that it ends up being on the same page and thus avoid a [TLB](http://en.wikipedia.org/wiki/Translation_lookaside_buffer) miss when the actual function is called.

Much like the previous approach, this method does not degrade gracefully when the number of virtual functions increases.

This method is ideal when:

* The dispatching behaviour needs to be altered at runtime
* The dispatching logic is complicated
* The number of virtual functions per class is low
* The number of class instances is high

### The virtual table:
Finally we reach the current popular implementation: a single pointer to an array of virtual function pointers. Similar to previous methods, on object construction we simply set the proper array pointer. For this method to work, the array must contain function pointers for all virtual functions of the current class as well as all base classes. When we perform a virtual function call, knowing which function is called we can infer an offset in the array to use and simply call the correct virtual function pointer.

The upside is that like the previous approach, this scales well to a large number of object instances due to the low per object overhead but unlike the previous approach, it also scales well to a large number of virtual functions since finding the correct one is O(1).

There are no obvious downsides and in the end, this method will degrade gracefully.

However, things are not perfect: the array of virtual functions must be put somewhere. When we call a virtual function, we will thus incur two data cache misses: one for the pointer to the array and another for the actual virtual function pointer used. This second cache miss may very well not contain relevant information in the cache line besides the few bytes we need for the pointer. This will of course depend heavily on the usage but in general, there will be a lot of waste in that cache line. Because we can’t position the array in meaningful position, it is also possible that the page where it resides does not contain other relevant information, causing pressure on the TLB. In practice, other virtual function arrays are likely to end up in that page and a large number of them could fit inside. Thus a program using virtual functions with this method with 16KB worth of virtual function arrays could very easily end up permanently using four 4KB TLB entries (it is typical for most kernels to use 4KB pages for this sort of data). Incidentally, with increased TLB pressure, we also have an increased pressure on higher level caches such as ERAT on PowerPC and the [micro TLB](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360e/CHDDIJBD.html) on ARM chips.

This method is ideal when:

* The number of class instances is high
* The number of virtual functions per class is high

### The conclusion:
Depending on the scenario and usage, each variant could end up being the superior choice but ultimately, if a language does not expose control over which method is used for this, it must make a safe choice that supports its relevant use cases (e.g.: duck typing at runtime) and degrades as gracefully as possible under unknown scenarios.

