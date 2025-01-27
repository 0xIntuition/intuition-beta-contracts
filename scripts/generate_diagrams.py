#!/usr/bin/env python3

import os
import re
import json
from typing import Dict, List, Set, Tuple

class ContractInfo:
    def __init__(self, name: str, path: str):
        self.name = name
        self.path = path
        self.inherits: Set[str] = set()
        self.functions: List[Tuple[str, str, str]] = []  # (name, params, visibility)
        self.state_vars: List[Tuple[str, str]] = []  # (name, type)
        self.is_interface = False
        self.is_abstract = False
        self.uses: Set[str] = set()

def clean_type_name(type_name: str) -> str:
    """Clean up type names by removing array markers and mappings."""
    # Remove array markers
    type_name = re.sub(r'\[\d*\]', '', type_name)
    # Extract the value type from mappings
    mapping_match = re.search(r'mapping\s*\([^)]*\s*=>\s*([^)]*)\)', type_name)
    if mapping_match:
        return clean_type_name(mapping_match.group(1))
    return type_name.strip()

def extract_type_references(type_str: str) -> Set[str]:
    """Extract potential contract references from a type string."""
    refs = set()
    # Clean the type string
    type_str = clean_type_name(type_str)
    # Split on common type separators and extract potential contract names
    parts = re.split(r'[,\s<>()]', type_str)
    for part in parts:
        part = part.strip()
        if part and part[0].isupper() and not part.startswith(('uint', 'int', 'bytes', 'string', 'bool', 'address')):
            refs.add(part)
    return refs

def parse_contract_json(contract_path: str) -> ContractInfo:
    """Parse contract information from forge inspect JSON output."""
    with open(contract_path, 'r') as f:
        data = json.load(f)
    
    name = os.path.basename(contract_path).replace('.json', '')
    contract = ContractInfo(name, contract_path)
    
    # Check if interface or abstract
    contract.is_interface = name.startswith('I')
    contract.is_abstract = 'abstract' in data.get('devdoc', {}).get('kind', '')
    
    # Get inheritance from devdoc
    if 'devdoc' in data:
        inherits = data['devdoc'].get('details', '').split('Inherits:')
        if len(inherits) > 1:
            contract.inherits.update(re.findall(r'\b([A-Z]\w+)\b', inherits[1]))
    
    # Get state variables from storage layout
    if 'storageLayout' in data:
        for var in data['storageLayout'].get('storage', []):
            var_name = var['label']
            var_type = var['type']
            contract.state_vars.append((var_name, var_type))
            # Add usage relationships from type
            contract.uses.update(extract_type_references(var_type))
    
    # Get functions from ABI
    if 'abi' in data:
        for item in data['abi']:
            if item.get('type') == 'function':
                func_name = item['name']
                visibility = 'external' if item.get('stateMutability') == 'external' else 'public'
                
                # Get parameters
                params = []
                for param in item.get('inputs', []):
                    param_name = param.get('name', '_')
                    param_type = param['type']
                    params.append(f"{param_name}: {param_type}")
                    # Add usage relationships from parameter type
                    contract.uses.update(extract_type_references(param_type))
                
                # Add usage relationships from return types
                for output in item.get('outputs', []):
                    contract.uses.update(extract_type_references(output['type']))
                
                if params or item.get('stateMutability') in ['view', 'pure']:
                    contract.functions.append((func_name, ', '.join(params), visibility))
    
    # Remove basic types and self-references from uses
    basic_types = {'uint', 'int', 'string', 'bool', 'address', 'bytes', 'uint256', 'uint8', 'bytes32'}
    contract.uses = {use for use in contract.uses if use not in basic_types and use != contract.name}
    
    return contract

def generate_mermaid_diagram(contracts: Dict[str, ContractInfo]) -> str:
    """Generate a Mermaid class diagram from contract information."""
    diagram = [
        "classDiagram",
        "    %% Core Contracts"
    ]

    # Add classes with their functions and state variables
    for name, contract in sorted(contracts.items()):
        class_def = [f"    class {name} {{"]
        if contract.is_interface:
            class_def.append('        <<interface>>')
        elif contract.is_abstract:
            class_def.append('        <<abstract>>')
        
        # Add state variables
        for var_name, var_type in sorted(contract.state_vars):
            # Clean up the type for display
            var_type = re.sub(r'\s+', ' ', var_type)  # Normalize whitespace
            var_type = var_type.strip()
            if var_type.endswith(')'):  # Fix malformed types
                var_type = var_type[:-1]
            class_def.append(f'        +{var_type} {var_name}')
        
        # Add functions
        for func_name, params, _ in sorted(contract.functions):
            if params:
                class_def.append(f'        +{func_name}({params})')
            else:
                class_def.append(f'        +{func_name}()')

        class_def.append("    }")
        diagram.extend(class_def)

    # Add relationships
    seen_relationships = set()  # Track unique relationships
    
    diagram.append("\n    %% Inheritance Relationships")
    for name, contract in sorted(contracts.items()):
        for parent in sorted(contract.inherits):
            rel = (name, parent)
            if rel not in seen_relationships:
                seen_relationships.add(rel)
                if parent in contracts:
                    diagram.append(f"    {name} --|> {parent}")
                elif parent.startswith('I'):
                    diagram.append(f"    {name} ..|> {parent}")

    # Add usage relationships
    diagram.append("\n    %% Usage Relationships")
    for name, contract in sorted(contracts.items()):
        for used in sorted(contract.uses):
            rel = (name, used)
            if used in contracts and rel not in seen_relationships:
                seen_relationships.add(rel)
                diagram.append(f"    {name} ..> {used} : uses")

    return '\n'.join(diagram)

def ensure_architecture_docs():
    """Create architecture documentation directory and overview file if they don't exist."""
    arch_dir = 'docs/src/architecture'
    overview_path = f'{arch_dir}/overview.md'
    
    # Create architecture directory if it doesn't exist
    os.makedirs(arch_dir, exist_ok=True)
    
    # Create or update overview file if it doesn't exist
    if not os.path.exists(overview_path):
        with open(overview_path, 'w') as f:
            f.write("# Contract Architecture\n\nThis document provides an overview of the inheritance and relationship diagram of core contracts.\n")

def main():
    # Ensure architecture documentation exists
    ensure_architecture_docs()
    
    # Load contract information from JSON files
    contracts_dir = 'docs/contracts'
    contracts: Dict[str, ContractInfo] = {}
    
    for file in os.listdir(contracts_dir):
        if file.endswith('.json'):
            contract_path = os.path.join(contracts_dir, file)
            contract = parse_contract_json(contract_path)
            if contract:
                contracts[contract.name] = contract

    # Generate diagram
    diagram = generate_mermaid_diagram(contracts)

    # Update the overview.md file
    overview_path = 'docs/src/architecture/overview.md'
    with open(overview_path, 'r') as f:
        content = f.read()

    # Add the diagram after the introduction text
    if '```mermaid' not in content:
        content = content.rstrip() + f'\n\n```mermaid\n{diagram}\n```\n'
    else:
        content = re.sub(
            r'```mermaid.*?```',
            f'```mermaid\n{diagram}\n```',
            content,
            flags=re.DOTALL
        )

    with open(overview_path, 'w') as f:
        f.write(content)

if __name__ == '__main__':
    main() 