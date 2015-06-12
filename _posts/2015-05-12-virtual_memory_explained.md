---
layout: post
title: Virtual memory explained
---
Virtual memory is present on most hardware platforms and it is surprisingly simple. However, it is often poorly understood. It works so well and seamlessly that few inquire about its true nature.

Today we will take an in-depth look at why do we have virtual memory and how it works under the hood.

### Physical memory: a scarce ressource

In the earlier days of computing, there was no virtual memory. The computing needs were simple and single process operating systems were common (batch processing was the norm). As the demand grew for computers, so did the complexity of the software running on them.

Eventually the need to run multiple processes concurrently appeared and soon became mainstream. The problem with multiple processes in regards to memory is three-fold:

* Physical memory must be shared somehow
* We must be able to access more than 64KB of memory using 16 bit registers
* We must protect the memory to prevent tampering (malicious or accidental)

### Memory segments

[On x86](http://en.wikipedia.org/wiki/X86_memory_segmentation), the first and second point were addressed first with *real mode* (1MB range) and later, memory protection was introduced with *protected mode* (16MB range). Virtual memory was born but it was not in the form most commonly seen today: early x86 used a segment based virtual memory model.

Segments were complex to manage but served their original purpose. Coupled with secondary storage, the operating system was now able to share the physical memory by swapping entire segments in and out of memory. Under 16 bit processors, segments had a fixed size of 64KB but later, when 32 bit processors emerged, segments grew to a variable and maximum size of 16MB. This later development had an unfortunate side-effect: due to the variable size of segments, physical memory fragmentation could now occur.

To address this, paging was introduced. Paging, like earlier segments, divides physical memory into fixed sized blocks. They also introduce an added indirection. With paging, segments were now further divided into pages and each segment further contained a page table to resolve the mapping between segment relative addresses and real effective physical addresses. By their nature, pages do not need to be contiguous within a given segment allowing them to resolve the memory fragmentation issues.

At this point in time, memory accesses now contain two indirections: first we must construct the segment relative address using a 16 bit segment index, reading the 32 bit segment base address associated and adding a 32 bit segment offset (386 CPUs shifted from 24 bit base addresses and offsets to 32 bit at the same time it introduced paging). This yields us a memory address that we must now look up in the segment page table to ultimately find the physical memory page (often called frame) that contains what we are looking for.

### Modern virtual memory

Things now look much closer to modern virtual memory. Now that we have 32 bit processors and that they are common enough, there is no longer a need for segments and paging alone can be used. The x86 hardware of the time already used 32 bit segment base addresses and 32 bit segment offsets. Memory becomes far easier to manage if we assume it is a single memory segment with paging and it allows us to drop one level of indirection.

Most of this memory address translation logic now happens inside the MMU (memory management unit) and is helped by internal caches. This cache is now more commonly called the Translation Look-aside Buffer, or TLB for short.

[Earlier x86 processors](http://www.rcollins.org/ddj/May96/) only supported 4KB memory pages. To accommodate this, a virtual memory address was split into three parts:

* The first 10 bits represent an index in a page directory that is used to look up a page table.
* The following 10 bits represent an index in the previously found page table that is used to look up a physical page frame.
* The remaining 12 least significant bits are the final offset into the physical page frame leading to the desired memory address.

A dedicated register points to a page directory in memory. Both page directory entries and page table entries are 32 bits and contain flags to indicate memory protection and other attributes (cacheable, write combine, etc.). Another dedicated register holds the current process identifier which is used to tell which TLB entries are valid or not (and avoids the need for flushing the entire TLB when context switching between processes).

As memory grew, 4KB pages had difficulty scaling. Servicing large allocation requests requires mapping large numbers of 4KB pages putting more and more pressure on the TLB. The bookkeeping overhead also grows along with the number of pages used. Eventually, [larger pages (4MB)](http://en.wikipedia.org/wiki/Page_Size_Extension) were introduced to address these issues.

And then memory sizes grew even further. Soon enough, being confined to an address space of 4GB with 32 bit pointers became too small and [physical address extension](http://en.wikipedia.org/wiki/Physical_Address_Extension) was introduced and extended the addressable range to 64GB. This forced larger pages to reduce to a size of 2MB as now some bits were needed for another indirection level in the page table walk.

### Virtual memory today

Today, x64 hardware most commonly supports pages of the following sizes: 4KB, 2MB, and sometimes 1GB. Typically, only 48 bits are used limiting the addressable memory to 256TB.

Another important aspect of virtual memory today is how it interacts with virtualization (when present). Because physical memory must be shared between the running operating systems, page directory entries and page table entries now point into virtual memory instead of physical memory and require further TLB look-ups to resolve the complete effective physical address. Much like process identifiers, a virtualization instance identifier has been introduced for the same purpose: avoiding full TLB flushes when context switching.

Modern hardware will generally have separate caches per page size which means that to get the most performance, [which page sizes are used for what data must be carefully planned](http://lwn.net/Articles/379748/). For example, in certain embedded platforms, it is not uncommon to have 4KB pages be used for code segments, data segments, and the stack while encouraging programmers to use 2MB pages inside their programs. It is also not uncommon to have virtual pages introduced: a virtual page will be composed of a smaller number of pages. For example, you might request allocations to use 64KB or 4MB pages even though the underlying hardware only supports 4KB and 2MB pages. The distinction is mostly important for the kernel since managing larger pages implies lower bookkeeping overhead and faster servicing.

An important point bears mentioning, when pages larger than 4KB are used, the kernel must find contiguous physical memory to allocate them. This can be a problem if page sizes are mixed, it opens the door to fragmentation to rear its ugly head. When the kernel fails to find enough contiguous space but it knows enough space would otherwise remain, it has two choices:

* Bail out and return stating that you have run out of memory.
* Defragment the physical memory by copying memory around and remapping the pages.

Generally speaking, if mixed page sizes are used, it is generally recommended to allocate large pages as early as possible in the process’s life to remedy the above problem.

### Virtual memory secondary storage

The fact that modern hardware allows virtual memory to be mapped in your process without mapping all the required pages to physical memory enables modern kernels to spill memory onto secondary storage to artificially increase the amount of memory available up to the limits of that secondary storage.

As is common knowledge, the most common form of secondary storage is the swap file on your hard drive.

However, the kernel is free to place that memory anywhere and implementations exist where the memory will be distributed in a network or some other medium (e.g: memory mapped files).

### Conclusion

This concludes our introduction to virtual memory. In later blog posts we will explore the TLB into further details and the implications virtual memory has on the CPU cache. Until then, here are some additional links:

* [http://www.cs.princeton.edu/courses/archive/fall11/cos318/lectures/L15_VMPaging.pdf](http://www.cs.princeton.edu/courses/archive/fall11/cos318/lectures/L15_VMPaging.pdf)
* [http://www.it.uu.se/edu/course/homepage/dark/ht11/dark15-vm2.pdf](http://www.it.uu.se/edu/course/homepage/dark/ht11/dark15-vm2.pdf)
* [http://www.informit.com/articles/article.aspx?p=29961&seqNum=4](http://www.informit.com/articles/article.aspx?p=29961&seqNum=4)
* [http://lwn.net/Articles/250967/](http://lwn.net/Articles/250967/)


