pragma solidity ^0.8.0;

contract MetricsCoordinator {
    address public owner;
    address[] public oracleAddresses;
    mapping(address => bool) public isOracle;

    event OracleAdded(address indexed oracle);
    event OracleRemoved(address indexed oracle);
    event MetricsPushed(address indexed oracle, uint256 metric);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyOracle() {
        require(isOracle[msg.sender], "Only oracle can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addOracle(address _oracle) external onlyOwner {
        require(!isOracle[_oracle], "Oracle already added");
        isOracle[_oracle] = true;
        oracleAddresses.push(_oracle);
        emit OracleAdded(_oracle);
    }

    function removeOracle(address _oracle) external onlyOwner {
        require(isOracle[_oracle], "Oracle not found");
        isOracle[_oracle] = false;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracleAddresses[i] == _oracle) {
                oracleAddresses[i] = oracleAddresses[oracleAddresses.length - 1];
                oracleAddresses.pop();
                break;
            }
        }
        emit OracleRemoved(_oracle);
    }

    function pushMetrics(uint256 _metric) external onlyOracle {
        emit MetricsPushed(msg.sender, _metric);
    }
}
