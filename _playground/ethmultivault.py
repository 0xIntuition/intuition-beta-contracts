from decimal import *
from web3 import Web3
import math


## ------------ Parameters ------------

# Atom
atomCreationProtocolFee = Web3.to_wei(Decimal('0.0002'), 'ether')
atomWalletInitialDepositAmount = Web3.to_wei(Decimal('0.0001'), 'ether')

# Triple
tripleCreationProtocolFee = Web3.to_wei(Decimal('0.0002'), 'ether')
atomDepositFractionOnTripleCreation = Web3.to_wei(Decimal('0.0003'), 'ether')
atomDepositFractionForTriple = 1500 # 15%

# General
minShare = Web3.to_wei(Decimal('0.0000000000001'), 'ether')
protocolFee = 100 # 1%
entryFee = 500 # 5%
exitFee = 500 # 5%
feeDenominator = 10000

# Costs
atomCost = Decimal(atomCreationProtocolFee) + Decimal(atomWalletInitialDepositAmount) + Decimal(minShare)
tripleCost = Decimal(tripleCreationProtocolFee) + Decimal(atomDepositFractionOnTripleCreation) + Decimal(2) * Decimal(minShare)


## ------------ Functions ------------

def createAtom(value: Decimal) -> tuple[Decimal, Decimal, Decimal, Decimal, Decimal]:
  # Variables
  userDeposit = value - atomCost
  protocolFeeAmount = math.ceil(userDeposit * Decimal(protocolFee) / Decimal(feeDenominator))
  userDepositAfterprotocolFee = userDeposit - Decimal(protocolFeeAmount)

  # Atom vault
  userShares = userDepositAfterprotocolFee
  totalShares = userDepositAfterprotocolFee + Decimal(atomWalletInitialDepositAmount) + Decimal(minShare)
  totalAssets = totalShares

  # Addresses
  atomWalletShares = Decimal(atomWalletInitialDepositAmount)
  protocolMultisigAssets = Decimal(atomCreationProtocolFee) + Decimal(protocolFeeAmount)

  return (userShares, totalShares, totalAssets, atomWalletShares, protocolMultisigAssets)


def createTriple(value: Decimal) -> tuple[Decimal, Decimal, Decimal, Decimal, Decimal, Decimal, Decimal, Decimal, Decimal]:
  # Variables
  userDeposit = value - tripleCost
  protocolFeeAmount = math.ceil(userDeposit * Decimal(protocolFee) / Decimal(feeDenominator))
  userDepositAfterprotocolFee = userDeposit - Decimal(protocolFeeAmount)
  atomDepositFraction = math.floor(userDepositAfterprotocolFee * Decimal(atomDepositFractionForTriple) / Decimal(feeDenominator))
  perAtom = math.floor(atomDepositFraction / Decimal(3))
  userAssetsAfterAtomDepositFraction = userDepositAfterprotocolFee - atomDepositFraction
  entryFeeAmount = math.floor(perAtom * Decimal(entryFee) / Decimal(feeDenominator))
  assetsForTheAtom = perAtom - entryFeeAmount
  userSharesAfterTotalFees = assetsForTheAtom # assuming current price = 1 ether

  # Triple vaults
  userSharesPositiveVault = userAssetsAfterAtomDepositFraction
  totalSharesPositiveVault = userAssetsAfterAtomDepositFraction + Decimal(minShare)
  totalAssetsPositiveVault = totalSharesPositiveVault
  totalSharesNegativeVault = Decimal(minShare)
  totalAssetsNegativeVault = Decimal(minShare)

  # Underlying atom's vaults
  userSharesAtomVault = userSharesAfterTotalFees
  totalAssetsAtomVault = assetsForTheAtom + entryFeeAmount + math.floor(Decimal(atomDepositFractionOnTripleCreation) / Decimal(3))
  totalSharesAtomVault = userSharesAfterTotalFees

  # Addresses
  protocolMultisigAssets = Decimal(tripleCreationProtocolFee) + Decimal(protocolFeeAmount)

  return (userSharesPositiveVault,
          totalSharesPositiveVault,
          totalAssetsPositiveVault,
          totalSharesNegativeVault,
          totalAssetsNegativeVault,
          userSharesAtomVault,
          totalSharesAtomVault,
          totalAssetsAtomVault,
          protocolMultisigAssets)


def depositAtom(value: Decimal, totalAssets: Decimal, totalShares: Decimal) -> tuple[Decimal, Decimal, Decimal, Decimal]:
  # Variables
  protocolFeeAmount = math.ceil(value * Decimal(protocolFee) / Decimal(feeDenominator))
  userDepositAfterprotocolFee = value - Decimal(protocolFeeAmount)
  entryFeeAmount = math.floor(userDepositAfterprotocolFee * Decimal(entryFee) / Decimal(feeDenominator))
  assetsForTheAtom = userDepositAfterprotocolFee - entryFeeAmount
  userSharesForTheAtom = math.floor((assetsForTheAtom * totalShares) / totalAssets)

  # Atom vault
  totalAssetsAtomVault = totalAssets + assetsForTheAtom + entryFeeAmount
  totalSharesAtomVault = totalShares + userSharesForTheAtom

  # Addresses
  protocolMultisigAssets = protocolFeeAmount

  return (userSharesForTheAtom, totalSharesAtomVault, totalAssetsAtomVault, protocolMultisigAssets)


def depositTriple(value: Decimal, totalAssets: Decimal, totalShares: Decimal, totalAssetsAtom: Decimal, totalSharesAtom: Decimal) -> tuple[Decimal, Decimal, Decimal, Decimal, Decimal, Decimal, Decimal]:
  # Variables for triple
  protocolFeeAmount = math.ceil(value * Decimal(protocolFee) / Decimal(feeDenominator))
  userDepositAfterprotocolFee = value - Decimal(protocolFeeAmount)
  atomDepositFraction = math.floor(userDepositAfterprotocolFee * Decimal(atomDepositFractionForTriple) / Decimal(feeDenominator))
  userAssetsAfterAtomDepositFraction = userDepositAfterprotocolFee - atomDepositFraction
  if (totalShares == minShare):
    entryFeeAmount = 0
  else:
    entryFeeAmount = math.floor(userAssetsAfterAtomDepositFraction * Decimal(entryFee) / Decimal(feeDenominator))
  assetsAfterEntryFee = userAssetsAfterAtomDepositFraction - entryFeeAmount
  if (totalShares == 0):
    userSharesAfterEntryFee = assetsAfterEntryFee
  else:
    userSharesAfterEntryFee = math.floor((assetsAfterEntryFee * totalShares) / totalAssets)

  # Triple vaults
  userSharesPositiveVault = userSharesAfterEntryFee
  totalAssetsPositiveVault = assetsAfterEntryFee + Decimal(entryFeeAmount)
  totalSharesPositiveVault = userSharesAfterEntryFee

  # Variables for atom
  perAtom = math.floor(atomDepositFraction / Decimal(3))
  if (totalSharesAtom == minShare):
    entryFeeAmountForAtom = 0
  else:
    entryFeeAmountForAtom = math.floor(perAtom * Decimal(entryFee) / Decimal(feeDenominator))
  assetsForTheAtom = perAtom - entryFeeAmountForAtom
  if (totalSharesAtom == 0):
    userSharesForTheAtom = assetsForTheAtom
  else:  
    userSharesForTheAtom = math.floor((assetsForTheAtom * totalSharesAtom) / totalAssetsAtom)

  # Underlying atom's vaults
  userSharesAtomVault = userSharesForTheAtom
  totalAssetsAtomVault = assetsForTheAtom + entryFeeAmountForAtom
  totalSharesAtomVault = userSharesForTheAtom

  # Addresses
  protocolMultisigAssets = Decimal(protocolFeeAmount)

  return (userSharesPositiveVault,
          totalSharesPositiveVault,
          totalAssetsPositiveVault,
          userSharesAtomVault,
          totalSharesAtomVault,
          totalAssetsAtomVault,
          protocolMultisigAssets)


def redeem(shares: Decimal, totalAssets: Decimal, totalShares: Decimal):
  if (totalShares == 0):
    userAssets = shares
  else:
    userAssets = math.floor((shares * totalAssets) / totalShares)

  protocolFeeAmount = math.ceil(Decimal(userAssets) * Decimal(protocolFee) / Decimal(feeDenominator))
  userAssetsAfterprotocolFee = Decimal(userAssets) - Decimal(protocolFeeAmount)

  if (totalShares - shares == minShare):
    exitFeeAmount = 0
  else:
    exitFeeAmount = math.ceil(userAssetsAfterprotocolFee * Decimal(exitFee) / Decimal(feeDenominator))

  userAssetsAfterexitFee = userAssetsAfterprotocolFee - Decimal(exitFeeAmount)
  
  return (userAssetsAfterexitFee, protocolFeeAmount, exitFeeAmount)


## ------------ Create Atom data ------------

print()
print("Create atom data")

for value in [
    atomCost,
    Decimal(atomCost) + Decimal(1),
    Web3.to_wei(Decimal('1'), 'ether'),
    Web3.to_wei(Decimal('10'), 'ether'),
    Web3.to_wei(Decimal('100'), 'ether'),
    Web3.to_wei(Decimal('1000'), 'ether'),
]:
  (userShares, totalShares, totalAssets, atomWalletShares, protocolMultisigAssets) = createAtom(value)

  print(f"useCaseAtoms.push(UseCaseAtom({{ \
    value: {value}, \
    userShares: {userShares}, \
    atomWalletShares: {atomWalletShares}, \
    totalShares: {totalShares}, \
    totalAssets: {totalAssets}, \
    protocolMultisigAssets: {protocolMultisigAssets} \
  }}));".replace("  ", ''))


## ------------ Create Triple data ------------

print()
print("Create triple data")

for value in [
    tripleCost,
    Decimal(tripleCost) + Decimal(1),
    Web3.to_wei(Decimal('1'), 'ether'),
    Web3.to_wei(Decimal('10'), 'ether'),
    Web3.to_wei(Decimal('100'), 'ether'),
    Web3.to_wei(Decimal('1000'), 'ether'),
]:
  # Create atoms
  (userShares0, totalShares0, totalAssets0, atomWalletShares0, protocolMultisigAssets0) = createAtom(value)
  (userShares1, totalShares1, totalAssets1, atomWalletShares1, protocolMultisigAssets1) = createAtom(value + Decimal(1))
  (userShares2, totalShares2, totalAssets2, atomWalletShares2, protocolMultisigAssets2) = createAtom(value + Decimal(2))

  # Create triple
  (userSharesPositiveVault, totalSharesPositiveVault, totalAssetsPositiveVault, totalSharesNegativeVault,
    totalAssetsNegativeVault, userSharesAtomVault, totalSharesAtomVault, totalAssetsAtomVault, protocolMultisigAssets) = createTriple(value)

  print(f"useCaseTriples.push(UseCaseTriple({{ \
    value: {value}, \
    userShares: {userSharesPositiveVault}, \
    totalSharesPos: {totalSharesPositiveVault}, \
    totalAssetsPos: {totalAssetsPositiveVault}, \
    totalSharesNeg: {totalSharesNegativeVault}, \
    totalAssetsNeg: {totalAssetsNegativeVault}, \
    protocolMultisigAssets: {protocolMultisigAssets0 + protocolMultisigAssets1 + protocolMultisigAssets2 + protocolMultisigAssets}, \
    subject:UseCaseAtom({{ \
      value: {value}, \
      userShares: {userShares0 + userSharesAtomVault}, \
      atomWalletShares: {atomWalletShares0}, \
      totalShares: {totalShares0 + totalSharesAtomVault}, \
      totalAssets: {totalAssets0 + totalAssetsAtomVault}, \
      protocolMultisigAssets: {protocolMultisigAssets0} \
    }}), \
    predicate:UseCaseAtom({{ \
      value: {value + Decimal(1)}, \
      userShares: {userShares1 + userSharesAtomVault}, \
      atomWalletShares: {atomWalletShares1}, \
      totalShares: {totalShares1 + totalSharesAtomVault}, \
      totalAssets: {totalAssets1 + totalAssetsAtomVault}, \
      protocolMultisigAssets: {protocolMultisigAssets1} \
    }}), \
    obj:UseCaseAtom({{ \
      value: {value + Decimal(2)}, \
      userShares: {userShares2 + userSharesAtomVault}, \
      atomWalletShares: {atomWalletShares2}, \
      totalShares: {totalShares2 + totalSharesAtomVault}, \
      totalAssets: {totalAssets2 + totalAssetsAtomVault}, \
      protocolMultisigAssets: {protocolMultisigAssets2} \
    }}) \
  }}));".replace("  ", ''))


## ------------ Deposit Atom data ------------

print()
print("Deposit atom data")

for value in [
    atomCost,
    Decimal(atomCost) + Decimal(1),
    Web3.to_wei(Decimal('1'), 'ether'),
    Web3.to_wei(Decimal('10'), 'ether'),
    Web3.to_wei(Decimal('100'), 'ether'),
    Web3.to_wei(Decimal('1000'), 'ether'),
]:
  (userShares, totalShares, totalAssets, atomWalletShares, protocolMultisigAssets) = createAtom(value)

  for _ in range(3):
    (userSharesFromDeposit, totalShares, totalAssets, protocolMultisigAssetsFromDeposit) = depositAtom(value, totalAssets, totalShares)

    userShares += userSharesFromDeposit
    protocolMultisigAssets += protocolMultisigAssetsFromDeposit

  print(f"useCaseAtoms.push(UseCaseAtom({{ \
    value: {value}, \
    userShares: {userShares}, \
    atomWalletShares: {atomWalletShares}, \
    totalShares: {totalShares}, \
    totalAssets: {totalAssets}, \
    protocolMultisigAssets: {protocolMultisigAssets} \
  }}));".replace("  ", ''))


## ------------ Deposit Triple data ------------

print()
print("Deposit triple data")

for value in [
    tripleCost,
    Decimal(tripleCost) + Decimal(1),
    Web3.to_wei(Decimal('1'), 'ether'),
    Web3.to_wei(Decimal('10'), 'ether'),
    Web3.to_wei(Decimal('100'), 'ether'),
    Web3.to_wei(Decimal('1000'), 'ether'),
]:
  # Create 3 atoms
  (userShares0, totalShares0, totalAssets0, atomWalletShares0, protocolMultisigAssets0) = createAtom(atomCost)
  (userShares1, totalShares1, totalAssets1, atomWalletShares1, protocolMultisigAssets1) = createAtom(atomCost)
  (userShares2, totalShares2, totalAssets2, atomWalletShares2, protocolMultisigAssets2) = createAtom(atomCost)

  userSharesPerAtom = userShares0
  totalSharesPerAtom = totalShares0
  totalAssetsPerAtom = totalAssets0
  protocolMultisigAssets = protocolMultisigAssets0 + protocolMultisigAssets1 + protocolMultisigAssets2

  # Create 1 triple
  (userSharesPositiveVault, totalSharesPositiveVault, totalAssetsPositiveVault, totalSharesNegativeVault,
    totalAssetsNegativeVault, userSharesAtomVault, totalSharesAtomVault, totalAssetsAtomVault, protocolMultisigAssetsFromCreation) = createTriple(value)

  userSharesPerAtom += userSharesAtomVault
  totalSharesPerAtom += totalSharesAtomVault
  totalAssetsPerAtom += totalAssetsAtomVault
  protocolMultisigAssets += protocolMultisigAssetsFromCreation

  for _ in range(3):
    # Deposits
    (userSharesPositiveVaultFromDeposit, totalSharesPositiveVaultFromDeposit, totalAssetsPositiveVaultFromDeposit, userSharesAtomVault, totalSharesPerAtomFromDeposit, 
      totalAssetsPerAtomFromDeposit, protocolMultisigAssetsFromDeposit) \
      = depositTriple(value, totalAssetsPositiveVault, totalSharesPositiveVault, totalAssetsPerAtom, totalSharesPerAtom)
    
    userSharesPositiveVault += userSharesPositiveVaultFromDeposit
    totalAssetsPositiveVault += totalAssetsPositiveVaultFromDeposit
    totalSharesPositiveVault += totalSharesPositiveVaultFromDeposit
    userSharesPerAtom += userSharesAtomVault
    totalSharesPerAtom += totalSharesPerAtomFromDeposit
    totalAssetsPerAtom += totalAssetsPerAtomFromDeposit
    protocolMultisigAssets += protocolMultisigAssetsFromDeposit

  print(f"useCaseTriples.push(UseCaseTriple({{ \
    value: {value}, \
    userShares: {userSharesPositiveVault}, \
    totalSharesPos: {totalSharesPositiveVault}, \
    totalAssetsPos: {totalAssetsPositiveVault}, \
    totalSharesNeg: {totalSharesNegativeVault}, \
    totalAssetsNeg: {totalAssetsNegativeVault}, \
    protocolMultisigAssets: {protocolMultisigAssets}, \
    subject:UseCaseAtom({{ \
      value: {atomCost}, \
      userShares: {userSharesPerAtom}, \
      atomWalletShares: {atomWalletShares0}, \
      totalShares: {totalSharesPerAtom}, \
      totalAssets: {totalAssetsPerAtom}, \
      protocolMultisigAssets: {protocolMultisigAssets0} \
    }}), \
    predicate:UseCaseAtom({{ \
      value: {atomCost}, \
      userShares: {userSharesPerAtom}, \
      atomWalletShares: {atomWalletShares1}, \
      totalShares: {totalSharesPerAtom}, \
      totalAssets: {totalAssetsPerAtom}, \
      protocolMultisigAssets: {protocolMultisigAssets1} \
    }}), \
    obj:UseCaseAtom({{ \
      value: {atomCost}, \
      userShares: {userSharesPerAtom}, \
      atomWalletShares: {atomWalletShares2}, \
      totalShares: {totalSharesPerAtom}, \
      totalAssets: {totalAssetsPerAtom}, \
      protocolMultisigAssets: {protocolMultisigAssets2} \
    }}) \
  }}));".replace("  ", ''))


## ------------ Redeem Atom data ------------

print()
print("Redeem atom data")

for value in [
    atomCost,
    Decimal(atomCost) + Decimal(1),
    Web3.to_wei(Decimal('1'), 'ether'),
    Web3.to_wei(Decimal('10'), 'ether'),
    Web3.to_wei(Decimal('100'), 'ether'),
    Web3.to_wei(Decimal('1000'), 'ether'),
]:
  (userShares, totalShares, totalAssets, _, protocolMultisigAssets) = createAtom(value)

  for _ in range(3):
    (userSharesFromDeposit, totalShares, totalAssets, protocolMultisigAssetsFromDeposit) = depositAtom(value, totalAssets, totalShares)

    userShares += userSharesFromDeposit
    protocolMultisigAssets += protocolMultisigAssetsFromDeposit

  (userAssets, protocolFeeAmount, exitFeeAmount) = redeem(userShares, totalAssets, totalShares)

  totalRemainingShares = totalShares - userShares
  totalRemainingAssets = totalAssets - userAssets - protocolFeeAmount
  protocolMultisigAssets += protocolFeeAmount

  print(f"useCaseRedeems.push(UseCaseRedeem({{ \
    value: {value}, \
    shares: {userShares}, \
    assets: {userAssets}, \
    totalRemainingShares: {totalRemainingShares}, \
    totalRemainingAssets: {totalRemainingAssets}, \
    protocolMultisigAssets: {protocolMultisigAssets} \
  }}));".replace("  ", ''))


## ------------ Redeem Triple data ------------

print()
print("Redeem triple data")

for value in [
    tripleCost,
    Decimal(tripleCost) + Decimal(1),
    Web3.to_wei(Decimal('1'), 'ether'),
    Web3.to_wei(Decimal('10'), 'ether'),
    Web3.to_wei(Decimal('100'), 'ether'),
    Web3.to_wei(Decimal('1000'), 'ether'),
]:
  # Create 3 atoms
  (_, _, _, _, protocolMultisigAssets0) = createAtom(atomCost)
  (_, _, _, _, protocolMultisigAssets1) = createAtom(atomCost)
  (_, _, _, _, protocolMultisigAssets2) = createAtom(atomCost)

  protocolMultisigAssets = protocolMultisigAssets0 + protocolMultisigAssets1 + protocolMultisigAssets2

  # Create 1 triple
  (userShares, totalShares, totalAssets, _, _, _, _, _, protocolFeeAmount) = createTriple(value)

  protocolMultisigAssets += protocolFeeAmount

  for _ in range(3):
    # Deposits
    (userSharesFromDeposit, totalSharesPositiveVaultFromDeposit, totalAssetsPositiveVaultFromDeposit, _, _, _, protocolFeeAmount) = \
      depositTriple(value, totalAssets, totalShares, 1, 1) # any atom totals, not used in this case
    
    userShares += userSharesFromDeposit
    totalShares += totalSharesPositiveVaultFromDeposit
    totalAssets += totalAssetsPositiveVaultFromDeposit
    protocolMultisigAssets += protocolFeeAmount

  (userAssets, protocolFeeAmount, exitFeeAmount) = redeem(userShares, totalAssets, totalShares)

  totalRemainingShares = totalShares - userShares
  totalRemainingAssets = totalAssets - userAssets - protocolFeeAmount
  protocolMultisigAssets += protocolFeeAmount

  print(f"useCaseRedeems.push(UseCaseRedeem({{ \
    value: {value}, \
    shares: {userShares}, \
    assets: {userAssets}, \
    totalRemainingShares: {totalRemainingShares}, \
    totalRemainingAssets: {totalRemainingAssets}, \
    protocolMultisigAssets: {protocolMultisigAssets} \
  }}));".replace("  ", ''))
