#!/usr/bin/python3

import os

BANK_COUNT = 2
TILE_COUNT = 16 * 16
BYTES_PER_TILE = 16

def tile_to_str(tile_id: int) -> str:
    bank_id = tile_id // 256
    return f'{bank_id}:{(tile_id % 256):x}'

if __name__ == '__main__':
    data_dir = os.path.dirname(os.path.realpath(__file__)) + '/..'
    with open(data_dir + '/base.chr', 'rb') as chr_file:
        chr_data = chr_file.read()

    for bank in range(BANK_COUNT):
        print(f'Processing bank {bank}')
        unique_tiles = {}
        for tile in range(TILE_COUNT):
            tile_id = bank * TILE_COUNT + tile
            data = chr_data[tile_id * BYTES_PER_TILE:(tile_id + 1) * BYTES_PER_TILE]
            if data in unique_tiles:
                print(f'Duplicate tile found: tile {tile_to_str(tile_id)} is the same as {tile_to_str(unique_tiles[data])}!')
            else:
                unique_tiles[data] = tile_id
            