---
layout: post
title: Out of Memory
---
I have been playing *Game of War: Fire Age* for some time now and a peculiar issue keeps recurring which prompted this post: the game often runs out of memory.

This is an often rarely discussed issue and the solutions to it are seldom discussed as well. This post is an attempt to document various causes and solutions to this and help offer some insight into this.

### The causes

In video games, the memory workload is typically very predictable: we have hard limits on many features (e.g: max number of players) and generally fixed data. These two things coupled together imply that out of memory situations are generally quite rare. The typical causes are as follow:

> An excessively large memory size is requested and cannot be serviced.

I mean by this that 2GB or more might be requested on a device with very little memory (e.g: 256MB). This is generally caused by attempting to allocate memory with a negative size (size_t is typically used in C++ to represent this and it is unsigned however depending on the warning level and the compiler, automatic (or sometimes programmer forced) coercion can happen). This is generally an error due to unforeseen circumstances which rarely happens in a released title but that happens from time to time during development.

> More memory is allocated than the system allows.

Again, due to the predictable memory footprint of things in video games, it generally happens during development and very rarely in a released title.

> Over time, due to memory leaking, you run out of memory.

This can happen in released titles and more than a few have shipped with memory leaks.

> Memory fragmentation.

If the memory pressure is high and fragmentation is present, even though free memory might exist to service a particular allocation request, the system might fail due to fragmentation (either in user space or due to physical memory fragmentation on some embedded devices). Fragmentation is a real and painful issue to deal with when it creeps up. It will often remain hidden during development until very late primarily due to two things: final content often comes very late in production and the game will often not run for more than one hour until late in production as well. Out of memory situations can happen in released titles on memory constrained devices. I see it at least twice a day in Game of War on my android tablet.

### How to deal with it

On memory constrained devices, if you have memory fragmentation it is a fact of life that you will hit out of memory situations. This is even more likely if your software might run on devices below your minimum specifications (e.g: mobile android devices). When this happens, there are a few ways to deal with this. Here are the ones that come to mind, in increasing order of complexity:

> Do nothing and let it crash and burn.

Many games go this route and it costs literally nothing to adopt this strategy (if you can call it that). Sadly, not all crashes will be equal in impact. It is quite common for save games to generate quite a few memory allocations and crashing while the game is saving can often result in corrupted save games. For obvious reasons, this is very bad for the user experience.

> Let it crash but do so in a controller manner.

Games that realize that they might crash and instead opt to handle this with the least amount of effort will typically poll how much free memory remains and crash when it passes a threshold in a controlled and safe manner. Typically this implies doing this when the game isn’t doing anything important (such as saving the game) and presenting some kind of fatal error message to the user. As far I as I can recall, a version of *Gears of War* running on *Unreal 3* simply displayed a dirty disk error. This is generally considered acceptable since while it isn’t ideal for the user, at least nothing of value will be lost and ultimately it will remain a minor annoyance (depending on the frequency of course).

> Deal with it in a clever way.

*Game of War* is a good example of this. When the game runs out of memory, it sends you back to your home city screen and flashes some colours briefly. (I do not have access to the source code to confirm this but it appears to me to be the cause of this peculiar behaviour.) This can happen almost anywhere except when in the city screen. This is likely because the city screen has a low or very predictable memory footprint. This is superior to the previous approaches since while it remains a minor annoyance, at least you remain within the game and presumably you can continue playing for a little while longer.

> Fix the underlying issues.

This often requires the largest time investment. Not only does it require extensive testing to make sure even under all your imposed hard limits you do not exceed the maximum memory allowed (e.g: 16 vs 16 players) but it often requires dealing with memory fragmentation and making sure that there is none or very little.

### Case study: *AAA title (2014)*

During the development of *AAA title (2014)*, our final content for most maps came in very late in development and it all came at once. This made testing everything very hard. We knew very early on that a single platform would struggle with memory pressure and that prediction proved very accurate: our *PlayStation 3* title suffered from rampant out of memory situations.

A number of factors lead to this:

* 64KB page sizes meant that our memory allocator had to deal properly with virtual memory to avoid fragmentation.
* The PS3 has ~213MB of usable main memory and ~256MB of usable video memory. While you can use video memory as general purpose memory, accessing it from the CPU is very slow and is generally not recommended. This makes it the platform with the least amount of general purpose memory.
* With high memory pressure comes memory fragmentation issues.

While we made sure to perform memory optimizations throughout development to reduce our footprint, ultimately it proved not to be sufficient when we neared our release date. The final major memory optimizations (both code and data) came in about 6 months before we released our title. Around that time, memory fragmentation reared its ugly head and the battle began.

Fighting memory fragmentation is hard and painful. Even though I had knowledge of how it happens prior to facing it, I had never had actual experience dealing with it.

The battle raged on for 6 months before we finally eradicated it for good. We ultimately released the game with much more free memory than we anticipated: our efforts finally paid off.

But that is not the whole story. Dealing with memory fragmentation is complicated and is best left to a future blog post. I will however discuss our plan to deal with our worst case scenario: failure to fix our memory fragmentation issues.

Few people on *AAA title (2014)* really knew how bad it really got. At one point I had over 100 separate bug reports of out of memory issues: so many that whenever I would make an improvement, all I could do was claim everything as fixed and see what came back. It became a running gag that I had over half the bug reports assigned to me.

At some point, about 2 months before our release date, we could play the game for about an hour or two before running out of memory due to memory fragmentation. It was bad and we weren’t sure if we were going to be able to fix the issue in time for the release or even in time for our first patch. To prepare for this scenario, we took a similar approach to *Game of War* and when we detected a low memory situation, we would force a map transition into the *Player Hub* level. This was a small level that you would return to in between story arcs. This made it the perfect place. It was expected that the map transition would always succeed (at least before the user got tired!) due to the fact that whatever was unloading was larger than what we loaded. The map transition would also save your progress ensuring that your save game would never corrupt due to this.

It was a horrible hack, it was ugly, but it was necessary. With this, we knew that it was better than crashing and that if the user continued to play after this, and fragmentation became really bad, at worst he would not be able to leave that level without reloading into it and they would eventually get the message and restart the title. A necessary evil.

Ultimately, only 2 or 3 bug reports ever spoke of this weird behaviour and by the time we released our game, our memory fragmentation issues were fixed and it became unnecessary. In the end, we removed the hack from the final product since it was only for a single platform and now unnecessary. I personally played the game for over 4 consecutive hours on the night prior to our release and made sure our free memory would never dip below our acceptable threshold: 10MB. Most maps ended up with 15-20MB of free memory with our biggest maps closer to 10MB.

These hacks are a poor substitute for a real fix but with the pressures of the real world, they are often a necessary and realistic option. Do you have a similar war story?

[**Back to table of contents**]({% post_url 2016-10-18-memory_allocators_toc %})

