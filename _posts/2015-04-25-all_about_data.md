---
layout: post
title: All about data
---
The modern computers of today are an amazing and complex creation. From the smallest cellphones up to your super charged desktop PC, each and everyone of them is in reality a mixture of many smaller specialized computers working in concert.

However, at the end of the day, they all do the same thing: they munch on data. That is their only purpose and from the meaning inscribed in that data comes out the complex behaviours that we see in everyday programs and devices.

Programming is the art of organizing that data in meaningful ways in order to achieve a specific end result. Many criteria exist to take into consideration when designing such systems:

* User friendly: how do we show the data and how do we allow the data to be manipulated by the user?
* Development friendly: how do we organize the data (and code) for it to be easily manipulated in the ways that are required by the product?
* Hardware friendly: how do we make sure that the data is layered out in the optimal way for the hardware underneath?
* Communication friendly: how do we make sure that the data is easily communicated in between various systems either internally in the computer or externally?
* Resilient to damage: how do we make the data safe from hardware failures?
* Tamper proof: how do we make the data safe from malicious tampering?
* Secure: how do we make sure that data in transit isn’t intercepted by a third party?

I am sure there are many more, these a simply a small subset.

What is often less discussed is that very often these goals have conflicting desires. In such scenarios, it is paramount to clearly identify the main goals of the software in order to make and validate our assumptions. These should guide all the important decisions regarding how the software is built and how the data is dealt with.

> For example, in the context of AAA video games, with the hardware being largely fixed and the demand for ever higher & prettier visuals, the two most important criteria are almost always user friendliness and hardware friendliness for single player games. For multiplayer games, the complexity increases and communication & tampering become important. Last but not least, for games with micro transactions, security comes into play. Depending on the platform and the game, the risks will also vary in scale and scope.
> 
> In contrast, in the context of mobile games, development friendliness is king to allow churning updates, content and new games as quick as possible. It isn’t unusual to find mobile games with poor user interfaces, bad performance and that are easily tampered or compromised. In the top tier of games, user & hardware friendliness are again very important and show up in very clean games such as Clash of Clans and Candy Crush.

The single most important thing for a team is to be aligned on these goals and consider them when making every decision. Failure to do this exercise can have disastrous consequences: a change might easily introduce a performance issue or a security issue if one isn’t careful and paying attention to these goals. Ultimately the entire product can become at risk.

This is the reality in software design as much as it is in any other industry where teams must juggle multiple goals.

