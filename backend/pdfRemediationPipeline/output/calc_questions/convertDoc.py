import json
import re
from reportlab.pdfgen import canvas

def strip_html_tags(text):
    """Removes HTML tags so the PDF gets clean text instead of code."""
    if not text:
        return ""
    clean = re.compile('<.*?>')
    text = text.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    return re.sub(clean, '', text).strip()

def extract_content(block):
    """Recursively extracts text or HTML from a block."""
    content = ""
    if block.get('html'):
        content += block['html'] + " "
    elif block.get('text'):
        content += block['text'] + " "
        
    if block.get('children'):
        for child in block['children']:
            content += extract_content(child) + " "
            
    return content.strip()

# 1. Load BOTH Marker JSON files
with open('calc_questions.json', 'r') as f:
    data = json.load(f)

with open('calc_questions_meta.json', 'r') as f:
    meta_data = json.load(f)

# 2. Build a lookup dictionary for missing titles from the meta file
toc_mapping = {}
for entry in meta_data.get('table_of_contents', []):
    pid = entry.get('page_id')
    if pid not in toc_mapping:
        toc_mapping[pid] = []
    toc_mapping[pid].append(entry)

def get_meta_title(page_id, block):
    """Attempts to find missing text in the meta file's Table of Contents."""
    if page_id in toc_mapping:
        block_y1 = block.get('bbox', [0,0,0,0])[1]
        
        for entry in toc_mapping[page_id]:
            # The polygon in meta is a list of points: [[x1,y1], [x2,y1], ...]
            # We compare the top 'y' coordinate to see if they roughly match
            toc_y1 = entry.get('polygon', [[0,0]])[0][1]
            
            # If they are within ~20 pixels of each other vertically, it's a match!
            if abs(block_y1 - toc_y1) < 20:
                return entry.get('title', '')
    return ""

page_width, page_height = 612, 792

# --- SETUP HTML ---
html_lines = [
    "<!DOCTYPE html>",
    "<html lang='en'>",
    "<head>",
    "<meta charset='UTF-8'>",
    "<title>Accessible Document</title>",
    "<script>",
    "  MathJax = {",
    "    tex: { inlineMath: [['$', '$'], ['\\\\(', '\\\\)']], displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']] },",
    "    mml: { forceDraw: true }", 
    "  };",
    "</script>",
    "<script id='MathJax-script' async src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js'></script>",
    "<style>",
    f"  .page {{ position: relative; width: {page_width}px; height: {page_height}px; border: 1px solid #ccc; margin: 20px auto; background: white; }}",
    "  .block { position: absolute; margin: 0; font-family: sans-serif; font-size: 12px; }",
    "  h1.block { font-size: 20px; font-weight: bold; text-align: center; }",
    "  h2.block { font-size: 16px; font-weight: bold; }",
    "  .header.block, .footer.block { font-size: 10px; color: gray; }",
    "</style>",
    "</head>",
    "<body>"
]

# --- SETUP PDF ---
pdf_path = "reconstructed_layout.pdf"
c = canvas.Canvas(pdf_path, pagesize=(page_width, page_height))

# 3. Process Page by Page to keep track of page IDs
pages = data.get('children', [])
for page_index, page in enumerate(pages):
    html_lines.append("  <div class='page'>")
    
    # Sort blocks on this specific page
    page_blocks = page.get('children', [])
    sorted_blocks = sorted(
        page_blocks, 
        key=lambda b: (b.get('bbox', [0,0])[1], b.get('bbox', [0,0])[0])
    )

    for block in sorted_blocks:
        bbox = block.get('bbox', [0, 0, 100, 100]) 
        x1, y1, x2, y2 = bbox
        block_type = block.get('block_type', 'Text')
        
        # Extract content normally
        raw_content = extract_content(block)
        
        # FIX: If the block is a Header/Title and is empty, pull from meta file!
        if not raw_content.strip() and block_type in ["SectionHeader", "Title"]:
            raw_content = get_meta_title(page_index, block)
            
        clean_pdf_text = strip_html_tags(raw_content)
        
        # If it's STILL empty after checking the meta file, skip it
        if not clean_pdf_text.strip():
            continue
            
        # --- HTML GENERATION ---
        if block_type == "Title":
            tag = "h1"
        elif block_type == "SectionHeader":
            tag = "h2"
        elif block_type in ["PageHeader", "PageFooter"]:
            tag = "div"
            html_lines.append(f"    <{tag} class='block header' style='left: {x1}px; top: {y1}px; width: {x2-x1}px;'>{raw_content}</{tag}>")
            continue 
        else:
            tag = "div" 
            
        html_lines.append(f"    <{tag} class='block' style='left: {x1}px; top: {y1}px; width: {x2-x1}px;'>{raw_content}</{tag}>")
        
        # --- PDF GENERATION ---
        pdf_y = page_height - y1 - 10 
        
        if block_type in ["Title", "SectionHeader"]:
            c.setFont("Helvetica-Bold", 14 if block_type == "SectionHeader" else 18)
        elif block_type in ["PageHeader", "PageFooter"]:
            c.setFont("Helvetica-Oblique", 8)
        else:
            c.setFont("Helvetica", 10)
            
        c.drawString(x1, pdf_y, clean_pdf_text[:120] + ("..." if len(clean_pdf_text) > 120 else ""))
        
    # Move to the next page in the PDF, and close the page div in HTML
    c.showPage()
    html_lines.append("  </div>")

# --- FINALIZE FILES ---
html_lines.append("</body>")
html_lines.append("</html>")

with open("reconstructed_layout.html", "w", encoding="utf-8") as f:
    f.write("\n".join(html_lines))

c.save()

print("Successfully generated files.")