import re
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Ellipse


REPO_ROOT = Path(__file__).resolve().parents[1]
DB_SCHEMA_PATH = REPO_ROOT / "lib" / "database" / "database.dart"
OUT_DIR = REPO_ROOT / "thesis_diagrams" / "generated"


@dataclass(frozen=True)
class ColumnInfo:
    name: str
    # Drift type expression as a short string (best-effort).
    dtype: str
    is_pk: bool = False
    fk_table: Optional[str] = None
    fk_column: Optional[str] = None


@dataclass(frozen=True)
class TableInfo:
    name: str
    columns: List[ColumnInfo]

    def pk_columns(self) -> List[str]:
        return [c.name for c in self.columns if c.is_pk]

    def fk_edges(self) -> List[Tuple[str, str, str]]:
        """
        Returns edges as tuples:
          (from_table, from_column, to_table, to_column)
        """
        edges = []
        for c in self.columns:
            if c.fk_table and c.fk_column:
                edges.append((self.name, c.name, c.fk_table, c.fk_column))
        return edges


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_drift_schema(database_dart_path: Path) -> List[TableInfo]:
    """
    Best-effort parser for Drift Table definitions in lib/database/database.dart.
    Extracts:
      - table name (class X extends Table)
      - columns (TextColumn/RealColumn/DateTimeColumn/get <name> => ...; )
      - PK columns (primaryKey => {a, b})
      - FK references (...references(OtherTable, #id)...)
    """
    src = _read_text(database_dart_path)

    # Find each drift table class block: class <Name> extends Table { ... }
    table_pat = re.compile(r"class\s+(\w+)\s+extends\s+Table\s*\{(.*?)\n\}", re.S)
    # Some files may contain '}\n' differently; fallback: locate by next "@DriftDatabase" or next "class "
    matches = list(table_pat.finditer(src))
    if not matches:
        # Less strict: up to "}\n\n// ===== DATABASE CLASS" or next "class"
        table_pat2 = re.compile(r"class\s+(\w+)\s+extends\s+Table\s*\{(.*?)\n\}\n\n//", re.S)
        matches = list(table_pat2.finditer(src))

    # Map class name -> block content
    table_blocks: Dict[str, str] = {m.group(1): m.group(2) for m in matches}

    if not table_blocks:
        raise RuntimeError(f"Could not parse Drift schema from {database_dart_path}")

    # For each table, parse primary key.
    pk_pat = re.compile(r"Set<Column>\s+get\s+primaryKey\s*=>\s*\{([^}]+)\};", re.S)
    # Parse column declarations.
    # Example: TextColumn get id => text().withLength(min: 1, max: 50)();
    col_pat = re.compile(
        r"(TextColumn|RealColumn|DateTimeColumn|IntColumn|BlobColumn|BoolColumn)\s+get\s+(\w+)\s+=>\s+(.*?);\s*",
        re.S,
    )

    # References: references(Projects, #id)
    ref_pat = re.compile(r"references\((\w+),\s*#(\w+)\)")

    tables: List[TableInfo] = []
    for table_name, block in table_blocks.items():
        pk_set: set = set()
        pk_match = pk_pat.search(block)
        if pk_match:
            pk_expr = pk_match.group(1)
            # e.g. {id} or {projectId, tag}
            for tok in pk_expr.replace("\n", " ").split(","):
                tok = tok.strip()
                if tok:
                    pk_set.add(tok)

        cols: List[ColumnInfo] = []
        for cm in col_pat.finditer(block):
            dtype_kind = cm.group(1)
            col_name = cm.group(2)
            expr = cm.group(3)

            fk_table = None
            fk_col = None
            ref_match = ref_pat.search(expr)
            if ref_match:
                fk_table = ref_match.group(1)
                fk_col = ref_match.group(2)

            # Keep dtype short (best-effort)
            dtype = dtype_kind
            cols.append(
                ColumnInfo(
                    name=col_name,
                    dtype=dtype,
                    is_pk=(col_name in pk_set),
                    fk_table=fk_table,
                    fk_column=fk_col,
                )
            )

        # Order columns by appearance and keep only those we captured
        tables.append(TableInfo(name=table_name, columns=cols))

    return tables


# -------------------- Drawing Helpers --------------------
def _setup_axes(figsize: Tuple[float, float] = (12, 7)) -> Tuple[plt.Figure, plt.Axes]:
    fig, ax = plt.subplots(figsize=figsize)
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis("off")
    return fig, ax


def _fit_wrap(s: str, width: int) -> str:
    s = " ".join(s.split())
    return "\n".join(textwrap.wrap(s, width=width, break_long_words=False))


def draw_box(
    ax: plt.Axes,
    x: float,
    y: float,
    w: float,
    h: float,
    text: str,
    *,
    fontsize: int = 10,
    align: str = "center",
    rounding: float = 0.08,
    fc: str = "#FFFFFF",
    ec: str = "#2B2B2B",
    lw: float = 1.2,
    zorder: int = 3,
):
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle=f"round,pad=0.02,rounding_size={rounding}",
        linewidth=lw,
        edgecolor=ec,
        facecolor=fc,
        zorder=zorder,
    )
    ax.add_patch(patch)
    ax.text(x + w / 2, y + h / 2, text, ha=align, va="center", fontsize=fontsize, zorder=zorder + 0.1)


def draw_ellipse(
    ax: plt.Axes,
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    text: str,
    *,
    fontsize: int = 10,
    fc: str = "#FFF8E1",
    ec: str = "#2B2B2B",
    lw: float = 1.2,
    zorder: int = 3,
):
    e = Ellipse((cx, cy), 2 * rx, 2 * ry, linewidth=lw, edgecolor=ec, facecolor=fc, zorder=zorder)
    ax.add_patch(e)
    ax.text(cx, cy, text, ha="center", va="center", fontsize=fontsize, zorder=zorder + 0.1)


def draw_arrow(
    ax: plt.Axes,
    x1: float,
    y1: float,
    x2: float,
    y2: float,
    *,
    color: str = "#2B2B2B",
    lw: float = 1.1,
    mutation: float = 12,
    connectionstyle: str = "arc3,rad=0.04",
    zorder: int = 1,
):
    arrow = FancyArrowPatch(
        (x1, y1),
        (x2, y2),
        arrowstyle=f"-|>",
        mutation_scale=mutation,
        linewidth=lw,
        color=color,
        connectionstyle=connectionstyle,
    )
    arrow.set_zorder(zorder)
    ax.add_patch(arrow)


def rect_edge_point(cx: float, cy: float, w: float, h: float, tx: float, ty: float) -> Tuple[float, float]:
    """
    Intersection point of a ray from (cx,cy) to (tx,ty) with an axis-aligned rectangle.
    Rectangle is defined by center (cx,cy) and size (w,h).
    """
    dx = tx - cx
    dy = ty - cy
    if abs(dx) < 1e-9 and abs(dy) < 1e-9:
        return cx, cy

    half_w = w / 2.0
    half_h = h / 2.0
    eps = 1e-9
    candidates: List[float] = []

    # Intersect with vertical edge (x = +/-half_w)
    if abs(dx) > eps:
        edge_x = half_w if dx > 0 else -half_w
        t = edge_x / dx
        y_int = dy * t
        if -half_h - 1e-6 <= y_int <= half_h + 1e-6 and t > 0:
            candidates.append(t)

    # Intersect with horizontal edge (y = +/-half_h)
    if abs(dy) > eps:
        edge_y = half_h if dy > 0 else -half_h
        t = edge_y / dy
        x_int = dx * t
        if -half_w - 1e-6 <= x_int <= half_w + 1e-6 and t > 0:
            candidates.append(t)

    if not candidates:
        # Fallback: just clamp to the nearest boundary direction
        return cx + (half_w if dx > 0 else -half_w), cy + (0.0 if abs(dy) < eps else (dy / abs(dy)) * half_h)

    t_min = min(candidates)
    return cx + dx * t_min, cy + dy * t_min


def ellipse_edge_point(cx: float, cy: float, rx: float, ry: float, tx: float, ty: float) -> Tuple[float, float]:
    """
    Intersection point of a ray from (cx,cy) to (tx,ty) with an axis-aligned ellipse.
    """
    dx = tx - cx
    dy = ty - cy
    if abs(dx) < 1e-9 and abs(dy) < 1e-9:
        return cx, cy

    # Parametric ellipse scaling factor along the ray direction.
    # For point (dx*s, dy*s) to satisfy: (dx*s/rx)^2 + (dy*s/ry)^2 = 1.
    denom = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
    if denom <= 1e-12:
        return cx, cy
    s = 1.0 / (denom ** 0.5)
    return cx + dx * s, cy + dy * s


def draw_title(fig: plt.Figure, title: str):
    fig.suptitle(title, fontsize=16, y=0.98, fontweight="bold")


def save_fig(fig: plt.Figure, out_path: Path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)


# -------------------- Diagrams --------------------
def generate_gantt():
    tasks = [
        ("Week 1", "Requirements + diagram design", 0, 1),
        ("Week 2", "DB schema (Drift) + Auth basics", 1, 1),
        ("Weeks 3-4", "Projects + Daily material entry", 2, 2),
        ("Week 5", "Receipt capture + OCR + validation", 4, 1),
        ("Week 6", "Receipts gallery + reports/analytics", 5, 1),
        ("Week 7", "Notifications + settings/profile polish", 6, 1),
        ("Week 8", "Testing + documentation + final handoff", 7, 1),
    ]

    fig, ax = plt.subplots(figsize=(12, 6))
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")

    y_positions = list(range(len(tasks)))[::-1]
    starts = [t[2] for t in tasks]
    durations = [t[3] for t in tasks]
    labels = [t[1] for t in tasks]

    ax.barh(y_positions, durations, left=starts, height=0.65, color="#4F46E5")
    ax.set_yticks(y_positions)
    ax.set_yticklabels(labels, fontsize=10)
    ax.set_xlabel("Timeline (weeks)", fontsize=11)
    ax.set_xlim(0, 8.2)
    ax.set_xticks(range(0, 9))
    ax.grid(axis="x", linestyle="--", alpha=0.35)
    ax.set_title("Gantt Chart (Project Schedule)", fontsize=15, fontweight="bold")

    # Add start labels
    for i, t in enumerate(tasks):
        start = t[2]
        dur = t[3]
        y = y_positions[i]
        ax.text(start + dur / 2, y, f"{t[0]}", ha="center", va="center", fontsize=10, color="white")

    out_png = OUT_DIR / "figure_1_1_gantt_chart.png"
    out_svg = OUT_DIR / "figure_1_1_gantt_chart.svg"
    save_fig(fig, out_png)
    # Save SVG separately (matplotlib sometimes doesn't like multiple saves after close)
    fig, ax = plt.subplots(figsize=(12, 6))
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")
    ax.barh(y_positions, durations, left=starts, height=0.65, color="#4F46E5")
    ax.set_yticks(y_positions)
    ax.set_yticklabels(labels, fontsize=10)
    ax.set_xlabel("Timeline (weeks)", fontsize=11)
    ax.set_xlim(0, 8.2)
    ax.set_xticks(range(0, 9))
    ax.grid(axis="x", linestyle="--", alpha=0.35)
    ax.set_title("Gantt Chart (Project Schedule)", fontsize=15, fontweight="bold")
    for i, t in enumerate(tasks):
        start = t[2]
        dur = t[3]
        y = y_positions[i]
        ax.text(start + dur / 2, y, f"{t[0]}", ha="center", va="center", fontsize=10, color="white")
    save_fig(fig, out_svg)


def generate_incremental_development_model():
    phases = [
        ("Phase 1\nRequirements\n& Planning", 1.0, 7.7),
        ("Phase 2\nCore DB +\nAuthentication", 3.8, 7.7),
        ("Phase 3\nProjects +\nExpense Logging", 6.6, 7.7),
        ("Phase 4\nReceipts\nCapture + OCR", 6.6, 4.2),
        ("Phase 5\nReports +\nNotifications", 3.8, 4.2),
        ("Phase 6\nTesting +\nDocumentation", 1.0, 4.2),
    ]

    fig, ax = _setup_axes(figsize=(12, 6))
    draw_title(fig, "Incremental Development Model")

    for label, x, y in phases:
        draw_box(ax, x, y, 2.4, 1.6, label, fontsize=11, rounding=0.10, fc="#EEF2FF")

    # Arrows to show progression/iterations
    draw_arrow(ax, 2.2, 8.1, 4.6, 8.1)
    draw_arrow(ax, 5.2, 8.1, 7.0, 5.0)
    draw_arrow(ax, 7.0, 5.0, 4.6, 4.6)
    draw_arrow(ax, 4.0, 4.6, 2.2, 4.6)

    # Feedback loop (iteration)
    draw_arrow(ax, 1.4, 4.0, 1.4, 6.9, color="#6B7280")
    draw_arrow(ax, 1.4, 6.9, 3.6, 6.9, color="#6B7280")
    draw_box(
        ax,
        1.0,
        2.0,
        8.0,
        1.2,
        "Iterate: refine requirements, UI, and data model as each\nincrement becomes stable.",
        fontsize=10,
        rounding=0.06,
        fc="#F9FAFB",
    )

    out_png = OUT_DIR / "figure_3_1_incremental_development_model.png"
    out_svg = OUT_DIR / "figure_3_1_incremental_development_model.svg"
    save_fig(fig, out_png)
    fig, ax = _setup_axes(figsize=(12, 6))
    draw_title(fig, "Incremental Development Model")
    for label, x, y in phases:
        draw_box(ax, x, y, 2.4, 1.6, label, fontsize=11, rounding=0.10, fc="#EEF2FF")
    draw_arrow(ax, 2.2, 8.1, 4.6, 8.1)
    draw_arrow(ax, 5.2, 8.1, 7.0, 5.0)
    draw_arrow(ax, 7.0, 5.0, 4.6, 4.6)
    draw_arrow(ax, 4.0, 4.6, 2.2, 4.6)
    draw_arrow(ax, 1.4, 4.0, 1.4, 6.9, color="#6B7280")
    draw_arrow(ax, 1.4, 6.9, 3.6, 6.9, color="#6B7280")
    draw_box(
        ax,
        1.0,
        2.0,
        8.0,
        1.2,
        "Iterate: refine requirements, UI, and data model as each\nincrement becomes stable.",
        fontsize=10,
        rounding=0.06,
        fc="#F9FAFB",
    )
    save_fig(fig, out_svg)


def generate_system_modules_architecture():
    fig, ax = _setup_axes(figsize=(12, 6))
    draw_title(fig, "System Modules Architecture")

    # Layer boxes
    draw_box(ax, 0.4, 7.2, 3.0, 2.0, "UI Layer\n(Screens + Navigation)", fontsize=11, fc="#ECFDF5")
    draw_box(ax, 3.6, 7.2, 3.0, 2.0, "State/Providers\n(Auth, Drift, Theme, Currency)", fontsize=10, fc="#ECFDF5")
    draw_box(ax, 6.8, 7.2, 2.6, 2.0, "OCR Layer\n(ML Kit Text Recognition)", fontsize=11, fc="#ECFDF5")

    draw_box(ax, 0.4, 4.5, 4.2, 2.2, "Feature Workflows\nProjects, Expenses, Receipts, Tasks,\nReports, Notifications", fontsize=10, fc="#EFF6FF")
    draw_box(ax, 4.8, 4.5, 3.6, 2.2, "Data Layer\nSQLite/Drift + Migrations", fontsize=10, fc="#EEF2FF")
    draw_box(ax, 8.6, 4.5, 1.0, 2.2, "Security\nStorage + Biometrics", fontsize=10, fc="#FDE68A")

    draw_box(ax, 0.4, 2.1, 5.4, 1.6, "File Storage\nReceipt images saved to app documents/", fontsize=10, fc="#F3F4F6")
    draw_box(ax, 5.9, 2.1, 3.2, 1.6, "External Inputs\nCamera/Gallery images", fontsize=10, fc="#F3F4F6")

    # Arrows between main layers
    draw_arrow(ax, 3.4, 8.2, 3.9, 8.2)
    draw_arrow(ax, 5.6, 8.2, 7.0, 8.2)
    draw_arrow(ax, 3.0, 6.9, 4.8, 5.7)
    draw_arrow(ax, 6.0, 5.2, 6.6, 5.9)
    draw_arrow(ax, 8.1, 6.3, 8.1, 6.3)
    draw_arrow(ax, 8.2, 6.8, 6.8, 5.6)
    draw_arrow(ax, 5.4, 3.7, 5.0, 4.2)
    draw_arrow(ax, 6.8, 3.7, 6.0, 4.6)
    draw_arrow(ax, 7.2, 2.1, 7.7, 3.9)

    # Legend-ish note
    draw_box(
        ax,
        0.4,
        0.3,
        9.6,
        1.5,
        "Flow (high level): UI -> Providers -> Drift DB.\nReceipt image -> OCR -> create Expense -> DB updates project budget/progress.",
        fontsize=10,
        rounding=0.06,
        fc="#FFFFFF",
    )

    out_png = OUT_DIR / "figure_3_2_system_modules_architecture.png"
    out_svg = OUT_DIR / "figure_3_2_system_modules_architecture.svg"
    save_fig(fig, out_png)
    fig, ax = _setup_axes(figsize=(12, 6))
    draw_title(fig, "System Modules Architecture")
    draw_box(ax, 0.4, 7.2, 3.0, 2.0, "UI Layer\n(Screens + Navigation)", fontsize=11, fc="#ECFDF5")
    draw_box(ax, 3.6, 7.2, 3.0, 2.0, "State/Providers\n(Auth, Drift, Theme, Currency)", fontsize=10, fc="#ECFDF5")
    draw_box(ax, 6.8, 7.2, 2.6, 2.0, "OCR Layer\n(ML Kit Text Recognition)", fontsize=11, fc="#ECFDF5")
    draw_box(ax, 0.4, 4.5, 4.2, 2.2, "Feature Workflows\nProjects, Expenses, Receipts, Tasks,\nReports, Notifications", fontsize=10, fc="#EFF6FF")
    draw_box(ax, 4.8, 4.5, 3.6, 2.2, "Data Layer\nSQLite/Drift + Migrations", fontsize=10, fc="#EEF2FF")
    draw_box(ax, 8.6, 4.5, 1.0, 2.2, "Security\nStorage + Biometrics", fontsize=10, fc="#FDE68A")
    draw_box(ax, 0.4, 2.1, 5.4, 1.6, "File Storage\nReceipt images saved to app documents/", fontsize=10, fc="#F3F4F6")
    draw_box(ax, 5.9, 2.1, 3.2, 1.6, "External Inputs\nCamera/Gallery images", fontsize=10, fc="#F3F4F6")
    draw_arrow(ax, 3.4, 8.2, 3.9, 8.2)
    draw_arrow(ax, 5.6, 8.2, 7.0, 8.2)
    draw_arrow(ax, 3.0, 6.9, 4.8, 5.7)
    draw_arrow(ax, 6.0, 5.2, 6.6, 5.9)
    draw_arrow(ax, 8.2, 6.8, 6.8, 5.6)
    draw_arrow(ax, 5.4, 3.7, 5.0, 4.2)
    draw_arrow(ax, 6.8, 3.7, 6.0, 4.6)
    draw_arrow(ax, 7.2, 2.1, 7.7, 3.9)
    draw_box(
        ax,
        0.4,
        0.3,
        9.6,
        1.5,
        "Flow (high level): UI -> Providers -> Drift DB.\nReceipt image -> OCR -> create Expense -> DB updates project budget/progress.",
        fontsize=10,
        rounding=0.06,
        fc="#FFFFFF",
    )
    save_fig(fig, out_svg)


def generate_context_diagram_existing():
    fig, ax = _setup_axes(figsize=(12, 6))
    draw_title(fig, "Context Diagram - Existing System")

    # External entities
    draw_ellipse(ax, 1.0, 7.2, 1.0, 0.6, "User")
    draw_box(ax, 8.0, 7.0, 1.6, 1.3, "Camera/\nGallery", fontsize=10, fc="#F3F4F6")
    draw_box(ax, 8.0, 4.4, 1.6, 1.3, "OCR Engine\n(ML Kit)", fontsize=10, fc="#F3F4F6")

    # System
    draw_box(ax, 3.5, 4.0, 3.2, 2.9, "ProjectRack Mobile App\n(Receipts, Projects, Reports)", fontsize=11, fc="#ECFDF5")

    # Data stores (local)
    draw_box(ax, 3.5, 1.1, 3.2, 1.6, "Local Database\n(Drift/SQLite) + Image Files", fontsize=10, fc="#EEF2FF")

    # Flows
    # Use accurate edge-to-edge arrows (reduces overlap and makes direction clear).
    user_cx, user_cy, user_rx, user_ry = 1.0, 7.2, 1.0, 0.6
    cam_x, cam_y, cam_w, cam_h = 8.0, 7.0, 1.6, 1.3
    ocr_x, ocr_y, ocr_w, ocr_h = 8.0, 4.4, 1.6, 1.3
    app_x, app_y, app_w, app_h = 3.5, 4.0, 3.2, 2.9
    db_x, db_y, db_w, db_h = 3.5, 1.1, 3.2, 1.6

    cam_cx, cam_cy = cam_x + cam_w / 2, cam_y + cam_h / 2
    ocr_cx, ocr_cy = ocr_x + ocr_w / 2, ocr_y + ocr_h / 2
    app_cx, app_cy = app_x + app_w / 2, app_y + app_h / 2
    db_cx, db_cy = db_x + db_w / 2, db_y + db_h / 2

    # user -> app
    u_to_app = ellipse_edge_point(user_cx, user_cy, user_rx, user_ry, app_cx, app_cy)
    app_to_u = rect_edge_point(app_cx, app_cy, app_w, app_h, user_cx, user_cy)
    draw_arrow(ax, u_to_app[0], u_to_app[1], app_to_u[0], app_to_u[1], color="#2B2B2B", lw=1.0, zorder=1, connectionstyle="arc3,rad=0.02")

    # app -> user (feedback)
    app_to_user = rect_edge_point(app_cx, app_cy, app_w, app_h, user_cx, user_cy)
    user_from_app = ellipse_edge_point(user_cx, user_cy, user_rx, user_ry, app_cx, app_cy)
    draw_arrow(ax, app_to_user[0], app_to_user[1], user_from_app[0], user_from_app[1], color="#6B7280", lw=1.0, zorder=1, connectionstyle="arc3,rad=0.02")

    # image input -> app (use camera box)
    cam_to_app = rect_edge_point(cam_cx, cam_cy, cam_w, cam_h, app_cx, app_cy)
    app_from_cam = rect_edge_point(app_cx, app_cy, app_w, app_h, cam_cx, cam_cy)
    draw_arrow(ax, cam_to_app[0], cam_to_app[1], app_from_cam[0], app_from_cam[1], lw=1.0, color="#2B2B2B", zorder=1, connectionstyle="arc3,rad=-0.03")

    # OCR -> app
    ocr_to_app = rect_edge_point(ocr_cx, ocr_cy, ocr_w, ocr_h, app_cx, app_cy)
    app_from_ocr = rect_edge_point(app_cx, app_cy, app_w, app_h, ocr_cx, ocr_cy)
    draw_arrow(ax, ocr_to_app[0], ocr_to_app[1], app_from_ocr[0], app_from_ocr[1], lw=1.0, color="#6B7280", zorder=1, connectionstyle="arc3,rad=0.02")

    # app <-> local data
    app_to_db = rect_edge_point(app_cx, app_cy, app_w, app_h, db_cx, db_cy)
    db_from_app = rect_edge_point(db_cx, db_cy, db_w, db_h, app_cx, app_cy)
    draw_arrow(ax, app_to_db[0], app_to_db[1], db_from_app[0], db_from_app[1], lw=1.0, color="#6B7280", zorder=1, connectionstyle="arc3,rad=0.02")
    draw_arrow(ax, db_from_app[0], db_from_app[1], app_to_db[0], app_to_db[1], lw=1.0, color="#6B7280", zorder=1, connectionstyle="arc3,rad=-0.02")

    # Caption box
    draw_box(
        ax,
        0.6,
        0.0,
        9.0,
        1.0,
        "User actions drive workflows.\nSystem stores and retrieves data locally.",
        fontsize=9,
        rounding=0.05,
        fc="#FFFFFF",
    )

    out_png = OUT_DIR / "figure_4_1_context_diagram_existing_system.png"
    out_svg = OUT_DIR / "figure_4_1_context_diagram_existing_system.svg"
    save_fig(fig, out_png)
    fig, ax = _setup_axes(figsize=(12, 6))
    draw_title(fig, "Context Diagram - Existing System")
    draw_ellipse(ax, 1.0, 7.2, 1.0, 0.6, "User")
    draw_box(ax, 8.0, 7.0, 1.6, 1.3, "Camera/\nGallery", fontsize=10, fc="#F3F4F6")
    draw_box(ax, 8.0, 4.4, 1.6, 1.3, "OCR Engine\n(ML Kit)", fontsize=10, fc="#F3F4F6")
    draw_box(ax, 3.5, 4.0, 3.2, 2.9, "ProjectRack Mobile App\n(Receipts, Projects, Reports)", fontsize=11, fc="#ECFDF5")
    draw_box(ax, 3.5, 1.1, 3.2, 1.6, "Local Database\n(Drift/SQLite) + Image Files", fontsize=10, fc="#EEF2FF")
    # Redraw clean arrows (same edge-to-edge logic).
    user_cx, user_cy, user_rx, user_ry = 1.0, 7.2, 1.0, 0.6
    cam_x, cam_y, cam_w, cam_h = 8.0, 7.0, 1.6, 1.3
    ocr_x, ocr_y, ocr_w, ocr_h = 8.0, 4.4, 1.6, 1.3
    app_x, app_y, app_w, app_h = 3.5, 4.0, 3.2, 2.9
    db_x, db_y, db_w, db_h = 3.5, 1.1, 3.2, 1.6

    cam_cx, cam_cy = cam_x + cam_w / 2, cam_y + cam_h / 2
    ocr_cx, ocr_cy = ocr_x + ocr_w / 2, ocr_y + ocr_h / 2
    app_cx, app_cy = app_x + app_w / 2, app_y + app_h / 2
    db_cx, db_cy = db_x + db_w / 2, db_y + db_h / 2

    u_to_app = ellipse_edge_point(user_cx, user_cy, user_rx, user_ry, app_cx, app_cy)
    app_to_u = rect_edge_point(app_cx, app_cy, app_w, app_h, user_cx, user_cy)
    draw_arrow(ax, u_to_app[0], u_to_app[1], app_to_u[0], app_to_u[1], color="#2B2B2B", lw=1.0, zorder=1, connectionstyle="arc3,rad=0.02")

    app_to_user = rect_edge_point(app_cx, app_cy, app_w, app_h, user_cx, user_cy)
    user_from_app = ellipse_edge_point(user_cx, user_cy, user_rx, user_ry, app_cx, app_cy)
    draw_arrow(ax, app_to_user[0], app_to_user[1], user_from_app[0], user_from_app[1], color="#6B7280", lw=1.0, zorder=1, connectionstyle="arc3,rad=0.02")

    cam_to_app = rect_edge_point(cam_cx, cam_cy, cam_w, cam_h, app_cx, app_cy)
    app_from_cam = rect_edge_point(app_cx, app_cy, app_w, app_h, cam_cx, cam_cy)
    draw_arrow(ax, cam_to_app[0], cam_to_app[1], app_from_cam[0], app_from_cam[1], lw=1.0, color="#2B2B2B", zorder=1, connectionstyle="arc3,rad=-0.03")

    ocr_to_app = rect_edge_point(ocr_cx, ocr_cy, ocr_w, ocr_h, app_cx, app_cy)
    app_from_ocr = rect_edge_point(app_cx, app_cy, app_w, app_h, ocr_cx, ocr_cy)
    draw_arrow(ax, ocr_to_app[0], ocr_to_app[1], app_from_ocr[0], app_from_ocr[1], lw=1.0, color="#6B7280", zorder=1, connectionstyle="arc3,rad=0.02")

    app_to_db = rect_edge_point(app_cx, app_cy, app_w, app_h, db_cx, db_cy)
    db_from_app = rect_edge_point(db_cx, db_cy, db_w, db_h, app_cx, app_cy)
    draw_arrow(ax, app_to_db[0], app_to_db[1], db_from_app[0], db_from_app[1], lw=1.0, color="#6B7280", zorder=1, connectionstyle="arc3,rad=0.02")
    draw_arrow(ax, db_from_app[0], db_from_app[1], app_to_db[0], app_to_db[1], lw=1.0, color="#6B7280", zorder=1, connectionstyle="arc3,rad=-0.02")
    draw_box(
        ax,
        0.6,
        0.0,
        9.0,
        1.0,
        "User actions drive workflows.\nSystem stores and retrieves data locally.",
        fontsize=9,
        rounding=0.05,
        fc="#FFFFFF",
    )
    save_fig(fig, out_svg)


def generate_dfd_level0_existing(proposed: bool):
    """
    If proposed=True, render the proposed DFD (Figure 4.3).
    If proposed=False, render existing DFD (Figure 4.2).
    """
    fig, ax = _setup_axes(figsize=(12, 7))
    draw_title(fig, "DFD Level 0 - Proposed System" if proposed else "DFD Level 0 - Existing System")

    # Processes
    draw_box(ax, 0.6, 6.3, 2.7, 1.1, "P1\nManage Projects", fontsize=10, fc="#E0F2FE")
    draw_box(ax, 3.7, 6.3, 3.0, 1.1, "P2\nLog Expenses & Receipts", fontsize=10, fc="#E0F2FE")
    draw_box(ax, 7.1, 6.3, 2.3, 1.1, "P3\nReports/Stats", fontsize=10, fc="#E0F2FE")
    draw_box(ax, 2.0, 3.3, 5.3, 1.0, "P4\nNotifications (Budget/Activity/Tasks)", fontsize=10, fc="#E0F2FE")

    # Data stores
    if proposed:
        draw_box(ax, 0.6, 1.0, 2.0, 1.6, "D1\nProjects", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 2.9, 1.0, 2.4, 1.6, "D2\nExpenses", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 5.6, 1.0, 2.4, 1.6, "D3\nReceipts\n(OCR data)", fontsize=9, fc="#EEF2FF")
        draw_box(ax, 8.1, 1.0, 1.5, 1.6, "D4\nTasks", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 0.6, 2.5, 9.0, 0.7, "D5\nReceipt image files stored in app documents", fontsize=9, fc="#F3F4F6")
    else:
        draw_box(ax, 0.6, 1.0, 2.2, 1.6, "D1\nProjects", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 3.0, 1.0, 2.2, 1.6, "D2\nExpenses\n(receiptImage)", fontsize=9, fc="#EEF2FF")
        draw_box(ax, 5.6, 1.0, 2.0, 1.6, "D3\nTasks", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 7.8, 1.0, 2.0, 1.6, "D4\nReceipt image files", fontsize=9, fc="#F3F4F6")

    # Flows (clean edge-to-edge).
    # Process boxes
    p1 = (0.6, 6.3, 2.7, 1.1)
    p2 = (3.7, 6.3, 3.0, 1.1)
    p3 = (7.1, 6.3, 2.3, 1.1)
    p4 = (2.0, 3.3, 5.3, 1.0)
    rx_box = (7.1, 3.2, 2.3, 0.9)  # Receipt Image (Camera/Gallery)

    def arrow_rect_to_rect(xa, ya, wa, ha, xb, yb, wb, hb, *, color: str, lw: float = 0.9, rad: float = 0.04):
        ax_cx, ax_cy = xa + wa / 2, ya + ha / 2
        bx_cx, bx_cy = xb + wb / 2, yb + hb / 2
        a_edge = rect_edge_point(ax_cx, ax_cy, wa, ha, bx_cx, bx_cy)
        b_edge = rect_edge_point(bx_cx, bx_cy, wb, hb, ax_cx, ax_cy)
        draw_arrow(ax, a_edge[0], a_edge[1], b_edge[0], b_edge[1], color=color, lw=lw, zorder=1, connectionstyle=f"arc3,rad={rad}")

    # Data stores
    if proposed:
        d1 = (0.6, 1.0, 2.0, 1.6)   # Projects
        d2 = (2.9, 1.0, 2.4, 1.6)   # Expenses
        d3 = (5.6, 1.0, 2.4, 1.6)   # Receipts OCR data
        d4 = (8.1, 1.0, 1.5, 1.6)   # Tasks
        d5 = (0.6, 2.5, 9.0, 0.7)   # Receipt image files
    else:
        d1 = (0.6, 1.0, 2.2, 1.6)   # Projects
        d2 = (3.0, 1.0, 2.2, 1.6)   # Expenses
        d3 = (5.6, 1.0, 2.0, 1.6)   # Tasks
        d4 = (7.8, 1.0, 2.0, 1.6)   # Receipt image files

    # Receipt capture feeds P2
    draw_box(ax, rx_box[0], rx_box[1], rx_box[2], rx_box[3], "Receipt Image\n(Camera/Gallery)", fontsize=9, fc="#F3F4F6")
    arrow_rect_to_rect(*rx_box, *p2, color="#111827", rad=-0.06)

    # P1 <-> Projects
    arrow_rect_to_rect(*p1, *d1, color="#6B7280")
    arrow_rect_to_rect(*d1, *p1, color="#6B7280", rad=-0.02)

    # P2 <-> Expenses
    arrow_rect_to_rect(*p2, *d2, color="#6B7280")
    arrow_rect_to_rect(*d2, *p2, color="#6B7280", rad=-0.02)

    # P2 updates Projects budget/progress
    arrow_rect_to_rect(*p2, *d1, color="#6B7280", lw=0.8, rad=0.03)

    # P3 reports reads from stores
    arrow_rect_to_rect(*p3, *d1, color="#6B7280", lw=0.85)
    arrow_rect_to_rect(*p3, *d2, color="#6B7280", lw=0.85)
    if proposed:
        arrow_rect_to_rect(*p3, *d4, color="#6B7280", lw=0.85)
    else:
        arrow_rect_to_rect(*p3, *d3, color="#6B7280", lw=0.85)  # Tasks

    # P4 notifications reads from stores
    arrow_rect_to_rect(*p4, *d1, color="#6B7280", lw=0.85)
    arrow_rect_to_rect(*p4, *d2, color="#6B7280", lw=0.85)
    if proposed:
        arrow_rect_to_rect(*p4, *d4, color="#6B7280", lw=0.85)
    else:
        arrow_rect_to_rect(*p4, *d3, color="#6B7280", lw=0.85)

    # Proposed: OCR text saved as Receipts OCR data
    if proposed:
        # Minimal highlight boxes
        draw_box(ax, 6.1, 4.2, 1.2, 0.6, "OCR\n(ML Kit)", fontsize=9, fc="#FEE2E2", zorder=3)
        draw_box(ax, 7.2, 3.6, 1.0, 0.5, "Save OCR\ntext/conf.", fontsize=8, fc="#FEE2E2", zorder=3)
        # P2 -> D3
        arrow_rect_to_rect(*p2, *d3, color="#EF4444", lw=0.95, rad=0.04)
        # P2 -> D5 receipt image files (storage)
        arrow_rect_to_rect(*p2, *d5, color="#6B7280", lw=0.75, rad=0.05)
    else:
        # Existing: receipt image files tied to expenses
        arrow_rect_to_rect(*p2, *d4, color="#6B7280", lw=0.75, rad=0.05)

    out_png = OUT_DIR / ("figure_4_2_dfd_level0_existing_system.png" if not proposed else "figure_4_3_dfd_level0_proposed_system.png")
    out_svg = OUT_DIR / ("figure_4_2_dfd_level0_existing_system.svg" if not proposed else "figure_4_3_dfd_level0_proposed_system.svg")
    save_fig(fig, out_png)
    fig, ax = _setup_axes(figsize=(12, 7))
    draw_title(fig, "DFD Level 0 - Proposed System" if proposed else "DFD Level 0 - Existing System")
    # Redraw quickly (code duplication for SVG)
    draw_box(ax, 0.6, 6.3, 2.7, 1.1, "P1\nManage Projects", fontsize=10, fc="#E0F2FE")
    draw_box(ax, 3.7, 6.3, 3.0, 1.1, "P2\nLog Expenses & Receipts", fontsize=10, fc="#E0F2FE")
    draw_box(ax, 7.1, 6.3, 2.3, 1.1, "P3\nReports/Stats", fontsize=10, fc="#E0F2FE")
    draw_box(ax, 2.0, 3.3, 5.3, 1.0, "P4\nNotifications (Budget/Activity/Tasks)", fontsize=10, fc="#E0F2FE")
    if proposed:
        draw_box(ax, 0.6, 1.0, 2.0, 1.6, "D1\nProjects", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 2.9, 1.0, 2.4, 1.6, "D2\nExpenses", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 5.6, 1.0, 2.4, 1.6, "D3\nReceipts\n(OCR data)", fontsize=9, fc="#EEF2FF")
        draw_box(ax, 8.1, 1.0, 1.5, 1.6, "D4\nTasks", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 0.6, 2.5, 9.0, 0.7, "D5\nReceipt image files stored in app documents", fontsize=9, fc="#F3F4F6")
    else:
        draw_box(ax, 0.6, 1.0, 2.2, 1.6, "D1\nProjects", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 3.0, 1.0, 2.2, 1.6, "D2\nExpenses\n(receiptImage)", fontsize=9, fc="#EEF2FF")
        draw_box(ax, 5.6, 1.0, 2.0, 1.6, "D3\nTasks", fontsize=10, fc="#EEF2FF")
        draw_box(ax, 7.8, 1.0, 2.0, 1.6, "D4\nReceipt image files", fontsize=9, fc="#F3F4F6")
    # Redraw DFD flows using the same clean edge-to-edge logic.
    p1 = (0.6, 6.3, 2.7, 1.1)
    p2 = (3.7, 6.3, 3.0, 1.1)
    p3 = (7.1, 6.3, 2.3, 1.1)
    p4 = (2.0, 3.3, 5.3, 1.0)
    rx_box = (7.1, 3.2, 2.3, 0.9)

    def arrow_rect_to_rect(xa, ya, wa, ha, xb, yb, wb, hb, *, color: str, lw: float = 0.9, rad: float = 0.04):
        ax_cx, ax_cy = xa + wa / 2, ya + ha / 2
        bx_cx, bx_cy = xb + wb / 2, yb + hb / 2
        a_edge = rect_edge_point(ax_cx, ax_cy, wa, ha, bx_cx, bx_cy)
        b_edge = rect_edge_point(bx_cx, bx_cy, wb, hb, ax_cx, ax_cy)
        draw_arrow(ax, a_edge[0], a_edge[1], b_edge[0], b_edge[1], color=color, lw=lw, zorder=1, connectionstyle=f"arc3,rad={rad}")

    if proposed:
        d1 = (0.6, 1.0, 2.0, 1.6)
        d2 = (2.9, 1.0, 2.4, 1.6)
        d3 = (5.6, 1.0, 2.4, 1.6)
        d4 = (8.1, 1.0, 1.5, 1.6)
        d5 = (0.6, 2.5, 9.0, 0.7)
    else:
        d1 = (0.6, 1.0, 2.2, 1.6)
        d2 = (3.0, 1.0, 2.2, 1.6)
        d3 = (5.6, 1.0, 2.0, 1.6)
        d4 = (7.8, 1.0, 2.0, 1.6)

    draw_box(ax, rx_box[0], rx_box[1], rx_box[2], rx_box[3], "Receipt Image\n(Camera/Gallery)", fontsize=9, fc="#F3F4F6", zorder=3)
    arrow_rect_to_rect(*rx_box, *p2, color="#111827", rad=-0.06)

    arrow_rect_to_rect(*p1, *d1, color="#6B7280")
    arrow_rect_to_rect(*d1, *p1, color="#6B7280", rad=-0.02)

    arrow_rect_to_rect(*p2, *d2, color="#6B7280")
    arrow_rect_to_rect(*d2, *p2, color="#6B7280", rad=-0.02)
    arrow_rect_to_rect(*p2, *d1, color="#6B7280", lw=0.8, rad=0.03)

    arrow_rect_to_rect(*p3, *d1, color="#6B7280", lw=0.85)
    arrow_rect_to_rect(*p3, *d2, color="#6B7280", lw=0.85)
    if proposed:
        arrow_rect_to_rect(*p3, *d4, color="#6B7280", lw=0.85)
    else:
        arrow_rect_to_rect(*p3, *d3, color="#6B7280", lw=0.85)

    arrow_rect_to_rect(*p4, *d1, color="#6B7280", lw=0.85)
    arrow_rect_to_rect(*p4, *d2, color="#6B7280", lw=0.85)
    if proposed:
        arrow_rect_to_rect(*p4, *d4, color="#6B7280", lw=0.85)
    else:
        arrow_rect_to_rect(*p4, *d3, color="#6B7280", lw=0.85)

    if proposed:
        draw_box(ax, 6.1, 4.2, 1.2, 0.6, "OCR\n(ML Kit)", fontsize=9, fc="#FEE2E2", zorder=3)
        draw_box(ax, 7.2, 3.6, 1.0, 0.5, "Save OCR\ntext/conf.", fontsize=8, fc="#FEE2E2", zorder=3)
        arrow_rect_to_rect(*p2, *d3, color="#EF4444", lw=0.95, rad=0.04)
        arrow_rect_to_rect(*p2, *d5, color="#6B7280", lw=0.75, rad=0.05)
    else:
        arrow_rect_to_rect(*p2, *d4, color="#6B7280", lw=0.75, rad=0.05)
    save_fig(fig, out_svg)


def generate_erd(tables: List[TableInfo]):
    """
    Render an ERD using matplotlib boxes/arrows.
    Layout: 2-column grid; boxes sized based on number of columns.
    """
    fig, ax = _setup_axes(figsize=(13, 9))
    draw_title(fig, "Entity Relationship Diagram (ERD)")

    # Layout tables into two columns
    left = ["Users", "Projects", "Expenses", "Receipts"]
    right = ["Tasks", "Categories", "Settings", "ProjectTags"]
    name_to_table = {t.name: t for t in tables}
    left_tables = [name_to_table[n] for n in left if n in name_to_table]
    right_tables = [name_to_table[n] for n in right if n in name_to_table]

    def col_positions(col_tables: List[TableInfo], x: float) -> List[Tuple[TableInfo, float]]:
        # y positions evenly spaced from top to bottom
        usable_top = 8.8
        usable_bottom = 1.1
        count = max(len(col_tables), 1)
        span = usable_top - usable_bottom
        step = span / max(count, 1)
        out = []
        for i, t in enumerate(col_tables):
            y_top = usable_top - i * step
            out.append((t, y_top))
        return out

    left_pos = col_positions(left_tables, x=1.0)
    right_pos = col_positions(right_tables, x=6.8)

    def fmt_cols(t: TableInfo) -> List[str]:
        lines = []
        for c in t.columns:
            tag = "PK" if c.is_pk else ("FK" if c.fk_table else "")
            if tag and c.fk_table:
                tag = f"{tag}({c.fk_table}.{c.fk_column})"
            elif tag:
                tag = f"{tag}"
            base = f"{c.name}{':' if True else ''}{c.dtype}"
            if tag:
                base = f"{base} [{tag}]"
            lines.append(base)
        return lines

    # Draw boxes first
    boxes: Dict[str, Tuple[float, float, float, float]] = {}  # name -> (x,y,w,h)

    for (t, y_top) in left_pos:
        lines = fmt_cols(t)
        # Split into multiple lines with a max per box.
        # Keep the ERD readable: cap lines shown.
        max_lines = 9
        shown = lines[:max_lines]
        if len(lines) > max_lines:
            shown.append("...")

        label_lines = [f"{t.name}"] + shown
        label = "\n".join(label_lines)

        h = 0.9 + 0.25 * len(shown)
        w = 3.6
        y = max(0.2, y_top - h / 2)
        x = 0.6
        draw_box(ax, x, y, w, h, label, fontsize=8.8, rounding=0.08, fc="#FFFFFF")
        boxes[t.name] = (x, y, w, h)

    for (t, y_top) in right_pos:
        lines = fmt_cols(t)
        max_lines = 9
        shown = lines[:max_lines]
        if len(lines) > max_lines:
            shown.append("...")

        label_lines = [f"{t.name}"] + shown
        label = "\n".join(label_lines)
        h = 0.9 + 0.25 * len(shown)
        w = 3.6
        y = max(0.2, y_top - h / 2)
        x = 6.0
        draw_box(ax, x, y, w, h, label, fontsize=8.8, rounding=0.08, fc="#FFFFFF")
        boxes[t.name] = (x, y, w, h)

    # Arrows for FKs
    def center_of(table_name: str) -> Tuple[float, float]:
        x, y, w, h = boxes[table_name]
        return x + w / 2, y + h / 2

    for t in tables:
        for (from_t, from_col, to_t, to_col) in t.fk_edges():
            if from_t in boxes and to_t in boxes:
                fx, fy, fw, fh = boxes[from_t]
                tx_, ty_, tw, th = boxes[to_t]
                fcx, fcy = fx + fw / 2, fy + fh / 2
                tcx, tcy = tx_ + tw / 2, ty_ + th / 2
                a_edge = rect_edge_point(fcx, fcy, fw, fh, tcx, tcy)
                b_edge = rect_edge_point(tcx, tcy, tw, th, fcx, fcy)
                draw_arrow(ax, a_edge[0], a_edge[1], b_edge[0], b_edge[1], lw=0.9, color="#6B7280", zorder=1, connectionstyle="arc3,rad=0.02")
                # Note: keeping FK labels minimal to avoid clutter

    out_png = OUT_DIR / "figure_4_4_erd.png"
    out_svg = OUT_DIR / "figure_4_4_erd.svg"
    save_fig(fig, out_png)

    fig, ax = _setup_axes(figsize=(13, 9))
    draw_title(fig, "Entity Relationship Diagram (ERD)")
    # Redraw (same logic)
    left_pos = col_positions(left_tables, x=1.0)
    right_pos = col_positions(right_tables, x=6.8)
    boxes = {}
    for (t, y_top) in left_pos:
        lines = fmt_cols(t)
        max_lines = 9
        shown = lines[:max_lines]
        if len(lines) > max_lines:
            shown.append("...")
        label = "\n".join([f"{t.name}"] + shown)
        h = 0.9 + 0.25 * len(shown)
        w = 3.6
        y = max(0.2, y_top - h / 2)
        x = 0.6
        draw_box(ax, x, y, w, h, label, fontsize=8.8, rounding=0.08, fc="#FFFFFF")
        boxes[t.name] = (x, y, w, h)
    for (t, y_top) in right_pos:
        lines = fmt_cols(t)
        max_lines = 9
        shown = lines[:max_lines]
        if len(lines) > max_lines:
            shown.append("...")
        label = "\n".join([f"{t.name}"] + shown)
        h = 0.9 + 0.25 * len(shown)
        w = 3.6
        y = max(0.2, y_top - h / 2)
        x = 6.0
        draw_box(ax, x, y, w, h, label, fontsize=8.8, rounding=0.08, fc="#FFFFFF")
        boxes[t.name] = (x, y, w, h)

    def center_of(table_name: str) -> Tuple[float, float]:
        x, y, w, h = boxes[table_name]
        return x + w / 2, y + h / 2

    for t in tables:
        for (from_t, from_col, to_t, to_col) in t.fk_edges():
            if from_t in boxes and to_t in boxes:
                fx, fy, fw, fh = boxes[from_t]
                tx_, ty_, tw, th = boxes[to_t]
                fcx, fcy = fx + fw / 2, fy + fh / 2
                tcx, tcy = tx_ + tw / 2, ty_ + th / 2
                a_edge = rect_edge_point(fcx, fcy, fw, fh, tcx, tcy)
                b_edge = rect_edge_point(tcx, tcy, tw, th, fcx, fcy)
                draw_arrow(ax, a_edge[0], a_edge[1], b_edge[0], b_edge[1], lw=0.9, color="#6B7280", zorder=1, connectionstyle="arc3,rad=0.02")
    save_fig(fig, out_svg)


def generate_use_case_diagram():
    fig, ax = _setup_axes(figsize=(12, 7))
    draw_title(fig, "Use Case Diagram")

    # Actors
    draw_ellipse(ax, 1.0, 7.8, 0.9, 0.55, "User")

    # Use cases (grouped)
    use_cases: List[Tuple[str, str, float, float]] = [
        ("UC1", "Register", 3.2, 8.5),
        ("UC2", "Login", 5.8, 8.5),
        ("UC3", "Enable Biometric Login", 8.2, 8.5),

        ("UC4", "Create/Edit/Delete Projects", 3.2, 6.6),
        ("UC5", "Set Budget & Progress", 5.8, 6.6),

        ("UC6", "Daily Material Entry", 3.2, 4.7),
        ("UC7", "Validate Receipt (Optional)", 5.8, 4.7),
        ("UC8", "Scan Receipt via OCR", 8.2, 4.7),

        ("UC9", "View Receipts Gallery", 3.2, 2.8),
        ("UC10", "View Receipt Details", 5.8, 2.8),
        ("UC11", "View Expenses & Filters", 8.2, 2.8),

        ("UC12", "Generate Reports/Analytics", 5.0, 1.0),
        ("UC13", "View Notifications", 2.2, 1.0),
        ("UC14", "Update Profile & Change Password", 8.2, 1.0),
        ("UC15", "Manage Tasks (Due Dates)", 6.6, 0.2),
    ]

    # Draw use case ovals
    for uc_id, label, x, y in use_cases:
        draw_ellipse(ax, x, y, 1.2, 0.42, f"{uc_id}\n{label}", fontsize=9, fc="#FFFFFF")

    # Actor associations arrows (edge-to-edge ellipse intersections).
    actor_cx, actor_cy, actor_rx, actor_ry = 1.0, 7.8, 0.9, 0.55
    for _, __, x, y in use_cases:
        uc_rx, uc_ry = 1.2, 0.42
        start = ellipse_edge_point(actor_cx, actor_cy, actor_rx, actor_ry, x, y)
        end = ellipse_edge_point(x, y, uc_rx, uc_ry, actor_cx, actor_cy)
        draw_arrow(ax, start[0], start[1], end[0], end[1], color="#6B7280", lw=0.9, mutation=10, zorder=1, connectionstyle="arc3,rad=0.05")

    # Group boxes for readability
    draw_box(ax, 0.2, 6.0, 9.7, 2.0, "Authentication & Account", fontsize=11, fc="#F3F4F6", rounding=0.05)
    draw_box(ax, 0.2, 4.2, 9.7, 1.7, "Projects & Expenses", fontsize=11, fc="#F3F4F6", rounding=0.05)
    draw_box(ax, 0.2, 2.0, 9.7, 2.0, "Receipts, Reports & Notifications", fontsize=11, fc="#F3F4F6", rounding=0.05)

    out_png = OUT_DIR / "figure_4_5_use_case_diagram.png"
    out_svg = OUT_DIR / "figure_4_5_use_case_diagram.svg"
    save_fig(fig, out_png)
    fig, ax = _setup_axes(figsize=(12, 7))
    draw_title(fig, "Use Case Diagram")
    draw_ellipse(ax, 1.0, 7.8, 0.9, 0.55, "User")
    for uc_id, label, x, y in use_cases:
        draw_ellipse(ax, x, y, 1.2, 0.42, f"{uc_id}\n{label}", fontsize=9, fc="#FFFFFF")
    actor_cx, actor_cy, actor_rx, actor_ry = 1.0, 7.8, 0.9, 0.55
    for _, __, x, y in use_cases:
        uc_rx, uc_ry = 1.2, 0.42
        start = ellipse_edge_point(actor_cx, actor_cy, actor_rx, actor_ry, x, y)
        end = ellipse_edge_point(x, y, uc_rx, uc_ry, actor_cx, actor_cy)
        draw_arrow(ax, start[0], start[1], end[0], end[1], color="#6B7280", lw=0.9, mutation=10, zorder=1, connectionstyle="arc3,rad=0.05")
    draw_box(ax, 0.2, 6.0, 9.7, 2.0, "Authentication & Account", fontsize=11, fc="#F3F4F6", rounding=0.05)
    draw_box(ax, 0.2, 4.2, 9.7, 1.7, "Projects & Expenses", fontsize=11, fc="#F3F4F6", rounding=0.05)
    draw_box(ax, 0.2, 2.0, 9.7, 2.0, "Receipts, Reports & Notifications", fontsize=11, fc="#F3F4F6", rounding=0.05)
    save_fig(fig, out_svg)


def main():
    if not DB_SCHEMA_PATH.exists():
        raise FileNotFoundError(f"Drift schema file not found: {DB_SCHEMA_PATH}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Generate diagrams
    generate_gantt()
    generate_incremental_development_model()
    generate_system_modules_architecture()
    generate_context_diagram_existing()
    generate_dfd_level0_existing(proposed=False)
    generate_dfd_level0_existing(proposed=True)

    tables = parse_drift_schema(DB_SCHEMA_PATH)
    generate_erd(tables)
    generate_use_case_diagram()

    print(f"Diagrams generated into: {OUT_DIR}")


if __name__ == "__main__":
    main()

