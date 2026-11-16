"""Generate the first N Fibonacci numbers (default 1000).

Sequence starts F(0)=0, F(1)=1. Python ints are arbitrary precision,
so large terms are exact.

Usage:
    python fibonacci.py            # print first 1000 to stdout
    python fibonacci.py -n 50      # first 50
    python fibonacci.py -o fib.txt # write to file, one per line
"""
import argparse
import sys


def fibonacci(n):
    """Return a list of the first n Fibonacci numbers."""
    seq = []
    a, b = 0, 1
    for _ in range(n):
        seq.append(a)
        a, b = b, a + b
    return seq


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("-n", type=int, default=1000, help="how many terms (default 1000)")
    parser.add_argument("-o", "--output", help="output file (default: stdout)")
    args = parser.parse_args()
    if args.n < 0:
        parser.error("-n must be non-negative")

    if hasattr(sys, "set_int_max_str_digits"):  # allow huge -n on Python 3.11+
        sys.set_int_max_str_digits(0)
    lines = "\n".join(str(x) for x in fibonacci(args.n)) + "\n"
    if args.output:
        with open(args.output, "w") as f:
            f.write(lines)
    else:
        sys.stdout.write(lines)


if __name__ == "__main__":
    main()
