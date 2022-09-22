#!/bin/bash

#colors
GREEN='\033[0;32m'
BGREEN='\033[1;32m'
NC='\033[0m'

WASM_ADDR=wasm1ll3s59aawh0qydpz2q3xmqf6pwzmj24t8l43cp
OSMO_ADDR=osmo1ll3s59aawh0qydpz2q3xmqf6pwzmj24t9ch58c
PASSWORD=1234567890

# upload and init CW721 on wasmd (wasmd address)
echo -e "${BGREEN}START: ${GREEN} Upload and init CW721 on wasmd ${NC}"

cw721_init_msg=$( jq -n \
            --arg addr $WASM_ADDR \
            '{name: "Testnet", symbol: "TN", minter: $addr}' )

read -r WASM_CW721_ADDR WASM_CW721_CODE_ID < <(./upload_init.sh -d wasmd -c cw721.wasm -i "$cw721_init_msg" | jq -r '.contract_address + "\t" + (.code_id | tostring)' )

# echo $WASM_CW721_CODE_ID
# echo $WASM_CW721_ADDR

# upload CW721 on osmo (osmo address)
echo -e "\n${BGREEN}START: ${GREEN} Upload CW721 on osmosis ${NC}"

OSMO_CW721_CODE_ID=$(./upload.sh -d osmosis -c cw721.wasm | jq '.["code_id"]')

# upload and init ics721 on wasmd
echo -e "\n${BGREEN}START: ${GREEN} Upload and init ICS721 on wasm ${NC}"

wasm_ics721_init_msg=$( jq -n \
            --argjson code_id $WASM_CW721_CODE_ID \
            '{cw721_base_code_id: $code_id}')

read -r WASM_ICS721_ADDR WASM_ICS721_CODE_ID < <(./upload_init.sh -d wasmd -c ics721.wasm -i "$wasm_ics721_init_msg" | jq -r '.contract_address + "\t" + (.code_id | tostring)' )

# echo $WASM_ICS721_CODE_ID
# echo $WASM_ICS721_ADDR

# upload and init ics721 on osmosis
echo -e "\n${BGREEN}START: ${GREEN} Upload and init ICS721 on osmosis ${NC}"

osmo_ics721_init_msg=$( jq -n \
            --argjson code_id $OSMO_CW721_CODE_ID \
            '{cw721_base_code_id: $code_id}' )

read -r OSMO_ICS721_ADDR OSMO_ICS721_CODE_ID < <(./upload_init.sh -d osmosis -c ics721.wasm -i "$osmo_ics721_init_msg" | jq -r '.contract_address + "\t" + (.code_id | tostring)' )

# echo $OSMO_ICS721_CODE_ID
# echo $OSMO_ICS721_ADDR

# open channel between ICS721
echo -e "\n${BGREEN}START: ${GREEN} Open channel between both ICS721 (wasmd <-> osmosis) ${NC}"

read -r WASM_CHANNEL_ID OSMO_CHANNEL_ID < <(./open_channel.sh -ac $WASM_ICS721_ADDR -bc $OSMO_ICS721_ADDR -cv ics721-1 | jq -cr '.wasm.channel_id + "\t" + .osmo.channel_id' )

# echo $WASM_CHANNEL_ID
# echo $OSMO_CHANNEL_ID

# mint NFTs on wasmd to be ready for send
echo -e "\n${BGREEN}START: ${GREEN} Mint 10 NFTs for testing ${NC}"

for ((i = 1; i < 11; ++i)); do
    NFT_JSON=$( jq -cn \
            --arg token_id $i \
            --arg owner $WASM_ADDR \
            '{mint: {token_id: $token_id, owner: $owner, token_uri: "test"}}' )

    RES=$(echo "$PASSWORD" | docker exec -i wasmd wasmd tx wasm execute $WASM_CW721_ADDR \
    $NFT_JSON --from $WASM_ADDR \
    --chain-id wasmd-1 --gas-prices 0.1ucosm --gas auto --gas-adjustment 1.3 -b block -y --output json| jq -cr '.["logs"]')
done

# output addresses
echo "\n" $( jq -n --color-output \
            --arg wasm_ics721 $WASM_ICS721_ADDR \
            --arg wasm_ics721_code_id $WASM_ICS721_CODE_ID \
            --arg wasm_cw721 $WASM_CW721_ADDR \
            --arg wasm_cw721_code_id $WASM_CW721_CODE_ID \
            --arg wasm_channel_id $WASM_CHANNEL_ID \
            --arg osmo_ics721 $OSMO_ICS721_ADDR \
            --arg osmo_ics721_code_id $OSMO_ICS721_CODE_ID \
            --arg osmo_cw721_code_id $OSMO_CW721_CODE_ID \
            --arg osmo_channel_id $OSMO_CHANNEL_ID \
            '{wasm: {cw721_addr: $wasm_cw721, 
                cw721_code_id: $wasm_cw721_code_id, 
                ics721_code_id: $wasm_ics721_code_id, 
                ics721_addr: $wasm_ics721,
                channel_id: $wasm_channel_id},
            osmo: {ics721_addr: $osmo_ics721, 
                ics721_code_id: $osmo_ics721_code_id, 
                cw721_code_id: $osmo_cw721_code_id,
                channel_id: $osmo_channel_id}}')