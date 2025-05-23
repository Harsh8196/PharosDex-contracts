// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Upgrade.sol";
import "contracts/AdminFacet.sol";
import "contracts/SwapFacet.sol";
import "contracts/SwapAuxillaryFacet.sol";
import "contracts/pools/vc/PHAS.sol";
import "contracts/pools/vc/vePHAS.sol";
import "contracts/pools/converter/WETHConverter.sol";
import "contracts/pools/wombat/WombatPool.sol";
import "contracts/MockERC20.sol";
import "contracts/lens/Lens.sol";
import "contracts/NFTHolderFacet.sol";
import "contracts/InspectorFacet.sol";
import "contracts/SwapHelperFacet.sol";
import "contracts/SwapHelperFacet2.sol";
import "contracts/lens/VelocoreLens.sol";
import "contracts/pools/xyk/XYKPoolFactory.sol";
import "contracts/pools/constant-product/ConstantProductPoolFactory.sol";
import "contracts/pools/linear-bribe/LinearBribeFactory.sol";
import "contracts/authorizer/SimpleAuthorizer.sol";
import "contracts/MockERC20.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "contracts/SwapHelperFacet2.sol";
import "contracts/lib/Token.sol";

contract Placeholder is ERC1967Upgrade {
    address immutable admin;

    constructor() {
        admin = msg.sender;
    }

    function upgradeTo(address newImplementation) external {
        require(msg.sender == admin, "not admin");
        ERC1967Upgrade._upgradeTo(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external {
        require(msg.sender == admin, "not admin");
        ERC1967Upgrade._upgradeToAndCall(newImplementation, data, true);
    }
}

contract Deployer {
    function deployAndCall(bytes memory bytecode, bytes memory cd) external returns (address) {
        address deployed;
        bool success;
        assembly ("memory-safe") {
            deployed := create(0, add(bytecode, 32), mload(bytecode))
            success := call(gas(), deployed, 0, add(cd, 32), mload(cd), 0, 0)
        }
        require(deployed != address(0) && success);
        return deployed;
    }
}

contract DeployScript is Script {
    Deployer public deployer;
    Placeholder public placeholder_;
    IVault public vault;
    PharosSwap public vc;
    VePharosSwap public veVC;
    MockERC20 public oldVC;
    WombatPool public wombat;
    XYKPoolFactory public cpf;
    StableSwapPoolFactory public spf;
    IAuthorizer public auth;
    AdminFacet public adminFacet;
    LinearBribeFactory public lbf;
    WETHConverter public wethConverter;
    VelocoreLens public lens;
    MockERC20 public crvUSD;
    MockERC20 public PTT_USDC;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = 0xff7F2575141EE08Bf774fDAD938a0c2b025B8B77;
        vm.startBroadcast(deployerPrivateKey);
        deployer = new Deployer();
        placeholder_ = new Placeholder();
        auth = new SimpleAuthorizer();
        adminFacet = new AdminFacet(auth, deployerAddress);

        vault = IVault(adminFacet.deploy(vm.getCode("Diamond.sol:Diamond")));

        vc = PharosSwap(placeholder());
        veVC = VePharosSwap(placeholder());
        lbf = new LinearBribeFactory(vault);
        address wptt = address(WPTT_ADDRESS);
        wethConverter = new WETHConverter(vault, IWETH(wptt));
        lbf.setFeeToken(toToken(veVC));
        lbf.setFeeAmount(1000e18);
        lbf.setTreasury(deployerAddress);
        SimpleAuthorizer(address(auth)).grantRole(
            keccak256(abi.encodePacked(bytes32(uint256(uint160(address(vault)))), IVault.attachBribe.selector)),
            address(lbf)
        );

        //Volatile Pool factory
        cpf = new XYKPoolFactory(vault);
        //Stable Pool factory
        spf = new StableSwapPoolFactory(vault);
        cpf.setFee(0.01e9);
        spf.setFee(0.0005e9);
        lens = VelocoreLens(address(new Lens(vault)));
        Lens(address(lens)).upgrade(
            address(
                new VelocoreLens(
                    NATIVE_TOKEN,
                    vc,
                    XYKPoolFactory(address(cpf)),
                    spf,
                    XYKPoolFactory(address(cpf)),
                    VelocoreLens(address(lens))
                )
            )
        );

        vault.admin_addFacet(new SwapFacet(vc, IWETH(wptt), toToken(veVC)));
        vault.admin_addFacet(new SwapAuxillaryFacet(vc, toToken(veVC)));

        vault.admin_addFacet(new NFTHolderFacet());
        vault.admin_addFacet(new InspectorFacet());

        SwapHelperFacet swapHelperFaucet = new SwapHelperFacet(address(vc), cpf, spf);
        vault.admin_addFacet(swapHelperFaucet);

        SwapHelperFacet2 swapHelperFacet2 = new SwapHelperFacet2(address(vc), cpf, spf);
        vault.admin_addFacet(swapHelperFacet2);

        Placeholder(address(vc)).upgradeToAndCall(
            address(new PharosSwap(address(vc), vault, address(veVC))), abi.encodeWithSelector(PharosSwap.initialize.selector)
        );

        Placeholder(address(veVC)).upgradeToAndCall(
            address(new VePharosSwap(address(veVC), vault, vc)), abi.encodeWithSelector(VePharosSwap.initialize.selector)
        );

        IERC20 usdc = IERC20(0xE1B2057710A262F4aFb49636bCe05EE2b593f3b0);

        XYKPool ptt_vc_lp = cpf.deploy(NATIVE_TOKEN, toToken(vc));
        XYKPool usdc_vc_lp = cpf.deploy(toToken(vc), toToken(usdc));

        vc.approve(address(vault), 110_000 ether);
        usdc.approve(address(vault), 11_000 ether);

        vault.execute1(address(vc), 0, address(vc), 0, 0, "");

        // Add liquidity to the ptt_vc_lp
        SwapHelperFacet2(address(vault)).addLiquidity{value: 0.1 ether}(
            address(0), address(vc), false, 0.1 ether, 10_000 ether, 0, 0, deployerAddress, type(uint256).max
        );

        // Add liquidity to the usdc_vc_lp
        SwapHelperFacet2(address(vault)).addLiquidity(
            address(usdc), address(vc), false, 10_000 ether, 100_000 ether, 0, 0, deployerAddress, type(uint256).max
        );

        vm.stopBroadcast(); 
        console.log("authorizer: %s", address(auth));
        console.log("IVault: %s", address(vault));
        console.log("Lens: %s", address(lens));

        console.log("cpf: %s", address(cpf));
        console.log("spf: %s", address(spf));
        console.log("vc: %s", address(vc));
        console.log("veVC: %s", address(veVC));
        console.log("LinearBribeFactory: %s", address(lbf));
        console.log("WPTT: %s", address(wptt));
        console.log("WPTTConverter: %s", address(wethConverter));
        console.log("ptt_vc_lp: %s", address(ptt_vc_lp));
        console.log("usdc_vc_lp: %s", address(usdc_vc_lp));
    }

    function placeholder() internal returns (address) {
        //return deployer.deployAndCall(vm.getCode("DumbProxy.yul:DumbProxy"), abi.encode(placeholder_));

        return deployer.deployAndCall(
            hex"604e80600c6000396000f3fe7f360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc805480363d3d37603257506000519055005b3d903d9036903d905af43d6000803e6049573d6000fd5b3d6000f3",
            abi.encode(placeholder_)
        );
    }
}