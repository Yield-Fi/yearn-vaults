// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract VaultConfig {
    using SafeMath for uint256;

    address public governance = 0x1F0F7336d624656b71367A1F330094496ccb03ed;
    address public pendingGovernance;
    address public management;
    address public guardian;
    address public partner;
    address public partnerFeeRecipient;
    address public approver;
    address public rewards;

    mapping (address => bool) isWhitelisted;

    mapping (address => uint256) partnerFees;
    mapping (address => uint256) managementFees;
    mapping (address => uint256) performanceFees;

    uint256 public constant MAX_BPS = 10000;

    event Configured (
        address indexed partner, address indexed management, address guardian, address rewards, address approver
        );
    event PerformanceFeeUpdated(address indexed vault, uint256 newFee);
    event ManagementUpdated(address indexed from, address indexed management);
    event ManagementFeeUpdated(address indexed vault, uint256 newFee);
    event PartnerFeeUpdated(address indexed vault, uint256 newFee);
    event PartnerUpdated(address indexed from, address indexed partner);
    event PartnerFeeRecipientUpdated (address indexed from, address indexed recipient);
    event ApproverUpdated (address indexed from, address indexed approver);
    event GuardianUpdated (address indexed from, address indexed guardian);
    event GovernanceUpdated (address indexed newGov, address indexed oldGov);
    event RewardRecipientUpdated (address indexed reward);

    modifier onlyGov () {
        require(msg.sender == governance, "feeConfig/unauthorised gov");
        _;
    }
    modifier onlyPartner () {
        require(msg.sender == partner, "feeConfig/unauthorised partner");
        _;
    }
    modifier onlyPendingGov () {
        require(msg.sender == pendingGovernance, "feeConfig/not a pendng gov");
        _;
    }

    constructor () public {
        governance = msg.sender;
    }

    function config (address _partner, address _management, address _guardian, address _rewards, address _approver) public onlyGov {
        partner = _partner;
        partnerFeeRecipient = _partner;
        management = _management;
        guardian = _guardian;
        rewards = _rewards;
        approver = _approver;
        emit Configured(_partner, _management, _guardian, _rewards, _approver);
    }

    function updatePartner (address _partner ) public onlyGov {
        partner = _partner;
        partnerFeeRecipient = _partner;
        emit PartnerUpdated(msg.sender ,_partner);
    }

    function updatePartnerFeeRecipient (address _recipient) public onlyPartner {
        partnerFeeRecipient = _recipient;
        emit PartnerFeeRecipientUpdated(msg.sender, _recipient);
    }

    function updatePartnerFee (address _vault, uint256 _partnerFee) public {
        require(
            msg.sender == governance ||
            msg.sender ==  partner,
            "feeConfig/unauthorised to update partner fee"
        );
        require(MAX_BPS > _partnerFee, "feeConfig/invalid partner fee");
        partnerFees[_vault] = _partnerFee;
        emit PartnerFeeUpdated(_vault, _partnerFee);
    }

    function updatePerformanceFee (address _vault,uint256 _performanceFee) public onlyGov {
        require(MAX_BPS.div(2) > _performanceFee, "feeConfig/invalid managementFee");
        performanceFees[_vault] = _performanceFee;
        emit PerformanceFeeUpdated(_vault,_performanceFee);
    }

    function updateManagement (address _newManagement) public onlyGov {
        require(_newManagement != address(0), "feeConfig/invalid management address");
        management = _newManagement;
        emit ManagementUpdated(msg.sender, _newManagement);
    }

    function updateManagementFee (address _vault, uint256 _managementFee) public onlyGov {
        require(MAX_BPS > _managementFee, "feeConfig/invalid managementFee");
        managementFees[_vault] = _managementFee;
        emit ManagementFeeUpdated(_vault,_managementFee);
    }

    function updateGuardian (address _newGuardian) public onlyGov {
        require(_newGuardian != address(0), "feeConfig/invalid guardian");
        guardian = _newGuardian;
        emit GuardianUpdated(msg.sender, _newGuardian);
    }

    function updateApprover (address _newApprover) public onlyGov {
        require(_newApprover != address(0), "feeConfig/invalid approver");
        approver = _newApprover;
        emit ApproverUpdated(msg.sender, _newApprover);
    }
    function updateRewards (address _newRewards) public onlyGov {
        require(_newRewards != address(0), "feeConfig/invalid reward recipient");
        rewards = _newRewards;
        emit RewardRecipientUpdated(_newRewards);
    }

    function proposeNewGoverner (address newGov) public onlyGov {
        pendingGovernance = newGov;
    }

    function acceptGovernance () public onlyPendingGov {
        emit GovernanceUpdated(pendingGovernance, governance);
        governance = pendingGovernance;
        pendingGovernance = address(0);
    }

    function getManagementFee (address _vault) public view returns (uint256 fee) {
        fee = managementFees[_vault];
        if(fee == 0)
            fee = 200;
    }

    function getPerformanceFee (address _vault) public view returns (uint256 fee) {
        fee = performanceFees[_vault];
        if (fee == 0)
            fee = 1000;
    }

    function getPartnerFee (address _vault) public view returns (uint256 fee) {
        fee = partnerFees[_vault];
    }

    function whitelist (address _toWhitelist) public {
        require(
            msg.sender == governance ||
            msg.sender ==  partner,
            "feeConfig/unauthorised to whitelist"
        );
        require(_toWhitelist != address(0), "feeConfig/invalid address to whitelist");
        require(!isWhitelisted[_toWhitelist], "feeConfig/already whitelisted");
        isWhitelisted[_toWhitelist] = true;
    }

    function cancelWhitelist (address _toCancel) public {
        require(
            msg.sender == governance ||
            msg.sender ==  partner,
            "feeConfig/unauthorised to whitelist"
        );
        require(_toCancel != address(0), "feeConfig/invalid address to cancel whitelisting");
        isWhitelisted[_toCancel] = false;
    }

    function bulkWhitelist (address [] calldata _toWhitelists) public {
        require(
            msg.sender == governance ||
            msg.sender ==  partner,
            "feeConfig/unauthorised to whitelist"
        );
        uint256 length = _toWhitelists.length;
        for (uint256 i = 0; i < length ;i++) {
            address tmp = _toWhitelists[i];
            if(tmp != address(0) && isWhitelisted[tmp]) {
                isWhitelisted[tmp] = true;
            }
        }
    }

}