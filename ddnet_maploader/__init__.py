from typing import Optional
from . import cbindings, ddnet_maploader

def load_map(map_name: str) -> Optional[ddnet_maploader.MapData]:
    map_data = cbindings.load_map(map_name.encode(encoding='utf-8'))
    if map_data.game_layer.data:
        return map_data
    return None
