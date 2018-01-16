/*
Copyright (c) 2015-2017 Nick Papanastasiou

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

/// Authors: Nick Papanastasiou

module dlib.math.combinatorics;

import std.functional : memoize;
import std.algorithm : reduce, map;
import std.range : iota;
import std.bigint;

/// Returns the factorial of n
ulong factorial(ulong n) @safe nothrow {
    if(n <= 1) {
        return 1;
    }

    alias mfac = memoize!factorial;

    return n * mfac(n - 1);
}

unittest {
    assert(factorial(10) == 3_628_800);

    int n = 5;
    assert(n.factorial == 5.factorial && 5.factorial == 120);
}

/// Computes the nth fibonacci number
ulong fibonacci(ulong n) {
    if(n == 0 || n == 1) {
        return n;
    }

    alias mfib = memoize!fibonacci;

    return mfib(n - 1) + mfib(n - 2);
}

/// Common vernacular for fibonacci
alias fib = fibonacci;

unittest {
    import std.array : array;

    auto fibs = iota(1, 21).map!(n => fib(n)).array;

    assert(fibs == [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144,
                    233, 377, 610, 987, 1597, 2584, 4181, 6765]);
}


/// Computes the double factorial of n: n * (n - 2) * (n - 4) * ... * 1
ulong doubleFactorial(ulong n) {
    if(n <= 1) {
        return 1;
    }

    alias mDoubleFac = memoize!doubleFactorial;

    return n * doubleFactorial(n - 2);
}

/// Computes the hyperfactorial of n: 1^1 * 2^2 * 3^3 * ... n^n
BigInt hyperFactorial(ulong n) {
    if(n <= 1) {
        return BigInt("1");
    }

    alias mhfac = memoize!hyperFactorial;

    return BigInt(n ^^ n) * hyperFactorial(n - 1);


}

/++
+ Compute the number of combinations of `objects` types of items
+ when considered `taken` at a time, where order is ignored
+/
ulong combinations(ulong objects, ulong taken) @safe nothrow {
    if(objects < taken) {
        return 0;
    }

    return objects.factorial / (taken.factorial * (objects - taken).factorial);
}

/// Common vernacular for combinations
alias C = combinations;

/// Ditto
alias choose = combinations;

/++
+  Compute the number of permutations of `objects` types of items
+ when considered `taken` at a time, where order is considered
+/
ulong permutations(ulong objects, ulong taken) @safe nothrow {
    return objects.factorial / (objects - taken).factorial;
}

// Common vernacular for permutations
alias P = permutations;

unittest {
    assert(5.choose(2) == 10);
    assert(10.P(2) == 90);
}

/// Computes the nth Lucas number
ulong lucas(ulong n) @safe nothrow {
    if(n == 0) {
        return 2;
    }

    if(n == 1) {
        return 1;
    }

    alias mlucas = memoize!lucas;

    return mlucas(n - 1) + mlucas(n - 2);
}

unittest {
    import std.algorithm : map;
    import std.array;

    auto lucasRange = iota(0, 12).map!(k => lucas(k)).array;

    assert(lucasRange == [2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123, 199]);
}
