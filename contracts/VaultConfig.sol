// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract VaultConfig is Initializable {
    using SafeMath for uint256;

    address public governance;
    address public pendingGovernance;
    address public management;
    address public guardian;
    address public partner; //address that collects this partner's rewards
    address public approver; //address that controls this partner's vaults whitelists
    address public rewards;

    mapping (address => bool) public isWhitelisted;

    mapping (address => uint256) public partnerFees;
    mapping (address => uint256) public managementFees;
    mapping (address => uint256) public performanceFees;

    address[] public vaults;

    uint256 public constant MAX_BPS = 10000;

    event Initialized (
        address indexed partner, address indexed management, address guardian, address rewards, address approver
        );
    event VaultAdded(address indexed vault);
    event PerformanceFeeUpdated(address indexed vault, uint256 newFee);
    event ManagementUpdated(address indexed from, address indexed management);
    event ManagementFeeUpdated(address indexed vault, uint256 newFee);
    event PartnerFeeUpdated(address indexed vault, uint256 newFee);
    event PartnerUpdated(address indexed from, address indexed partner);
    event ApproverUpdated (address indexed from, address indexed approver);
    event GuardianUpdated (address indexed from, address indexed guardian);
    event GovernanceUpdated (address indexed newGov, address indexed oldGov);
    event RewardRecipientUpdated (address indexed reward);

    modifier onlyGov () {
        require(msg.sender == governance, "!Gov");
        _;
    }
    modifier onlyPartner () {
        require(
            msg.sender == partner ||
            msg.sender == governance,
            "!Partner"
        );
        _;
    }
    modifier onlyPendingGov () {
        require(msg.sender == pendingGovernance, "!PendingGov");
        _;
    }
    modifier onlyApprover () {
        require(
            msg.sender == approver ||
            msg.sender == governance,
            "!Approver"
        );
        _;
    }

    function initialize (address _gov, address _partner, address _management, address _guardian, address _rewards, address _approver) public reinitializer(3) {
        governance = _gov;
        partner = _partner;
        management = _management;
        guardian = _guardian;
        rewards = _rewards;
        approver = _approver;
        emit Initialized(_partner, _management, _guardian, _rewards, _approver);
    }

    function updatePartner (address _partner ) external onlyGov {
        partner = _partner;
        emit PartnerUpdated(msg.sender ,_partner);
    }

    function updatePartnerFee (address _vault, uint256 _partnerFee) external onlyPartner {
        require(MAX_BPS >= _partnerFee, "VaultConfig: invalid partner fee");
        partnerFees[_vault] = _partnerFee;
        emit PartnerFeeUpdated(_vault, _partnerFee);
    }

    function updatePerformanceFee (address _vault,uint256 _performanceFee) external onlyGov {
        require(MAX_BPS.div(2) >= _performanceFee, "VaultConfig:invalid managementFee");
        performanceFees[_vault] = _performanceFee;
        emit PerformanceFeeUpdated(_vault,_performanceFee);
    }

    function updateManagement (address _newManagement) external onlyGov {
        require(_newManagement != address(0), "VaultConfig:invalid management address");
        management = _newManagement;
        emit ManagementUpdated(msg.sender, _newManagement);
    }

    function updateManagementFee (address _vault, uint256 _managementFee) external onlyGov {
        require(MAX_BPS >= _managementFee, "VaultConfig:invalid managementFee");
        managementFees[_vault] = _managementFee;
        emit ManagementFeeUpdated(_vault,_managementFee);
    }

    function updateGuardian (address _newGuardian) external onlyGov { //FIXME one guardian for all the vaults?
        require(_newGuardian != address(0), "VaultConfig:invalid guardian");
        guardian = _newGuardian;
        emit GuardianUpdated(msg.sender, _newGuardian);
    }

    function updateApprover (address _newApprover) external onlyGov { //FIXME onlyGov, onlyPartner, onlyApprover?
        require(_newApprover != address(0), "VaultConfig:invalid approver");
        approver = _newApprover;
        emit ApproverUpdated(msg.sender, _newApprover);
    }
    function updateRewards (address _newRewards) external onlyGov {
        require(_newRewards != address(0), "VaultConfig:invalid reward recipient");
        // Yearn does not let a vault  be the rewards address, i've extended this to "any vault controlled by this VaultConfig
        for(uint256 i = 0; i < vaults.length; i++) { 
            require(_newRewards != vaults[i], "rewards can't be a vault");
        }
        rewards = _newRewards;
        emit RewardRecipientUpdated(_newRewards);
    }

    function setGovernance (address newGov) external onlyGov {
        pendingGovernance = newGov;
    }

    function acceptGovernance () external onlyPendingGov {
        emit GovernanceUpdated(pendingGovernance, governance);
        governance = pendingGovernance;
        pendingGovernance = address(0);
    }

    function getManagementFee (address _vault) external view returns (uint256) {
        return managementFees[_vault];
    }

    function getPerformanceFee (address _vault) external view returns (uint256) {
        return performanceFees[_vault];
    }

    function getPartnerFee (address _vault) external view returns (uint256) {
        return partnerFees[_vault];
    }

    function whitelist (address _toWhitelist) external onlyApprover {
        require(_toWhitelist != address(0), "VaultConfig:invalid address to whitelist");
        require(!isWhitelisted[_toWhitelist], "VaultConfig:already whitelisted");
        isWhitelisted[_toWhitelist] = true;
    }

    function cancelWhitelist (address _toCancel) external onlyApprover {
        require(_toCancel != address(0), "VaultConfig:invalid address to cancel whitelisting");
        require(!isWhitelisted[_toCancel], "VaultConfig:address not whitelisted before");
        isWhitelisted[_toCancel] = false;
    }

    function bulkWhitelist (address [] calldata _toWhitelists) external onlyApprover {
        for (uint256 i = 0; i < _toWhitelists.length; i++) {
            require(_toWhitelists[i] != address(0), "!Zero");
            isWhitelisted[_toWhitelists[i]] = true;
        }
    }

    function bulkCancelWhitelist (address [] calldata _toCancel) external onlyApprover {
        for (uint256 i = 0; i < _toCancel.length; i++) {
            require(_toCancel[i] != address(0), "!Zero");
            isWhitelisted[_toCancel[i]] = false;
        }   
    }

    function addVault (address _vault) external onlyGov {
        for(uint256 i = 0; i < vaults.length; i++) {
            require(_vault != vaults[i], "Vault already added");
        }
        vaults.push(_vault);
        //Default fees: they are also used in tests
        performanceFees[_vault] = 1000; //10%
        managementFees[_vault] = 200; //2%
        partnerFees[_vault] = 0; //2%

        emit VaultAdded(_vault);
    }

}