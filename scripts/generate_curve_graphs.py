#!/usr/bin/env python3
import json
import os

def load_curve_data(data_path):
    """Load curve data from JSON file"""
    with open(data_path, 'r') as f:
        return json.load(f)

def generate_mermaid_graph(data, title):
    """Generate a mermaid line graph from curve data"""
    points = data['points']
    
    # Extract x and y values and scale them, formatting as regular decimals
    x_values = [f"{int(p['assets']) / 1e18:.18f}" for p in points]
    y_values = [f"{int(p['shares']) / 1e18:.18f}" for p in points]
    
    # Start the mermaid graph
    mermaid = [
        '```mermaid',
        'xychart-beta',
        f'    title "{title}"',
        f'    x-axis "Assets (ETH)" [{", ".join(x_values)}]',
        f'    y-axis "Shares"',
        f'    line [{", ".join(y_values)}]',
        '```\n'
    ]
    
    return '\n'.join(mermaid)

def insert_graph_into_doc(doc_path, data_path):
    """Insert the mermaid graph into the markdown documentation"""
    print(f"Processing {doc_path}")
    
    # Read the current markdown
    with open(doc_path, 'r') as f:
        content = f.read()
    
    # Load curve data
    data = load_curve_data(data_path)
    
    # Generate graph with initialization
    # We don't know why, but the graph doesn't style correctly without rendering this text directly
    # Wrapping it in HTML to change the color or hide it makes it stop applying the styles
    init_directive = '\n```mermaid\n%%{init: {"xychart": {"showTitle": true}} }%%\n```\n\n'
    graph = generate_mermaid_graph(data, f'{data["name"].title()} Curve')
    
    # Find the end of the contract description (first empty line after the description)
    lines = content.split('\n')
    insert_pos = 0
    for i, line in enumerate(lines):
        if line.startswith('*'):  # Skip past the contract metadata
            continue
        if not line.strip():  # First empty line after metadata
            insert_pos = i
            break
    
    # Insert the initialization and graph after the description
    lines.insert(insert_pos + 1, "\n## Curve Visualization\n")
    lines.insert(insert_pos + 2, init_directive)
    lines.insert(insert_pos + 3, graph)
    
    # Write the updated content
    with open(doc_path, 'w') as f:
        f.write('\n'.join(lines))

def main():
    # Generate forge script data
    os.system('forge script script/GenerateCurveData.s.sol --ffi')
    
    # Load the metadata file
    try:
        with open('out/curve_metadata.json', 'r') as f:
            metadata = json.load(f)
    except FileNotFoundError:
        print("Metadata file not found. Did the forge script run successfully?")
        return
    except json.JSONDecodeError:
        print("Invalid metadata file. Did the forge script complete successfully?")
        return
    
    # Process each curve
    for file_info in metadata['files']:
        # Convert HTML path to markdown path
        md_path = file_info['doc'].replace('/book/src/', '/src/src/').replace('.html', '.md')
        if os.path.exists(md_path):
            insert_graph_into_doc(md_path, file_info['data'])
        else:
            print(f"Markdown file not found: {md_path}")

if __name__ == '__main__':
    main() 