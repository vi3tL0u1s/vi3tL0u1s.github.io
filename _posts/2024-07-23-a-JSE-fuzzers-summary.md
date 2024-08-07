---
layout: post
title:  "A summary of some Javascript Engine (JSE) fuzzers"
date:   2024-07-22 10:15:00 +0700
categories: [browser, chrome, fuzzers]
---

### Introduction

In the evolving world of JSE fuzzing, several tools have stood out for their innovation and impact. Fuzzilli, created by Samuel Groß in 2019, brought coverage-guided and mutation-based fuzzing to the forefront. Junjie Wang's FuzzJIT in 2023 focused on triggering JIT compiler logic errors, while her earlier work, Superion, addressed grammar-blind issues by mutating at the AST level. Soyeon Park's DIE in 2020 introduced aspect-preserving mutations, leveraging PoC-influenced corpora. This post explores these fuzzers, highlighting their unique approaches and contributions to JSE security.

### Fuzzilli (2019)

Let's start with probably the most famous JavaScript (JS) engine fuzzer of all time, Fuzzilli, created by Samuel Groß from Google in 2019. This fuzzer was built to address two main problems of the previous fuzzers: maintaining high levels of syntactical and semantic correctness for the produced JS samples. The former is easier to achieve and was kind of solved, but not optimally, by some previous fuzzers such as Domato (from Google), LangFuzz, and jsfunfuzz (Mozilla's funfuzz). The latter, semantic correctness, is harder to achieve, which is the main reason why Fuzzilli was born. 


I want to emphasize that semantic correctness is crucial because there is a Just-In-Time (JIT) compiler at the heart of the JavaScript engine (JSE). We already know that JavaScript is different since it is dynamically typed (which is why so many "big-hand" coders hate it). However, not many people know that the JIT compiler also does not compile JavaScript code in a trivial way. First, JavaScript code is parsed into an Abstract Syntax Tree (AST) by the JSE. Second, the JSE compiles the AST into bytecode and executes it several times using the interpreter. During this time, the JSE collects the type information. Third, the bytecode is passed to the JIT compiler, which translates it into an Intermediate Representation (IR). During this time, the JIT compiler applies [speculative optimizations](https://webkit.org/blog/10308/speculation-in-javascriptcore/) on the frequently executed code (most of the time) by inserting so-called type "guards" to ensure this frequently executed code has the same type. If the JIT compiler finds that the type of the variable is different, it will deoptimize the code and recompile it. This is the reason why semantic correctness should be maintained at a high level: to trigger the JIT compiler to compile the code and apply the optimizations.

Based on this information, Samuel created an Intermediate Representation (IR) called FuzzIL, which is used to generate JavaScript code that is semantically correct. Below is an example of FuzzIL code generated by Fuzzilli:

```js
v0 <- LoadGlobal ‘print’
v1 <- LoadString ‘Hello World’
v2 <- CallFunction v0, v1
```


FuzzIL can be mutated in four ways:
1. Input mutator
```js
v0 <- LoadGlobal ‘print’
v1 <- LoadString ‘Hello World’
v2 <- CallFunction v0, v0
```

2. Operation mutator
```js
v0 <- LoadGlobal ‘encodeURI’
v1 <- LoadString ‘Hello World’
v2 <- CallFunction v0, v1
```

3. Insertion Mutator (Generates new code)
```js
v0 <- LoadGlobal ‘print’
v1 <- LoadString ‘Hello World’
v2 <- LoadProperty v0, ‘foo’
v3 <- CallFunction v0, v1
```

4. Splice Mutator (Inserts existing code)
```js
v0 <- LoadGlobal ‘print’
v1 <- LoadString ‘Hello World’
v2 <- LoadGlobal ‘print’
v3 <- CallFunction v0, v1
```


So, by now, you probably realize that Fuzzilli is a mutation-based fuzzer. It is also worth mentioning that Fuzzilli is a coverage-guided fuzzer, which means that it uses code coverage information to guide the fuzzer in generating new samples that could help increase edge-coverage (similar to the famous AFL). This is done by using the so-called "feedback" from the JSE. The feedback is collected by the JSE and sent back to the fuzzer. The fuzzer uses this feedback to continue the loop of fuzzing. Overall, Fuzzilli is a great fuzzer that has been used to find many CVEs (~52 CVEs so far) in the JSEs.

### FuzzJIT (2023)

FuzzJIT was created by Junjie Wang (the author of Skyfire and Superion) in 2023. In short, FuzzJIT inherits many ideas and implementations from Fuzzilli, but it is designed to focus on triggering logic errors in the JIT compiler. More specifically, Junjie made a template to generate JavaScript code, ensuring that the JIT compiler is triggered. The idea is quite simple, but very effective, as she has found ~17 CVEs in five different JSEs. Below is an example of the template (in the file fuzzjit\Sources\FuzzilliCli\Profiles\JSCProfile.swift) that is used by FuzzJIT:

```js
1   function opt(opt_param){
2       // MUTATION POINT
3   }
4   let gflag = true;
5   let jit_a0 = opt(true);
6   let jit_a0_0 = opt(false);
7   for(let i=0;i<0x10;i++){opt(false);}
8   let jit_a2 = opt(true);
9   if (jit_a0 === undefined && jit_a2 === undefined) {
10      opt(true);
11   } else {
12       if (jit_a0_0===jit_a0 && !deepEquals(jit_a0, jit_a2)) {
14           gflag = false;
15       }
16   }
17   for(let i=0;i<0x200;i++){opt(false);} // Trigger JIT optimization
18   let jit_a4 = opt(true);
19   if (jit_a0 === undefined && jit_a4 === undefined) {
20       opt(true);
21   } else {
22       if (gflag && jit_a0_0===jit_a0 && !deepEquals(jit_a0, jit_a4)) {
23           fuzzilli('FUZZILLI_CRASH', 0);
24       }
25   }
```

As shown in the code above, the opt function is the mutation point, where the FuzzJIT will mutate the code. Additionally, at line 17, a for-loop with 0x200 iterations is used to trigger the JIT optimization. After that, the deepEquals function is used to compare the type of opt function objects at the pre- and post-optimization. If the JIT compiler is triggered and the deepEquals function returns False, the FuzzJIT will call the Fuzzilli's function to report an immidiate crash (crash 0).

Yes, this is how simple it is, but let have a closer look on the deepEquals function (in file fuzzjit\Sources\FuzzilliCli\Profiles\V8Profile.swift) as shown below:

```js
1   function classOf(object) {
2       var string = Object.prototype.toString.call(object);
3       return string.substring(8, string.length - 1);
4   }
5
6   function deepObjectEquals(a, b) {
7       var aProps = Object.keys(a);
8       aProps.sort();
9       var bProps = Object.keys(b);
10       bProps.sort();
11       if (!deepEquals(aProps, bProps)) {
12           return false;
13       }
14       for (var i = 0; i < aProps.length; i++) {
15           if (!deepEquals(a[aProps[i]], b[aProps[i]])) {
16               return false;
17           }
18       }
19       return true;
20   }
21
22   function deepEquals(a, b) {
23       if (a === b) {
24           if (a === 0) return (1 / a) === (1 / b);
25           return true;
26       }
27       if (typeof a != typeof b) return false;
28       if (typeof a == 'number') return (isNaN(a) && isNaN(b)) || (a===b);
29       if (typeof a !== 'object' && typeof a !== 'function' && typeof a !== 'symbol') return false;
30       var objectClass = classOf(a);
31       if (objectClass === 'Array') {
32           if (a.length != b.length) {
33               return false;
34           }
35           for (var i = 0; i < a.length; i++) {
36               if (!deepEquals(a[i], b[i])) return false;
37           }
38           return true;
39       }                
40       if (objectClass !== classOf(b)) return false;
41       if (objectClass === 'RegExp') {
42           return (a.toString() === b.toString());
43       }
44       if (objectClass === 'Function') return true;
45       
46       if (objectClass == 'String' || objectClass == 'Number' ||
47           objectClass == 'Boolean' || objectClass == 'Date') {
48           if (a.valueOf() !== b.valueOf()) return false;
49       }
50       return deepObjectEquals(a, b);
51   }
```

Function Descriptions:

1. classOf(object) (Lines 1-3)
- Lines 2-3: Uses Object.prototype.toString.call to determine the class of an object, then returns a substring representing the object's class.
2. deepObjectEquals(a, b) (Lines 6-20)
- Lines 7-13: Compares the sorted properties of two objects.
- Lines 14-18: Recursively checks for deep equality of corresponding properties in both objects.
3. deepEquals(a, b) (Lines 22-51)
- Lines 23-25: Checks for strict equality, including handling 0 and -0.
- Line 27: Compares types.
- Lines 28: Handles NaN and number comparisons.
- Line 29: Checks if the types are non-object, non-function, and non-symbol.
- Lines 31-39: Handles array comparisons, including length and element-wise comparison.
- Lines 40: Compares object classes.
- Lines 41-49: Handles RegExp, Function, String, Number, Boolean, and Date comparisons.
- Line 50: Recursively calls deepObjectEquals for objects.

There is another point worth mentioning, which is what the author calls the PoC-influenced corpus. Essentially, she adds a fixed list of JavaScript types, a few interesting values, and edge cases of each type to incorporate into the mutation process. This is done to increase the chance of finding bugs in the JIT compiler. It is important to note that FuzzJIT is still classified as a generation-based fuzzer since it generates new samples based on the template and then applies mutations to them.

The list of js types and values is shown below:

```js
// Possible return values of the 'typeof' operator.
public static let jsTypeNames = ["undefined", "boolean", "number", "string", "symbol", "function", "object", "bigint"]

// Integer values that are more likely to trigger edge-cases.
public let interestingIntegers: [Int64] = [
    -9223372036854775808, -9223372036854775807,               // Int64 min, mostly for BigInts
    -9007199254740992, -9007199254740991, -9007199254740990,  // Smallest integer value that is still precisely representable by a double
    -4294967297, -4294967296, -4294967295,                    // Negative Uint32 max
    -2147483649, -2147483648, -2147483647,                    // Int32 min
    -1073741824, -536870912, -268435456,                      // -2**32 / {4, 8, 16}
    -65537, -65536, -65535,                                   // -2**16
    -4096, -1024, -256, -128,                                 // Other powers of two
    -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 16, 64,         // Numbers around 0
    127, 128, 129,                                            // 2**7
    255, 256, 257,                                            // 2**8
    512, 1000, 1024, 4096, 10000,                             // Misc numbers
    65535, 65536, 65537,                                      // 2**16
    268435456, 536870912, 1073741824,                         // 2**32 / {4, 8, 16}
    2147483647, 2147483648, 2147483649,                       // Int32 max
    4294967295, 4294967296, 4294967297,                       // Uint32 max
    9007199254740990, 9007199254740991, 9007199254740992,     // Biggest integer value that is still precisely representable by a double
    9223372036854775806,  9223372036854775807                 // Int64 max, mostly for BigInts (TODO add Uint64 max as well?)
]

// Double values that are more likely to trigger edge-cases.
public let interestingFloats = [-Double.infinity, -Double.greatestFiniteMagnitude, -1e-15, -1e12, -1e9, -1e6, -1e3, -5.0, -4.0, -3.0, -2.0, -1.0, -Double.ulpOfOne, -Double.leastNormalMagnitude, -0.0, 0.0, Double.leastNormalMagnitude, Double.ulpOfOne, 1.0, 2.0, 3.0, 4.0, 5.0, 1e3, 1e6, 1e9, 1e12, 1e-15, Double.greatestFiniteMagnitude, Double.infinity, Double.nan]

// TODO more?
public let interestingStrings = jsTypeNames

// TODO more?
public let interestingRegExps = [".", "\\d", "\\w", "\\s", "\\D", "\\W", "\\S"]
public let interestingRegExpQuantifiers = ["*", "+", "?"]

public var intType = JSType.integer
public var bigIntType = JSType.bigint
public var floatType = JSType.float
public var booleanType = JSType.boolean
public var regExpType = JSType.jsRegExp
public var stringType = JSType.jsString
public var arrayType = JSType.jsArray
public var objectType = JSType.jsPlainObject

public func functionType(forSignature signature: Signature) -> JSType {
    return .jsFunction(signature)
}
```

### Superion (2019)

Now, let's talk about Superion, which was also created by Junjie Wang in 2019 (the same year as the birth of Fuzzilli). During this time, the famous greybox fuzzer AFL faced the challenge of being grammar-blind, where the input structure is so volatile and easily destroyed during the fuzzing process. Junjie made Superion to address the specific formats of XML and js code. The key difference between Superion and Fuzzilli is that the mutation is conducted at the AST level of the code, as FuzzIL had not been published at that time.

There are three additional features of Superion that were added to the AFL skeleton:

1. Grammar-aware Trimming
- This feature checks the test cases by searching all the subtrees of the AST representation of the testcase, attempting to remove each subtree one by one. After each removal, if the new AST has the same coverage, the new AST without this subtree will be kept.

2. Dictionary-based Mutation
- This feature checks if each byte of the test input is either an alphabet or a digit; if not, the mutation engine will replace that byte with a byte from the dictionary. The author explains that the reason for this is that most of the tokens (variable names, reserved words, etc.) in JavaScript and XML files are composed of alphabets and digits. However, I personally think this is not a good idea since JavaScript code can contain many special characters (in RegEx statements) such as @, #, !, etc.

3. Tree-based Mutation
- This is quite clear now in 2024; however, in 2019, I think it was relatively new to the community. The idea was first to parse the test input to an AST. If this parsing failed, it meant that the test input was not valid. Otherwise, all the subtrees of the AST would be added to a set, which later would be used to mutate the test input. Also, to avoid storage explosion, the author used heuristic rules to limit the size of the test input and the number of the subtrees in the mutation set.

### DIE (2020)

DIE was created by Soyeon Park in 2020. The author designed DIE with the property-preserving mutation called "aspect-preserving". The aspects she mentioned are the embedded features in the PoCs and regression tests of the existing bugs in JSE, which preserve types and structures. This is important since it is the first time PoCs were introduced to the fuzzing process.

This fuzzer mutates the js code at the AST level, which is similar to Superion. Interestingly, it is also based on the famous AFL, which is similar to Superion. So, what are the improvements of DIE compared to Superion? It is the way DIE performs dynamic analysis of the initial seeds of the PoCs and the regression tests. Soyeon added a type check to every single line in a seed file. In this way, all the types of each variable (which change in a PoC) can be recorded. Then this information is added to the AST from the child nodes up to the root node. This process is called static type analysis. As a result, the typed ASTs are produced for the aspect-preserving mutation.

The most interesting process in DIE is the aspect-preserving mutation, which includes two main mutation strategies: type and structure mutating.
1. Type mutating: mutates the type of the variable in the typed AST.
2. Structure mutating: This feature instructs the mutator which parts of the typed AST should not be mutated. These parts are the identifiers of for and while loops on the typed AST, since these loops are specifically used to trigger JIT compiler optimizations. This insight was gained from the PoCs.

We can see that DIE and FuzzJIT are quite similar, but DIE's mutation is on the AST level while FuzzJIT's is on the IR level. Also, DIE is a mutation-based fuzzer, while FuzzJIT is a generation-based fuzzer. Since DIE has only discovered a humble number of 12 CVEs, I think mutating JavaScript code at the IR level is much more effective than at the AST level.

### Conclusion

In this post, I've summarized some of the most notable JavaScript engine fuzzers. I hope this helps clarify the differences between these tools and their unique methods. Whether you're deciding which fuzzer to use for your research or simply curious about their innovations, I hope you found this information useful. Thanks for reading!