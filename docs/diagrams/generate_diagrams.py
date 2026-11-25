"""Genere les diagrammes du rapport.

Deux sorties par diagramme, a partir de la meme description :
- un PNG pour le rapport (lisible sans outil) ;
- un fichier .drawio editable dans https://app.diagrams.net ou draw.io desktop.

Principe : une seule liste de noeuds et d'aretes, deux serialiseurs. Les
diagrammes ne peuvent donc pas diverger entre l'image et la source.

    python docs/diagrams/generate_diagrams.py
"""

from __future__ import annotations

import pathlib
from dataclasses import dataclass, field
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent

INK = (15, 23, 42)
MUTED = (100, 116, 139)
LINE = (203, 213, 225)
ACCENT = (79, 70, 229)
TEAL = (13, 148, 136)
AMBER = (180, 83, 9)
BG = (248, 250, 252)
WHITE = (255, 255, 255)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    for base in ("/usr/share/fonts/truetype/dejavu/", "/usr/share/fonts/dejavu/"):
        path = pathlib.Path(base) / name
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


@dataclass
class Node:
    id: str
    label: str
    sub: str
    x: int
    y: int
    w: int
    h: int
    color: tuple[int, int, int] = INK
    fill: tuple[int, int, int] = WHITE
    dashed: bool = False
    mono: bool = False


@dataclass
class Edge:
    src: str
    dst: str
    label: str = ""
    dashed: bool = False
    color: tuple[int, int, int] = MUTED


@dataclass
class Group:
    label: str
    x: int
    y: int
    w: int
    h: int
    color: tuple[int, int, int] = ACCENT
    sub: str = ""


@dataclass
class Diagram:
    name: str
    title: str
    width: int
    height: int
    nodes: list[Node] = field(default_factory=list)
    edges: list[Edge] = field(default_factory=list)
    groups: list[Group] = field(default_factory=list)


def _arrow(draw: ImageDraw.ImageDraw, p1, p2, color, dashed=False, width=2):
    import math

    x1, y1 = p1
    x2, y2 = p2
    if dashed:
        total = math.dist(p1, p2)
        steps = max(int(total // 12), 1)
        for i in range(steps):
            if i % 2:
                continue
            a = (x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
            b = (x1 + (x2 - x1) * (i + 1) / steps, y1 + (y2 - y1) * (i + 1) / steps)
            draw.line([a, b], fill=color, width=width)
    else:
        draw.line([p1, p2], fill=color, width=width)

    angle = math.atan2(y2 - y1, x2 - x1)
    size = 11
    left = (x2 - size * math.cos(angle - 0.4), y2 - size * math.sin(angle - 0.4))
    right = (x2 - size * math.cos(angle + 0.4), y2 - size * math.sin(angle + 0.4))
    draw.polygon([(x2, y2), left, right], fill=color)


def _anchor(a: Node, b: Node) -> tuple[tuple[int, int], tuple[int, int]]:
    """Point de depart et d'arrivee sur les bords, centre a centre."""

    acx, acy = a.x + a.w / 2, a.y + a.h / 2
    bcx, bcy = b.x + b.w / 2, b.y + b.h / 2
    dx, dy = bcx - acx, bcy - acy
    if abs(dx) > abs(dy):
        start = (a.x + a.w if dx > 0 else a.x, acy)
        end = (b.x if dx > 0 else b.x + b.w, bcy)
    else:
        start = (acx, a.y + a.h if dy > 0 else a.y)
        end = (bcx, b.y if dy > 0 else b.y + b.h)
    return (int(start[0]), int(start[1])), (int(end[0]), int(end[1]))


def render_png(d: Diagram) -> pathlib.Path:
    scale = 1
    img = Image.new("RGB", (d.width * scale, d.height * scale), BG)
    draw = ImageDraw.Draw(img)

    draw.text((48, 34), d.title, font=font(30, bold=True), fill=INK)
    draw.text((48, 74), "Kaaru · projet Cloud Computing · JUNIA ISEN", font=font(16), fill=MUTED)

    for g in d.groups:
        draw.rounded_rectangle(
            [g.x, g.y, g.x + g.w, g.y + g.h],
            radius=18,
            outline=g.color,
            width=2,
            fill=(255, 255, 255),
        )
        draw.text((g.x + 20, g.y + 12), g.label, font=font(16, bold=True), fill=g.color)
        if g.sub:
            draw.text((g.x + 20, g.y + 34), g.sub, font=font(12), fill=MUTED)

    by_id = {n.id: n for n in d.nodes}

    for e in d.edges:
        a, b = by_id[e.src], by_id[e.dst]
        p1, p2 = _anchor(a, b)
        _arrow(draw, p1, p2, e.color, dashed=e.dashed)
        if e.label:
            t = 0.42
            mx = p1[0] + (p2[0] - p1[0]) * t
            my = p1[1] + (p2[1] - p1[1]) * t
            horizontal = abs(p2[0] - p1[0]) > abs(p2[1] - p1[1])
            if horizontal:
                my -= 14
            else:
                mx += 8
            f = font(12)
            tw = draw.textlength(e.label, font=f)
            draw.rounded_rectangle([mx - tw / 2 - 6, my - 10, mx + tw / 2 + 6, my + 10], radius=6, fill=BG)
            draw.text((mx - tw / 2, my - 7), e.label, font=f, fill=e.color)

    for n in d.nodes:
        box = [n.x, n.y, n.x + n.w, n.y + n.h]
        draw.rounded_rectangle(box, radius=12, fill=n.fill, outline=n.color, width=2)
        f_title = font(16, bold=True)
        f_sub = font(12)
        sub_lines = [s for s in n.sub.split("\n") if s]
        total = 22 + len(sub_lines) * 16
        ty = n.y + (n.h - total) / 2 + 2
        tw = draw.textlength(n.label, font=f_title)
        draw.text((n.x + (n.w - tw) / 2, ty), n.label, font=f_title, fill=n.color)
        for i, line in enumerate(sub_lines):
            lw = draw.textlength(line, font=f_sub)
            draw.text((n.x + (n.w - lw) / 2, ty + 24 + i * 16), line, font=f_sub, fill=MUTED)

    out = HERE / f"{d.name}.png"
    img.save(out, "PNG")
    return out


def render_drawio(d: Diagram) -> pathlib.Path:
    cells: list[str] = []
    cid = 2

    def add_vertex(x, y, w, h, label, style_extra=""):
        nonlocal cid
        style = (
            "rounded=1;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#0f172a;"
            "fontColor=#0f172a;fontSize=12;arcSize=10;" + style_extra
        )
        cells.append(
            f'<mxCell id="{cid}" value="{escape(label)}" style="{style}" vertex="1" parent="1">'
            f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>'
        )
        cid += 1
        return cid - 1

    group_ids = {}
    for g in d.groups:
        nonlocal_cid = add_vertex(g.x, g.y, g.w, g.h, f"{g.label}\n{g.sub}" if g.sub else g.label,
                                 "fillColor=#ffffff;strokeColor=#4f46e5;dashed=0;verticalAlign=top;align=left;spacingLeft=10;fontStyle=1;")
        group_ids[g.label] = nonlocal_cid

    node_ids = {}
    for n in d.nodes:
        label = n.label if not n.sub else f"{n.label}\n{n.sub}"
        node_ids[n.id] = add_vertex(n.x, n.y, n.w, n.h, label, "dashed=1;" if n.dashed else "")

    for e in d.edges:
        cells.append(
            f'<mxCell id="{cid}" value="{escape(e.label)}" style="edgeStyle=orthogonalEdgeStyle;'
            f'rounded=1;html=1;endArrow=block;strokeColor=#64748b;{"dashed=1;" if e.dashed else ""}" '
            f'edge="1" parent="1" source="{node_ids[e.src]}" target="{node_ids[e.dst]}">'
            f'<mxGeometry relative="1" as="geometry"/></mxCell>'
        )
        cid += 1

    xml = (
        '<mxfile host="app.diagrams.net" type="device">'
        f'<diagram id="{d.name}" name="{d.name}">'
        '<mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" '
        'connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1654" pageHeight="1169">'
        "<root>"
        '<mxCell id="0"/><mxCell id="1" parent="0"/>'
        + "".join(cells)
        + "</root></mxGraphModel></diagram></mxfile>"
    )
    out = HERE / f"{d.name}.drawio"
    out.write_text(xml, encoding="utf-8")
    return out


def architecture() -> Diagram:
    d = Diagram(
        name="architecture",
        title="Architecture Kaaru",
        width=1600,
        height=760,
    )
    d.groups = [
        Group("Client", 40, 130, 300, 360, MUTED, "navigateur de l'utilisateur"),
        Group("Azure · France Central", 380, 120, 1180, 600, ACCENT, "abonnement Azure for Students"),
    ]
    d.nodes = [
        Node("browser", "Navigateur", "editeur + apercu local", 70, 210, 240, 80, MUTED),
        Node("phone", "Telephone", "scanne le QR imprime", 70, 370, 240, 80, MUTED),
        Node("editor", "Editeur statique", "HTML + qr-code-styling\nservi par l'API", 430, 200, 240, 90),
        Node("links", "Table links", "source de verite", 760, 200, 180, 80),
        Node("stats", "Table scanstats", "compteurs par jour", 1040, 200, 190, 80),
        Node("kv", "Key Vault", "RBAC · prevu, vide", 1300, 195, 220, 90, AMBER, dashed=True),
        Node("api", "Container App · API", "FastAPI · 0 a 3 replicas", 430, 420, 240, 100, ACCENT),
        Node("queue", "Queue", "scan-events", 760, 430, 180, 80, TEAL),
        Node("worker", "Job · stats", "toutes les 2 min", 1040, 420, 190, 100, TEAL),
        Node("blobs", "Blob logos", "2 Mo max", 760, 580, 180, 70),
        Node("la", "Log Analytics", "traces · 30 jours", 1300, 580, 220, 80, AMBER),
    ]
    d.edges = [
        Edge("browser", "editor", "GET /"),
        Edge("browser", "api", "POST"),
        Edge("phone", "api", "GET /r/x"),
        Edge("api", "links", "lire / ecrire"),
        Edge("api", "queue", "1 message"),
        Edge("queue", "worker", "consomme"),
        Edge("worker", "stats", "incremente"),
        Edge("api", "stats", "lecture", dashed=True),
        Edge("api", "blobs", "logo"),
        Edge("api", "la", "logs", dashed=True),
        Edge("worker", "la", "logs", dashed=True),
    ]
    return d


def network() -> Diagram:
    d = Diagram(
        name="network",
        title="Reseau et filtrage",
        width=1540,
        height=740,
    )
    d.groups = [
        Group("Internet", 40, 130, 250, 200, MUTED, "utilisateurs et scanners"),
        Group("VNet vnet-kaaru · 10.42.0.0/16", 330, 120, 780, 580, ACCENT, "France Central"),
        Group(
            "snet-apps · 10.42.0.0/23",
            360,
            195,
            440,
            305,
            ACCENT,
            "delegue Microsoft.App/environments · NSG entrant 443 seulement",
        ),
        Group(
            "snet-data · 10.42.8.0/24",
            360,
            530,
            440,
            150,
            MUTED,
            "reserve aux points de terminaison prives · NSG entrant depuis snet-apps",
        ),
        Group("Storage account", 1150, 120, 350, 250, TEAL, "pare-feu : refus par defaut"),
        Group("Sorties autorisees", 1150, 410, 350, 270, AMBER, "NSG 100/110/120"),
    ]
    d.nodes = [
        Node("inet", "HTTPS 443", "entrant public", 60, 205, 210, 80, MUTED),
        Node("api", "Container App API", "0 a 3 replicas", 390, 280, 180, 90, ACCENT, fill=(255, 255, 255)),
        Node("job", "Job stats", "2 min", 390, 390, 180, 80, ACCENT, fill=(255, 255, 255)),
        Node("st", "stkaaruprod", "blob · table · queue", 1180, 210, 290, 100, TEAL),
        Node("acr", "Container Registry", "tirage par identite", 1180, 470, 290, 80, AMBER),
        Node("dns", "Azure DNS", "resolution 53", 1180, 570, 290, 80, AMBER),
    ]
    d.edges = [
        Edge("inet", "api", "443"),
        Edge("api", "st", "443 · service endpoint"),
        Edge("api", "acr", "443"),
        Edge("api", "dns", "53"),
    ]
    return d


def main() -> None:
    for builder in (architecture, network):
        d = builder()
        png = render_png(d)
        drawio = render_drawio(d)
        print(f"{d.name}: {png.name} + {drawio.name}")


if __name__ == "__main__":
    main()
