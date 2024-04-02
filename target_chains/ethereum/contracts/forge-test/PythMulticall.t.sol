pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythErrors.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./utils/WormholeTestUtils.t.sol";
import "./utils/PythTestUtils.t.sol";
import "./utils/RandTestUtils.t.sol";
import "@pythnetwork/pyth-sdk-solidity/PythMulticall.sol";
import "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";

contract PythMulticallTest is Test {
    MockPyth public pyth;
    SampleContract public multicallable;
    bytes32 constant ID = bytes32(uint256(0x1));

    function setUp() public {
        pyth = new MockPyth(60, 1);
        multicallable = new SampleContract(address(pyth), ID);
    }

    function priceFeedUpdateHelper(
        int64 price
    ) internal returns (bytes[] memory priceFeedUpdates) {
        priceFeedUpdates = new bytes[](1);
        priceFeedUpdates[0] = pyth.createPriceFeedUpdateData(
            ID,
            price,
            0,
            0,
            0,
            0,
            uint64(block.timestamp),
            uint64(block.timestamp)
        );
    }

    function testApproach1() public {
        bytes[] memory updateData = priceFeedUpdateHelper(123);
        uint fee = pyth.getUpdateFee(updateData);
        vm.deal(address(this), fee);
        console2.log("sending tx");
        console2.log(address(this));

        bytes memory call = abi.encodeCall(SampleContract.approach1, ());
        multicallable.updateFeedsAndCall{value: fee}(updateData, call);
    }

    function testApproach2() public {
        bytes[] memory updateData = priceFeedUpdateHelper(123);
        uint fee = pyth.getUpdateFee(updateData);
        vm.deal(address(this), fee);
        console2.log("sending tx");
        console2.log(address(this));

        multicallable.approach2{value: fee}(updateData);
    }
}

contract SampleContract is PythMulticall {
    IPyth pyth;
    bytes32 id;
    int64 counter = 0;

    constructor(address _pyth, bytes32 _id) {
        pyth = IPyth(_pyth);
        id = _id;
    }

    function pythAddress() internal override returns (address p) {
        p = address(pyth);
    }

    // One problem with approach 1 is that this method must be marked payable even though it use msg.value.
    // It needs to be payable because the multicall's delegatecall passes a nonzero msg.value to it.
    function approach1() external payable returns (int64) {
        counter += pyth.getPriceUnsafe(id).price;
        return counter;
    }

    function approach2(
        bytes[] calldata pythPrices
    ) external payable withPyth(pythPrices) returns (int64) {
        counter += pyth.getPriceUnsafe(id).price;
        return counter;
    }
}
