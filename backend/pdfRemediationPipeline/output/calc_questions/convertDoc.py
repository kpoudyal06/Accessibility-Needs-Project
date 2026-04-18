import json
import re
from reportlab.pdfgen import canvas

def strip_html_tags(text):
    """Removes HTML tags so the PDF gets clean text instead of code."""
    if not text:
        return ""
    clean = re.compile('<.*?>')
    # Unescape basic HTML entities before rendering to PDF
    text = text.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    return re.sub(clean, '', text).strip()

def extract_content(block, is_math=False):
    """Recursively extracts content. Ignores HTML wrappers if the block is an equation."""
    content = ""
    
    # If it's math, we ONLY want the raw LaTeX text, not Marker's HTML tags
    if not is_math and block.get('html'):
        return block['html']
        
    if block.get('text'):
        content += block['text'] + " "
        
    if block.get('children'):
        for child in block['children']:
            content += extract_content(child, is_math) + " "
            
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
            toc_y1 = entry.get('polygon', [[0,0]])[0][1]
            if abs(block_y1 - toc_y1) < 30:
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
    "    svg: { fontCache: 'global' }", 
    "  };",
    "</script>",
    "<script id='MathJax-script' async src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js'></script>",
    "<style>",
    f"  .page {{ position: relative; width: {page_width}px; height: {page_height}px; border: 1px solid #ccc; margin: 20px auto; background: white; }}",
    "  .block { position: absolute; margin: 0; font-family: sans-serif; font-size: 12px; }",
    "  h1.block { font-size: 16px; font-weight: bold; white-space: nowrap; }",
    "  h2.block { font-size: 14px; font-weight: bold; white-space: nowrap; }",
    "  .header.block, .footer.block { font-size: 10px; color: gray; }",
    "</style>",
    "</head>",
    "<body>"
]

# --- SETUP PDF ---
pdf_path = "reconstructed_layout.pdf"
c = canvas.Canvas(pdf_path, pagesize=(page_width, page_height))

pages = data.get('children', [])
for page_index, page in enumerate(pages):
    html_lines.append("  <div class='page'>")
    
    page_blocks = page.get('children', [])
    sorted_blocks = sorted(
        page_blocks, 
        key=lambda b: (b.get('bbox', [0,0])[1], b.get('bbox', [0,0])[0])
    )

    for block in sorted_blocks:
        bbox = block.get('bbox', [0, 0, 100, 100]) 
        x1, y1, x2, y2 = bbox
        block_type = block.get('block_type', 'Text')
        
        is_equation = (block_type == "Equation")
        raw_content = extract_content(block, is_math=is_equation)
        
        if not raw_content.strip() and block_type in ["SectionHeader", "Title"]:
            raw_content = get_meta_title(page_index, block)
            
        if not raw_content.strip():
            continue
            
        # THE FIX: Aggressively clean Marker's raw LaTeX and safely wrap it
        if is_equation:
            # 1. Remove all possible existing delimiters so they don't nest 
            clean_math = raw_content.replace('\\$', '').replace('$', '')
            clean_math = clean_math.replace('\\[', '').replace('\\]', '')
            clean_math = clean_math.replace('\\(', '').replace('\\)', '')
            
            # 2. Escape angle brackets so the HTML parser doesn't swallow them
            clean_math = clean_math.replace('<', '&lt;').replace('>', '&gt;')
            
            # 3. Cleanly wrap
            raw_content = f"$${clean_math.strip()}$$"
            
        clean_pdf_text = strip_html_tags(raw_content)
        
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
            
        if tag in ["h1", "h2"]:
            html_lines.append(f"    <{tag} class='block' style='left: {x1}px; top: {y1}px;'>{raw_content}</{tag}>")
        else:
            html_lines.append(f"    <{tag} class='block' style='left: {x1}px; top: {y1}px; width: {x2-x1}px;'>{raw_content}</{tag}>")
        
        # --- PDF GENERATION ---
        pdf_y = page_height - y1 - 10 
        
        if block_type == "Title":
            c.setFont("Helvetica-Bold", 14)
        elif block_type == "SectionHeader":
            c.setFont("Helvetica-Bold", 12)
        elif block_type in ["PageHeader", "PageFooter"]:
            c.setFont("Helvetica-Oblique", 8)
        else:
            c.setFont("Helvetica", 10)
            
        c.drawString(x1, pdf_y, clean_pdf_text[:120] + ("..." if len(clean_pdf_text) > 120 else ""))
        
    c.showPage()
    html_lines.append("  </div>")

# --- FINALIZE FILES ---
html_lines.append("</body>")
html_lines.append("</html>")

with open("reconstructed_layout.html", "w", encoding="utf-8") as f:
    f.write("\n".join(html_lines))

c.save()

print("Successfully generated clean HTML and PDF layouts.")