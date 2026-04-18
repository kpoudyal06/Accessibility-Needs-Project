import json
from reportlab.pdfgen import canvas

# 1. Load your Marker JSON
with open('calc_questions.json', 'r') as f:
    data = json.load(f)

# Page 0 is 612x792
page_width, page_height = 612, 792

# 2. Sort the blocks for screen reader order (Top to Bottom, then Left to Right)
# This is the crucial step for accessibility!
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
    "<style>",
    f"  .page {{ position: relative; width: {page_width}px; height: {page_height}px; border: 1px solid #ccc; margin: 20px auto; background: white; }}",
    "  .block { position: absolute; margin: 0; font-family: sans-serif; font-size: 12px; }",
    "  h2.block { font-size: 16px; font-weight: bold; }",
    "</style>",
    "</head>",
    "<body>",
    "  <div class='page'>"
]

# --- SETUP PDF ---
pdf_path = "reconstructed_layout.pdf"
c = canvas.Canvas(pdf_path, pagesize=(page_width, page_height))

# 3. Loop through every sorted block and build both formats
for block in sorted_blocks:
    bbox = block['bbox'] # e.g., [24.75, 39.0, 293.25, 69.0]
    x1, y1, x2, y2 = bbox
    
    # Extract actual text if it exists in your JSON, otherwise use the block type as a placeholder
    content = block.get('text', f"[{block['block_type']}]") 
    
    # --- HTML GENERATION ---
    # Semantic tagging based on the type of block
    tag = "h2" if block['block_type'] == "SectionHeader" else "p"
    
    # Use standard top and left CSS for exact positioning
    html_lines.append(f"    <{tag} class='block' style='left: {x1}px; top: {y1}px; width: {x2-x1}px;'>{content}</{tag}>")
    
    # --- PDF GENERATION ---
    # PDF coordinates (0,0) start at the BOTTOM-LEFT. 
    # Your JSON (0,0) is TOP-LEFT. We must invert the Y-axis.
    # We subtract ~10 extra pixels so the text draws inside the box constraints, not floating above it.
    pdf_y = page_height - y1 - 10 
    
    if block['block_type'] == "SectionHeader":
        c.setFont("Helvetica-Bold", 14)
    else:
        c.setFont("Helvetica", 10)
        
    c.drawString(x1, pdf_y, content)

# --- FINALIZE HTML ---
html_lines.append("  </div>")
html_lines.append("</body>")
html_lines.append("</html>")

with open("reconstructed_layout.html", "w", encoding="utf-8") as f:
    f.write("\n".join(html_lines))

# --- FINALIZE PDF ---
c.save()

print("Successfully generated 'reconstructed_layout.html' and 'reconstructed_layout.pdf'.")