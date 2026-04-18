import json
import re
from reportlab.pdfgen import canvas

def strip_html_tags(text):
    """Removes HTML tags so the PDF gets clean text instead of code."""
    clean = re.compile('<.*?>')
    return re.sub(clean, '', text)

def extract_text_from_block(block):
    """Recursively searches a Marker block for text or HTML content."""
    if 'html' in block and block.get('html'):
        return block['html']
        
    text_content = ""
    if 'text' in block and block.get('text'):
        text_content += block['text'] + " "
        
    if 'children' in block and block['children']:
        for child in block['children']:
            text_content += extract_text_from_block(child) + " "
            
    return text_content.strip()

# 1. Load your Marker JSON
with open('calc_questions.json', 'r') as f:
    data = json.load(f)

page_width, page_height = 612, 792

# 2. Sort the blocks for screen reader order
sorted_blocks = sorted(
    data['children'][0]['children'], 
    key=lambda b: (b['bbox'][1], b['bbox'][0])
)

# --- SETUP HTML ---
html_lines = [
    "<!DOCTYPE html>",
    "<html lang='en'>",
    "<head>",
    "<meta charset='UTF-8'>",
    "<title>Accessible Document</title>",
    # Configure MathJax to recognize standard LaTeX delimiters including single $ for inline math
    "<script>",
    "  MathJax = {",
    "    tex: {",
    "      inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],",
    "      displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']]",
    "    }",
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
    "<body>",
    "  <div class='page'>"
]

# --- SETUP PDF ---
pdf_path = "reconstructed_layout.pdf"
c = canvas.Canvas(pdf_path, pagesize=(page_width, page_height))

# 3. Loop through every sorted block
for block in sorted_blocks:
    bbox = block['bbox'] 
    x1, y1, x2, y2 = bbox
    block_type = block.get('block_type', '')
    
    raw_content = extract_text_from_block(block)
    
    if not raw_content:
        raw_content = f"[{block_type}]"
        
    # FORCE EQUATION RENDERING: 
    # If Marker didn't wrap the LaTeX, we wrap it in $$ so MathJax catches it.
    if block_type == "Equation" and not raw_content.startswith(("$", "\\")):
        raw_content = f"$${raw_content}$$"
    
    # --- HTML GENERATION (Expanded block mapping) ---
    if block_type == "Title":
        tag = "h1"
    elif block_type == "SectionHeader":
        tag = "h2"
    elif block_type in ["PageHeader", "PageFooter"]:
        tag = "div" # Use a standard div but class it for styling
        html_lines.append(f"    <{tag} class='block header' style='left: {x1}px; top: {y1}px; width: {x2-x1}px;'>{raw_content}</{tag}>")
        continue # Skip the default append below
    else:
        tag = "p"
        
    html_lines.append(f"    <{tag} class='block' style='left: {x1}px; top: {y1}px; width: {x2-x1}px;'>{raw_content}</{tag}>")
    
    # --- PDF GENERATION ---
    pdf_y = page_height - y1 - 10 
    
    if block_type in ["Title", "SectionHeader"]:
        c.setFont("Helvetica-Bold", 14 if block_type == "SectionHeader" else 18)
    elif block_type in ["PageHeader", "PageFooter"]:
        c.setFont("Helvetica-Oblique", 8)
    else:
        c.setFont("Helvetica", 10)
        
    clean_pdf_text = strip_html_tags(raw_content)
    c.drawString(x1, pdf_y, clean_pdf_text[:100] + ("..." if len(clean_pdf_text) > 100 else ""))

# --- FINALIZE HTML ---
html_lines.append("  </div>")
html_lines.append("</body>")
html_lines.append("</html>")

with open("reconstructed_layout.html", "w", encoding="utf-8") as f:
    f.write("\n".join(html_lines))

# --- FINALIZE PDF ---
c.save()

print("Successfully generated 'reconstructed_layout.html' and 'reconstructed_layout.pdf'.")