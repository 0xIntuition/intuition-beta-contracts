from manticore.ethereum import ManticoreEVM
from manticore.core.smtlib import Operators
import json

# Initialize Manticore EVM
m = ManticoreEVM()

# User account
user_account = m.create_account(balance=1000)

# Load the compiled contract
with open('out/EthMultiVault/EthMultiVault.json') as f:
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
    print(f"Contract balance: {contract_balance}")

# Terminate Manticore
m.finalize()
