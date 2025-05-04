Official repository of PharosSwap, a veDEX on PHAROS CHAIN

### Features

-   100% Protocol fees distributed to users
-   Efficient Swap Router
-   Launchpad for Fair Launches on PHAROS CHAIN

```
forge build
forge test -vvvv
forge script script/deploy.pharos.sol:DeployScript --rpc-url https://devnet.dplabs-internal.com --broadcast -vvvv 
```

### Contract Addresses Deployed on Open Campus Sepolia
| Name                           | Address                                    |
|--------------------------------|--------------------------------------------|
| Vault (Router)                | 0xb91465A7cAc67eBCcCC218484205711713E587Bd |
| Lens                          | 0xa3C18F3E08b71774b96a544C58Ecc363efF07701 |
| Volatile Pool Factory         | 0x0F2AC9b59F51018Afcf47ae8a1e154Ad9A5Dbe10 |
| Stable Pool Factory           | 0x9FfC95Db1E18fBfE3DcC4CBb237DA28269111a52 |
| $PHAROS                       | 0x716e5aa44BC37c54C7dc9427Ef4344AB5EA3a967 |
| $vePHAROS                     | 0x5E338E6b8Cab4EC02f636919AFB990c0CE7089E8 |
| $WPTT                         | 0x2fDf50e10927333c73a2F8ceC708018b3C3fD19a |
| $USDC                         | 0xE1B2057710A262F4aFb49636bCe05EE2b593f3b0 |
| Authorizer Contract For Diamond | 0xC4ab0e3878a866e430ae334b71117A434A376758 |
| Linear Bribe Factory          | 0x2e4E0f848b477b3c9D12024579404a15F0417F4d |

### Architecture Overview

![Architecture](https://github.com/user-attachments/assets/28ddd326-5985-4989-a153-994f59cc3cd0)

![Architecture_1](https://github.com/user-attachments/assets/ee593e60-dcf3-458b-a89f-9d70057845a9)

