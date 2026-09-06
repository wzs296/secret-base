// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting{
    mapping(bytes32=>uint256) private votes;
    bytes32[] private candidates;

    function addCandidate(bytes32 candidate) external{
        uint256 len =candidates.length;
        for(uint i=0;i<len;i++){
            if(candidates[i]==candidate){
                return;
            }
        }
        candidates.push(candidate);
    }
    function vote(bytes32 candidate) external{
        votes[candidate]++;
    }
    function getVotes(bytes32 candidate)external view returns(uint256){
        return votes[candidate];
    }
    function resetVores()external{
        uint256 len=candidates.length;
        for(uint256 i=0;i<len;i++){
            votes[candidates[i]]=0;
        }
    }
}

