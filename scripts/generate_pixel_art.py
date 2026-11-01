import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "projects" / "last-light" / "assets" / "art"
COLORS = {
    ".": (0, 0, 0, 0),
    "O": (25, 30, 28, 255),
    "C": (90, 136, 105, 255),
    "W": (216, 205, 166, 255),
    "A": (218, 164, 83, 255),
    "R": (164, 72, 60, 255),
    "P": (89, 107, 83, 255),
    "V": (143, 156, 119, 255),
    "S": (133, 87, 58, 255),
    "D": (205, 190, 145, 255),
    "H": (193, 139, 103, 255),
    "G": (91, 112, 78, 255),
    "M": (93, 96, 89, 255),
    "I": (145, 163, 128, 255),
}


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.pixels = [["." for _ in range(width)] for _ in range(height)]

    def rect(self, x0: int, y0: int, x1: int, y1: int, color: str) -> None:
        for y in range(max(y0, 0), min(y1, self.height)):
            for x in range(max(x0, 0), min(x1, self.width)):
                self.pixels[y][x] = color

    def polygon(self, points: list[tuple[int, int]], fill: str, outline: str = "O") -> None:
        for y in range(self.height):
            for x in range(self.width):
                inside = False
                for index, (x1, y1) in enumerate(points):
                    x2, y2 = points[(index + 1) % len(points)]
                    if (y1 > y) != (y2 > y):
                        crossing = (x2 - x1) * (y - y1) / (y2 - y1) + x1
                        if x < crossing:
                            inside = not inside
                if inside:
                    self.pixels[y][x] = fill
        original = [row[:] for row in self.pixels]
        for y in range(self.height):
            for x in range(self.width):
                if original[y][x] != fill:
                    continue
                if any(
                    nx < 0 or ny < 0 or nx >= self.width or ny >= self.height
                    or original[ny][nx] == "."
                    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
                ):
                    self.pixels[y][x] = outline

    def save(self, path: Path) -> None:
        raw = bytearray()
        for row in self.pixels:
            raw.append(0)
            for symbol in row:
                raw.extend(COLORS[symbol])
        header = struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)
        data = b"\x89PNG\r\n\x1a\n"
        data += _chunk(b"IHDR", header)
        data += _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        data += _chunk(b"IEND", b"")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def make_survivor() -> Canvas:
    image = Canvas(32, 32)
    # helmet
    image.rect(10, 2, 22, 7, "G")
    image.rect(11, 1, 21, 3, "O")
    image.rect(12, 4, 14, 6, "W")
    image.rect(18, 4, 20, 6, "W")
    image.rect(10, 7, 22, 9, "M")
    # face/neck
    image.rect(12, 8, 20, 11, "H")
    # torso vest
    image.polygon([(9, 11), (23, 11), (26, 22), (22, 26), (10, 26), (6, 22)], "G")
    image.rect(11, 13, 21, 16, "C")
    image.rect(13, 17, 15, 19, "A")
    image.rect(17, 17, 19, 19, "A")
    # arms
    image.rect(6, 13, 9, 21, "C")
    image.rect(23, 13, 26, 21, "C")
    # legs/boots
    image.rect(11, 25, 15, 30, "S")
    image.rect(17, 25, 21, 30, "S")
    image.rect(10, 28, 16, 31, "O")
    image.rect(16, 28, 22, 31, "O")
    # rifle
    image.rect(25, 10, 29, 23, "M")
    image.rect(24, 8, 30, 12, "A")
    image.rect(26, 5, 28, 9, "O")
    image.rect(23, 13, 25, 15, "O")
    return image


def make_drifter() -> Canvas:
    image = Canvas(32, 32)
    image.polygon([(12, 2), (21, 4), (28, 11), (29, 21), (23, 29), (10, 30), (3, 22), (4, 11)], "I")
    image.rect(2, 13, 7, 18, "I")
    image.rect(25, 14, 30, 19, "I")
    image.rect(10, 10, 13, 13, "O")
    image.rect(20, 10, 23, 13, "O")
    image.rect(11, 11, 12, 12, "R")
    image.rect(21, 11, 22, 12, "R")
    image.rect(12, 19, 21, 22, "R")
    image.rect(14, 19, 16, 22, "W")
    image.rect(18, 19, 20, 22, "W")
    image.rect(11, 26, 14, 30, "O")
    image.rect(20, 25, 23, 29, "O")
    image.rect(13, 23, 19, 25, "O")
    return image


def make_skitter() -> Canvas:
    image = Canvas(32, 32)
    image.polygon([(13, 5), (21, 3), (27, 9), (24, 17), (20, 20), (12, 17), (7, 11)], "V")
    image.polygon([(8, 10), (2, 5), (5, 15), (1, 21), (10, 20)], "G")
    image.polygon([(22, 10), (30, 5), (27, 15), (31, 21), (22, 20)], "G")
    image.rect(13, 9, 16, 12, "O")
    image.rect(19, 9, 22, 12, "O")
    image.rect(14, 10, 15, 11, "R")
    image.rect(20, 10, 21, 11, "R")
    image.rect(15, 15, 20, 18, "R")
    image.rect(16, 16, 19, 17, "W")
    image.rect(8, 21, 12, 29, "O")
    image.rect(21, 21, 25, 29, "O")
    image.rect(11, 23, 15, 26, "S")
    image.rect(18, 23, 22, 26, "S")
    return image


def make_dasher() -> Canvas:
    image = Canvas(32, 32)
    image.polygon([(5, 9), (15, 4), (24, 7), (30, 15), (25, 22), (17, 21), (12, 28), (5, 25), (2, 17)], "S")
    image.rect(20, 10, 26, 15, "I")
    image.rect(23, 11, 25, 13, "R")
    image.rect(22, 12, 24, 14, "W")
    image.polygon([(4, 22), (1, 29), (12, 26), (16, 20)], "O")
    image.rect(10, 24, 13, 30, "O")
    image.rect(24, 19, 28, 24, "O")
    image.rect(16, 12, 19, 17, "R")
    image.rect(17, 13, 18, 16, "W")
    return image


def make_warden() -> Canvas:
    image = Canvas(64, 64)
    image.polygon([(22, 2), (42, 2), (52, 10), (62, 26), (58, 44), (48, 58), (32, 63), (15, 58), (5, 43), (2, 25), (12, 9)], "I")
    image.polygon([(18, 12), (31, 7), (46, 13), (51, 29), (46, 45), (32, 54), (17, 45), (12, 29)], "G", "A")
    image.rect(18, 22, 25, 28, "O")
    image.rect(39, 22, 46, 28, "O")
    image.rect(20, 23, 23, 26, "R")
    image.rect(41, 23, 44, 26, "R")
    image.rect(21, 24, 22, 25, "W")
    image.rect(42, 24, 43, 25, "W")
    image.polygon([(23, 34), (41, 34), (37, 43), (27, 43)], "R")
    image.rect(27, 35, 30, 40, "W")
    image.rect(34, 35, 37, 40, "W")
    image.polygon([(5, 23), (0, 17), (9, 21), (14, 30), (6, 34)], "I")
    image.polygon([(59, 23), (64, 17), (55, 21), (50, 30), (58, 34)], "I")
    image.rect(29, 44, 35, 48, "R")
    return image


def make_projectile() -> Canvas:
    image = Canvas(8, 16)
    image.rect(3, 2, 5, 14, "M")
    image.rect(2, 1, 6, 5, "A")
    image.rect(3, 0, 5, 3, "W")
    return image


def main() -> None:
    for folder, name, builder in (
        ("player", "survivor.png", make_survivor),
        ("enemies", "drifter.png", make_drifter),
        ("enemies", "skitter.png", make_skitter),
        ("enemies", "dasher.png", make_dasher),
        ("enemies", "rift_warden.png", make_warden),
        ("projectiles", "player_bullet.png", make_projectile),
    ):
        builder().save(ROOT / folder / name)


if __name__ == "__main__":
    main()
