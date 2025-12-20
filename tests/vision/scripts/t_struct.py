


def run(fn):
    try:
        fn()
        print("ok")
        return True
    except Exception as exc:
        print("fail:", type(exc).__name__, str(exc))
        return False

def main():
    import struct

    data = struct.pack("<I", 0x12345678)
    val = struct.unpack("<I", data)[0]
    assert val == 0x12345678
if __name__ == "__main__":
    run(main)
