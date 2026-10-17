---
layout: post
title: GPGPU woes part 3
---
After fixing the [previous]({% post_url 2015-07-07-gpgpu_woes_part_2 %}) mind bending issue, we move on to the next issue.

### On the GPU, the address space size can differ

Virtually every programmer out there knows that the address space size on the CPU can differ based on the hardware, executable, and kernel. The two most common sizes being 32 bits and 64 bits (partially true since in practice only 48 bits are used for now). Some older programmers will also remember the times of the 16 bits address space.

What few programmers realize is that other chips in their computer might have a different address space size and as such sharing binary structures with them that contain pointers is generally unsafe.

### Case in point: my GPU has a 64 bits address space.

What this means is that if I run a i386 executable in either OS X or Windows, the pointer size will be 4 bytes on the CPU but the GPU will use 8 bytes for pointers. This means that structures like this that are shared will not work:    

{% highlight cpp %}
struct dom_node
{
    struct dom_node *parent;
    cl_int id;
    cl_int tag_name;
    cl_int class_count;
    cl_int first_class;
    cl_int style[MAX_STYLE_PROPERTIES];
};
{% endhighlight %}

The above code was causing the reading and writing of memory far past the buffer that contained them when running on the GPU. This caused the output to differ from the expected result of the CPU version.

In particular, it ended up corrupting read-only buffers that the kernel was using (the read-only stylesheet) causing further confusion since the output differed from run to run. I was lucky enough that I didn’t end up corrupting anything else more critical as it could have made debugging the issue much harder (e.g: driver crash).

The fix is to ensure there is proper padding by wrapping the pointer in a union:

{% highlight cpp %}
struct dom_node
{
    union
    {
        struct dom_node *parent;
        cl_ulong pad_parent;
    };
    cl_int id;
    cl_int tag_name;
    cl_int class_count;
    cl_int first_class;
    cl_int style[MAX_STYLE_PROPERTIES];
};
{% endhighlight %}

OpenCL has integer types with the `cl_` prefix in order to ensure their size does not differ between the CPU and GPU but sadly no such trick is possible with pointers: we have to resort to our manual union hack. In practice we could probably introduce a macro to wrap this and make it cleaner.

Ideally sharing structures that contain pointers with the GPU isn’t such a good idea. Unless memory is unified, the GPU will not be able to access that memory and as such it is wasteful. Even if the memory is unified, typically the GPU accessible memory must be allocated with particular flags and depending on the platform it might only be possible through the driver.
