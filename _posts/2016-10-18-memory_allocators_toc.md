---
layout: post
title: "Memory Allocators: Table of Contents"
toc: "Memory Allocators"
---
It is perhaps a bit late but I am starting to have quite a few posts on the topic of memory allocators and navigation was beginning to be a bit complex.

I thought it would be a good idea to have a central place that links everything together.

All the relevant code for this lives under [Gin]({% post_url 2015-05-03-introducing_gin %}) ([code](https://github.com/nfrechette/gin)) on GitHub.

# Table of Content

* Linear allocators
  * [Classic linear allocator]({% post_url 2015-05-21-linear_allocator %})
  * [Virtual memory aware linear allocator]({% post_url 2015-06-11-vmem_linear_allocator %})
  * Thread safe linear allocator
* [Stack frame allocators]({% post_url 2016-05-08-stack_frame_allocators %})
  * [Greedy stack allocator]({% post_url 2016-05-09-greedy_stack_frame_allocator %})
  * [Virtual memory aware stack allocator]({% post_url 2016-10-17-vmem_stack_frame_allocator %})
* Circular allocators
  * Classic circular allocator
  * Circular frame allocator
* Miscellaneous
  * [Dealing with being out of memory]({% post_url 2015-06-25-out_of_memory %})

