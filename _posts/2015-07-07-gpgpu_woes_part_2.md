---
layout: post
title: GPGPU woes part 2
---
After fixing the [previous]({% post_url 2015-07-02-gpgpu_woes_part_1 %}) painful issue, we move on to the next strange issue (and much worse!).

### On the GPU, a NULL pointer isn’t always NULL

Despite the code being very simple, the CPU and GPU versions produced very different outputs for me in OS X (not verified in Windows 8.1). For the life of me I could not figure it out as it proved even stranger than the previous issue.

Ultimately, the issue was here:

{% highlight cpp %}
// Inlined the CSS_CUCKOO_HASH_FIND macro and minor formatting cleanup
__global const struct css_rule * rule = 0;
if (hash_->left[left_index_].type != 0 && hash_->left[left_index_].value == value_) {
    rule = &hash_->left[left_index_];
}
if (hash_->right[right_index_].type != 0 && hash_->right[right_index_].value == value_) {
    rule = &hash_->right[right_index_];
}
if (rule_set != 0) {
    // code
}
{% endhighlight %}

Can you see it? If you can’t, I don’t think anybody could blame you.

After painfully narrowing it down to this precise piece of code, it turns out that the `rule_set != 0` check was failing when no rule was found (neither `if` statement was taken) on the GPU (and was obviously working as expected on the CPU).

This is mere speculation but I have the gut feeling that this issue might be caused because internally some bits in the memory addresses must be used to tell global memory from local memory on the GPU.

It is entirely possible that a NULL pointer for global memory might not equal a NULL pointer for local memory (or constant memory). In such a scenario, comparing both would return `false`. Perhaps the memory qualifier information was lost and the optimizer was left to perform a comparison with the literal *0* value.

The only other alternative would be a compiler bug. Sadly I could not take a look at the generated assembly to double check what was happening.

The fix was simply to introduce a boolean/integer variable that we could safely compare against. Again note that I was more concerned with getting the code to work while keeping it as close to the original than making it fast. It is also possible that force casting the *0* literal to the pointer type might have worked. This is left as an exercise to the reader.
