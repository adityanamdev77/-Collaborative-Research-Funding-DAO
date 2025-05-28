// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Collaborative Research Funding DAO
 * @dev A decentralized platform for funding research projects through community collaboration
 */
contract CollaborativeResearchFundingDAO {
    
    struct ResearchProposal {
        uint256 id;
        address researcher;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 currentFunding;
        uint256 deadline;
        bool isActive;
        bool isCompleted;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    struct ResearchOutcome {
        uint256 proposalId;
        string results;
        bool isVerified;
        uint256 successRating; // 1-10 scale
    }
    
    mapping(uint256 => ResearchProposal) public proposals;
    mapping(uint256 => ResearchOutcome) public outcomes;
    mapping(address => uint256[]) public userContributions;
    
    uint256 public nextProposalId;
    uint256 public constant MIN_CONTRIBUTION = 0.01 ether;
    uint256 public constant PLATFORM_FEE = 5; // 5% platform fee
    
    event ProposalCreated(uint256 indexed proposalId, address indexed researcher, string title, uint256 fundingGoal);
    event ContributionMade(uint256 indexed proposalId, address indexed contributor, uint256 amount);
    event ResearchCompleted(uint256 indexed proposalId, string results, uint256 successRating);
    event RewardsDistributed(uint256 indexed proposalId, uint256 totalRewards);
    
    modifier onlyResearcher(uint256 _proposalId) {
        require(proposals[_proposalId].researcher == msg.sender, "Only researcher can perform this action");
        _;
    }
    
    modifier proposalExists(uint256 _proposalId) {
        require(_proposalId < nextProposalId, "Proposal does not exist");
        _;
    }
    
    /**
     * @dev Core Function 1: Create a new research proposal
     * @param _title Title of the research project
     * @param _description Detailed description of the research
     * @param _fundingGoal Amount of funding needed in wei
     * @param _durationDays Duration of funding period in days
     */
    function createProposal(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _durationDays
    ) external {
        require(_fundingGoal > 0, "Funding goal must be greater than 0");
        require(_durationDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        uint256 proposalId = nextProposalId++;
        ResearchProposal storage newProposal = proposals[proposalId];
        
        newProposal.id = proposalId;
        newProposal.researcher = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.fundingGoal = _fundingGoal;
        newProposal.currentFunding = 0;
        newProposal.deadline = block.timestamp + (_durationDays * 1 days);
        newProposal.isActive = true;
        newProposal.isCompleted = false;
        
        emit ProposalCreated(proposalId, msg.sender, _title, _fundingGoal);
    }
    
    /**
     * @dev Core Function 2: Contribute funding to a research proposal
     * @param _proposalId ID of the proposal to fund
     */
    function contributeToResearch(uint256 _proposalId) external payable proposalExists(_proposalId) {
        require(msg.value >= MIN_CONTRIBUTION, "Contribution below minimum amount");
        
        ResearchProposal storage proposal = proposals[_proposalId];
        require(proposal.isActive, "Proposal is not active");
        require(block.timestamp <= proposal.deadline, "Funding deadline has passed");
        require(proposal.currentFunding < proposal.fundingGoal, "Funding goal already reached");
        
        // Record contribution
        if (proposal.contributions[msg.sender] == 0) {
            proposal.contributors.push(msg.sender);
            userContributions[msg.sender].push(_proposalId);
        }
        
        proposal.contributions[msg.sender] += msg.value;
        proposal.currentFunding += msg.value;
        
        // Check if funding goal is reached
        if (proposal.currentFunding >= proposal.fundingGoal) {
            proposal.isActive = false;
            // Transfer funds to researcher (minus platform fee)
            uint256 platformFee = (proposal.currentFunding * PLATFORM_FEE) / 100;
            uint256 researcherAmount = proposal.currentFunding - platformFee;
            
            payable(proposal.researcher).transfer(researcherAmount);
        }
        
        emit ContributionMade(_proposalId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Submit research results and distribute rewards
     * @param _proposalId ID of the completed proposal
     * @param _results Description of research results
     * @param _successRating Self-assessed success rating (1-10)
     */
    function submitResearchResults(
        uint256 _proposalId,
        string memory _results,
        uint256 _successRating
    ) external onlyResearcher(_proposalId) proposalExists(_proposalId) {
        require(_successRating >= 1 && _successRating <= 10, "Success rating must be between 1-10");
        require(bytes(_results).length > 0, "Results cannot be empty");
        
        ResearchProposal storage proposal = proposals[_proposalId];
        require(!proposal.isActive, "Research funding still active");
        require(!proposal.isCompleted, "Results already submitted");
        require(proposal.currentFunding >= proposal.fundingGoal, "Funding goal not reached");
        
        // Record research outcome
        outcomes[_proposalId] = ResearchOutcome({
            proposalId: _proposalId,
            results: _results,
            isVerified: true,
            successRating: _successRating
        });
        
        proposal.isCompleted = true;
        
        // Distribute rewards to contributors based on success rating
        _distributeRewards(_proposalId, _successRating);
        
        emit ResearchCompleted(_proposalId, _results, _successRating);
    }
    
    /**
     * @dev Internal function to distribute rewards to contributors
     * @param _proposalId ID of the proposal
     * @param _successRating Success rating of the research
     */
    function _distributeRewards(uint256 _proposalId, uint256 _successRating) internal {
        ResearchProposal storage proposal = proposals[_proposalId];
        
        // Calculate reward pool based on success rating (higher rating = more rewards)
        uint256 rewardMultiplier = _successRating; // 1-10%
        uint256 totalRewards = (proposal.currentFunding * rewardMultiplier) / 100;
        
        // Distribute rewards proportionally to contributors
        for (uint256 i = 0; i < proposal.contributors.length; i++) {
            address contributor = proposal.contributors[i];
            uint256 contribution = proposal.contributions[contributor];
            uint256 reward = (totalRewards * contribution) / proposal.currentFunding;
            
            if (reward > 0) {
                payable(contributor).transfer(reward);
            }
        }
        
        emit RewardsDistributed(_proposalId, totalRewards);
    }
    
    // View functions
    function getProposalDetails(uint256 _proposalId) external view proposalExists(_proposalId) returns (
        address researcher,
        string memory title,
        string memory description,
        uint256 fundingGoal,
        uint256 currentFunding,
        uint256 deadline,
        bool isActive,
        bool isCompleted
    ) {
        ResearchProposal storage proposal = proposals[_proposalId];
        return (
            proposal.researcher,
            proposal.title,
            proposal.description,
            proposal.fundingGoal,
            proposal.currentFunding,
            proposal.deadline,
            proposal.isActive,
            proposal.isCompleted
        );
    }
    
    function getContributorCount(uint256 _proposalId) external view proposalExists(_proposalId) returns (uint256) {
        return proposals[_proposalId].contributors.length;
    }
    
    function getUserContribution(uint256 _proposalId, address _user) external view proposalExists(_proposalId) returns (uint256) {
        return proposals[_proposalId].contributions[_user];
    }
    
    function getUserProposals(address _user) external view returns (uint256[] memory) {
        return userContributions[_user];
    }
}
