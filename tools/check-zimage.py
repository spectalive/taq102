#!/usr/bin/env python3
"""Refuse an ARM zImage whose length disagrees with its own header.

An ARM zImage records its start and end addresses at 0x28 and 0x2c, after the
magic 0x016f2818 at 0x24, so end - start is the size the file must have. On
2026-11-02 the SMP trial image carried a kernel cut to 9797632 of its 10331200
bytes: the board hung with a black screen, and the hang was blamed on SMP.
A file without the magic (the stock vendor kernel blob) is passed through.

Usage: check-zimage.py <zImage>
"""
import struct
import sys

MAGIC = 0x016F2818


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: check-zimage.py <zImage>")
    path = sys.argv[1]
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 0x30:
        sys.exit(f"{path}: too short to be a kernel ({len(data)} bytes)")
    magic, start, end = struct.unpack_from("<3I", data, 0x24)
    if magic != MAGIC:
        return
    if end - start != len(data):
        sys.exit(f"{path}: zImage header says {end - start} bytes, file has {len(data)}")


if __name__ == "__main__":
    main()
