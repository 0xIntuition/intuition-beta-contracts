#!/usr/bin/env python3

import os
import re
import json
from typing import Dict, List, Set, Tuple
from collections import defaultdict

class ContractInfo:
    def __init__(self, name: str):
        self.name = name
        self.functions: Dict[str, List[str]] = defaultdict(list)  # category -> functions
        self.state_vars: Dict[str, List[str]] = defaultdict(list)  # category -> vars
        self.inherits_from: Set[str] = set()
        self.uses: Set[str] = set()
        self.is_interface = False
        self.is_abstract = False
        self.source_path = ""

def categorize_function(name: str) -> str:
    """Categorize function based on its name prefix."""
    if name.startswith("preview"):
        return "Preview Functions"
    elif name.startswith("get"):
        return "Getters"
    elif name.startswith("set"):
        return "Setters"
    elif name.startswith("init"):
        return "Initialization"
    elif name.startswith("convert"):
        return "Conversion Functions"
    else:
        return "Core Functions"

def get_doc_link(contract_name: str, source_path: str, member_name: str = "") -> str:
    """Generate documentation link for a contract or member."""
    base_url = "http://localhost:3000/src/"
    
    # Get the full path and type from the source path
    if source_path.startswith('libraries/'):
        type_prefix = "library"
    elif source_path.startswith('interfaces/'):
        type_prefix = "interface"
    else:
        type_prefix = "contract"
    
    # Use the full source path for the link
    if member_name:
        return f"{base_url}{source_path}/{type_prefix}.{contract_name}.html#{member_name.lower()}"
    return f"{base_url}{source_path}/{type_prefix}.{contract_name}.html"

def get_category_from_path(path: str) -> str:
    """Get the category for a contract based on its path."""
    parts = path.split('/')
    
    # Default to Core for files directly in src
    if len(parts) == 1:
        return "Core"
        
    # Use the first subdirectory as the category
    return parts[0].title()

def parse_contract_doc(contract_path: str) -> ContractInfo:
    base = os.path.basename(contract_path).replace(".json", "")
    info = ContractInfo(base)
    
    with open(contract_path, 'r') as f:
        data = json.load(f)
        
        # Parse ABI for functions
        if "abi" in data:
            for item in data["abi"]:
                if item.get("type") == "function":
                    name = item["name"]
                    inputs = [f"{inp.get('name', '')}: {inp['type']}" for inp in item.get("inputs", [])]
                    outputs = [f"{out.get('name', '')}: {out['type']}" for out in item.get("outputs", [])]
                    sig = f"{name}({', '.join(inputs)})"
                    if outputs:
                        sig += f" → {', '.join(outputs)}"
                    category = categorize_function(name)
                    info.functions[category].append((name, sig))

        # Parse storage layout for state variables
        if "storageLayout" in data and "storage" in data["storageLayout"]:
            for item in data["storageLayout"]["storage"]:
                var_type = item["type"]
                var_name = item["label"]
                category = "State Variables"
                info.state_vars[category].append((var_name, f"{var_type} {var_name}"))

        # Check contract type and inheritance
        if "devdoc" in data:
            info.is_interface = data["devdoc"].get("kind") == "interface" or base.startswith('I')
            info.is_abstract = data["devdoc"].get("kind") == "abstract"
            # Parse inheritance from devdoc
            details = data["devdoc"].get("details", "")
            if "Inherits:" in details:
                inherits = details.split("Inherits:")[1].strip()
                info.inherits_from.update(re.findall(r'\b([A-Z]\w+)\b', inherits))

        # Look for the contract in src directory to determine its path
        for root, _, files in os.walk("src"):
            for file in files:
                if file == f"{base}.sol":
                    # Get the relative path from src
                    rel_path = os.path.relpath(os.path.join(root, file), "src")
                    info.source_path = rel_path
                    break
            if info.source_path:
                break
                
        # If not found, default to root
        if not info.source_path:
            info.source_path = f"{base}.sol"

    return info

def generate_contract_diagram(contract: ContractInfo) -> str:
    mermaid = f"""```mermaid
graph TB
    root(("{contract.name}"))
"""
    
    # Track nodes for styling
    state_var_nodes = []
    function_nodes = []
    contract_nodes = []
    
    # Add state variables subgraph if present
    if contract.state_vars:
        mermaid += """
    subgraph StateVars ["📦 State Variables"]
        direction LR
"""
        # Group vars in pairs for better layout
        pairs = []
        current_pair = []
        for var_name, var_sig in sorted(contract.state_vars["State Variables"]):
            node_id = f"var_{var_name}"
            state_var_nodes.append(node_id)
            current_pair.append(f"{node_id}[{var_name}]")
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
        if current_pair:
            pairs.append(current_pair)
            
        for pair in pairs:
            mermaid += f"        {' & '.join(pair)}\n"
        mermaid += "    end\n"
        mermaid += "    root --> StateVars\n"
    
    # Add functions by category
    for category, funcs in sorted(contract.functions.items()):
        if funcs:  # Only add category if it has functions
            safe_category = category.replace(" ", "")
            mermaid += f"""
    subgraph {safe_category} ["{category}"]
        direction LR
"""
            # Group functions in pairs
            pairs = []
            current_pair = []
            for func_name, func_sig in sorted(funcs):
                node_id = f"func_{func_name}"
                function_nodes.append(node_id)
                current_pair.append(f"{node_id}[{func_name}]")
                if len(current_pair) == 2:
                    pairs.append(current_pair)
                    current_pair = []
            if current_pair:
                pairs.append(current_pair)
                
            for pair in pairs:
                mermaid += f"        {' & '.join(pair)}\n"
            mermaid += "    end\n"
            mermaid += f"    root --> {safe_category}\n"
    
    # Add inheritance information if present
    if contract.inherits_from:
        mermaid += """
    subgraph Inheritance ["🔄 Inherits From"]
        direction LR
"""
        # Group inherited contracts in pairs
        pairs = []
        current_pair = []
        for parent in sorted(contract.inherits_from):
            node_id = f"inherits_{parent}"
            contract_nodes.append(node_id)
            current_pair.append(f"{node_id}[{parent}]")
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
        if current_pair:
            pairs.append(current_pair)
            
        for pair in pairs:
            mermaid += f"        {' & '.join(pair)}\n"
        mermaid += "    end\n"
        mermaid += "    root --> Inheritance\n"
    
    # Add usage information if present
    if contract.uses:
        mermaid += """
    subgraph Uses ["🔗 Uses"]
        direction LR
"""
        # Group used contracts in pairs
        pairs = []
        current_pair = []
        for used in sorted(contract.uses):
            node_id = f"uses_{used}"
            contract_nodes.append(node_id)
            current_pair.append(f"{node_id}[{used}]")
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
        if current_pair:
            pairs.append(current_pair)
            
        for pair in pairs:
            mermaid += f"        {' & '.join(pair)}\n"
        mermaid += "    end\n"
        mermaid += "    root --> Uses\n"
    
    # Add styles
    mermaid += """
    %% Style definitions
    classDef default fill:#f4f4f4,stroke:#333,stroke-width:2px,font-size:28px,font-family:Arial,rounded:true;
    classDef root fill:#6366f1,color:#fff,stroke:#4338ca,stroke-width:4px,font-size:32px,font-weight:bold,font-family:Arial,rx:40px;
    classDef stateVar fill:#dbeafe,stroke:#3b82f6,stroke-width:2px,color:#1e40af,font-size:28px,font-family:Arial,rounded:true;
    classDef function fill:#e0e7ff,stroke:#818cf8,stroke-width:2px,color:#4338ca,font-size:28px,font-family:Arial,rounded:true;
    classDef contract fill:#fef3c7,stroke:#f59e0b,stroke-width:2px,color:#b45309,font-size:28px,font-family:Arial,rounded:true;
    classDef category fill:none,stroke:none,color:#333,font-size:28px,font-weight:bold,font-family:Arial;
    
    %% Apply styles
    class root root;
    class StateVars,CoreFunctions,Getters,Setters,PreviewFunctions,ConversionFunctions,Initialization,Uses,Inheritance category;
"""
    
    # Apply styles to nodes
    if state_var_nodes:
        mermaid += f"    class {','.join(state_var_nodes)} stateVar;\n"
    if function_nodes:
        mermaid += f"    class {','.join(function_nodes)} function;\n"
    if contract_nodes:
        mermaid += f"    class {','.join(contract_nodes)} contract;\n"
    
    # Add click actions
    mermaid += "\n    %% Click actions\n"
    
    # Add click for root node to link to contract documentation
    mermaid += f'    click root "{get_doc_link(contract.name, contract.source_path)}" "{contract.name} documentation"\n'
    
    # Add clicks for state variables
    for var_name, _ in contract.state_vars.get("State Variables", []):
        node_id = f"var_{var_name}"
        mermaid += f'    click {node_id} "{get_doc_link(contract.name, contract.source_path, var_name)}" "{var_name} documentation"\n'
    
    # Add clicks for functions
    for category, funcs in contract.functions.items():
        for func_name, _ in funcs:
            node_id = f"func_{func_name}"
            mermaid += f'    click {node_id} "{get_doc_link(contract.name, contract.source_path, func_name)}" "{func_name} documentation"\n'
    
    # Add clicks for contracts
    for parent in contract.inherits_from:
        node_id = f"inherits_{parent}"
        mermaid += f'    click {node_id} "{parent}.html" "{parent} documentation"\n'
    
    for used in contract.uses:
        node_id = f"uses_{used}"
        mermaid += f'    click {node_id} "{used}.html" "{used} documentation"\n'
    
    mermaid += "```"
    return mermaid

def generate_overview_diagram(contracts: Dict[str, ContractInfo]) -> str:
    # Group contracts by their categories
    categorized_contracts: Dict[str, List[Tuple[str, ContractInfo]]] = defaultdict(list)
    
    for name, info in contracts.items():
        category = get_category_from_path(info.source_path)
        categorized_contracts[category].append((name, info))
    
    # Start the diagram
    mermaid = """```mermaid
graph TB
"""
    
    # Add root nodes for each category that has contracts
    for category in categorized_contracts.keys():
        safe_category = category.replace(" ", "")
        mermaid += f'    {safe_category}(("{category}"))\n'
    
    # Add subgraphs for each category
    for category, contract_list in categorized_contracts.items():
        if not contract_list:
            continue
            
        safe_category = category.replace(" ", "")
        mermaid += f"""
    subgraph {safe_category}List ["{category}"]
        direction LR
"""
        # Group contracts in pairs for better layout
        pairs = []
        current_pair = []
        for name, _ in sorted(contract_list):
            current_pair.append(name)
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
        if current_pair:
            pairs.append(current_pair)
            
        for pair in pairs:
            mermaid += f"        {' & '.join(pair)}\n"
        mermaid += "    end\n"
        mermaid += f"    {safe_category} --> {safe_category}List\n"
    
    # Add styles
    mermaid += """
    %% Style definitions
    classDef default fill:#f4f4f4,stroke:#333,stroke-width:2px,font-size:24px,font-family:Arial,rounded:true,color:#000;
    classDef root fill:#6366f1,color:#fff,stroke:#4338ca,stroke-width:4px,font-size:32px,font-weight:bold,font-family:Arial,rx:40px;
    classDef category fill:none,stroke:none,color:#000,font-size:24px,font-weight:bold,font-family:Arial;
    
    %% Apply styles
"""
    # Add root styles
    root_nodes = [cat.replace(" ", "") for cat in categorized_contracts.keys()]
    if root_nodes:
        mermaid += f"    class {','.join(root_nodes)} root;\n"
    
    # Add category styles
    category_nodes = [f"{cat.replace(' ', '')}List" for cat in categorized_contracts.keys()]
    if category_nodes:
        mermaid += f"    class {','.join(category_nodes)} category;\n"
    
    # Add click actions
    mermaid += "\n    %% Click actions\n"
    
    # Add clicks for all contracts
    for category, contract_list in categorized_contracts.items():
        for name, info in contract_list:
            # Core contracts link to architecture diagrams, others link to their documentation
            if category == "Core":
                mermaid += f'    click {name} "{name}.html" "{name} documentation"\n'
            else:
                mermaid += f'    click {name} "{get_doc_link(name, info.source_path)}" "{name} documentation"\n'
    
    mermaid += "```"
    return mermaid

def main():
    # Create architecture directory if it doesn't exist
    os.makedirs("docs/src/architecture", exist_ok=True)
    
    # Parse all contract information
    contracts: Dict[str, ContractInfo] = {}
    for filename in os.listdir("docs/contracts"):
        if filename.endswith(".json"):
            contract_info = parse_contract_doc(f"docs/contracts/{filename}")
            contracts[contract_info.name] = contract_info
    
    # Generate and save overview diagram
    overview = generate_overview_diagram(contracts)
    with open("docs/src/architecture/overview.md", "w") as f:
        f.write("# Contract Architecture\n\n")
        f.write("This document provides an overview of the core contracts and their relationships. Click on any contract to view its detailed documentation.\n\n")
        f.write(overview)
    
    # Generate individual contract pages
    for name, contract in contracts.items():
        diagram = generate_contract_diagram(contract)
        with open(f"docs/src/architecture/{name}.md", "w") as f:
            f.write(f"# {name}\n\n")
            f.write(f"Detailed view of the {name} contract and its members. Click on any member to view its documentation.\n\n")
            f.write(diagram)

if __name__ == "__main__":
    main() 