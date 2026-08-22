#!/usr/bin/env python3
"""Remove the 'EA <version> Unregistered Trial Version' watermark tiled by
Sparx Enterprise Architect over exported PDF diagrams.

The watermark is real text drawn on the page (not an image), tiled in full
width rows using a fixed light-gray fill color. It is removed by editing the
PDF content stream directly (via PyMuPDF redactions) rather than painting
over it, so it can't bleed through and the underlying diagram (shapes, real
labels) is left untouched:

  - Each watermark text row is located by matching the phrase, then split on
    the x-axis around any real (non-watermark) text span that overlaps it
    vertically, so redaction never touches real labels sitting inside the
    same row band.
  - Redaction annotations use fill=None (no covering box painted on top) and
    graphics=PDF_REDACT_LINE_ART_NONE, so vector graphics (borders, icons)
    under a redacted row are preserved instead of being erased or covered.

Usage:
    python remove-ea-watermark.py <input.pdf> [output.pdf]

If output.pdf is omitted, the input file is overwritten in place.

Requires: pip install pymupdf
"""

import sys

import pymupdf as fitz

WATERMARK_MARKER = "Unregistered Trial"


def strip_watermark(src_path: str, dst_path: str) -> int:
    doc = fitz.open(src_path)
    total_segments = 0

    for page in doc:
        d = page.get_text("dict")

        wm_rects = []
        other_rects = []
        for block in d["blocks"]:
            for line in block.get("lines", []):
                for span in line.get("spans", []):
                    rect = fitz.Rect(span["bbox"])
                    if WATERMARK_MARKER in span["text"]:
                        wm_rects.append(rect)
                    else:
                        other_rects.append(rect)

        if not wm_rects:
            continue

        pad = 0.5
        for wr in wm_rects:
            blockers = sorted(
                (o for o in other_rects if wr.y0 < o.y1 and wr.y1 > o.y0),
                key=lambda o: o.x0,
            )
            x = wr.x0
            for o in blockers:
                bx0 = max(wr.x0, o.x0 - pad)
                bx1 = min(wr.x1, o.x1 + pad)
                if bx0 > x:
                    page.add_redact_annot(fitz.Rect(x, wr.y0, bx0, wr.y1), fill=None)
                    total_segments += 1
                x = max(x, bx1)
            if x < wr.x1:
                page.add_redact_annot(fitz.Rect(x, wr.y0, wr.x1, wr.y1), fill=None)
                total_segments += 1

        page.apply_redactions(
            images=fitz.PDF_REDACT_IMAGE_NONE,
            graphics=fitz.PDF_REDACT_LINE_ART_NONE,
            text=fitz.PDF_REDACT_TEXT_REMOVE,
        )

    if dst_path == src_path:
        tmp_path = dst_path + ".tmp"
        doc.save(tmp_path)
        doc.close()
        import os

        os.replace(tmp_path, dst_path)
    else:
        doc.save(dst_path)
        doc.close()

    return total_segments


def main() -> None:
    if len(sys.argv) not in (2, 3):
        print(f"Usage: {sys.argv[0]} <input.pdf> [output.pdf]", file=sys.stderr)
        sys.exit(1)

    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) == 3 else src

    n = strip_watermark(src, dst)
    print(f"Redacted {n} watermark segment(s). Saved to: {dst}")


if __name__ == "__main__":
    main()
