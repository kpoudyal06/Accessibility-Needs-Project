import json
import re
from reportlab.pdfgen import canvas

def strip_html_tags(text):
    """Removes HTML tags so the PDF gets clean text instead of code."""
    if not text:
        return ""
    clean = re.compile('<.*?>')
    # Unescape common HTML entities that Marker might leave behind
    text = text.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    return re.sub(clean, '', text).strip()

def extract_content(block):
    """
    Recursively extracts text or HTML. 
    We prioritize HTML because Marker stores MathML inside <math> tags.
    """
    content = ""
    
    # Grab HTML if available (preserves <math> tags for MathJax)
    if block.get('html'):
        content += block['html'] + " "
    elif block.get('text'):
        content += block['text'] + " "
        
    if block.get('children'):
        for child in block['children']:
            content += extract_content(child) + " "
            
    return content.strip()

# 1. Load your Marker JSON
# Make sure this points to the correct main JSON file (not the meta file)
with open('calc_questions.json', 'r') as f:
    data = json.load(f)

page_width, page_height = 612, 792

# 2. Extract and sort blocks
# (Updated to ensure we iterate over the page wrapper correctly)
all_blocks = []
pages = data.get('children', [])
for page in pages:
    if page.get('children'):
         all_blocks.extend(page['children'])

sorted_blocks = sorted(
    all_blocks, 
    key=lambda b: (b.get('bbox', [0,0])[1], b.get('bbox', [0,0])[0])
)

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
    "    mml: { forceDraw: true }", # Ensures MathML tags from Marker are drawn
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
    bbox = block.get('bbox', [0, 0, 100, 100]) 
    x1, y1, x2, y2 = bbox
    block_type = block.get('block_type', 'Text')
    
    raw_content = extract_content(block)
    clean_pdf_text = strip_html_tags(raw_content)
    
    # FIX: If the block is completely empty after cleaning, skip it!
    # This stops "[SectionHeader]" from printing.
    if not clean_pdf_text:
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
        tag = "div" # Changed from <p> so we don't accidentally nest HTML paragraphs
        
    html_lines.append(f"    <{tag} class='block' style='left: {x1}px; top: {y1}px; width: {x2-x1}px;'>{raw_content}</{tag}>")
    
    # --- PDF GENERATION ---
    pdf_y = page_height - y1 - 10 
    
    if block_type in ["Title", "SectionHeader"]:
        c.setFont("Helvetica-Bold", 14 if block_type == "SectionHeader" else 18)
    elif block_type in ["PageHeader", "PageFooter"]:
        c.setFont("Helvetica-Oblique", 8)
    else:
        c.setFont("Helvetica", 10)
        
    # Remember: This PDF will ONLY show the raw LaTeX code. 
    # For a PDF with beautifully rendered equations, open the HTML file and print to PDF.
    c.drawString(x1, pdf_y, clean_pdf_text[:120] + ("..." if len(clean_pdf_text) > 120 else ""))

# --- FINALIZE HTML ---
html_lines.append("  </div>")
html_lines.append("</body>")
html_lines.append("</html>")

with open("reconstructed_layout.html", "w", encoding="utf-8") as f:
    f.write("\n".join(html_lines))

# --- FINALIZE PDF ---
c.save()

print("Successfully generated 'reconstructed_layout.html' and 'reconstructed_layout.pdf'.")
print("Note: The generated PDF contains raw equation code. Open the HTML file in your browser to see rendered math!")