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
    
    # Determine the correct path and type prefix based on the source path
    if contract_name.startswith('I') and not contract_name == 'Intuition':
        path = f"interfaces/{contract_name}.sol"
        type_prefix = "interface"
    elif source_path.endswith('Library.sol'):
        path = f"libraries/{contract_name}.sol"
        type_prefix = "library"
    elif source_path.startswith('utils/'):
        path = f"utils/{contract_name}.sol"
        type_prefix = "contract"
    else:
        path = f"{contract_name}.sol"
        type_prefix = "contract"
    
    if member_name:
        return f"{base_url}{path}/{type_prefix}.{contract_name}.html#{member_name.lower()}"
    return f"{base_url}{path}/{type_prefix}.{contract_name}.html"

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

        # Determine source path
        if info.is_interface:
            info.source_path = f"interfaces/{base}.sol"
        elif base.endswith("Library"):
            info.source_path = f"libraries/{base}.sol"
        elif "utils" in contract_path:
            info.source_path = f"utils/{base}.sol"
        else:
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
    classDef default fill:#f4f4f4,stroke:#333,stroke-width:2px,font-size:14px,font-family:Arial,rounded:true;
    classDef root fill:#6366f1,color:#fff,stroke:#4338ca,stroke-width:4px,font-size:18px,font-weight:bold,font-family:Arial,rx:40px;
    classDef stateVar fill:#dbeafe,stroke:#3b82f6,stroke-width:2px,color:#1e40af,font-size:14px,font-family:Arial,rounded:true;
    classDef function fill:#e0e7ff,stroke:#818cf8,stroke-width:2px,color:#4338ca,font-size:14px,font-family:Arial,rounded:true;
    classDef contract fill:#fef3c7,stroke:#f59e0b,stroke-width:2px,color:#b45309,font-size:14px,font-family:Arial,rounded:true;
    classDef category fill:none,stroke:none,color:#333,font-size:16px,font-weight:bold,font-family:Arial;
    
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
    mermaid = """```mermaid
graph TB
    root(("🔗 Smart Contracts"))
"""
    
    # Group contracts by type
    interfaces = []
    core_contracts = []
    utils = []
    libraries = []
    
    for name, info in contracts.items():
        if info.is_interface:
            interfaces.append((name, info))
        elif info.source_path.startswith("utils/"):
            utils.append((name, info))
        elif info.source_path.startswith("libraries/"):
            libraries.append((name, info))
        else:
            core_contracts.append((name, info))
    
    # Add core contracts subgraph
    if core_contracts:
        mermaid += """
    subgraph Core ["🛠️ Core Contracts"]
        direction LR
"""
        # Group contracts in pairs for better layout
        pairs = []
        current_pair = []
        for name, _ in sorted(core_contracts):
            current_pair.append(name)
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
        if current_pair:  # Add any remaining contract
            pairs.append(current_pair)
            
        # Add the pairs to the diagram
        for pair in pairs:
            mermaid += f"        {' & '.join(pair)}\n"
        mermaid += "    end\n"
    
    # Add interfaces subgraph
    if interfaces:
        mermaid += """
    subgraph Interfaces ["📋 Interfaces"]
        direction LR
"""
        # Group interfaces in pairs
        pairs = []
        current_pair = []
        for name, _ in sorted(interfaces):
            current_pair.append(name)
            if len(current_pair) == 2:
                pairs.append(current_pair)
                current_pair = []
        if current_pair:
            pairs.append(current_pair)
            
        for pair in pairs:
            mermaid += f"        {' & '.join(pair)}\n"
        mermaid += "    end\n"
    
    # Add root connections
    mermaid += """
    root --> Core
    root --> Interfaces
    
    %% Style definitions
    classDef default fill:#f4f4f4,stroke:#333,stroke-width:2px,font-size:14px,font-family:Arial,rounded:true;
    classDef root fill:#6366f1,color:#fff,stroke:#4338ca,stroke-width:4px,font-size:18px,font-weight:bold,font-family:Arial,rx:40px;
    classDef contract fill:#e0e7ff,stroke:#818cf8,stroke-width:2px,color:#4338ca,font-size:14px,font-family:Arial,rounded:true;
    classDef interface fill:#fef3c7,stroke:#f59e0b,stroke-width:2px,color:#b45309,font-size:14px,font-family:Arial,rounded:true;
    classDef category fill:none,stroke:none,color:#333,font-size:16px,font-weight:bold,font-family:Arial;
    
    %% Apply styles
    class root root;
    class Core,Interfaces category;
"""
    
    # Apply contract styles
    contract_styles = []
    for name, _ in core_contracts:
        contract_styles.append(name)
    if contract_styles:
        mermaid += f"    class {','.join(contract_styles)} contract;\n"
    
    # Apply interface styles
    interface_styles = []
    for name, _ in interfaces:
        interface_styles.append(name)
    if interface_styles:
        mermaid += f"    class {','.join(interface_styles)} interface;\n"
    
    # Add click actions
    mermaid += "\n    %% Click actions\n"
    for name, _ in core_contracts + interfaces:
        mermaid += f'    click {name} "{name}.html" "{name} documentation"\n'
    
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