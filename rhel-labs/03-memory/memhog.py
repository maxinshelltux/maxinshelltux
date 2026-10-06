#!/usr/bin/env python3
import argparse
import mmap
import os
import sys
import time

PAGE = mmap.PAGESIZE
MIB = 1024 * 1024


def read_fields(path, wanted):
    values = {}
    with open(path, encoding="ascii") as handle:
        for line in handle:
            key, _, rest = line.partition(":")
            if key in wanted:
                values[key] = int(rest.split()[0]) // 1024
    return values


def report(stage):
    proc = read_fields("/proc/self/status", ("VmSize", "VmRSS", "VmSwap"))
    system = read_fields("/proc/meminfo", ("MemAvailable", "Committed_AS"))
    print(
        f"{stage:<14} VmSize={proc['VmSize']:>5}  VmRSS={proc['VmRSS']:>5}  VmSwap={proc['VmSwap']:>5}"
        f"  |  MemAvailable={system['MemAvailable']:>5}  Committed_AS={system['Committed_AS']:>5}",
        flush=True,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Запрашивает у ядра анонимную память и показывает в МиБ, что при этом меняется."
    )
    parser.add_argument("mib", type=int, help="сколько мебибайт запросить")
    parser.add_argument("--touch", action="store_true", help="записать по байту в каждую страницу")
    parser.add_argument("--hold", type=int, default=0, metavar="SEC", help="держать память столько секунд")
    args = parser.parse_args()
    if args.mib < 1:
        parser.error("mib должен быть не меньше 1")

    print(f"pid {os.getpid()}, запрос {args.mib} МиБ, страница {PAGE} байт", flush=True)
    report("старт")
    try:
        region = mmap.mmap(-1, args.mib * MIB, flags=mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS)
    except OSError as error:
        print(f"mmap {args.mib} МиБ: отказ ядра — {error.strerror}", flush=True)
        return 1
    report("после mmap")
    if args.touch:
        for offset in range(0, args.mib * MIB, PAGE):
            region[offset] = 1
        report("после записи")
    if args.hold:
        time.sleep(args.hold)
        report("перед выходом")
    return 0


if __name__ == "__main__":
    sys.exit(main())
