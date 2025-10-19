import ddnet_maploader

def test_basic():
    try:
        ddnet_maploader.load_map("aa")
    except ValueError:
        pass
