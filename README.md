# ddnet_maploader_py

Python bindings for https://github.com/Teero888/ddnet_maploader_c99

## dependencies

```
git clone https://github.com/Teero888/ddnet_maploader_c99
cd ddnet_maploader_c99
git checkout b4c0cc03fa27c95175601500a044596e9362eea5
mkdir build && cd build
cmake ..
make install
```

## sample usage

```
pip install ddnet-maploader
```

```python
#!/usr/bin/env python3

import ddnet_maploader

with ddnet_maploader.load_map("/home/chiller/.teeworlds/maps/tinycave.map") as map:
    x = 3
    y = 3
    tile = map.game_layer.data[y * map.width + x]
    print(f"at x={x} y={y} tile={tile}")

    for setting in map.settings:
        print(f"map setting: {setting}")
```
