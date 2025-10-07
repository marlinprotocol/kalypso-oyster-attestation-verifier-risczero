#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined variable, and error in pipelines

# Function to verify the existence of required binaries
check_all_binaries_exist() {
    echo "Verifying the presence of required binaries..."

    # Define the list of required binaries
    REQUIRED_BINARIES=("test-connection" "benchmark" "kalypso-attestation-prover" "kalypso-cli")

    # Initialize an array to hold any missing binaries
    MISSING_BINARIES=()

    # Iterate over each required binary and check its existence and executability
    for binary in "${REQUIRED_BINARIES[@]}"; do
        if [ ! -x "./$binary" ]; then
            MISSING_BINARIES+=("$binary")
        fi
    done

    # If there are missing binaries, display an error and exit
    if [ "${#MISSING_BINARIES[@]}" -ne 0 ]; then
        echo "Error: The following required binaries are missing or not executable in the current directory:"
        for missing in "${MISSING_BINARIES[@]}"; do
            echo "  - $missing"
        done
        echo "Please ensure that all build steps completed successfully and the binaries are executable."
        exit 1
    else
        echo "All required binaries are present and executable in the current directory."
    fi
}

# Function to display usage instructions
usage() {
  echo "Usage: $0 {register-join|benchmark|test-connection|run-prover|symbiotic-stake|native-stake|claim-rewards|discard-request|read-stake|symbiotic-register|set-operator-meta|request-stake-withdrawal|read-pending-withdrawals|process-pending-withdrawals|check-reward|request-marketplace-exit}"
  echo
  echo "Options:"
  echo "  benchmark                      Run benchmark tests"
  echo "  check-reward                   Check Available Rewards"
  echo "  claim-rewards                  Claim Rewards"
  echo "  discard-request                Discard Request"
  echo "  leave-marketplace              Exit Marketplace"
  echo "  native-stake                   Stake your own tokens"
  echo "  process-pending-withdrawals    Process Pending Withdrawals"
  echo "  read-pending-withdrawals       Read Pending Withdrawals"
  echo "  read-stake                     Read Stake data"
  echo "  register-join                  Register and join the network"
  echo "  request-marketplace-exit       Request To Leave Marketplace"
  echo "  request-stake-withdrawal       Request Stake Withdrawal"
  echo "  run-prover                     Execute the prover service"
  echo "  set-operator-meta              Set Operator data"
  echo "  symbiotic-register             Register Operator with symbiotic"
  echo "  symbiotic-stake                Request Symbiotic Stake"
  echo "  test-connection                Test network connection"
  exit 1
}

# Cleanup function to handle termination
cleanup() {
  echo "Received termination signal. Cleaning up..."
  
  # Add any necessary cleanup commands here
  # For example, kill background processes if any
  # pkill -P $$  # Kills all child processes spawned by this script
  
  exit 0
}

# Trap SIGINT (Ctrl+C) and SIGTERM
trap cleanup SIGINT SIGTERM

# Verify binaries before proceeding
check_all_binaries_exist

# Check if at least one argument is provided
if [ $# -lt 1 ]; then
  echo "Error: No option provided."
  usage
fi

# Capture the first argument as the operation
OPERATION="$1"

# Export necessary environment variables
export CHAIN_ID="42161"
export PROOF_MARKETPLACE_ADDRESS="0xE68A7457c0fd11CcBe96126Bf69B27a9064636a2"
export GENERATOR_REGISTRY_ADDRESS="0xEcF45b1272D3B0ed2eB2A3c85b1E4bBa8a3611D6"
export ENTITY_KEY_REGISTRY_ADDRESS="0x9C0Da9ac6B563A87CAf6F5b49f58f3C6D8D9BDef"
export START_BLOCK="384000000"
export MARKET_ID="1"
export INDEXER_URL="https://indexer.kalypso.org"

export STAKING_TOKEN="0xdA0a57B710768ae17941a9Fa33f8B720c8bD9ddD"
export PAYMENT_TOKEN="0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
export NATIVE_STAKING_ADDRESS="0xd96418F0507F992E2a33942e54FA832ba3d2287e"

# Execute based on the selected operation
case "$OPERATION" in
  register-join)
    # Temporarily disable exit on error for multistep process
    set +e

    export DECLARED_COMPUTE="10"
    export COMPUTE_PER_REQUEST="10"
    
    echo "Starting registration and joining process..."
    
    # Run the first operation
    OPERATION_NAME="Register" ./kalypso-cli
    REGISTER_STATUS=$?
    echo "Registration process completed with exit status $REGISTER_STATUS"
    
    # Run the second operation regardless of the first one's result
    OPERATION_NAME="Join Marketplace" ./kalypso-cli
    JOIN_STATUS=$?
    echo "Join Marketplace process completed with exit status $JOIN_STATUS"
    
    # Re-enable exit on error
    set -e
    ;;

  request-marketplace-exit)
    # Temporarily disable exit on error for multistep process
    set +e
    
    # Run the first operation
    OPERATION_NAME="Request To Leave Marketplace" ./kalypso-cli
    STATUS=$?
    echo "Request to leave marketplace with exit status $STATUS"

    # Re-enable exit on error
    set -e
    ;;

  leave-marketplace)
    # Temporarily disable exit on error for multistep process
    set +e
    
    # Run the first operation
    OPERATION_NAME="Leave Marketplace" ./kalypso-cli
    STATUS=$?
    echo "Leave marketplace with exit status $STATUS"

    # Re-enable exit on error
    set -e
    ;;
  
  benchmark)
    echo "Running benchmark tests..."
    # Add your benchmark commands below
    RUST_BACKTRACE=1 ./benchmark &
    BENCHMARK_PID=$!
    wait "$BENCHMARK_PID"
    ;;
  
  test-connection)
    echo "Testing network connection..."
    # Add your connection test commands below
    # ./test-connection --url "http://3.110.146.109:1500/attestation/raw" &
    ./test-connection --url "https://attestation.ivs.nitro.kalypso.org/attestation/raw" &
    HOST_PID=$!
    wait "$HOST_PID"
    ;;
  
  run-prover)
    export MAX_PARALLEL_PROOFS="1"
    export IVS_URL="http://3.110.146.109:3030"
    export PROVER_PORT=2020
    export PROMETHEUS_PORT=8888
    export POLLING_INTERVAL=10000
    
    echo "Executing the prover service..."
    # Add your prover execution commands below
    ./kalypso-attestation-prover &
    PROVER_PID=$!
    wait "$PROVER_PID"
    ;;
  
  symbiotic-stake)
    echo "Starting symbiotic stake request..."
    export SYMBIOTIC_CHAIN_ID="1"
    export VAULT_OPT_IN_SERVICE="0xb361894bC06cbBA7Ea8098BF0e32EB1906A5F891"
    export NETWORK_OPT_IN_SERVICE="0x7133415b33B438843D581013f98A08704316633c"
    
    OPERATION_NAME="Request Symbiotic Stake" ./kalypso-cli &
    SYM_PID=$!
    # Wait for background processes to finish
    wait "$SYM_PID"
    ;;

  native-stake)
    echo "Native Staking"

    OPERATION_NAME="Native Stake" ./kalypso-cli &
    NAT_PID=$!
    # Wait for background processes to finish
    wait "$NAT_PID"
    ;;

  claim-rewards)
    echo "Claim Rewards"

    OPERATION_NAME="Claim Rewards" ./kalypso-cli &
    CLAIM_ID=$!
    # Wait for background processes to finish
    wait "$CLAIM_ID"
    ;;

  discard-request)
    echo "Discard Request"

    OPERATION_NAME="Discard Request" ./kalypso-cli &
    D_ID=$!
    # Wait for background processes to finish
    wait "$D_ID"
    ;;

  symbiotic-register)
    echo "Register Operator with symbiotic"

    export SYMBIOTIC_CHAIN_ID="1"
    export SYMBIOTIC_OPERATOR_REGISTRY="0xAd817a6Bc954F678451A71363f04150FDD81Af9F"

    OPERATION_NAME="Symbiotic Operator Register" ./kalypso-cli &
    S_ID=$!
    # Wait for background processes to finish
    wait "$S_ID"
    ;;

  read-stake)
    echo "Read Operator Stake data"

    OPERATION_NAME="Read Stake Data" ./kalypso-cli &
    S_ID=$!
    # Wait for background processes to finish
    wait "$S_ID"
    ;;

  set-operator-meta) 
    echo "Update Operator Metadata"

    GENERATOR_META_JSON="./generatormeta.json"

    if [ ! -f "$GENERATOR_META_JSON" ]; then
      echo "Error: $GENERATOR_META_JSON NOT FOUND"
      exit 1
    else
      echo "Updating Operator Metadata from $GENERATOR_META_JSON"
    fi
    
    OPERATION_NAME="Update Generator Metadata" ./kalypso-cli &
    S_ID=$!
    # Wait for background processes to finish
    wait "$S_ID"
    ;;

  request-stake-withdrawal)
    echo "Request Stake Withdrawal"

    OPERATION_NAME="Request Native Stake Withdrawal" ./kalypso-cli &
    S_ID=$!
    # Wait for background processes to finish
    wait "$S_ID"
    ;;
    

  read-pending-withdrawals)
    echo "Read Pending Withdrawals"

    OPERATION_NAME="Read Native Staking Pending Withdrawals" ./kalypso-cli &
    S_ID=$!
    # Wait for background processes to finish
    wait "$S_ID"
    ;;

  process-pending-withdrawals)
    echo "Process Pending Withdrawals (if any)"
    
    OPERATION_NAME="Process Withdrawal Requests" ./kalypso-cli &
    S_ID=$!
    # Wait for background processes to finish
    wait "$S_ID"
    ;;

  check-reward)
    echo "Check Available Rewards"
    
    OPERATION_NAME="Read Rewards Info" ./kalypso-cli &
    S_ID=$!
    # Wait for background processes to finish
    wait "$S_ID"
    ;;

  *)
    echo "Error: Invalid option '$OPERATION'."
    usage
    ;;
esac
