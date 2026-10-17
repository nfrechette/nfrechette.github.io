---
layout: post
title: GPGPU woes part 1
---
Curiosity about the [Servo](https://github.com/servo/servo) project from Mozilla finally got the best of me and I looked around to see if I could contribute somehow. A particular exploratory task caught my eye that involved running the CSS rule matching on the GPU. I forked the [original sample code](https://github.com/nfrechette/selectron) and got to work.

Little did I know I would hit some very weird and peculiar issues related to OpenCL on my Intel Iris 5100 inside my MacBook Pro. These issues are so exotic and rarely discussed that I figure they warranted their own blog posts.

Just getting the sample to work reliably on OS X and Windows 8.1 while attempting to get identical results in x86, x64, CPU, and GPU versions proved to take considerable time due to various issues.

### Moving pieces

GPGPU has a lot of moving pieces that can easily cause havoc. Code is typically written in a C like dialect (OpenCL, CUDA) and it is easy to make mistakes if you are not careful. If the old adage of blowing your foot off with C is true on the CPU, writing C on the GPU is probably akin to blowing up your whole neighbourhood along with your foot.

The first moving piece is the driver you use. Different platforms have different drivers, they also differ by hardware and how they update also differs. Bugs in the drivers are not unheard of and quite frequent since the hardware is still rapidly evolving and the range of supported devices grows everyday. For example, OS X provides the drivers as opposed to the manufacturer providing them like they do on Windows. This means the update process is much slower.

The second moving piece is the hardware itself. Even from a single manufacturer, there is considerable variation. From the number of compute units, the size of local storage, the size of the address space, all the way to whether memory is unified or not with the CPU.

This brings us to our first issue.

### On the GPU, there is no stack

The first exotic issue I hit was that the original code would not run for me. On Windows 8.1, the GPU would hit 100% utilization and cause the driver to time out (sometimes forcing me to power cycle). On OS X, the kernel would return after 5 or 10 seconds of runtime and attempting to run it a second time would cause the program to crash (after modifying it to run the kernel more than once to gather average timings).

After hunting for several hours, I finally found the culprit: a C style stack array with 16 elements. The total size of this array was 3 integers times 16 or 192 bytes. This seems fairly small but it fails to take into account how the GPU and generated assembly handle C style stack arrays.

{% highlight cpp %}
struct css_matched_property
{
    cl_int specificity;
    cl_int property_index;
    cl_int property_count;
};

// Later inside the kernel function
struct css_matched_property matched_properties[16];
{% endhighlight %}

On the GPU, there is no stack. From past experiences, the generated assembly will attempt to keep everything in registers instead of putting it in local or global storage (since local and global storage usage require explicit keywords). Because of this reason, it also will fail to spill in local storage or global memory if we run out of registers. In practice the driver could probably spill to memory when this happens but the performance would be terrible.

According to [the hardware specifications](https://software.intel.com/sites/default/files/managed/f3/13/Compute_Architecture_of_Intel_Processor_Graphics_Gen7dot5_Aug2014.pdf) of my GPU, each thread has 128 registers that each store 32 bytes (SIMD 8 elements of 32 bits). The above array requires 48 such registers if the data is not coalesced into fewer registers. Since we use a struct with 3 individual integers, this is a reasonable assumption. Along with everything else going on in the function, my kernel would in all likelihood (due to the nature of the crash, I failed to get exact measurements for the number of registers used) exhaust all available registers.

This marks the second time I see a GPU crash caused by the driver attempting to run a kernel that requires more registers than are available.

These sort of issues are nasty since the same kernel would work on hardware with more registers. It also looks like clean and simple code if you aren’t aware of what happens being the curtains.

The fix, as is probably obvious now, was to keep the array in shared local memory. This ensures we can calculate how much actual memory we require for this and based on the amount available on the given hardware, it caps the maximum number of threads we can execute in a group to avoid running out.

{% highlight cpp %}
const cl_int MAX_NUM_WORKITEMS_PER_GROUP = 320;
__local struct css_matched_property matched_properties[16 * MAX_NUM_WORKITEMS_PER_GROUP];
cl_int matched_properties_base_offset = 16 * get_local_id(0);
{% endhighlight %}

Keep in mind that at this stage of development, I was more concerned with getting the code running correctly than I was in getting it to run fast. The is no point in having fast code that does not do what you want.
