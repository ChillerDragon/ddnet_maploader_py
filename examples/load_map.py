#!/usr/bin/env python3

import sys
import ddnet_maploader

if len(sys.argv) != 2:
    print(f"usage: {sys.argv[0]} [map path]")
    sys.exit(1)

map_path = sys.argv[1]
map_data = ddnet_maploader.load_map(map_path)
if not map_data:
    sys.exit(1)

print(f"got map width: {map_data.width} height: {map_data.height}")
