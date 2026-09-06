// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BeggingContract {
    mapping(address => uint256) public donations;
    address[] public donors;
    address public owner;
    event Donation(address indexed donor, uint256 amount, uint256 timestamp);
    event Withdrawal(address indexed owner, uint256 amount);

    uint256 public donationStartTime;
    uint256 public donationEndTime;
    bool public timeLimiteEnabled = false;

    modifier onlyowner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    modifier withinTimeLimit() {
        if (timeLimiteEnabled) {
            require(
                block.timestamp > donationStartTime &&
                    block.timestamp <= donationEndTime,
                "Donation is not within the allowed time period"
            );
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function donate() public payable withinTimeLimit {
        require(msg.value > 0, "Donation amount must be greater than 0");

        if (donations[msg.sender] == 0) {
            donors.push(msg.sender);
        }

        donations[msg.sender] += msg.value;

        emit Donation(msg.sender, msg.value, block.timestamp);
    }

    function withdraw() public onlyowner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available to withdraw");

        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Withdrawal failed");

        emit Withdrawal(owner, balance);
    }

    function getDonation(address donor) public view returns (uint256) {
        return donations[donor];
    }

   function getTotalFunds() public view returns (uint256) {
        return address(this).balance;
    }

    function getDonorCount()public view returns(uint256) {
        return donors.length;
    }

    function getTopDonors()public view returns(address[3] memory,uint256[3] memory) {
        address[3] memory topDonorsAddresses;
        uint256[3] memory topDonorsAmounts;

        for (uint256  i = 0;  i < donors.length;  i++) {
            uint256 amount=donations[donors[i]];

            for (uint256 j = 0; j<3; j++) {
                if(amount>topDonorsAmounts[j]){
                    if (j<2) {
                        topDonorsAmounts[2]=topDonorsAmounts[1];
                        topDonorsAddresses[2]=topDonorsAddresses[1];
                    }
                    if(j<1){
                        topDonorsAddresses[1]=topDonorsAddresses[0];
                        topDonorsAmounts[1]=topDonorsAmounts[0];
                    }

                    topDonorsAmounts[j]=amount;
                    topDonorsAddresses[j]=donors[i];
                    break;
                }
            }
        }
        return(topDonorsAddresses,topDonorsAmounts);
    }

    function setDonationTimeLimit(uint256 startTime,uint256 endTime)public onlyowner {
        require(endTime>startTime,"End time must be after start time");
        donationStartTime=startTime;
        donationEndTime=endTime;
        timeLimiteEnabled=true;
    }

    function disableTimeLimit() public onlyowner{
        timeLimiteEnabled=false;
    }

    receive() external payable{
        donate();
    }
}
