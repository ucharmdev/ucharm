


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import functools
    import heapq
    import itertools
    import statistics

    nums = [3, 1, 2]
    heapq.heapify(nums)
    assert heapq.heappop(nums) == 1

    pairs = list(itertools.islice(itertools.count(0), 3))
    assert pairs == [0, 1, 2]

    assert functools.reduce(lambda a, b: a + b, [1, 2, 3]) == 6
    assert statistics.mean([2, 4]) == 3
if __name__ == "__main__":
    run(main)
