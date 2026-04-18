import json
from PIL import Image, ImageDraw

# 1. Load your Marker JSON
with open('calc_questions.json', 'r') as f:
    data = json.load(f)

# 2. Create a blank "page" (using the page bbox from the JSON)
# Page 0 is 612x792
page_width, page_height = 612, 792
img = Image.new('RGB', (page_width, page_height), 'white')
draw = ImageDraw.Draw(img)

# 3. Loop through every block in the first page
for block in data['children'][0]['children']:
    bbox = block['bbox'] # e.g., [24.75, 39.0, 293.25, 69.0]
    
    # Draw a rectangle where the content belongs
    draw.rectangle([bbox[0], bbox[1], bbox[2], bbox[3]], outline="blue")
    
    # Optional: Write the block type or a snippet of the text inside the box
    draw.text((bbox[0] + 2, bbox[1] + 2), block['block_type'], fill="black")

img.save("reconstructed_layout.png")
print("Image saved to reconstructed_layout.png. Download it to view.")
