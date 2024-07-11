---
layout: post
title:  "My first blog about Chromium"
date:   2024-07-10 10:15:00 +0700
categories: [browser, chrome]
---

### Intro

Since I use web browser in everyday tasks, I always wonder how this amazing software works. Therefore, I want to conduct a code review and investigate the browser working mechanism. Hopefully, this could also help me to improve my pentesting skills. So, here we go, this is my first blog in my browser blog series.

I choose Chrome since I use it the most, and I know that this codebase is well-written, well-maintained, and well-designed. Of course, it also has a really big and complicated codebase. So, I have some expectations and am ready to put effort into this journey.

### Helpers

First, I want to look for any neccessary websites and tools that could help me to do the following tasks:

1. Following different routes
2. Following different executions
3. Following different test cases
4. Examine some lines of code if required

The above list suggests strongly that I need to compile the code somehow. Yes, it is quite important, but let's first investigate some useful websites.

#### Websites

The [Chromium Code Search](https://source.chromium.org/chromium) is probably the most important starting point. It has a user-friendly interface and a good search engine from Google, which could make the navigation become much smoother.

Second, the [Learning your way around the code](https://www.chromium.org/developers/learning-your-way-around-the-code/) site provides a good generic guide for developers to start learning the Chromium ecosystem, which I find quite good.

Third, the [Chromium Dev Group](https://groups.google.com/a/chromium.org/g/chromium-dev?pli=1) with several blogs and conversations amongst Chrome developers could provide lots of domain insights.

Last but not least, there are several other sites that could help, but to sustain the review in the long run, I will stop here for my initial list of websites.

#### Tools

Well, let's try to build Chromium. My question is what to build and how to build.

The answer is found on this [site](https://chromium.googlesource.com/chromium/src/+/main/docs/linux/build_instructions.md#get-the-code). Here, it looks like the compulsory tool is Depot Tool. Honestly, at first, I kind of hesitated when I saw the spec requirements since I only have access to my personal laptop, with limited RAM and hard disk. But anyway, this is just the brainstorming step, and let's see if later I could find a way to compile, build, and debug Chromium part by part.

The build process also needs Ninja and a GN tool to generate .ninja file. Well, hope that I could learn some useful jutsu here.

### Conclude

Well, to make the blog to be about 10-min of reading time, I will stop my intial plan here. In this blog, I have specified the Chromium as my target to do code review, and some initial sites and tools which could help me to commence my journey. I look forward to starting some implementation. Stay tuned for my sharing in the future!

