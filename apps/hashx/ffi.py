"""配った共有ライブラリを、C でも C++ でもない実行時から呼ぶ。

C ABI で配るとはこういうことである。相手は見出しを読まず、翻訳もせず、
リンクもしない——実行時に名前で引くだけである。したがってここで確かめて
いるのは宣言ではなく、**成果物が外へ出している名前そのもの**である。

引数は共有ライブラリの道。答を1行で刷る。
"""
import ctypes
import sys

lib = ctypes.CDLL(sys.argv[1])

lib.hashx_fnv1a.restype = ctypes.c_uint32
lib.hashx_fnv1a.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
lib.hashx_crc32.restype = ctypes.c_uint32
lib.hashx_crc32.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
lib.hashx_version.restype = ctypes.c_char_p

data = b"dowel"


class Crc(ctypes.Structure):
    _fields_ = [("state", ctypes.c_uint32)]


# 少しずつ渡す側も呼ぶ。構造体を跨いで渡せることまで見ないと、
# 「関数が1つ引けた」以上のことは言えない。
h = Crc()
lib.hashx_crc_begin(ctypes.byref(h))
lib.hashx_crc_feed(ctypes.byref(h), data, len(data))
lib.hashx_crc_end.restype = ctypes.c_uint32
lib.hashx_crc_end.argtypes = [ctypes.POINTER(Crc)]

print("%08x %08x %08x %s" % (
    lib.hashx_fnv1a(data, len(data)),
    lib.hashx_crc32(data, len(data)),
    lib.hashx_crc_end(ctypes.byref(h)),
    lib.hashx_version().decode(),
))
