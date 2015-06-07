---
layout: post
title: Caches everywhere
redirect_from: /2014/05/05/caches_everywhere
---
The modern computer is littered with caches to help improve performance. Each cache has its own unique role. A solid understanding of these caches is critical in writing high performance software in any programming language. I will describe the most important ones present on modern hardware but it is not meant to be an exhaustive list.

The modern computer is heavily based on the [Von Neumann architecture](http://en.wikipedia.org/wiki/Von_Neumann_architecture). This basically boils down to the fact that we need to get data into a memory of sorts before our CPU can process it.

This data will generally come from one of these sources: a chip (such as ROM), a hard drive or a network and this data must make it somehow all the way to the processor. Note that other external devices can DMA data into memory as well but the above three are the most common and relevant to today’s discussion.

I will not dive into the implications for all the networking stack and the caches involved but I will mention that there are a few and understanding them can yield [good gains](http://blog.superpat.com/2010/06/01/zero-copy-in-linux-with-sendfile-and-splice/).

### The kernel page cache

Hard drives are [notoriously slow](https://gist.github.com/jboner/2841832) compared to memory. To speed things up, a number of caches lay in between your application and the file on disk you are accessing. From the disk up to your application, the caches are in order: [disk embedded cache](http://en.wikipedia.org/wiki/Disk_buffer), [disk controller cache](http://en.wikipedia.org/wiki/Disk_array_controller), [kernel page cache](http://en.wikipedia.org/wiki/Page_cache), and last but not least, whatever [intermediate buffers](http://docs.oracle.com/javase/7/docs/api/java/io/BufferedReader.html) you might have in your user space application.

For the vasty majority of applications dealing with large files, the single most important optimization you can perform at this level is to use MMAP to access your files. You can find an excellent write up about it [here](http://duartes.org/gustavo/blog/post/page-cache-the-affair-between-memory-and-files/). I will not repeat what he says but add that this is a massive win not only because it allows avoiding needless copying of memory but also by mentioning that you can [prefetch easily](https://msdn.microsoft.com/en-us/library/windows/desktop/hh780543%28v=vs.85%29.aspx), something not so easily achieved with `fread` and the likes.

If you are writing an application that does a lot of IO or where it needs to happen as fast as possible (such as console/mobile games), you should ideally be using MMAP where it is supported ([android supports it](http://developer.android.com/reference/java/nio/channels/FileChannel.html), [iOS supports it but with 700MB virtual memory limit on 32bit processors](http://stackoverflow.com/questions/13425558/why-does-mmap-fail-on-ios), and both Windows and Linux obviously support it). I am not 100% certain, but in all likely hood, the newest game consoles (XboxOne and PlayStation 4) should support it as well. However, note that not all these platforms might have a kernel page cache but that it is a safe bet that going forward, newer devices are likely to support it.

### The CPU cache

The next level of caches lays much closer to the CPU and take the form of the popular [L1, L2, and L3 caches](http://en.wikipedia.org/wiki/CPU_cache). Not all processors will have these and when they do, they might only have one or two levels. Higher levels are generally inclusive in regards to the lower levels but [not always](http://stackoverflow.com/questions/19775173/inclusive-or-exclusive-l1-l2-cache-in-intel-core-ivybridge-processor). For example, while the L3 will generally be inclusive of the L2, the L2 might not be inclusive of the L1. This is so because some instructions such as [prefetching](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0438d/BABJCGGE.html) will prefetch in the L2 but not the L1 and thus potentially cause eviction of cache lines that are in the L1.

The CPU cache is always moving data in and out of memory in units called a [cache line](http://stackoverflow.com/questions/3928995/how-do-cache-lines-work) (they will always be aligned in memory to a multiple of the cache line size). Cache line sizes vary depending on the hardware. Popular values are: 32 bytes on some older mobile processors, 64 bytes on most modern mobile, desktop and game console processors, and 128 bytes on some PowerPC processors (notably the Xbox360 and the PlayStation 3).

This cache level will contain code that is executing, data being processed, and translation look-aside buffer entries (for both code and data, see next section). They might be dedicated to either code or data (e.g: L1) or be inclusive of both (e.g: L2/L3).

The CPU cache is usually N-way set associative. You can find a good write up about this [here](http://www.hardwaresecrets.com/article/How-The-Memory-Cache-Works/481/8). Note that depending on the cache level, where the cache line index and tag comes from might differ. For example, the [code L1 might use the physical memory address to calculate both the index and the tag](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360f/CHDEJHGD.html) while the [data L1 might use the virtual memory address for both the index and the tag](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0360f/CBAHAAGB.html). The L2 is also free to choose whatever arrangement it pleases and note that in theory, they could be mixed (tag from virtual, index from physical).

When the CPU requests for a memory address, it is said to *hit* the cache if the desired cache line is inside a particular cache level and a *miss* if it is not and we must look either in a higher cache level or worse, main memory.

This level of caching is the primary reason why packing things as tight as possible in memory is important for high performance: fetching a cache line from main memory is slow and when you do, you want most of that cache line to contain useful information to reduce waste. The larger the cache line, the more waste will generally be present. Things can be pushed further by aligning your data along cache lines when you know a cache miss will happen for a particular data element and to group relevant members next to it. This should not be done carelessly, as it can easily degrade performance if you are not careful.

This level of caching is also an important reason while calling a virtual function is often painted as slow: not only must you incur a potential cache miss to read the pointer to the virtual function table but you must also incur a potential cache miss for the pointer to the actual function to call afterwards. It is also generally the case that these two memory accesses will not be on the same cache line as they will generally live in different regions in memory.

This level of caching is also partly responsible for explaining why reading and writing unaligned values is slower (when the CPU supports it). Not only must it split or reconstruct the value from potentially two different cache lines but each access is potentially a separate cache miss.

Generally speaking, all cache levels discussed up to here are shared between processes that are currently executed by the operating system.

### The translation look-aside buffer

The next level of caching is the [translation look-aside buffer](http://en.wikipedia.org/wiki/Translation_lookaside_buffer), or TLB for short.

The TLB is responsible for caching results of the translation of virtual memory addresses into physical memory addresses. Translation happens with a granularity of a fixed page size and modern processors generally support two or more page sizes with the most popular on x64 hardware being 4KB and 2MB. Modern CPUs will often support 1GB pages but using anything but 4KB pages in a user space application is sometimes not trivial. However, on game console hardware, it is common for the kernel to expose this and using this important tool is important for high performance.

The TLB will generally have separate caches for the different page sizes and it often has several levels of caching as well (L1 and L2, note that these are separate from the CPU caches mentioned above). When the CPU requests the translation of a virtual memory address, since it does not yet know the page size used, it will look in all TLB  L1 caches for all page sizes and attempt to find a match. If it fails, it will look in all L2 caches. These operations are often done in parallel at every step. If it fails to find a cached result, a table walk will generally follow or a callback into the kernel happens. This step is potentially [very expensive](https://www.kernel.org/doc/gorman/html/understand/understand006.html)! On x64 with 4KB pages, typically four memory accesses will need to happen to find which physical memory frame  (frame is generally the word used to refer to the unit of memory management the hardware and kernel use) contains the data pointed to and a fifth memory access to finally load that data into the CPU cache. Using 2MB pages will remove one memory access reducing the total from five to four. Note that each time a TLB entry is accessed in memory, it will be cached in the CPU cache like any other code or data.

This sounds very scary but in practice, things are not as dire as they may seem. Since all the memory accesses are cached, a TLB miss does not generally result in five cache misses. Pages cover a large range of memory addresses and typically the top levels of the address used will cover a large range of virtual memory and as such, the least virtual memory touched, the less data the TLB needs to manage. However, a TLB entry miss at a level N will generally guaranty that all lower TLB entry accesses will result in cache misses as well. In essence, not all TLB misses are equal.

As must be obvious now, every time I mentioned the potential for CPU cache misses in the previous section, is now potentially even worse if it results in a TLB miss as well. For example, as previously mentioned, virtual tables require an extra memory access. This extra memory access, by virtue of being in a separate memory region (the virtual table itself is read only and compiled by the linker while the pointers to said virtual table could be on the heap, stack, or part of the data segment), will typically require a separate cache line for it and separate TLB entries. It is clear that the indirection has a very real cost, not only in terms of the branch the CPU must take that it cannot predict but also in the extra pressure on the CPU and TLB caches.

Note that when a hypervisor is used with multiple operating systems running concurrently, since the physical memory is shared between all of these, generally speaking when looking up a TLB entry, an additional virtual memory address translation might need to take place to find the true location. Depending on the security restrictions of the hypervisor, it might elect to share the TLB entries between guests and the hypervisor or not.

### The micro TLB

Yet another popular cache that is not present (as far as I know) in x64 hardware but common on PowerPC and ARM processors is a higher level cache for the TLB. ARM calls this the micro TLB while PowerPC calls it ERAT.

This cache level, like the previous one, caches the result of translation of virtual addresses into physical addresses but it uses a different granularity from the TLB. For example, while the [ARM processors](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0535b/CACCAFHH.html) will generally support pages of 4KB, 64KB, 1MB, and sometimes 16MB; the micro TLB will generally have a granularity of 4KB or 1MB. What this means is that the micro TLB will miss more often but will often hit in the TLB afterwards if a larger page is used.

This cache level will generally be split for code and data memory accesses but will generally contain mixed page sizes and it is often fully associative due to its reduced size.

The CPU, TLB, and micro TLB caches are not only shared by currently running processes of the current operating system but when running in a virtualized environment, they are also shared between all the other operating systems. When the hardware does not support the sharing by means of registers holding a process identifier and virtual environment identifier, generally these caches must be flushed or cleared when a switch happens.

### The CPU register

The last important cache level in a computer I will discuss today is the CPU register. The register is the basic unit modern processors use to manipulate data. As has been outlined so far, getting data here was not easy and the journey was long. It is no surprise that at this level, everything is now very fast and as such packing information in a register can yield good performance gains.

Values are loaded in and out of registers directly into the L1 assisted by the TLB. Register sizes keep growing over the years: 16bit is a thing of the past, 32bit is still very common on mobile processors, 64bit is now the norm on newer mobile and desktop processors, and processors with multimedia or vector processing capability will often have 128bit or even 256bit registers. In this later case, this means that we only need two 256bit registers to hold an entire cache line (generally 64 bytes on these processors).

### Conclusion

This last points hammers in the overall high performance mantra: don’t touch what you don’t need and do the most work you can with as little memory as possible.

This means loading as little as possible from a hard drive or the network when such accesses are time sensitive or look into compression: it is not unusual that simple compression or packing algorithms will improve throughput significantly.

Use as little virtual memory as you can and ideally use large pages if you can to reduce TLB pressure. Data used together should ideally resides close by in memory. Note that virtual memory exists primarily to help reduce physical memory fragmentation but the larger the pages you use, the less it helps you.

Pack as much relevant data as possible together to help ensure that it ends up on the same cache line or better yet, align it explicitly instead of leaving it to chance.

Pack as much relevant data as possible in register wide values and manipulate them as an aggregate to avoid individual memory accesses (bit packing).

Ultimately, each cache level is like an instrument in an orchestra: they must play in concert to sound good. Each has their part and purpose. You can tune individually all you like but if the overall order is not present, it will not sound good. It is thus not about the mastery of any one topic but in understanding how to make them work well together.

This post is merely an overview of the various caches and their individual impacts. A lot of information is incomplete and missing to keep this post concise (I tried..). I hope to revisit each of these topics in separate posts in the future when time will allow.

