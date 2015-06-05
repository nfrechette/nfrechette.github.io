---
layout: post
title: The need for speed
---
The art of writing fast software is subtle and ever changing. Fundamentally, it is all about where your data comes from and how you access it.

At a high level, you have the entire field of algorithmic complexity dedicated to touching the least amount of data for a given task. At this level, the actual hardware that executes the algorithm hardly matters since we deal in very large numbers but this is not to say that it is irrelevant, faster hardware will always help.

As the amount of data manipulated shrinks, the gains from an optimal algorithm versus a slightly less optimal one will blur and a new perspective is necessary.

At a lower level, knowing how to leverage the hardware becomes of paramount importance. The operating system and the hardware go to great lengths to cache data in various ways and knowing how they are used is key in squeezing the very last drop of performance.

Last but not least, the modern processor is really a [tiny virtual computer](http://blog.erratasec.com/2015/03/x86-is-high-level-language.html#.VUGC8q3BzGc). At this micro level, the instruction stream ordering and what instructions are used can still make a significant difference on performance.

Each tier has its own optimization specialists but they do not all enjoy the same amount of attention. The reason for this is simple: they are all not equal in value. Out in the real world, most programmers will be impacted largely by the first and second tier, in that order. It isn’t unusual to work with thousands of elements or more and at these scales, algorithmic complexity and good cache usage will always dominate. The last tier is mostly reserved to extreme low level programmers: hardware designers, embedded programmers, compiler programmers and specialized library programmers.

The secret to writing fast software is to make your assumptions explicit and measure early and often. Explicit assumptions are key to making sure and documenting that the choices you make as a result are proper and make sense. Should your assumptions change or prove wrong, bad things could happen or new opportunities might arise.

> It is not unusual for this to happen due to changes in technology. Consider how performance assumptions had to be revised after SSDs were introduced or when C++11 made the addition of move semantics.

However, high performance software is slightly different. Much like race cars, [performance is built in](http://hacksoflife.blogspot.ca/2015/01/high-performance-code-is-designed-not.html) from the ground up, it is intrinsic to its DNA. A Toyota Camry is a good car but fitting in a Formula One engine into it and dropping the car on a race track will yield disappointing results compared to true breeds. The same applies to software and the same could be said of the [many goals]({% post_url 2015-04-25-all_about_data %}) previously discussed (as Adobe Flash found out, security cannot be retro-fitted easily).

