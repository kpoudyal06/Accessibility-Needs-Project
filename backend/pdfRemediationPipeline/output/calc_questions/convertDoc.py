import json
from reportlab.pdfgen import canvas

# 1. Load ONLY the main JSON layout file
with open('calc_questions.json', 'r') as f:
    data = json.load(f)

page_width, page_height = 612, 792

# --- SETUP HTML ---
html_lines = [
    "<!DOCTYPE html>",
    "<html>",
    "<head>",
    "<title>Layout Bounding Boxes</title>",
    "<style>",
    f"  .page {{ position: relative; width: {page_width}px; height: {page_height}px; border: 2px solid black; margin: 20px auto; background: #f9f9f9; }}",
    "  .box { position: absolute; border: 1px solid red; background-color: rgba(255, 0, 0, 0.1); }",
    "</style>",
    "</head>",
    "<body>"
]

# --- SETUP PDF ---
pdf_path = "layout_boxes.pdf"
c = canvas.Canvas(pdf_path, pagesize=(page_width, page_height))
c.setStrokeColorRGB(1, 0, 0) # Red borders
c.setFillColorRGB(1, 0, 0, 0.1) # Light red fill with 10% opacity

# 2. Loop through all pages and blocks to draw boxes
pages = data.get('children', [])
for page in pages:
    html_lines.append("  <div class='page'>")
    
    blocks = page.get('children', [])
    for block in blocks:
        # Marker bboxes are [left, top, right, bottom]
        bbox = block.get('bbox')
        if not bbox:
            continue
            
        x1, y1, x2, y2 = bbox
        box_width = x2 - x1
        box_height = y2 - y1
        
        # --- HTML BOX ---
        # HTML coordinates start from the Top-Left
        html_lines.append(f"    <div class='box' style='left: {x1}px; top: {y1}px; width: {box_width}px; height: {box_height}px;'></div>")
        
        # --- PDF BOX ---
        # PDF coordinates start from the Bottom-Left
        # To find the bottom-left y-coordinate of the box, we subtract the BOTTOM edge (y2) from the total height
        pdf_y = page_height - y2 
        
        # c.rect(x, y, width, height, stroke=1, fill=1)
        c.rect(x1, pdf_y, box_width, box_height, fill=1)

    # Move to the next page
    html_lines.append("  </div>")
    c.showPage()

# --- FINALIZE HTML ---
html_lines.append("</body>")
html_lines.append("</html>")

with open("layout_boxes.html", "w", encoding="utf-8") as f:
    f.write("\n".join(html_lines))

# --- FINALIZE PDF ---
c.save()

print("Successfully generated 'layout_boxes.html' and 'layout_boxes.pdf'.")