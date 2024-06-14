// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Note: The AggregatorV3Interface might be at a different location than what was in the video!
// 喂价预言机
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// ETH转USDT
import {PriceConverter} from "./PriceConverter.sol";
// 定义一个自定义错误，当调用者不是合约的所有者时抛出。
error FundMe__NotOwner();

contract FundMe {
    // 使用PriceConverter库，为uint256类型提供扩展功能。
    // using for 语法：使uint256可以调PriceConverter库中的函数
    using PriceConverter for uint256;
    // 定义一个公共映射，将地址映射到它们资助的金额。类似于哈希表
    // public 内外部均可访问 可做函数返回值
    // mapping(KeyType KeyName?(?表示可选) => ValueType ValueName?)
    mapping(address => uint256) public addressToAmountFunded;
    // 定义一个公共动态(变长)数组，存储所有资助者的地址。
    // 如果数组作为状态变量声明（如这里的 public s_funders），它将存储在区块链的存储空间中。如果作为局部变量在函数内声明，它将存储在内存中。
    // 内存中的数据是连续的，存储中的数组不是连续的
    address[] public s_funders;

    // Could we make this constant?  /* hint: no! We should make it immutable! */
    // 定义合约所有者的地址，这是一个不可变的公共变量。
    // i_强调这个变量不可变，是字节码，不在Storage中
    address public /* immutable */ i_owner;
    // 定义一个常量，表示最低资助金额，单位是美元的以太币表示（这里假设1 ETH = 2000 USD）。
    // MINIMUM_USD 大写强调常量，是字节码，不在Storage中
    uint256 public constant MINIMUM_USD = 5 * 10 ** 18;
    // 定义一个私有变量，用于存储价格信息的接口。
    // private只能在合约内部访问
    AggregatorV3Interface private s_priceFeed;
    // 定义构造函数，初始化合约时需要传入价格信息的地址。
    constructor(address priceFeed) {
        // 将合约创建者的地址赋值给i_owner。
        i_owner = msg.sender;
        // 初始化价格信息接口。
        // address priceFeed是实现了AggregatorV3Interface接口的合约地址
        // 这样，s_priceFeed就可以用于调用接口中定义的函数
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    // 定义一个公共函数fund，允许用户向合约发送以太币。
    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "You need to spend more ETH!");
        // require(PriceConverter.getConversionRate(msg.value) >= MINIMUM_USD, "You need to spend more ETH!");
        // 将发送者的资助金额累加到映射中。
        addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }
    // 定义一个公共的只读函数getVersion，返回价格信息接口的版本。
    // view函数修饰符，标识函数不会修改合约状态，不会写入任何数据到区块链，用于读取数据，调用不产生gas费
    function getVersion() public view returns (uint256) {
        // AggregatorV3Interface private s_priceFeed; 接口类型变量
        // function version() external view returns (uint256);
        return s_priceFeed.version();
    }
    // 定义一个修饰符onlyOwner，确保只有合约所有者可以执行修饰的函数。
    modifier onlyOwner() {
        // require(msg.sender == owner);
        // 如果调用者不是合约所有者，则抛出自定义错误。
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    // 对withdraw()的gas费优化
    function cheaperWithdraw() public onlyOwner {
        // 只在Storage中读取一次,函数中的局部变量存储在内存中
        uint256 fundersLength = s_funders.length;
        for(uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++){
            // 此处的数组和映射在Storage中读取，暂时无法优化
            address funder = s_funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    function withdraw() public onlyOwner {
        for (
            uint256 funderIndex = 0; 
            // 每次运行时都会从Storage中读取数组的length
            // 看到s_就代表Storage中的数组，每次运行都要耗费Gas读取值！
            // funderIndex < s_s_funders.length;
            funderIndex < s_funders.length; 
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // // transfer
        // payable(msg.sender).transfer(address(this).balance);

        // // send
        // bool sendSuccess = payable(msg.sender).send(address(this).balance);
        // require(sendSuccess, "Send failed");

        // call
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }
    // Explainer from: https://solidity-by-example.org/fallback/
    // Ether is sent to contract
    //      is msg.data empty?
    //          /   \
    //         yes  no
    //         /     \
    //    receive()?  fallback()
    //     /   \
    //   yes   no
    //  /        \
    //receive()  fallback()

    fallback() external payable {
        fund();
    }

    receive() external payable {
        fund();
    }
}

// Concepts we didn't cover yet (will cover in later sections)
// 1. Enum
// 2. Events
// 3. Try / Catch
// 4. Function Selector
// 5. abi.encode / decode
// 6. Hash with keccak256
// 7. Yul / Assembly