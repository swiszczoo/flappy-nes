#!/usr/bin/python3

import os

START_TILE_ID = 0xB0
BG_WIDTH = 4
BG_HEIGHT = 5
PAGE_COUNT = 32

if __name__ == '__main__':
    data_dir = os.path.dirname(os.path.realpath(__file__)) + '/..'
    with open(data_dir + '/base.chr', 'rb') as chr_file:
        chr_data = [x for x in chr_file.read()]
    
    for i in range(PAGE_COUNT):
        with open(data_dir + f'/pages/page{i}.chr', 'wb') as out_file:
            out_file.write(bytes(chr_data))

        # This loop will nudge the background one pixel to the left on each page
        for row in range(BG_HEIGHT):
            for bitplane in range(2):
                for scanline in range(8):
                    for column in range(BG_WIDTH):
                        tile = START_TILE_ID + row * 16 + column
                        offset = tile * 16 + scanline + bitplane * 8
                        data = chr_data[offset]
                        if column == 0:
                            leftover = data >> 7
                        data <<= 1
                        data &= 0xFF
                        if column + 1 < BG_WIDTH:
                            data |= chr_data[offset + 16] >> 7
                        else:
                            data |= leftover

                        chr_data[offset] = data

