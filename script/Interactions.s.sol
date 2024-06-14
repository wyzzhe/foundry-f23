// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

// 这是一个空投脚本，白名单为mostRecentlyDeployedFundMe的人
contract FundFundMe is Script {
    uint256 constant SEND_VALUE = 0.01 ether;

    // fundFundMe函数模版
    function fundFundMe(address mostRecentlyDeployed) public {
        // vm是Foundry虚拟机
        // 模拟交易
        vm.startBroadcast();
        // 向最近给我Fund的人发0.01ether的空投
        FundMe(payable(mostRecentlyDeployed)).fund{value: SEND_VALUE}();
        vm.stopBroadcast();
        console.log("Funded FundMe with %s", SEND_VALUE);
    }

    function run() external {
        // 找出最近FundMe的人
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "FundMe",
            block.chainid
        );
        // fundFundMe函数实例化
        fundFundMe(mostRecentlyDeployed);
    }
}

contract WithdrawFundMe is Script {}
