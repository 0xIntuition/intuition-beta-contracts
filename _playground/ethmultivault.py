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
feeDenominator = 10000

# Costs
atomCost = Decimal(atomCreationProtocolFee) + Decimal(atomWalletInitialDepositAmount) + Decimal(minShare)
tripleCost = Decimal(tripleCreationProtocolFee) + Decimal(atomDepositFractionOnTripleCreation) + Decimal(2) * Decimal(minShare)


## ------------ Functions ------------

def createAtom(value: Decimal) -> tuple[Decimal, Decimal, Decimal, Decimal, Decimal]:
  # Variables
  userDeposit = value - atomCost
  protocolFeeAmount = math.ceil(userDeposit * Decimal(protocolFee) / Decimal(feeDenominator))
  userDepositAfterProtocolFees = userDeposit - Decimal(protocolFeeAmount)

  # Atom vault
  userShares = userDepositAfterProtocolFees
  totalShares = userDepositAfterProtocolFees + Decimal(atomWalletInitialDepositAmount) + Decimal(minShare)
  totalAssets = totalShares

  # Addresses
  atomWalletShares = Decimal(atomWalletInitialDepositAmount)
  zeroWalletShares = minShare
  protocolVaultAssets = Decimal(atomCreationProtocolFee) + Decimal(protocolFeeAmount)

  return (userShares, totalShares, totalAssets, atomWalletShares, protocolVaultAssets)

def createTriple(value: Decimal) -> tuple[Decimal, Decimal, Decimal, Decimal, Decimal, Decimal, Decimal, Decimal, Decimal]:
  # Variables
  userDeposit = value - tripleCost
  protocolFeeAmount = math.ceil(userDeposit * Decimal(protocolFee) / Decimal(feeDenominator))
  userDepositAfterProtocolFees = userDeposit - Decimal(protocolFeeAmount)
  atomDepositFraction = userDepositAfterProtocolFees * Decimal(atomDepositFractionForTriple) / Decimal(feeDenominator)
  perAtom = atomDepositFraction / Decimal(3)
  userAssetsAfterAtomDepositFraction = userDepositAfterProtocolFees - atomDepositFraction
  entryFeeAmount = perAtom * Decimal(entryFee) / Decimal(feeDenominator)
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
  totalAssetsAtomVault = assetsForTheAtom + entryFeeAmount + Decimal(atomDepositFractionOnTripleCreation) / Decimal(3)
  totalSharesAtomVault = userSharesAfterTotalFees

  # Addresses
  #zeroWalletShares = Decimal(2) * Decimal(minShare)
  protocolVaultAssets = Decimal(tripleCreationProtocolFee) + Decimal(protocolFeeAmount)

  return (userSharesPositiveVault,
          totalSharesPositiveVault,
          totalAssetsPositiveVault,
          totalSharesNegativeVault,
          totalAssetsNegativeVault,
          userSharesAtomVault,
          totalSharesAtomVault,
          totalAssetsAtomVault,
          protocolVaultAssets)


## ------------ Create atom data ------------

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
  (userShares, totalShares, totalAssets, atomWalletShares, protocolVaultAssets) = createAtom(value)

  print(f"useCaseAtoms.push(UseCaseAtom({{ \
    value: {value}, \
    userShares: {userShares}, \
    atomWalletShares: {atomWalletShares}, \
    totalShares: {totalShares}, \
    totalAssets: {totalAssets}, \
    protocolVaultAssets: {protocolVaultAssets} \
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
  (userShares0, totalShares0, totalAssets0, atomWalletShares0, protocolVaultAssets0) = createAtom(value)
  (userShares1, totalShares1, totalAssets1, atomWalletShares1, protocolVaultAssets1) = createAtom(value + Decimal(1))
  (userShares2, totalShares2, totalAssets2, atomWalletShares2, protocolVaultAssets2) = createAtom(value + Decimal(2))

  # Create triple
  (userSharesPositiveVault, totalSharesPositiveVault, totalAssetsPositiveVault, totalSharesNegativeVault,
    totalAssetsNegativeVault, userSharesAtomVault,totalSharesAtomVault, totalAssetsAtomVault, protocolVaultAssets) = createTriple(value)

  print(f"useCaseTriples.push(UseCaseTriple({{ \
    value: {value}, \
    userShares: {userSharesPositiveVault}, \
    totalSharesPos: {totalSharesPositiveVault}, \
    totalAssetsPos: {totalAssetsPositiveVault}, \
    totalSharesNeg: {totalSharesNegativeVault}, \
    totalAssetsNeg: {totalAssetsNegativeVault}, \
    protocolVaultAssets: {protocolVaultAssets0 + protocolVaultAssets1 + protocolVaultAssets2 + protocolVaultAssets}, \
    subject:UseCaseAtom({{ \
      value: {value}, \
      userShares: {userShares0 + userSharesAtomVault}, \
      atomWalletShares: {atomWalletShares0}, \
      totalShares: {totalShares0 + totalSharesAtomVault}, \
      totalAssets: {totalAssets0 + totalAssetsAtomVault}, \
      protocolVaultAssets: {protocolVaultAssets0} \
    }}), \
    predicate:UseCaseAtom({{ \
      value: {value + Decimal(1)}, \
      userShares: {userShares1 + userSharesAtomVault}, \
      atomWalletShares: {atomWalletShares1}, \
      totalShares: {totalShares1 + totalSharesAtomVault}, \
      totalAssets: {totalAssets1 + totalAssetsAtomVault}, \
      protocolVaultAssets: {protocolVaultAssets1} \
    }}), \
    obj:UseCaseAtom({{ \
      value: {value + Decimal(2)}, \
      userShares: {userShares2 + userSharesAtomVault}, \
      atomWalletShares: {atomWalletShares2}, \
      totalShares: {totalShares2 + totalSharesAtomVault}, \
      totalAssets: {totalAssets2 + totalAssetsAtomVault}, \
      protocolVaultAssets: {protocolVaultAssets2} \
    }}) \
  }}));".replace("  ", ''))
