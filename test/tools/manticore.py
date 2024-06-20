import os
import subprocess
import sys
import json
from manticore.ethereum import ManticoreEVM
from manticore.core.smtlib import Operators

# Ensure Manticore is installed
def install_manticore():
    try:
        import manticore
    except ImportError:
        print("Manticore is not installed. Installing now...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "manticore"])

install_manticore()

# Initialize Manticore EVM
m = ManticoreEVM()

# User account
user_account = m.create_account(balance=1000)

# Load the compiled contract
contract_path = 'out/EthMultiVault/EthMultiVault.json'
if not os.path.isfile(contract_path):
    print(f"Contract file not found at {contract_path}")
    sys.exit(1)

with open(contract_path) as f:
    contract_json = json.load(f)
    bytecode = contract_json['bytecode']['object']

# Create contract
contract_account = m.create_contract(owner=user_account, balance=0, init=bytecode)

# Define symbolic values
symbolic_value = m.make_symbolic_value()
symbolic_data = m.make_symbolic_buffer(320)

# Transaction sending
m.transaction(caller=user_account, address=contract_account, data=symbolic_data, value=symbolic_value)

# Explore all states
for state in m.running_states:
    world = state.platform
    contract_balance = world.get_balance(contract_account.address)
    m.terminate()
    print(f"Contract balance: {contract_balance}")

# Analyze issues
for state in m.terminated_states:
    for address, account in state.platform.items():
        if account.storage:
            for k, v in account.storage.items():
                print(f"Address: {address}, Key: {k}, Value: {v}")

    m.generate_testcase(state, name="test_case")
