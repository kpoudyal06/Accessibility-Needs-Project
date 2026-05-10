import json
import os
import glob
import argparse
import re
import html as html_lib
import io
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, Frame
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.utils import ImageReader

# Attempt to load matplotlib for math rendering
try:
    import matplotlib
    matplotlib.use('Agg') # Use non-interactive backend
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Warning: matplotlib not found. Install it with 'pip install matplotlib' for visual math.")

# --- ARGUMENT PARSING ---
parser = argparse.ArgumentParser(description="Convert Marker JSON to Accessible HTML/PDF.")
parser.add_argument("--input", required=True, help="Directory containing Marker JSON output")
parser.add_argument("--output", required=True, help="Directory to save final results")
args = parser.parse_args()

os.makedirs(args.output, exist_ok=True)

# Styles Setup
styles = getSampleStyleSheet()
normal_style = styles['Normal']
normal_style.fontSize = 9
normal_style.leading = 11

def get_all_blocks(data):
    """Recursively finds all blocks with a bbox to ensure 100% capture rate."""
    blocks = []
    if isinstance(data, dict):
        if 'bbox' in data:
            blocks.append(data)
        if 'children' in data and data['children']:
            blocks.extend(get_all_blocks(data['children']))
    elif isinstance(data, list):
        for item in data:
            blocks.extend(get_all_blocks(item))
    return blocks

def clean_for_pdf_text(raw_html):
    """Cleans HTML tags for ReportLab Paragraphs."""
    if not raw_html: return ""
    # Convert math tags to text placeholders for the 'Normal' text layer
    text = re.sub(r'<math[^>]*>', '', raw_html)
    text = re.sub(r'</math>', '', text)
    text = re.sub(r'<[^>]+>', '', text)
    text = html_lib.unescape(text)
    return html_lib.escape(text).strip()

def extract_latex(raw_html):
    """Converts Marker HTML tags into LaTeX strings for rendering."""
    # Replace <math> tags with $ for matplotlib/MathJax
    text = re.sub(r'<math[^>]*>', '$', raw_html)
    text = re.sub(r'</math>', '$', text)
    text = re.sub(r'<[^>]+>', '', text)
    return html_lib.unescape(text).strip()

# Process JSON files
json_files = glob.glob(os.path.join(args.input, "**", "*.json"), recursive=True)

for json_path in json_files:
    if "meta.json" in json_path.lower() or "status.json" in json_path.lower():
        continue
        
    base_name = os.path.splitext(os.path.basename(json_path))[0]
    print(f"Processing: {json_path}")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    page_width, page_height = 612, 792

    # --- HTML HEADER ---
    html_lines = [
        "<!DOCTYPE html><html><head>",
        "<script>window.MathJax = { tex: { inlineMath: [['$', '$']] }, chtml: { scale: 0.9 } };</script>",
        "<script id='MathJax-script' async src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js'></script>",
        "<style>",
        f"  .page {{ position: relative; width: {page_width}px; height: {page_height}px; border: 1px solid #000; margin: 20px auto; }}",
        "  .box { position: absolute; border: 1px solid rgba(255,0,0,0.2); overflow: visible; display: flex; align-items: center; font-size: 12px; }",
        "  mjx-container { margin: 0 !important; }",
        "</style></head><body>"
    ]

    # --- PDF SETUP ---
    pdf_path = os.path.join(args.output, f"{base_name}_remediated.pdf")
    c = canvas.Canvas(pdf_path, pagesize=(page_width, page_height))

    for page in data.get('children', []):
        html_lines.append("<div class='page'>")
        blocks = get_all_blocks(page)
        
        for block in blocks:
            bbox = block.get('bbox')
            if not bbox: continue
            
            x1, y1, x2, y2 = bbox
            bw, bh = x2 - x1, y2 - y1
            raw_html = block.get('html', '')
            btype = block.get('block_type', '')

            # 1. HTML Output (with clipping fix)
            math_ready_html = extract_latex(raw_html)
            html_lines.append(f"<div class='box' style='left:{x1}px; top:{y1}px; width:{bw}px; height:{bh}px;'>{math_ready_html}</div>")

            # 2. PDF Output
            pdf_y = page_height - y2
            
            if btype == "Equation" and HAS_MATPLOTLIB:
                # Render Visual Math
                try:
                    plt.figure(figsize=(bw/72, bh/72))
                    plt.axis('off')
                    # Center the LaTeX string in the box
                    plt.text(0.5, 0.5, math_ready_html, size=max(7, bh*0.6), ha='center', va='center', transform=plt.gcf().transFigure)
                    
                    img_buf = io.BytesIO()
                    plt.savefig(img_buf, format='png', transparent=True, dpi=200)
                    plt.close()
                    img_buf.seek(0)
                    c.drawImage(ImageReader(img_buf), x1, pdf_y, width=bw, height=bh, mask='auto')
                except:
                    plt.close() # Fallback to text if math rendering fails
                
                # Accessibility: Invisible Text layer for screen readers/searching
                c.setFillAlpha(0) 
                c.setFont("Helvetica", 1)
                c.drawString(x1, pdf_y + (bh/2), math_ready_html)
                c.setFillAlpha(1)
            else:
                # Regular Text rendering
                clean_text = clean_for_pdf_text(raw_html)
                if clean_text:
                    frame = Frame(x1, pdf_y, bw, bh, leftPadding=1, bottomPadding=1, rightPadding=1, topPadding=1)
                    p = Paragraph(clean_text, normal_style)
                    frame.addFromList([p], c)

        html_lines.append("</div>")
        c.showPage()

    c.save()
    html_lines.append("</body></html>")
    with open(os.path.join(args.output, f"{base_name}.html"), 'w', encoding='utf-8') as f:
        f.write("\n".join(html_lines))

print(f"Finished processing {len(json_files)} files.")