---
layout: post
title: "Virtual memory implications"
---
Virtual memory is an integral part of modern computing yet it remains often misunderstood. Detailed information can sometimes be hard to find on this topic. My goal with this post is simple: bring as many pieces of the puzzle into one place.

A good understanding of how virtual memory works will be required for my next post: measuring the performance of code that typically runs on a cold CPU cache (e.g. animation decompression, spatial hashing structures, etc.).

There are already a myriad of great posts our there that talk about this topic with images and fantastic explanations. [Here](https://lwn.net/Articles/253361/) is a great article that covers the topic quite in depth. The rest of the post will assume a certain degree of familiarity on the topic.

Note that in the interest of brevity, I will focus on modern consumer grade x86 and ARM CPUs. [High end server hardware](https://software.intel.com/sites/default/files/managed/2b/80/5-level_paging_white_paper.pdf), hypervisors, and [GPUs](https://www.cs.yale.edu/homes/abhishek/sshin-gcox-isca18.pdf) all use virtual memory in very similar fashion. See also the [history of virtual memory](http://denninginstitute.com/itcore/virtualmemory/vmhistory.html).

## The basics

Fundamentally, virtual memory is an abstraction layer around the real physical memory. By introducing an abstraction layer, the operating system can protect, share, and better manage the available physical memory. Each user process has access to its own address space (the bottom 48 bits of each pointer in 64 bit land). With the help of a mapping structure maintained by the operating system, the hardware can quickly find where data lives. This process of translating a virtual address into a physical one is handled by the Memory Management Unit (MMU). Each user space process has its own set of mapping structures.

CPUs only support splitting memory in fixed sized blocks called memory pages. Only a few page sizes are supported by the hardware itself. For example, modern Intel and AMD x64 processors support pages that are 4 KB, 2 MB, or 1 GB in size. [ARM often supports 4 KB, 16 KB, and 64 KB](https://static.docs.arm.com/100940/0100/armv8_a_address%20translation_100940_0100_en.pdf). Other processors might support different sizes.

## Address translation

A common page size on desktops and laptops is 4 KB. To be able to perform the address translation, our mapping structure requires [4 levels](https://lwn.net/Articles/253361/). Address translation levels are not to be confused with CPU cache levels. I will explicitly mention the CPU cache when I refer to it.

A 64 bit virtual address value is thus split into 5 regions:

*  Bits [63, 48] are ignored and often denote [user/kernal space addresses](https://unix.stackexchange.com/questions/509607/how-a-64-bit-process-virtual-address-space-is-divided-in-linux) (the bits typically have to be the same)
*  Bits [47, 39] are an offset into the Level 0 of our mapping structure
*  Bits [38, 30] are an offset into the Level 1 of our mapping structure
*  Bits [29, 21] are an offset into the Level 2 of our mapping structure
*  Bits [20, 12] are an offset into the Level 3 of our mapping structure
*  Bits[11, 0] are an offset into the physical memory page

In order to translate some virtual memory address into a physical one, the CPU needs to read 4 separate memory locations (in the mapping structure). A fifth access is required to read the actual data requested within the desired memory page.

Each offset (at every level) points to a table with 512 entries. Each entry in our table regardless of its level takes 8 bytes. Some bits are reserved for attributes of the memory page (e.g. read/write/exec).

The base of the Level 0 is held in a special hardware register (which changes when the CPU performs a context switch from one process to another). Each entry points to a table that spans a range of virtual memory.

*  Level 0 entries span 512 GB (512 x 1 GB)
*  Level 1 entries span 1 GB (512 x 2 MB)
*  Level 2 entries span 2 MB (512 x 4 KB)
*  Level 3 entries span 4 KB (a full memory page)

After the Level 1 table is found, the next offset points to a table in Level 2 (note that if we use 1 GB memory pages instead, we stop here and we have no Level 2 or 3). Following along with the next offset leads us to a table in Level 3 (note that if we use 2 MB memory pages instead, we stop here and we have no Level 3). Our final Level 3 offset points to a 4 KB page in physical memory.

This process of translating a virtual address is often called *page walking*. Processors are often limited in the number of concurrent page walkings they support. [AMD Zen2 processors apear to support two](https://en.wikichip.org/wiki/amd/microarchitectures/zen_2).

What this means is that the worst case scenario for a memory access is 5 un-cached reads from memory. CPU cache misses are often in the 150-300 cycle ballpark which means the worst case cost is around 750-1500 cycles! Thankfully in practice a lot of these accesses will hit in the CPU cache. [Details are sparse](https://electronics.stackexchange.com/questions/21469/are-page-table-walks-cached), but it is generally safe to assume that the mapping structure is cached in at least the CPU L2 (and L3) cache.

Most applications use less than 512 GB of memory and as such the Level 0 and Level 1 tables will be small and live in 1 or 2 cache lines which generally will be accessed often enough to remain in the CPU cache at all times. However, if the operating system context switches to another process, it could evict them as well. Similarly, if our process migrates to a different core, its local CPU cache might be cold.

Each table entry being 8 bytes, 8 such entries will fit in a typical 64 bytes cache line. This is important because processors cache with a granularity of a cache line. It follows that each cache line covers a fairly large span of virtual address space as well:

*  Level 0 table cache lines cover 4096 GB (8 x 512 GB)
*  Level 1 table cache lines cover 8 GB (8 x 1 GB)
*  Level 2 table cache lines cover 16 MB (8 x 2 MB)
*  Level 3 table cache lines cover 32 KB (8 x 4 KB)

The CPU will often attempt to prefetch memory ahead after it is accessed through [hardware prefetching](https://en.wikipedia.org/wiki/Cache_prefetching#Methods_of_hardware_prefetching). This typically kicks in after two consecutive cache lines are touched in a predictable pattern. I could not find reliable information to help determine if mapping structure cache line accesses can trigger the hardware prefetcher or not. Similarly, I do not know if they pollute the [hardware prefetcher streams](https://en.wikipedia.org/wiki/Cache_prefetching#Stream_buffers) that it keeps track of. There is a very good chance that they are not impacted by translation cache accesses.

## Translation lookaside buffer

Even if every memory access in our mapping structure is cached by the CPU, they each must be read one after the other. The reads cannot execute in parallel and the CPU cannot speculate. A typical memory load in the CPU L1 cache takes ~4 cycles. This means that the translation part might take around ~16 cycles in the best case scenario. In practice, the translation entries might not be cached in the CPU L1 cache but might live in other levels still. Overall, this leads to a fairly high cost: 16 cycles is 5-11% overhead added on top of our actual cache miss.

To speed things up, moderns CPUs have a [translation lookaside buffer (TLB)](https://en.wikipedia.org/wiki/Translation_lookaside_buffer). This is a cache of the most recently accessed memory pages and their translation results. Thanks to the TLB, accessing the same memory page over and over is very quick and cheap and it allows us to pay only for the potential cache miss of the cache line we access. In such a scenario, the translation part of the memory access is basically free when it hits the TLB.

As with normal data, this cache is generally split between the CPU L1 and L2 caches. For example, [AMD Zen2](https://www.7-cpu.com/cpu/Zen2.html) CPUs have ~192 entries in the CPU L1 and ~2048 entries in the CPU L2. Some CPUs support coalescing multiple neighboring pages and as such each TLB entry might cover multiple contiguous pages (AMD Zen2 appears to cover 4x 4KB pages per TLB entry).

When a memory access occurs, the processor first checks if the address translation is cached in the TLB L1, and if not, in the TLB L2, and if not it will perform the full table walk as described earlier.

Some updates the mapping structures require flushing some TLB entries which is slow. This most often happens when freeing memory which can lead to [TLB drive by shootings](http://bitcharmer.blogspot.com/2020/05/t_84.html). I highly recommend reading the linked article. He focuses on the CPU impact but I suspect that the GPU can also be impacted on platforms that have a shared virtual address space between the two (e.g. integrated graphics on a laptop or a gaming console).

## Practical implications

Now that we know how virtual memory works and how the hardware handles it, we can discuss some practical implications.

Re-using memory (instead of freeing it and allocating it again on demand) means we can avoid updating the mapping structures. It also means we can leverage any potentially cached translation entries in the TLB and in the virtual memory address translation cache lines already present in the CPU cache. The execution stack is perfect for this as well as [thread local stack memory allocators]({% post_url 2016-05-08-stack_frame_allocators %}).

Things that are accessed together should live close by in the virtual memory address space to leverage the TLB and the address translation cache lines. By controlling how your data is allocated, you can ensure optimal address translation performance. This can be achieved by using a [custom memory allocator]({% post_url 2016-10-18-memory_allocators_toc %}).

Using larger memory pages means that the cost of address translation is reduced. Accessing memory will thus be faster when a TLB miss occurs. It is worth noting that while faster, large pages can lead to internal fragmentation. When a memory page isn't fully used, the remaining space may unusable and thus wasted.

## Conclusion

Virtual address translation costs add up and when designing software to be as fast as possible from the ground up, taking virtual memory into account is paramount. Not only can it make the resulting code faster but it can also make its performance much more predictable. With the various potential cache misses involved for every memory access, code that is otherwise deterministic can end up having a large variance in its execution time. The fact that the memory bus is shared with many CPU cores (and other things) only makes things worse. This makes memory by far the biggest source of variance in CPU bound deterministic code.
