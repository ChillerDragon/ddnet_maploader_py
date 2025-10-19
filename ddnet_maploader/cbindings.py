import ctypes

from .ddnet_maploader import _MapDataInternal

_lib_map_loader = ctypes.cdll.LoadLibrary("/usr/local/lib/libddnet_map_loader.so")
load_map = _lib_map_loader.load_map
load_map.argtypes = [ctypes.c_char_p]
load_map.restype = _MapDataInternal
